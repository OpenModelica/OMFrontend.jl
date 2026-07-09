# OMFrontend.jl Insights

Project continuity notes. Append verified, high-confidence findings only.

## HANDOFF (LIVE, 2026-07-04) — from a MMJLTranslator session (Claude Fable), read this first

Cross-repo handoff. The bulk of the recent work was in sibling repos; this note
lets a session started HERE (OMFrontend.jl) pick up the design-side work.

- **Full write-up:** `~/REPORTS/cuniontype-findings-2026-07-04.md` (Findings 1-5).
  Read it before touching uniontype representations.
- **What @CUniontype is:** a "compacted tagged struct" for self-recursive
  uniontypes (one concrete `NameData <: Name` + tag enum, instead of
  abstract-type + N records), so recursive fields become CONCRETE and the
  traversal spine is inference-friendly. Lives in
  `~/Projects/Julia/OM.jl/MetaModelica.jl` (branch `compacted-uniontype-tag-match`,
  LOCAL ONLY, not pushed): `src/union.jl`. Added this session: `isvariant` /
  `variantof` (isa/typeof equivalents), the `const isa = isvariant` module-shadow
  trick so raw `v isa VARIANT` keeps working, and undef-safe `@assign`/
  `Accessors.setproperties`. Suite 216/216. Inventory in
  `~/Projects/Julia/MMJLTranslator.jl/CUSTOM.md`.
- **Translator state (MMJLTranslator):** the generated NFFrontEnd ALREADY
  compacts `NFComponentRef` (the only compacted type; opt-in at
  `translation/translate_nffrontend.jl:43`, emitter
  `src/CodeGen.jl:4634/4651`). It fits because OMC's NFComponentRef is
  CREF + nullary EMPTY/WILD. Remaining translator win: the self-recursive field
  is emitted `restCref::NFComponentRef` (abstract) but is always a
  `NFComponentRefData`; concretize it (`src/CodeGen.jl:4690-4699`).
- **Design work owed HERE (OMFrontend.jl, free to redesign):**
  1. This repo's `NFComponentRef` (`src/NewFrontend/NFComponentRef.jl:45`) has an
     extra `COMPONENT_REF_STRING(name, restCref)` variant whose disjoint payload
     BLOCKS the prefix rule that lets the translator compact the OMC version.
     Drop/merge STRING into the CREF/EMPTY/WILD shape to make it compactable, OR
     use a union-of-fields generalization (Finding 4).
  2. Hot disjoint types `NFExpression` (`NFExpression.jl:56`, ~2222 refs) and
     `NFType` (`NFType.jl:43`, ~1066 refs) only benefit via the union-of-fields
     generalization; prototype on NFComponentRef first, measure cref-walk
     dispatch elimination, then decide.
- **The 100-model pipeline goal is NOT here** — it lives in
  `~/Projects/Julia/MMJLTranslator.jl` (RESUME STATE at top of its INSIGHTS.md:
  the 514-model old-backend survey was lost to a WSL reboot and needs relaunch;
  AoT plan in `~/REPORTS/omjlc-aot-compilation-plan-2026-07-04.md`). A session
  rooted here should NOT drive that pipeline; it drives the OMFrontend design.

## Julia techniques

### `Base.isbitsunion(T)` — verify before concretizing an abstract field to a union (2026-06-14)

When replacing an abstract field/value type with a small `Union{...}` to get
**inline storage** (no per-element heap box in arrays / `Dict` value arrays),
confirm `Base.isbitsunion(Union{...}) == true` BEFORE claiming a win. A "bits
union" is stored inline (one payload array sized to the largest member + a
1-byte type-tag array); if the predicate is false the union silently falls back
to boxed pointers and you gain nothing.

Hard gotcha (cost a wasted attempt): the union members must be **concrete isbits
types**. A union of *parametric, unbounded* structs is NOT a bits-union:

```julia
struct IMPORT{T}; index::T; end          # ...
Base.isbitsunion(Union{IMPORT, COMPONENT, CLASS, FAILED_LOOKUP})              # false  (members are UnionAlls)
Base.isbitsunion(Union{IMPORT{Int}, COMPONENT{Int}, CLASS{Int}, FAILED_LOOKUP}) # true   (pinned to Int)
# non-parametric `index::Int` structs -> also true
```

So: pin the type parameter to a concrete type (`{Int}`), or make the structs
non-parametric. Useful generally for any "tagged-value" type stored in a hot
container. Probe it in the REPL with throwaway structs (no recompile needed)
before editing the real types.

## Data structures

### LookupTree backed by `Dict` instead of an AVL tree (2026-06-14)

`src/NewFrontend/LookupTree.jl` was converted from a hand-rolled mutable AVL
(`NODE`/`LEAF`/`EMPTY` nodes) to `const Tree = Dict{Key,Value}` (`Key=String`,
`Value=Entry`). The public interface is unchanged — same module, same function
signatures (`new`/`add`/`get`/`getOpt`/`hasKey`/`fold`/`map`/`listValues`/… and
the `Entry` constructors), so all callers (`NFClassTree`, `NFBuiltin`,
`NFClass`, `DuplicateTree`) compile unmodified. The raw `NODE`/`LEAF`/`EMPTY`
constructions in `NFBuiltin` literal trees are preserved via **constructor
shims** that build/merge `Dict`s (height arg ignored), so `NFBuiltin` needed
zero edits.

Key correctness invariant: every iteration function (`fold`, `toList`,
`listValues`, `listKeys`, `forEach`, `mapFold`, …) sorts keys via the original
`keyCompare` (`stringCompare`) so iteration order reproduces the AVL's in-order
(sorted) traversal exactly. This guarantees deterministic, bitwise-identical
flat output even though `Dict` iteration order is hash-dependent. Do not remove
the sort: it is what keeps output reproducible.

Verified: fullRobot flat model bitwise-identical (md5 767d2bed, 4321 eq / 6607
var / 36 initEq); OMFrontend suite 305 pass / 1 broken / 0 fail (baseline);
fullRobot `@allocated` 220.6 MiB vs 222.6 cls-hybrid baseline (~0.9% lower),
stable across hot runs. Win is allocation-driven (no per-node boxes), modest
because per-scope trees hold few short-string keys; lookup is expected-O(1) in N
(open-addressing Dict) but O(L) in key length, so it does not asymptotically
dominate the AVL's O(log N) short-circuiting compares at these small sizes.

The same conversion pattern (preserve API, sort-on-iterate for determinism,
gate by flat-diff + suite) generalizes to the other ported AVL trees that are
lookup-only: `NodeTree`, `TypeTreeImpl`, `FunctionTreeImpl`, `ReplTree`,
`ParameterTreeImpl`, `DuplicateTree`. `ConstantsSetImpl` is NOT safe to
naive-swap — its `listKeys()` order sets flat-variable prepend order
(`NFPackage.jl:76-77`); convert only with an explicit sort to preserve order.

### Shared `baseDictTreeCode.jl` template + NodeTree/ParameterTreeImpl (2026-06-14)

`src/Util/baseDictTreeCode.jl` is a Dict-backed drop-in for `baseAvlTreeCode.jl`:
textually included into a tree submodule that has defined `const Key`/`const
Value`; `Tree = Dict{Key,Value}`; lookup/insert use the key's `hash`/`isequal`;
`keyCompare` and `addConflictDefault` are reassignable globals the includer
overrides after the include (mirrors the AVL template); iteration sorts by
`keyCompare` for deterministic order. `NodeTree` (NFInstNode.jl) and
`ParameterTreeImpl` (NFCall.jl) switched their include from `baseAvlTreeCode.jl`
to `baseDictTreeCode.jl`. Verified flat-identical (md5 767d2bed) + suite
305/1/0. **Allocation-neutral on fullRobot** (220.8 vs 220.6 MiB) — NodeTree is
built once (C_TOP_SCOPE inner/outer) and ParameterTreeImpl is function-eval-only,
so neither is hot for fullRobot; value is code-quality (Dict, concrete field),
not perf.

KEY-TYPE CONSTRAINT for this template: a plain `Dict` keyed on `K` needs
value-based `Base.hash(::K)`/`Base.isequal` consistent with `keyCompare`. Only
`String` keys have this for free. The remaining ported AVL trees key on
`Absyn.Path` (TypeTreeImpl/FunctionTreeImpl), `ComponentRef` (ConstantsSetImpl),
`InstNode` (ReplTree) — these have custom `hash(cref,mod)`/`isEqual`/`crefCompare`
etc. but NOT value-based `Base.hash`/`isequal`, so a plain Dict would key by
identity and silently corrupt. Converting them needs a contained key-wrapper
struct (Base.hash/isequal bridged to the custom fns) — viable but low value
(these trees are once-per-model or usually empty). `DuplicateTree` is
String-keyed but its trees are almost always empty (duplicates rare) → near-zero
win; left on AVL.

### Next direction (parked): concretize `LookupTree.Entry`

`Value = Entry` is abstract, so `Dict{String,Entry}` boxes every value entry.
`Entry` is morally a tag+Int. Making `IMPORT`/`COMPONENT`/`CLASS` non-parametric
`index::Int` (isbits) and setting `Value = Union{IMPORT,COMPONENT,CLASS,
FAILED_LOOKUP}` (a small all-isbits union) would let the Dict store values inline
(bits-union), removing a per-entry box — likely a larger win than the tree-node
change since it is per-entry. Interface-preserving (types stay distinct so
`@match`/`isImport`/`index` still work). Verify `Base.isbitsunion(Value)` and
that all `COMPONENT(...)` args are `Int` before claiming the win. Gate as usual.

## Separate-instantiation flatten + JSON/ATD export (2026-06-21)

### Feature: per-component flatten for normal models (NF_SEPARATE_INSTANTIATION)
Normal (non-`structuralmode`) models can now be flattened so each TOP-LEVEL
component becomes its own entry in `FLAT_MODEL.structuralSubmodels`, reusing the
VSS storage that OMBackend's `BDAECreate.createEqSystems` already turns into a
separate `EQSYSTEM` per submodel (index reduction runs per component, no backend
change).
- Flag `Flags.NF_SEPARATE_INSTANTIATION` index 186 in `src/Util/Flags.jl`; also
  appended to `allDebugFlags` in `src/Util/FlagsUtil.jl` (must stay index-sorted).
- Decision site `flattenComponent` in `src/NewFrontend/NFFlatten.jl`. An
  `isTopLevel::Bool` kwarg is threaded `flatten`(true) -> `flattenClass`(false) ->
  `flattenComponent`. Split when
  `isStructuralMode || (isTopLevel && Flags.isSet(NF_SEPARATE_INSTANTIATION))`;
  the recursive split `flatten(...; isTopLevel=false)` so the flag does NOT cascade
  (one-level split, matches the backend's one-level limit).
- Public API mirrors `scalarize`: `separateInstantiation=false` kwarg on
  `instantiateSCodeToFM`/`flattenModel`/`flattenModelWithLibraries`, plus
  `enable/disableSeparateInstantiation()`. Default OFF, so other tiers unaffected.
- Verified on `test/Models/CoupledPenduliNormal.mo`: off=0 submodels, on=3
  (`[p1,p2,tb]`), no leak to later flattens; top level keeps only the 3 coupling
  equations. Tests `test/separateFlattenTests.jl` (wired into `runtests.jl`).

### JSON exporter rename + ATD schema export
- `exportFlatModelJSON`/`...FromFile` are now overloads of `OMFrontend.exportJSON`
  (FlatModel form + from-file form), no deprecated alias.
- `StructuralModeJSON.ATD_SCHEMA` is the single source of truth (canonical OCaml
  ATD). `OMFrontend.exportATD(; output_dir, base_name)` writes it;
  `exportJSON(...; atd=true)` also emits `<base>.atd` and returns `atd_path`.
  `docs/structural_mode_json.atd` is regenerated from the const.

### Revise caveat in the warm REPL (this session)
Revise tracked edits to `src/OMFrontend.jl` and `src/Export/StructuralModeJSON.jl`
but NOT a new `const` in `src/Util/Flags.jl` nor signature edits in
`src/NewFrontend/NFFlatten.jl` (`Revise.errors()` empty, `revise(throw=true)` ok,
yet `flatten` kept old kwargs). Restart-free workarounds:
- New flag: `@eval OMFrontend.Frontend.Flags const NF_... = DEBUG_FLAG(idx, name,
  default, Gettext.gettext(desc))` (description type is `Gettext.TranslatableContent`);
  `@eval` patch `FlagsUtil.allDebugFlags`; then `FlagsUtil.resetDebugFlags()` to
  rebuild the cached debug-flag Vector (`FlagsUtil.set(newflag)` does
  `arrayGet(arr, index)` -> BoundsError until the Vector is regrown).
- Changed functions: `Meta.parseall` the file and `Core.eval` only the target
  `:function` exprs into `OMFrontend.Frontend` (avoids re-running the
  `FunctionTreeImpl` module block at the top of NFFlatten.jl).
Authoritative gate is still a FRESH-process full `runtests.jl` (AGENTS.md); the
warm-session pass used the force-eval workaround.

## Fixed: partial-class name lookup now rejects (OMC parity) (2026-06-21)
`UsePartialDefault` (replaceableTests.jl) calls `P.compute(time)` where `P` is a
`replaceable package P = AbstractFnPkg2` left at its partial default and never
redeclared, so `compute` is a `partial function`. This is invalid Modelica. OMC
(checked via OMJulia `instantiateModel`) rejects it:
`"P is partial, name lookup is not allowed in partial classes."` OMFrontend used
to reject it too but with an ugly internal assertion
(`__NOT_IMPLEMENTED__ got non-instantiated function` at `NFFunction.collectParams`
:2691).
- Root cause: `Error.LOOKUP_IN_PARTIAL_CLASS` (Error.jl:891, message 107) was
  defined in the port but NEVER wired into the lookup path.
- Fix: in `lookupCrefInNode` (`src/NewFrontend/NFLookup.jl`, the qualified-cref
  recursion into a package), after `scope = instPackage(node)`, guard
  `if node isa CLASS_NODE && isPartial(scope)` ->
  `Error.addSourceMessageAndFail(Error.LOOKUP_IN_PARTIAL_CLASS, list(scopeName(scope)), sourceInfo())`.
  Used `sourceInfo()` (as at NFLookup.jl:684) because `lookupCref` has no `info`
  param to thread (threading would cascade through many callers); message text
  matches OMC, only the bracketed location points at compiler source.
- Why it does NOT break MSL/redeclared partials: a redeclared `Medium`/`P`
  resolves to its concrete target via `instPackage` BEFORE this lookup, so
  `isPartial(scope)` is false there; the guard only fires for a genuinely
  unredeclared partial default. Type refs (`Medium.AbsolutePressure`) go through
  `lookupName`/`lookupClassName`, not `lookupCrefInNode`, so they are unaffected.
- Test: `replaceableTests.jl` testset changed from `@test_broken begin flatten;
  true end` to `@test_throws MetaModelica.MetaModelicaGeneralException
  _flattenFM_replaceable("UsePartialDefault", ...)` (`fail()` throws
  `MetaModelicaGeneralException`; `instClassInProgramFM` prints the message then
  `rethrow()`s).
- Verified: FRESH-process full `runtests.jl` = 361 Pass, 0 Broken, 0 Fail (was
  360 Pass + 1 Broken). The lone `@test_broken` is gone.

## @CUniontype migrations: playbook, macro fixes, perf findings (2026-07-05)

Applied `@CUniontype` (MetaModelica.jl `src/union.jl`) to three recursive
frontend types. All gated by full `runtests.jl` (361 Pass) + MetaModelica
(216 Pass). Baseline DoublePendulum flatten: 2,507,738 allocs / 77.15 MB / 0.93s
(`@timed` alloc count is the deterministic metric).

### Migration playbook (mutable AVL / recursive tree -> @CUniontype)
Verified on DuplicateTree (`NFClassTree`/`DuplicateTree.jl`) and ModTable
(`NFModTable.jl`), which share the `NODE(key,value,height,left,right)/LEAF(key,
value)/EMPTY()` shape (a prefix chain: EMPTY K=0, LEAF K=2, NODE K=5):
1. Type decl `abstract type + mutable NODE/LEAF + EMPTY` -> `@CUniontype Tree
   begin EMPTY(); LEAF(...); NODE(...) end` (empties first so the shared field
   order is anchored by the widest variant).
2. In-place `setfield!` (`tree.left = ...`, `outTree.height = ...`, map/mapFold's
   `outTree.value = ...`) -> functional reconstruction returning a new NODE/LEAF.
   `balance`/`add` insert paths rebuild + `balance(NODE(...))`; conflict paths
   return unbalanced.
3. `x isa NODE/LEAF/EMPTY` -> `isvariant(x, VARIANT)` (verified allocation-free,
   constant-folds; `MetaModelica` is `using`-ed so `isvariant` is in scope).
4. Remove per-variant dispatch methods (`get(tree::EMPTY, ...)` etc.); guard the
   generic method with `isvariant(tree, EMPTY)` first.
5. AUDIT CALLERS for "rebuild-but-discard": functional map/add returns a NEW tree;
   a caller that discarded the result and relied on in-place mutation silently
   loses the update. This is a REAL latent bug the migration exposes — found +
   fixed `replaceDuplicates` (`NFClassTree.jl:831`) which computed a rebuilt tree
   then `return tree` (the original). ModTable callers (`NFModifier.jl:221,354`)
   already used results functionally.

### Macro fixes made to @CUniontype (all gated by MetaModelica 216 Pass)
- **Concrete spine**: macro stored field types verbatim, so a self-reference
  `restCref::Name` field stayed ABSTRACT — the headline benefit (concrete
  recursive spine) was not delivered. Added `_substSelfType` to rewrite the
  union name -> `NameData` in struct fields + inner-ctor arg types. Now
  `fieldtype(...,:restCref) === NameData`.
- **Untyped inner ctors**: inner constructors typed their params with the field
  types, so `NameData(tag, ..., subscripts::List{Subscript})` rejected a concrete
  `Cons{SUBSCRIPT_INDEX{...}}` arg (Julia parametric invariance). Made inner-ctor
  field params UNTYPED so `new` converts, matching the default constructor.
- **Nullary singletons**: a nullary variant `EMPTY()` heap-allocated a full
  NameData each call (a zero-field struct is a free singleton). Macro now emits
  `const _NameData_VARIANT_SINGLETON = NameData(tag); VARIANT() = <singleton>`.
  Keeps them in the tag scheme (spine stays concrete) AND allocation-free.
  Cannot instead redefine the generated ctor in the user module: "Method
  overwriting is not permitted during Module precompilation".

### Include-order gotcha (cross-file @CUniontype)
`@match` decides compacted-vs-record at EXPANSION time via
`isdefined(calling_module, T)` (`matchcontinue.jl:286`). A file included BEFORE
the `@CUniontype` registration compiles its cref patterns as record patterns ->
runtime `evaluated_fieldnames(CONSTRUCTOR)` MethodError (the variant is a
function, not a type). Self-contained modules (DuplicateTree, ModTable) are
immune (macro + matches in one file). For NFComponentRef (matched in ~15 files),
moved its include (`main.jl`) to just before `NFCeval.jl` (the first cref
matcher; abstract type is forward-declared in `NFInterfaces.jl` so field-type
deps are fine). Qualified patterns (`Mod.NODE(...)`) also fall back to the record
path (`T isa Symbol` is false) — so keep cross-module variant matching out, or
the type must resolve.

### Perf results (nuanced — immutability is the driver, not raw allocs)
- **DuplicateTree**: neutral on DoublePendulum (~2.51M, duplicates rare there).
- **NFComponentRef** (WILD/EMPTY/CREF; dropped the never-constructed
  COMPONENT_REF_STRING; merged variant-dispatch methods `toListReverse`/
  `appendCref!`/`instCrefSubscripts`/`typeCref2`/`mapCref!` into one +
  `isvariant`; 26 `isa` sites converted): DoublePendulum REGRESSED to ~2.58M
  allocs / +36% time. Short cref chains do not amortize the concrete-spine win,
  and immutable `referenceEq` (`=== `) became value-egal (recursive) vs pointer.
  KEPT anyway per @JKRT: DoublePendulum understates deep-hierarchy models, and
  immutability's structural wins (no aliasing bugs — same class as the
  replaceDuplicates bug; safe sharing; interning potential; concrete downstream
  inference) justify a per-construction alloc tick. Nullary-singleton caching
  only recovered ~9k allocs (WILD/EMPTY are not the bulk).
- After compaction, crefs are ONE concrete type, so `@nospecialize(cref::
  ComponentRef)` (added originally to avoid 4-subtype specialization blowup) is
  obsolete — removed from 16 functions (NFComponentRef/NFCeval/NFFlatten/
  NFTyping/NFFunction) to let inference specialize.

### Env fix (needed so test harness `Pkg.resolve()` at runtests.jl:14 works)
Bumped `ImmutableList` compat `"0.3" -> "0.3, 0.4"` (installed is 0.4.0) in
MetaModelica/DAE/DoubleEnded/SCode `Project.toml`. Config files — do NOT commit
without explicit @JKRT instruction.

### Fit rule (confirmed)
@CUniontype fits PREFIX-CHAIN recursive types (empty/leaf/node). It does NOT fit
field-DISJOINT unions (NFExpression ~35 variants, NFType, Call, Binding,
Statement, Equation) — those are the allocation-dominant unions but need a
disjoint-variant macro mode. Remaining good-fit targets: the `baseAvlTreeCode.jl`
map-tree family (AvlTreeString/StringString/CRToInt) — same playbook.

## OMFrontend instantiate/Simplify allocation profile + what is (not) reducible (2026-07-05)

Per-phase alloc breakdown of the flatten pipeline via `OMFrontend.ENABLE_EXECSTAT[]=true`
(wraps each `@EXECSTAT` phase in `@time`). DoublePendulum, ~2.55M allocs total:
Simplify 895k (35%) > instantiate 489k (19%) > typeClass 331k (13%) > scalarize
317k (12%) > instExpressions 206k > resolveConnections 147k > evaluate 76k >
collectFunctions 51k > flatten 36k. **Simplify, not instantiate, is the biggest.**

### `--track-allocation` .mem caveat (important)
The sibling `*.jl.905199.mem` files are CUMULATIVE over a large (whole-suite) run,
so their per-line byte ranking does NOT match a single model's per-phase
distribution. Fixes chosen off .mem hotspots kept being invisible on DoublePendulum
(e.g. the `VARIABLE(` .mem hotspot ~228k bytes is suite-cumulative; on DoublePendulum
the VARIABLE rebuild is tiny). Always MEASURE a candidate fix against the target
model's phase @time, not the .mem bytes.

### Instantiate allocations are largely IRREDUCIBLE (load-bearing sharing model)
`instantiate` (`NFClassTree.jl:946`) allocates, per element: one node + one
`Pointer{InstNode}` cell + `Vector{Pointer}` slices. This is load-bearing:
`old_comps` (`NFClassTree.jl:1006`) is the SHARED expanded-class-definition
component array — `clone` (`NFInstNode.jl:388`) only clones CLASS_NODEs, returns
COMPONENT_NODEs unchanged, so every instantiation of a class SHARES its definition's
component nodes. The fresh `comps` array at `:1037` + `setParentAndReplaceComponent`
copy exist because each instance needs its own `parent`. Mutating `c.parent` in place
(a tempting "CoW" fix) would CORRUPT the class definition across instances — UNSAFE.
The safe subset (unmodified TYPE_ATTRIBUTE nodes) is ALREADY shared via
`SHARE_ATTRS`/`FROZEN_ATTR_NODES` (`:1086`). InstNode redesign / `@CUniontype` are
both wrong here (mutable, aliased, parametric, identity-based; the box-on-share `cls`
hybrid `NFInstNode.jl:130-150` is a real, keep-it optimization).

### Simplify allocations are INTRINSIC (already reuse-aware)
The expression simplifier (`NFSimplifyExp.jl`) already uses `referenceEq` reuse
(`:163-165,:796,:815`), so DoublePendulum's 895k Simplify allocs are genuine
simplifications rebuilding CHANGED nodes, not wasteful re-creation. No cheap win.

### Verified small wins applied this session (all 361/361, zero downside)
- `NFSimplifyModel.jl:59` `simplifyVariable`: reuse `var` when `referenceEq(varBinding,
  var.binding)` instead of always rebuilding VARIABLE. Correct (simplifyTypeAttributes
  mutates in place). ~invisible on DoublePendulum, real for variable-heavy models.
- `NFClassTree.jl` `newEmptyClassTree`/`newEmptyFlatClassTree` replacing
  `deepcopy(EMPTY_*_TREE)` at `NFClassTree.jl:904`, `NFInst.jl:652` (cold paths:
  record constructors + external objects). deepcopy walks the whole graph; the fields
  are empty arrays + empty subtrees so a plain constructor call is equivalent.
- `lookupElementNode` (`NFClassTree.jl`): node-only sibling of `lookupElement` (no
  `ENTRY_INFO` wrapper) for the ~10 callers that ignore `isImport`. −5.4k allocs on
  DoublePendulum. The HOT lookups (`NFLookup` cref resolution) genuinely USE isImport
  and keep `ENTRY_INFO`, so the wrapper alloc there is irreducible.

### Meta-lesson
Allocation-hotspot agents/`.mem` correctly LOCATE bytes but their auto-suggested
fixes were mostly already-implemented, unsafe (aliasing), or invisible on the model.
OMFrontend's hot phases allocate primarily from intrinsic immutable-tree
reconstruction that the codebase already mitigates. Further real reduction needs
algorithmic change, not micro-guards.

## Simplify allocations are constant-folding of repeated pure calls, not node rebuilds (2026-07-05)

Correction to the note above. On DoublePendulum the `Simplify` phase is ~47% of
frontend allocations (1.63M of 3.45M). That cost is NOT immutable-tree rebuild.
Comprehensive `referenceEq` reuse added to every `simplify` reconstructor
(cref, subscripts, array, binary/unary/logic-binary/call-args, if, box, cast, unbox
in `NFSimplifyExp.jl` + `simplifySubscripts`/`simplifyList`) reduced the total by
under 1% (DoublePendulum 3,448,441 -> 3,424,825). So the equation/expression
reconstruction was never the bottleneck.

Where it actually is (verified by dissection, `scratchpad/dissect*.jl`): of the
1.63M, ~1.58M is in `simplifyVariables` (655 vars), and of THAT ~98.5% is two
variable bindings: `boxBody1.R.T` and `boxBody2.R.T`, each ~780k allocations.
Both are the identical constant call
`Frames.TransformationMatrices.from_nxy({0.5,0.0,0.0}, {0.0,1.0,0.0})` being
constant-folded (pure + all-literal-args -> `simplifyCall2` -> `evalCall`) into a
tiny 3x3 matrix. Evaluating one such nested MultiBody/Vectors function on constant
3-vectors costs ~780k allocs; the whole `from_nxy`/`normalizeWithAssert`/`cross`
call tree is interpreted symbolically.

Dissection trap: `simplifyFlatModel` does `@assign flatModel.equations = ...`,
which mutates the shared model in place. Stashing `flat_model` and re-simplifying
it measures re-simplification of ALREADY-simplified data (idempotent, ~40k), not
the real cost. Stash a `deepcopy` taken BEFORE the `Simplify` EXECSTAT line to
measure the true first-pass cost.

Fix shipped: a per-model constant-fold memo in `simplifyCall2`
(`const CONST_FOLD_CACHE = Dict{String,Expression}()`, keyed on
`toString(CALL_EXPRESSION(call))`, written only on successful `evalCall`,
`empty!`'d at the top of `simplifyFlatModel` in `NFSimplifyModel.jl`). Symmetric
models recompute identical constant folds once instead of once per binding.
DoublePendulum 3,424,825 -> 2,635,025 (-23.6% total / -47% of Simplify);
CauerLowPass and CoupledClutches unchanged (no repeated folds -> no benefit, no
harm). Gate: frontend 361/361 with cache + reuse enabled.

Remaining lever (not done): the SINGLE-fold cost (~780k allocs to evaluate one
constant `from_nxy`) is a `NFCeval` efficiency problem, not simplify. The cache
only removes the DUPLICATE folds. Reducing the first fold needs a leaner constant
array/function evaluator in `NFCeval.jl` (evalCall/ceval/evalArrayConstructor).

Measurement metric here: `instantiateSCodeToFM(name, LIB; scalarize=true)` alloc
count via `@timed` + `Base.gc_alloc_count`, min over 10 runs. MultiBody
(DoublePendulum) is the alloc-heavy case; analog/rotational models are 20-40x
lighter (70k-130k) and const-fold-cache-neutral.

## Root-cause fix: evaluate function-local mutable cells once (2026-07-05)

Follow-up to the const-fold note above. The single-fold cost (evaluating one
`from_nxy(constvec,constvec)` at ~780k allocs) was NOT intrinsic. Root cause was
in `NFCeval.jl` `evalExp_impl`, the `MUTABLE_EXPRESSION` arm: it evaluated a
function local/output variable's mutable cell but discarded the result. Function
locals reference each other (a dependency DAG), so a local referenced N times had
its whole binding subtree re-evaluated N times -> the DAG expanded into a tree and
re-evaluated combinatorially. One `from_nxy` fold: evalCall ~8835x, evaluateNormal
~4418x, for only 7 distinct evaluations.

Fix (`NFCeval.jl` MUTABLE_EXPRESSION arm): after evaluating the cell, write the
value back into the pointer (`P_Pointer.update`) when it changed. Repeated
references then read the cached value. Scoped to one function evaluation (the cell
is rebuilt per call by `createReplacements`); algorithm assignments overwrite the
cell so the cache is invalidated correctly. Local, no global cache, no keys.

Result: DoublePendulum 2,635,025 -> 1,909,098 (-27.5%; -44.6% from the original
3,448,441 baseline). Simplify phase 1.63M -> 110k (47% -> 6% of the frontend).
Analog/rotational models unchanged. Frontend 361/361. Committed cfc8352.

Why the earlier "global memo at evaluate()" prototype was wrong: it taxed EVERY
constant evaluation with a toString-key build; models with many small parameter
evals (CoupledClutches) or large array-arg evals (CauerLowPass) exploded to
29-65M allocations. The mutable-cell write-back is the correct layer -- it fixes
the re-evaluation at its source with zero per-call key overhead.

New DoublePendulum phase profile (~1.87M): instantiate 484k (25%), scalarize
439k (23%), typeClass 331k (17%), instExpressions 206k (11%), resolveConnections
147k (8%), Simplify 110k (6%). Simplify is no longer the bottleneck.

## instantiate is intrinsic: expansion already shared, clone is per-instance (2026-07-05)

Investigated whether `instantiate` (484k allocs, ~25% of the frontend on
DoublePendulum) can be sped up. Conclusion: no safe algorithmic win; it is
intrinsic. Evidence:

- 9,169 `instClass` calls collapse to 739 distinct `(classdef, modifier)` keys
  (97.5% repeats) -- but the repeats are CONTEXT-DEPENDENT, not context-free.
  Non-empty modifiers carry parent-scope crefs (`Real x(start=a+b)` resolves
  `a`,`b` per parent); `instClassDef(EXPANDED_DERIVED)` depends on `parentArg`
  and incoming `attributes` (`mergeDerivedAttributes(..., parentArg)`,
  `rootParent`). So result-caching is unsafe beyond the existing
  `PARTIAL_BUILTIN && isEmpty(modifier)` `INST_CACHE` (only 432 of 9,169 calls).
  The `isEmpty(modifier)` guard exists for this reason; do not widen it.
- The context-FREE part (class-definition expansion) is ALREADY shared. Measured
  `partialInstClass2` = 247 work-calls / 212 distinct defs, `expandClass2` = 217
  work-calls / 207 distinct defs -- i.e. ~230 expansions on ~210 defs, NOT 9,169.
  The `NOT_INSTANTIATED` guard in `partialInstClass` already caches it.
- So the 9,169 `instClass` calls do not re-expand; they CLONE the shared
  expanded definition (`instantiate` in NFClassTree.jl:946). Each component needs
  its own instance nodes (per-instance parent pointers, modifiers, types), so the
  clone is necessary and per-instance. That is the 484k.

Existing infra already present: `INST_CACHE`/`CACHE_INST` (builtin scalars),
`REINSTANTIATION_CLASSES` tracking, `SHARE_ATTRS`/`FROZEN_ATTR_NODES` (shared
immutable TYPE_ATTRIBUTE nodes), `dumpInstDiagnostics` (gated on
`OMFRONTEND_INST_PROFILE=true`). Diagnostic technique: instrument
`partialInstClass2`/`expandClass2`/`instClass` entry with counters keyed by
`objectid(definition(node))` to separate work-calls from distinct defs.

After the Simplify/Ceval fixes, the DoublePendulum top phases (instantiate 25%,
scalarize 23%, typeClass 17%) are all structural/proportional-to-model-size.
No further from_nxy-style pathological redundancy remains in them.

## @assign idioms (immutable-struct migration) (2026-07-05)

- `@assign x.f = v` (MetaModelica, `MetaModelica.jl/src/utilityMacros.jl:269`) uses
  `Accessors.setmacro` to create a NEW instance with `f` changed and rebind the local
  `x` (functional update). Works for BOTH mutable and immutable structs, so converting
  a bare in-place `x.f = v` to `@assign x.f = v` is testable without redefining the
  struct; flipping `mutable struct`->`struct` afterward is then a behavior no-op.
- Multiple field updates to the SAME struct are best handled with the BLOCK form
  `@assign begin x.f = a; x.g = b end` -- it reconstructs `x` once instead of
  allocating an intermediate per field. Use the block form ONLY when the assignments
  target the same variable/struct. When the targets are DIFFERENT objects/types
  (e.g. `attrs.variability = v` then `c.attributes = attrs`), use SEPARATE `@assign`
  statements -- the block form does not fit because each rebinds a different local.
- The rebind escapes `@match` arms and `if`/`begin` blocks to the enclosing function
  scope (empirically: existing setters use `@assign` inside a match arm and return the
  rebound value), so a setter that ends with `return component` / `updateComponent!(c, node)`
  installs the rebuilt value correctly.
- Migration workflow: flip the struct to immutable, run `using OMFrontend` + the test
  suite, and fix each `setfield!: immutable struct ... cannot be changed` runtime error
  by converting that bare mutation to `@assign` (block form when adjacent).

## Immutability migration: "immutable values, mutable identity cells" (2026-07-05)

Model for making the frontend node graph safer to reason about (and parallel-ready):
keep the node SHELLS (COMPONENT_NODE, CLASS_NODE) mutable as the identity/cell layer,
but make every PAYLOAD immutable. Payloads are threaded back into their (still mutable)
node via `updateComponent!` / `updateClass`, so no propagation-through-cells refactor is
needed. Each payload type is a separate, 361-gateable step.

Done:
- `Component` variants (TYPE_ATTRIBUTE, TYPED_COMPONENT, UNTYPED_COMPONENT, COMPONENT_DEF)
  immutable. Commit b7fa722. +~5% allocs on component-heavy models.
- `Class` variants (INSTANCED_BUILTIN, INSTANCED_CLASS, EXPANDED_DERIVED, EXPANDED_CLASS,
  PARTIAL_BUILTIN, PARTIAL_CLASS) immutable. Setters in NFClass.jl (setPrefixes,
  setRestriction, setType, setModifier) + NFTyping.jl (cls.ty) + NFInst.jl instExtends
  (cls.baseClass) converted to @assign.

Migration gotchas learned:
- The struct flip (mutable->struct) REQUIRES a Julia restart; the @assign conversions do
  not (testable via Revise first). Do conversions -> flip -> restart -> fix stragglers
  surfaced as `setfield!: immutable struct ... cannot be changed` runtime errors during
  the test suite (Revise-fixable once the module loads).
- A grep that excludes lines containing `::` MISSES sites like
  `cls.baseClass = instExtends(...)::CLASS_NODE`. Grep without the `::` filter.
- `Vector`/`ClassTree` fields on an immutable struct are fine to mutate in place
  (`dims[i] = x`); only reassigning the field (`cls.dims = v`) needs @assign.

## @CUniontype fit for the remaining unions (2026-07-05)

@CUniontype needs a PREFIX-CHAIN layout (each variant's fields = first K of a shared
field order, consistent TYPE per slot). Assessed:
- `InstNodeType`: NO. Position 1 conflicts (parent::InstNode in BASE/ROOT/REDECLARED_*
  vs ty::InstNodeType in DERIVED_CLASS); position 2 conflicts (definition::SCode.Element
  vs originalType::InstNodeType). Could be a HAND-WRITTEN single concrete tagged struct
  (enum tag + union of the few fields) for the inference win, but not via the macro.
- `ClassTree`: NO. Positions 2-3 type-conflict (Vector{InstNode} in PARTIAL/EXPANDED/FLAT
  vs Vector{Pointer{InstNode}} in INSTANTIATED); INSTANTIATED adds localComponents
  mid-layout; FLAT omits exts.
  BUT: CLASS_TREE_PARTIAL_TREE and CLASS_TREE_EXPANDED_TREE are STRUCTURALLY IDENTICAL
  (same 6 fields/types) -- they could collapse into one struct + a phase tag, removing a
  variant + its dispatch. Separable simplification.
- `InstNode`, `NFExpression`, `NFType`, `Call`, `Binding`, `Statement`, `Equation`: field-
  disjoint unions -> NO (established earlier). @CUniontype only fits recursive prefix-chain
  types (trees, cref chains: DuplicateTree, ComponentRef, ModTable done).

## NFType as a single concrete tagged struct (2026-07-05)

Collapsed the abstract `NFType` + 17 record variants into ONE immutable concrete
struct (`NFType`) + an `@enum NFTypeTag`, hand-written (the @CUniontype macro
rejects disjoint-field unions; NFType's variants have conflicting field-1 types).
Goal: make every `::NFType`/`::M_Type`-annotated field/arg across the frontend
CONCRETE (the recursive spine `ty`/`elementType`/`subscriptedTy`/`subs`/`types`
is `Union{NFType,Nothing}` / `List{NFType}`, not an abstract 17-way union) to cut
typing-inference/dispatch cost. Nullary types (TYPE_REAL/INTEGER/...) are interned
`const` singletons (zero alloc).

Mechanics that made the ~920 call sites mostly unchanged:
- Keep the old constructor NAMES as functions (`TYPE_ARRAY(et,dims)`, `TYPE_REAL()`).
- Keep the old field names as struct slots (`ty.elementType`, `ty.dimensions`, ...)
  so field access is untouched.
- Register `MetaModelica.compacted_tag_info(::typeof(TYPE_X)) = (NFType,:tag,NFT_X,
  (fields...))` per variant so `@match TYPE_X(...)`/`@match TYPE_X(f=..)=v` keep
  working (both positional and named).
- `x isa TYPE_X` -> `isvariant(x, TYPE_X)` (16 infix + 1 `isa(x,TYPE_X)` fn-form).

Structural gotcha (cost several restarts): NFType is forward-declared
`@UniontypeDecl NFType` (= `abstract type NFType`) in FrontendInterfaces/
NFInterfaces.jl:81, and `const M_Type = NFType` (NFAlias.jl) binds to it BEFORE
NFType.jl (line 154) loads (NFExpression.jl:153 needs `::NFType`). A concrete
struct cannot be forward-declared, so the struct+enum must be DEFINED at the
forward-decl site (NFInterfaces.jl:81), using the RAW interface type names
(M_Function/InstNode/NFComplexType/NFDimension -- the ComplexType/Dimension
aliases are not bound yet there). Constructors/singletons/registrations/methods
stay in NFType.jl.

THE load-bearing correctness fix -- `valueConstructor`: MetaModelica's generic
`valueConstructor(v) = hash(typeof(v))` discriminates uniontype variants by their
runtime TYPE. With one concrete NFType struct, `typeof` is `NFType` for EVERY
variant, so guards like `if valueConstructor(actual) != valueConstructor(expected)`
(NFTypeCheck array-vs-scalar cast routing, NFType.jl:316, NFClassTree.jl:1585)
silently collapse -> mismatched pairs skip the cast path and fall into the
array-only matcher (MatchFailure). Fix: `MetaModelica.valueConstructor(v::NFType)
= Int(v.tag)` (in NFType.jl). ANY future hand-written compacted uniontype needs
its own tag-based valueConstructor method. This is the #1 thing to check when a
single-struct compaction "loads fine but flattens wrong."

Vestigial parametric structs: a struct with a phantom `{T0<:NFType}` type param
whose field is `ty::NFType` (not `ty::T0`) breaks once NFType is concrete (the
custom `f(ty::T0) where T0<:NFType` outer constructor + explicit `X{TYPE_ENUM,...}`
call sites fail). Fix = make it non-parametric (ENUM_LITERAL_EXPRESSION). Structs
that actually USE the param (`ty::T0`: TYPED_DERIVED/ITERATOR_COMPONENT/
TYPE_ATTRIBUTE) are fine -- the default ctor infers T0=NFType.

Also fixed: `::TYPE_ARRAY`/`Tuple{...,TYPE_ARRAY,...}` type annotations ->
`::NFType` (TYPE_ARRAY is now a fn); a bareword `TYPE_STRING` passed as a value
-> `TYPE_STRING()`; two `const X::ENUM_LITERAL_EXPRESSION = ...` typed globals ->
drop the annotation (it was a UnionAll, now concrete).

DoublePendulum warm-flatten (best-of-10): allocs 2,047,555 -> 2,013,999 (-1.6%),
bytes +0.3% (wider data structs), wall noisy. The runtime-alloc win is modest;
the hypothesized inference/compile win is a cold-first-call/precompile effect not
captured by warm-flatten allocs.

## InstNodeType as a single concrete tagged struct (2026-07-05)

Same hand-written tagged-struct treatment as NFType (the 9 variants are field-
disjoint -- parent::InstNode vs ty::InstNodeType at position 1 -- so @CUniontype
rejects it). One immutable `struct InstNodeType` + `@enum InstNodeTypeTag`
(INTY_* tags), 4 nullable data slots (parent/definition/ty/originalType), nullary
variants (NORMAL_CLASS/BUILTIN_CLASS/TOP_SCOPE/NORMAL_COMP) as const singletons,
old constructor + field names kept, compacted_tag_info per variant, and the
mandatory `MetaModelica.valueConstructor(v::InstNodeType) = Int(v.tag)`.

MUCH smoother than NFType (loaded first try, no straggler cycles) because:
- Surface was smaller (120 sites vs 920; 5 isa vs 16; 0 phantom-param structs;
  0 typed consts; 0 bareword-as-value).
- InstNodeType is referenced ONLY in NFInstNode.jl + NFInst.jl (both at/after the
  NFInstNode include), so the @UniontypeDecl forward-decls (NFInterfaces.jl:53 AND
  NFInstNode.jl:36) were NOT load-bearing -- just removed them and defined the
  concrete struct in-place at the top of NFInstNode.jl (no forward-decl-site
  gymnastics like NFType needed). Kept `@UniontypeDecl InstNode` (37) since
  InstNodeType.parent references the still-abstract InstNode.
- All NFType lessons applied upfront (valueConstructor, isa->isvariant).

Playbook for the next hand-written compaction: (1) check where the type is first
USED vs defined -- if not used before its own file, skip the forward-decl-site
trick; (2) keep constructor + field names; (3) singletons for nullary; (4)
compacted_tag_info per variant; (5) ALWAYS add the tag-based valueConstructor;
(6) convert isa->isvariant; (7) check phantom {T<:ThisType} params, typed consts,
bareword-as-value, ::variant annotations.

## InstNode as a single concrete (mutable) tagged struct — Step 1 (2026-07-05)

Collapsed the 9 InstNode variants (EMPTY/VAR/EXP/IMPLICIT_SCOPE/NAME/REF/
INNER_OUTER/COMPONENT/CLASS) into ONE mutable tagged struct + @enum InstNodeTag,
so every ::InstNode annotation is concrete. KEPT MUTABLE for Step 1 (identity/
pooling/box-on-share preserved; in-place mutations untouched). Both InstNodeType
and InstNode structs live at the forward-decl site (NFInterfaces.jl) BEFORE the
NFType struct, because NFType.cls::InstNode references InstNode. Mutual recursion
broken by typing InstNodeType.parent::Any. Payload leaf slots (cls/definition/
exp/caches) are Any to keep NFInterfaces dependency-light; graph-spine slots
(parentScope/parent/inner/outer/locals::InstNode, nodeType::InstNodeType,
component::Component) stay concrete.

TWO load-bearing root-cause fixes (each fixed a whole cluster of failures):

1. P_Pointer.create/createImmutable use `supertype(T)` to pick the pointer's
   type parameter. For a concrete VARIANT (old CLASS_NODE) supertype was the
   abstract InstNode -> Pointer{InstNode}. For the concrete InstNode struct,
   supertype(InstNode)=Any -> Pointer{Any}, which will NOT convert into a
   Vector/List{Pointer{InstNode}} (Ref is invariant). Symptom: `Cannot convert
   Base.RefValue{Any} to InstNode` in insertGeneratedInners and every node-cell
   container. Fix: pin them --
   `P_Pointer.create(data::InstNode) = P_Pointer.Pointer{InstNode}(data)` (and
   createImmutable). This one fix cleared 13 of 18 gate errors.

2. refCompare(node1,node2) (the ONLY keyCompare for ReplTree, an AVL keyed by
   InstNode) compared nodes by PAYLOAD pointer
   (Util.referenceCompare(node.component/_clsVal(node))). Payload pointers are
   unstable (payloads get replaced by updateComponent!/setBinding) and can
   collide across distinct nodes -> AVL ordering corrupts -> ReplTree.get fails
   with a key-not-found `fail()` (seen as MetaModelicaGeneralException in
   evaluateRecordConstructor). Fix: compare by NODE identity (stable + unique for
   the mutable struct): `node1===node2 ? 0 : cmp(objectid(node1),objectid(node2))`.
   Cleared the 5 record/function-eval errors (ArmatureStroke, Fluid HeatingSystem/
   HeatExchanger/BranchingDynamicPipes/Surfaces).

Generic lesson for collapsing an abstract variant type to a concrete struct:
grep for `supertype(T)` pointer/box helpers and payload-pointer comparisons
(unsafe_pointer_from_objref / referenceCompare) keyed on the type -- both silently
break because the concrete type's supertype is Any and its instances are one type.

Debugging note: run models DIRECTLY (flattenModelWithMSL(name; MSL_Version=...))
not via runtests -- a buggy model can hang the whole suite. MSL 3.2.3 vs 4.0.0
example models differ; try 3.2.3 for the mslTests set. Use a ~3min per-probe
interrupt heuristic.

## InstNode immutability exploration -> mutable+const+concrete (2026-07-06)
Tried making InstNode a fully immutable `struct` (component/cls as Pointer cells,
getproperty for reads, @assign setters). It is CORRECT (immutability is safe) but
SLOW on modifier-heavy models (e.g. Modelica.Electrical.Analog.Examples.AmplifierWithOpAmpDetailed
~112s): immutable copies defeat the `referenceEq` structural-sharing shortcuts in
ModTable/merge, so trees get rebuilt instead of reused. A non-allocating spin earlier
was a real bug (setNodeType/setParent minting fresh cells) fixed by using @assign
consistently; after that it merely got slow, not stuck.
Landed instead on the workable state: `mutable struct InstNode` with `const` on the 11
never-mutated fields (tag, varPointer, exp, parentScope, locals, index, innerNode,
outerNode, visibility, parent, caches) and concrete field types (no Any): varPointer
::Union{Base.RefValue,Nothing}, exp::Union{NFExpression,Nothing}, definition
::Union{SCode.Element,Nothing}, cls::Union{Class,Pointer{Class},Nothing}, caches
::Union{Vector{CachedData},Nothing}. InstNodeType.definition also concretized;
InstNodeType.parent stays Any (breaks the InstNodeType<->InstNode field cycle).
The 5 mutated fields (name, component, nodeType, definition, cls) stay non-const.
Verified 361/361 (2m07s). Only NFInterfaces.jl changed vs commit d92d570.

## Tagged-union conversions: registration ordering gotcha (2026-07-06)
When collapsing a @Uniontype into a single concrete tagged struct (Component,
ClassTree), the variant names become CONSTRUCTOR FUNCTIONS and @match relies on
`MetaModelica.compacted_tag_info(::typeof(CTOR))` being defined BEFORE the @match
macro expands (at include time of the using file). If not visible, @match falls
back to `value isa CTOR` which errors at runtime (CTOR is a function, not a type).
For ClassTree this forced moving NFImport + LookupTree/DuplicateTree/JLookupTree +
NFClassTree includes up (right after NFComponent in src/main.jl) so the registrations
precede NFRecord/NFInst/... which @match ClassTree. Component did not need this (its
@match users all load after NFComponent). Pattern: keep the abstract supertype
(Component/ClassTree) so `::Type` fields forward-reference it (no NFType<->InstNode<->X
cycle, no Any); the single concrete subtype (ComponentImpl/ClassTreeImpl) is
tag-dispatched. ClassTreeImpl is mutable (trees mutate in place); classes/components
are a Union{Vector{InstNode},Vector{Pointer{InstNode}}} (INSTANTIATED uses Pointers).
Constructors must Base.convert vector args (Union fields do not auto-coerce like the
old concrete Vector{InstNode} fields did). All at 361/361; DP 2.07M / V6 27.31M allocs.

## Immutable InstNode: the four failure classes and their fixes (2026-07-08)

Continuing the functional rewrite (immutable `struct InstNode`, callers thread
rebuilt node shells back into ClassTree `Pointer` cells). The uncommitted state
had 162 test errors plus multi-minute hangs. Four distinct root causes, all
fixed; suite back to green (see per-fix locations below, verified by full
`include("test/runtests.jl")`).

1. **Component payload must be a shared cell, not an inline field.**
   Crefs/scopes/parents hold old node shells; with `component::Component`
   inline, `updateComponent!` rebuilds a shell nobody else sees (symptom:
   Ceval found RAW bindings, "failed on untyped binding" on Casc6).
   Fix: `COMPONENT_NODE.component` is `Pointer{Component}` (constructor boxes
   via `_compPayload`), mirroring OMC's `Mutable<Component>` and the earlier
   cls-cell commit d0e34e6. `updateComponent!` = cell write (identity
   preserved); `copyInstancePtr` shares the cell (redeclare aliasing);
   `setParentAndReplaceComponent` passes `_compVal` for a fresh cell (unique
   instance); shell rebuilds (setParent/setNodeType/withName) pass the cell
   through. Helpers `_compVal`/`_compSet!`/`_compRef` in
   `src/FrontendInterfaces/NFInterfaces.jl` next to the cls versions.

2. **Never reparent instantiated-tree children to the component instance.**
   `reparentInstantiatedClass` (added during the rewrite) rewired class-tree
   children (including exts) to the COMPONENT node, destroying lexical scoping
   for base-class lookup (symptom: "Lookup Error: TwoPin/OnePort/SO/Flange_b
   not found"). With payload cells the workaround is unnecessary; removed.

3. **Never `objectid`/order/hash an immutable InstNode.** For immutable
   structs `objectid` content-hashes the whole reachable immutable graph
   (parent chains + full SCode definitions), no short-circuit. Symptom:
   MultiBody.Parts.Fixed "hung" (10+ min in `refCompare` under ReplTree
   lookups; also `NFInline._bodyInfo` per-call-site keys). Fix: `_refId(node)`
   (`NFInterfaces.jl`) returns `objectid` of the payload CELL
   (component/cls/varPointer) — O(1), stable across shell rebuilds, equal
   exactly when two shells alias one instance. Used by `refCompare`,
   `refEqual` (cell `===`), `NFInline._bodyInfo`, lookup-cache key.
   Note `===`/`referenceEq` on nodes stays acceptable: jl_egal pointer-checks
   each field first, so rebuilt-shell comparisons short-circuit fast.

4. **Default `show` on node graphs never terminates.** Payload cells make the
   node graph cyclic; `Base.show_default` has no cycle detection, so any
   accidental print (Test.jl showing a failure value) spins forever (symptom:
   suite "hangs" right after printing a test-error trace). Fix: compact
   `Base.show(io, ::InstNode)` in `NFInterfaces.jl` printing tag+name only.

Also fixed while here: local-variable shadowing of the `node(cref)` accessor
in `collectExpConstants_traverser` (`NFPackage.jl:130`, "InstNode not
callable" on Fluid HeatingSystem) — a rename hazard to watch whenever the
functional rewrite introduces `local node =` into functions that also call
the `node(...)` accessor. Restored HEAD order in `typeComponentNode`
(`NFTyping.jl`): mark the component TYPED before typing children; cell writes
make the late classInst update cheap.

Debug technique: when a warm run "hangs", `kill -USR1 <julia-pid>` dumps all
task backtraces to the pane without killing the process; capture with a large
`tmux capture-pane -S -3000`. Ctrl-C does not land in non-yielding loops.

## Parallel instantiation: SHARE_ATTRS copy-on-write invariant is load-bearing (2026-07-08, Fable)

Root cause of the first true data race found while parallelizing sibling
component instantiation (OMFRONTEND_PARALLEL_INST fan-out in
applyLocalComponents_inst):

**Shared TYPE_ATTRIBUTE template nodes (SHARE_ATTRS) rely on mutators
REBUILDING the component node instead of writing the payload in place.** The
payload-cell design (COMPONENT_NODE.component as Pointer{Component}) made
`updateComponent!` write through the cell, silently breaking that contract:
`applyModifier -> componentApply(mergeModifier)` then performed a
read-modify-write on the SHARED attribute template (observed on `r.quantity`
of an SIunits type: two top-level workers, applyModifier from
instClassDef(EXPANDED_CLASS):1029 vs instClassDef(PARTIAL_BUILTIN):946, same
cell). Serially the repeated writes carry equal values and are invisible;
under threads the interleavings corrupt modifier chains, which later surfaces
far away as DUPLICATE_ELEMENTS_NOT_IDENTICAL on inherited duplicates of the
PartialShape family (color/height/shapeType with bindings from two different
usage contexts mixed into one tree).

Fix: `componentApply` (src/NewFrontend/NFInstNode.jl) does copy-on-write when
the new payload is a TYPE_ATTRIBUTE — rebuild the node with a fresh cell via
`withComponent` instead of `updateComponent!`; applyModifier's callers already
thread the rebuilt node back into the tree pointer (`P_Pointer.update` /
`replaceElementNode`), so other sharers keep the pristine template.

Debug methodology that cracked it (after read-site probes went in circles):
a write-site detector in `updateComponent!` recording, per payload cell, the
first writer's WORKER TOKEN and stack, reporting both stacks on a
foreign-worker write. Two lessons: (1) compare per-top-level-worker tokens
(task_local_storage, inherited into nested spawns at fan-out), NOT
Threads.threadid() — parent-before-spawn writes and nested workers produce
false positives otherwise; (2) `Base.join` must be qualified inside module
Frontend (NFSections.join shadows it) or the log record itself fails
silently. Also: Revise did not reliably apply edits in the threaded probe
session; each threaded iteration used a fresh `julia -t 8` start.

-- Fable, 2026-07-08

### Addendum: detector pitfall corrected the diagnosis (2026-07-08, Fable)

The SHARE_ATTRS entry above overstated its certainty. The original write-site
detector keyed cells by `objectid` WITHOUT holding the cell strongly; Julia
reuses freed addresses, so a dead cell's id can be recycled into a phantom
"conflict". After pinning the cell object in the detector entry, a full
threaded DoublePendulum run shows ZERO cross-worker writes to component or
class payload cells — yet the duplicate-mismatch failure persists (one tree
holding shapeType="sphere" from one worker and "cone" from another). The
componentApply copy-on-write for TYPE_ATTRIBUTE payloads is kept (it restores
the documented SHARE_ATTRS contract and is correct regardless), but the LIVE
race channel is elsewhere: current suspects are the Pointer{InstNode} TREE
SLOTS (applyModifier / replaceDuplicates / redeclare write rebuilt nodes into
whatever tree the lookup resolved into, possibly a scope shared between
workers) and in-place ClassTreeImpl array writes. Rule for any objectid-keyed
race detector on GC'd objects: pin the object in the map value, or every
report is suspect.

-- Fable, 2026-07-08

### Final root cause: in-place map! on the SHARED DuplicateTree children vectors (2026-07-09, Fable)

The actual bug behind every threaded DoublePendulum failure:
`replaceDuplicates2/3/4` (src/NewFrontend/NFClassTree.jl) resolved duplicate
entries with `map!(f, entry.children, entry.children)` — IN PLACE — while the
`children` vectors belong to the duplicates tree that `ClassTree.instantiate`
REUSES for every instance of a class (`dups` is passed through at the
INSTANTIATED_TREE construction). `DuplicateTree.map` itself is persistent, so
the tree LOOKED functional, but each instance's resolution clobbered the
shared vectors. Serially the last resolver was also the next reader
(replaceDuplicates directly precedes checkDuplicates), so nothing ever
surfaced; concurrently, checkDuplicates read kept/dup nodes resolved by a
DIFFERENT instance (observed: one tree comparing world's gravityArrowColor
node, worker token 6, against axisColor_z, worker token 1 — every write to
each cell single-worker, i.e. no cell race at all).

Fix: rebuild children vectors functionally in replaceDuplicates2/3/4 (a
commented-out line in replaceDuplicates3 shows this was once attempted).
Companion fix: SHARE_ATTRS attribute-template sharing is disabled while
PARALLEL_INST is on (`SHARE_ATTRS[] && !PARALLEL_INST[]` at the two
instantiate share sites) — shared templates receive per-context modifier
merges through the payload cell, which is only order-safe serially. The
broad componentApply copy-on-write attempt was REVERTED: typing-phase
componentApply callers rely on cell-write visibility through other aliases
(broke serial typeTypeAttribute).

Verified: DoublePendulum flattens green both serial and with 8-thread nested
parallel fan-out in one fresh process.

Diagnosis ladder that ended the hunt (after cell/pointer write detectors all
came back CLEAN with pinned objects): record the full write history
(worker token + call frames) per component cell, then print both nodes'
histories at the checkDuplicates mismatch — the two nodes were each
single-worker-owned, which pointed away from data races at cells and toward
shared CONTAINER mutation, found by reading the resolution code.

-- Fable, 2026-07-09

### Parallel instantiation slice 1 landed (2026-07-09, Fable)

Commit 73940e5 (on top of the immutable-InstNode checkpoint 2fbf72f).
Validation in ONE fresh `julia -t 8` process: five-model batch green in both
modes (EngineV6 serial 5.57s -> parallel 4.72s, 1.18x), full suite green
serially (361/361, 1m20s) AND with the flag on (361/361, 58.8s). Two more
races fixed since the duplicates entry above: (1) `expand`'s fast path must
require a fully expanded ELEMENTS tree, not just an EXPANDED_CLASS shell
(expansion publishes the shell before the tree; symptom: MatchFailure on
ClassTreeImpl in instantiate, EngineV6); (2) `generateInner` serialized under
the shared lock (check-then-create-then-add on the top-scope addedInner tree;
symptom: addConflictFail in NodeTree, MultiBody Loops.Utilities.Cylinder).

Speedup is modest because instantiation is one phase of the pipeline and the
fan-out is component-grained; the next levers are parallel typing/flattening
(user's roadmap: one top-level step at a time) and reducing the shared-lock
span (expansion currently serializes first touches).

-- Fable, 2026-07-09

### Lock-free cache reads for parallel instantiation (2026-07-09, Fable)

Commit 7aa4398. The 11k lock conflicts in V6's parallel instantiate phase were
the INST_CACHE read path (every default builtin scalar) plus instPackage
taking the shared lock on cache HITS. Pattern that fixed both, safely:
- INST_CACHE: `mutable struct` holding `@atomic dict::Base.PersistentDict`;
  readers `get(@atomic(c.dict), k, nothing)` with NO lock (immutable
  snapshot), inserts rebuild the dict copy-on-write under the shared lock so
  concurrent inserts are not lost. Same idiom is reusable for any read-hot,
  write-rare shared cache in the parallel frontend.
- instPackage: the CACHE_STATE_INSTANTIATED state is terminal, so that hit is
  served lock-free; all in-progress states still serialize.
Result on EngineV6/8 threads: conflicts 11003 -> 332, instantiate phase
1.78s serial -> 0.88s parallel (2.0x phase speedup), whole flatten 1.22x.
Suites green both modes (361/361 serial 1m37s, parallel 55.4s).

-- Fable, 2026-07-09

## Parallel typing slice: per-node claims, and where the shared state actually was (2026-07-09, Fable)

Typing is now fanned out at the root `typeComponents` call (`typeClass` passes
`fanOut = true`, `src/NewFrontend/NFTyping.jl`), with the same worker-token
scheme as instantiation. Unlike instantiation, typing one component routinely
reaches INTO other nodes (cref typing at `NFTyping.jl` `typeCrefDim`, binding
evaluation in `NFCeval.evalComponentBinding`, structural-param marking in
`NFInst.markStructuralParamsComp`, function typing in
`NFFunction.typeNodeCache`), so loop-splitting alone is unsound. The mechanism
that makes it sound is **per-node claim locks**: a sharded registry
`_TYPE_CLAIMS` in `src/NewFrontend/NFInst.jl` keyed by `_refId(node)` (payload
cell id), reentrant, acquired along dependency edges only. Valid models have an
acyclic dependency relation (a cycle is already a fatal recursion error
serially), so the wait-for graph cannot deadlock. Lock ORDER vs
`_INST_SHARED_LOCK` is uniformly claims -> shared lock, verified by the fact
that nothing under the shared lock (package first-touch instantiation,
`generateInner2`) evaluates bindings or types components.

Three rounds of failures pinned the real shared state; all three are load-bearing facts:

1. **Shared class nodes.** Derived/record class instances are NOT per-component
   clones; `typeClassType` (`EXPANDED_DERIVED` dims + `updateClass` collapse)
   and `typeComponents` (`TYPED_DERIVED` base-chain collapse) mutate class
   payloads shared by many components. Fix: claim `_refId(clsNode)` in both
   (`NFTyping.jl` wrappers `typeClassType`/`typeComponents`). Failure signature
   without the claim: spurious `CYCLIC_DIMENSIONS` from the
   `DIMENSION_UNTYPED(isProcessing = true)` marker observed cross-task
   (MultiBody BodyShape and friends).
2. **Aliased dimension vectors.** Even with class + component claims, one dims
   `Vector{Dimension}` can be reachable under two different claim keys
   (ForceAndTorque). Node-level claims cannot cover an aliased array; the fix
   claims the vector identity itself: `_typeClaim(objectid(dimensions))` in
   `typeDimension`. All dimension typing funnels through that wrapper.
3. **Claim contention, not work, was the first perf ceiling.** One global
   registry lock + claiming globally shared builtin class nodes gave 65,731
   lock conflicts in EngineV6 typeClass (1.68 s, slower than serial 1.23 s).
   Fixes: 64-shard claim registry, and terminal-state fast paths that skip
   claiming for read-only class states (`TYPED_DERIVED`, `INSTANCED_BUILTIN` in
   `typeClassType`; `INSTANCED_BUILTIN` in `typeComponents`). Result: 1,580
   conflicts, typeClass 1.11 s.

Other pieces: recursion depth counter moved to task-local storage
(`_typeDepthRef`; a shared counter sums concurrent chains and trips the limit
spuriously), max-depth diagnostic is a `Threads.Atomic{Int}`, and the claims
registry resets in `resetInstDiagnostics`.

Verified: full suite 361/361 serial AND 361/361 with `OMFRONTEND_PARALLEL_INST=true`
on `julia -t 8`; serial EngineV6 allocations unchanged (29.80 M). EngineV6 with
8 threads: whole flatten 6.25 s (was 7.34 s with typing contended), instantiate
1.09 s, typeClass 1.11 s. `resolveConnections` (2.2 s) is now clearly the
largest serial phase.

## resolveConnections 3x: exceptions as control flow in the union-find (2026-07-09, Fable)

EngineV6 `resolveConnections` went 2.2 s -> 0.66 s (fresh serial process, sub-step
timers now in `src/NewFrontend/NFFlatten.jl` behind `ENABLE_EXECSTAT`). The whole
win came from one defect: `ConnectionSets.find`
(`src/NewFrontend/NFConnectionSets.jl`) looked up the entry with
`sets.elements[entry]` inside try/catch and used the KeyError as the "not
found" branch. Every first-seen connector paid a thrown+caught exception; the
fix is a plain `get(dict, entry, 0)` sentinel.

Two constraints discovered while trying to also replace the string-based
Entry hash with a structural one (attempted, then deliberately reverted):

1. **The Entry hash order is load-bearing.** `extractSets` iterates
   `Sets.elements::Dict{Entry,Int}` to build the per-set connector lists, and
   the reference outputs in `test/frontendResultTest.jl` encode exactly the
   equation order that falls out of the current string-hash dict order.
   Changing the hash (or switching to insertion-order iteration) permutes the
   representative choice in `c1.e = c2.e`-style equations and fails 19-40
   reference tests. The string hash costs allocations, not time; do not swap it
   without also canonicalising the output order AND regenerating references in
   one deliberate change.
2. **Revise does not reliably apply edits to `Base.hash` methods in the nested
   `ConnectionSets` module.** The warm REPL kept running the old hash and showed
   the suite green while every fresh process failed. When touching nested
   frontend submodules, gate with a fresh process, not the warm REPL.

`hash(::ComponentRef, ::Int)` in `src/NewFrontend/NFComponentRef.jl` is now
structural (name + subscripts per level, no string rendering); it feeds the
`NFHashTableCG` bucket placement, which is order-neutral (BaseHashTable
iterates its insertion-ordered value array). The remaining sub-step cost is
`handleOverconstrainedConnections` (~0.5 s), which sits on the legacy
BaseHashTable closure-tuple machinery; replacing that table with a Dict is the
next candidate, a larger refactor.

Verified: fresh-process suites 361/361 serial and 361/361 parallel
(`OMFRONTEND_PARALLEL_INST=true`, `julia -t 8`).

## Overconstrained graph: Dict-backed tables, exception-free walk (2026-07-09, Fable)

`NFHashTableCG` / `NFHashTable` / `NFHashTable3` (about 2400 lines of ported
BaseHashTable closure-tuple machinery, used only by `NFOCConnectionGraph`) are
now ~45-line modules backed by `Dict{CrefHashKey, V}`. `CrefHashKey`
(`src/NewFrontend/NFComponentRef.jl`) wraps a cref with structural
hash/equality (`hashStructural` / `isEqual`). The graph walk itself had the
same exception-as-control-flow disease as ConnectionSets.find, seven times
over: `canonical` threw once per union-find root hit, `connectComponents`
carried two dead `@shouldFail` branches costing two exceptions per edge,
`connectCanonicalComponents` / `addPotentialRootsToTable` / `setRootDistance` /
`addConnectionRooted` / `getRooted` all used `@matchcontinue` fallthrough on a
failing `BaseHashTable.get`. All are plain Julia now (`getOrNothing` +
branches). Net effect: allocations down (1.61 M -> 1.38 M in the phase), wall
time roughly unchanged (~0.5 s) — the remaining cost is the whole-model
`evalConnectionsOperators` equation traversal, not the tables.

## Env-derived const Refs bake their precompile-time value (2026-07-09, Fable)

`const FLAG = Ref(get(ENV, ...) == "true")` at module top level evaluates
during PRECOMPILE and the Ref value is serialized; a later process with a
different environment silently gets the stale baked value. This made
`OMFRONTEND_PARALLEL_INST=true julia -t 8` run SERIAL after an env-less
precompile. Fix: re-read every env-derived flag in `OMFrontend.__init__`
(`src/OMFrontend.jl`): `PARALLEL_INST`, `CACHE_INST`, `ENABLE_EXECSTAT`.
Runtime `Ref` flips are unaffected. When adding an env-gated flag, wire it
into `__init__` or it only works by precompile luck.

## Test suite exercises parallel paths by default (2026-07-09, Fable)

`test/runtests.jl` sets `PARALLEL_INST[] = Threads.nthreads() >= 2` unless
`OMFRONTEND_PARALLEL_INST` is set explicitly, logs the mode, and warns when
single-threaded that parallel paths are not tested (recipe:
`Pkg.test("OMFrontend"; julia_args = ["-t", "auto"])`). Gates for all of the
above: 361/361 fresh `julia -t 8` (parallel by default) and 361/361 fresh
`julia -t 1` (serial).
