# OMFrontend.jl — Agent Guide

Entry point for AI agents working in this repository. Read this fully before editing. All file references below are relative to the repository root (`OMFrontend.jl/`).

## What This Package Is

OMFrontend.jl is an experimental Julia port of the OpenModelica New Frontend (NF). It parses Modelica source, lowers it to SCode, then instantiates the SCode into either FlatModelica or DAE form. It is the parsing/typing/flattening stage of the OM.jl compiler stack and is consumed by OMBackend.jl downstream.

The package is intentionally low-level. End users typically invoke it through OM.jl. Within OM.jl, OMFrontend output is the input to BDAE and SimCode lowering, so changes here have direct effects on backend behaviour even though backend code is not part of this repository.

## Source Layout

- `src/OMFrontend.jl` — outer module `OMFrontend`. Public API: `parseFile`, `translateToSCode`, `instantiateSCodeToFM`, `instantiateSCodeToDAE`, `flattenModel`, `flattenModelWithMSL`, `flattenModelWithLibraries`, `loadLibrary`, `loadPackageDirectory`, `enableDumpDebug`, `disableDumpDebug`, `toString`, `toFlatModelica`, `exportDAERepresentationToFile`.
- `src/main.jl` — inner module `Frontend`. The pipeline lives here. It includes everything under `src/Util/`, `src/FrontendUtil/`, `src/FrontendInterfaces/`, and `src/NewFrontend/`.
- `src/Util/` — generic utilities ported from MetaModelica (Pointer, BaseHashTable, BaseAvlTree, ErrorExt, etc.). Submodules of `Frontend`.
- `src/FrontendUtil/` — `Prefix`, `Util`, `FrontendUtil` glue.
- `src/FrontendInterfaces/` — `NFAlias`, `NFInterfaces` thin wrappers and re-exports.
- `src/NewFrontend/` — the actual NF port (~77 files, prefix `NF`). The hot path lives here. Notable files:
  - `NFFlatten.jl`, `NFInst.jl`, `NFTyping.jl`, `NFEvalConstants.jl` — pipeline phases.
  - `NFClassTree.jl`, `NFClass.jl`, `NFComponent.jl`, `NFInstNode.jl` — class and component representation.
  - `NFExpression.jl`, `NFSubscript.jl`, `NFCall.jl`, `NFBinding.jl` — expression, call, and binding ASTs.
  - `NFConvertDAE.jl` — final lowering to `DAE` data structures from DAE.jl.
  - `NFPerfHelpers.jl` — `mapPreservingEq` and `reuseIfRefEqual` performance helpers.
- `src/AbsynToSCode.jl`, `src/SCodeUtil.jl`, `src/AbsynUtil.jl` — Absyn and SCode helpers used during translation.
- `src/GUI_API.jl`, `src/ZeroMQ.jl`, `src/Corba.jl` — IPC and GUI integration points (not part of the core flatten path).
- `test/` — see "Tests" below.

## Pipeline

```
.mo source
  └─► OMParser              -> Absyn program        (parseFile)
        └─► AbsynToSCode    -> SCode program        (translateToSCode)
              └─► NF instantiate / type / flatten -> FlatModel       (instantiateSCodeToFM)
                                                  └─► DAE form       (instantiateSCodeToDAE)
```

The entry helpers `flattenModel`, `flattenModelWithMSL`, and `flattenModelWithLibraries` are convenience wrappers that compose those steps.

## Performance Metric: Allocations, Not Wall Time

This applies specifically to the OMFrontend flatten path. Other stages (backend lowering, simulation runtime) measure differently.

When measuring an OMFrontend change, the deterministic signal is `@time`'s allocation count and bytes, not seconds. Wall time on a single run is dominated by GC scheduling noise and can vary 30%+ between identical runs.

Workflow:
- Pick a representative MSL model (for example `Modelica.Mechanics.MultiBody.Examples.Elementary.DoublePendulum`).
- Call the flatten entry once to warm precompile, then `@time` it.
- Suppress the printed flat model when timing in the REPL: `@time (flatten(...); nothing)`. Otherwise the flat-Modelica dump scrolls the timing line out of the buffer.
- Compare allocation counts before and after a change. A real OMFrontend perf win shows up as fewer allocations and/or fewer bytes. Identical allocation counts mean the change is wall-time neutral or only affects JIT or GC behaviour.

Repository convention: when discussing "frontend perf", the headline number is allocation count of the flatten pipeline measured this way. Do not report wall-clock time as the headline. Report allocation count and bytes, and only mention wall time if it correlates.

Hot allocation sources to scrutinise in the `instantiate` path:
- `Pointer.create(...)` calls inside per-component loops (`src/NewFrontend/NFClassTree.jl:1020, 1023, 1044, 1076`). One allocation per component per pass.
- `pushfirst!` and `prepend!([x], list)` patterns. Both are O(N) per call and produce O(N²) total allocations. See `src/NewFrontend/NFClassTree.jl:1077` and `:808` for prior fixes.
- `Cons{T}(head, tail)` accumulators in `MetaModelica.list` chains. Each cons cell is a heap allocation. Converting to `Vector{T}` with `push!` plus a final `reverse!` collapses N small allocations into one Vector allocation.
- Eager string concatenation in error paths. `getInstanceName() + " miscounted ..." + name(clsNode)` allocates the message string even when the assert does not fire. Wrap in a guarded branch where the cost matters.

`--track-allocation=user` and `Profile.@profile` can produce stale `.mem` files when precompiled methods are not re-instrumented, and the profiler may hang on long flatten runs. The reliable workflow is `@time` with two warm runs and a sequence of code-review-driven fixes verified by allocation-count delta.

## Helper Pattern Caveats

The helpers `mapPreservingEq` and `reuseIfRefEqual` live in `src/NewFrontend/NFPerfHelpers.jl` and are loaded at the top level of module `Frontend` via `src/main.jl`.

### `reuseIfRefEqual` and parametric wrapper types

`reuseIfRefEqual(unchanged, orig, new, makeNew)` is safe ONLY when `unchanged` and `makeNew(new)` produce values of the same concrete (non-parametric) type, so the inferred `Union` return widens to a single concrete type at the caller.

- Sites where this is true and the helper helps: `CALL_EXPRESSION`, `CREF_EXPRESSION`, `ALG_TERMINATE`, `ALG_NORETCALL`.
- Sites where it is NOT, and the helper boxes and explodes allocations 2–3×: every `SUBSCRIPT_INDEX{T <: Expression}` and `SUBSCRIPT_UNTYPED{T <: Expression}` pattern in `src/NewFrontend/NFSubscript.jl`. Keep the inline `if referenceEq(...) ... end` shape there.

Empirical finding: applying the helper to `mapShallowExp` and `mapExp` in `NFSubscript.jl` increased one representative flatten run from roughly 8 M to roughly 22 M allocations. Reverting brought it back. Rule of thumb: before refactoring an arm to use `reuseIfRefEqual`, check whether the wrapper struct is parametric (`struct X{T <: Y}`). If yes, leave the inline pattern alone.

### Helper visibility from submodules

`mapPreservingEq` and `reuseIfRefEqual` are visible in the top-level `Frontend` module. They are NOT visible inside `Frontend`'s submodules (for example `LookupTree`, `DuplicateTree`, `LookupTreeS`, the various `Hash*` modules). Calling them from a submodule produces `UndefVarError: reuseIfRefEqual`.

To use them in a submodule, either keep the inline `if referenceEq(...) ... end` pattern, or explicitly import via `import ...reuseIfRefEqual` if DRY across submodule boundaries is really needed. The import path is brittle and these submodule sites are typically not on the allocation hot path.

## Recently Fixed Bugs Worth Knowing

### `TYPES_VAR` stale 6-arg call

- Symptom: `MethodError: no method matching TYPES_VAR(::String, ::ATTR, ::T_REAL, ::UNBOUND, ::Bool, ::Nothing)`.
- Root cause: `DAE.TYPES_VAR` has 5 fields. The OpenModelica source had a 6-field variant with an extra `bind_from_outside::Bool`. The sibling function `makeTypeRecordVar` at `src/NewFrontend/NFConvertDAE.jl:1679` correctly omitted the extra arg. `makeTypeVar` at `src/NewFrontend/NFConvertDAE.jl:1648` still passed `false,` as a stale 5th arg.
- Fix: removed the stale `false,` line at `src/NewFrontend/NFConvertDAE.jl:1653`.

### Uniontype dotted-accessor pattern

- Symptom: `FieldError: type DataType has no field 'X'` where X is a record variant name.
- Cause: OpenModelica source uses `Module.Uniontype.Variant(...)` (for example `DAE.Element.TERMINATE(...)`). The Julia port via `@Uniontype X begin @Record Y ... end` flattens records into the enclosing module, so `Y` is `Module.Y`, NOT `Module.X.Y`.
- Fix pattern: drop the uniontype prefix (use `DAE.TERMINATE`, not `DAE.Element.TERMINATE`). Valid exception: `DAE.ClassInf.RECORD(...)` is a real nested submodule.

### `BINDING_EXP` subscript index in function body evaluation

- Symptom: Package constants like `Medium.h_default` are left unresolved in the flat model even though simpler constants (e.g. `Medium.T_default`) evaluate correctly. More specifically, any function that uses a package-level constant as an array subscript index (e.g. `X[Water]` where `Water` is a `constant Integer` in the package) silently fails to evaluate at compile time.
- Root cause: `applyIndexExpArray` in `src/NewFrontend/BindingExpression.jl:5420` has a malformed lambda in the `isBindingExp(index)` branch. Package constant bindings arrive wrapped in `BINDING_EXP` (the compile-time propagation wrapper), making `isBindingExp(index)` true. `bindingExpMap` then calls the lambda with ONE argument (the unwrapped inner expression), but the lambda was defined with TWO parameters `(exp, restSubscripts)`, causing `MethodError`. Additionally, `exp` in the lambda shadowed the outer array, and the call used keyword syntax on a positional-only function.
- Fix: one-line change at `src/NewFrontend/BindingExpression.jl:5420`. Change `(exp, restSubscripts) -> applyIndexExpArray(exp = exp, restSubscripts = restSubscripts)` to `ind -> applyIndexExpArray(exp, ind, restSubscripts)`. The outer `exp` (the array being subscripted) and `restSubscripts` are now correctly captured from the enclosing scope.
- Tests: `test/bindingExpTests.jl` with models in `test/Models/BindingExpFuncEval.mo`.

## Tests

Test entry: `test/runtests.jl`. The file `cd`s into `test/` so relative paths to `Models/`, `Equations/`, etc. resolve.

Test groups (top-level `@testset`s in `runtests.jl`):
- `scodeSanityTest.jl` — Absyn to SCode.
- `daeTests.jl` — SCode to DAE / FlatModel.
- `gui_api_tests.jl` — gated behind `OMFRONTEND_TEST_GUI_API=1` because of an outstanding `compileModel`/`isfile` mismatch.
- `frontendResultTest.jl` — flat model string match against expected output.
- `mslTests.jl` — exercise components from the Modelica Standard Library.
- `useOfMSLTests.jl` — user models that import MSL components.
- `dynamicOverconstrainedConnectorTests.jl` — overconstrained connector handling.
- `VSS/testVSS.jl` — variable structure systems extension.

To run the full suite from a cold start:
```
julia --project=. -e 'import Pkg; Pkg.test()'
```
From a warm REPL with the project activated:
```julia
include("test/runtests.jl")
```
The warm-REPL form keeps the precompile cache.

## Contribution Rules for Agents

These rules apply to any agent (Claude Code, Codex, or otherwise) operating in this repository.

### Never commit or open PRs without running the tests fully and locally

Hard rule. Do not run `git commit` and do not open a pull request unless ALL of the following are true:

1. The full test suite has been executed locally on the current branch via either `Pkg.test()` or `include("test/runtests.jl")` from a warm REPL with the latest source loaded.
2. All test sets passed. A `@test_broken` flipping to passing is acceptable; an unexpected regression is not.
3. The output of the run was inspected, not just the exit code. `runtests.jl` emits `@info` lines and per-set summaries that are easy to misread.

If running the suite is infeasible (sandbox restriction, missing dependency, partial environment), stop. Surface that fact to the maintainer and let them decide. Do not commit speculatively or open a PR labelled "tests not run yet".

The repository maintainer may override this on a per-task basis with an explicit instruction such as "commit without running tests". Absent that explicit override, the rule stands.

### Other process rules

- Read a file fully before editing it. Follow existing patterns and conventions.
- Prefer minimal, targeted changes over broad rewrites.
- Do not introduce backwards-compatibility shims, dead `_var` renames, or `// removed` markers. If something is unused, delete it.
- For OMFrontend perf claims, report allocation count and bytes, not wall time. See "Performance Metric" above.
- Do not speculate about why something happened. If a log file or test output exists, read it. Say "I do not know yet, let me check" instead of guessing.
- Do not restart a live Julia REPL unless asked. Use `Revise.retry()` first. Restarting throws away minutes of warm precompile.
- Reference files by repo-relative path with line number where applicable, for example `src/NewFrontend/NFConvertDAE.jl:1653`.

## Pointers Outside This Repository

- Parser: `OMParser` package.
- Absyn / SCode / DAE data structures: `Absyn.jl`, `SCode.jl`, `DAE.jl` packages.
- Downstream consumer: `OMBackend.jl`, which lowers OMFrontend output to BDAE and then to MTK / DifferentialEquations.jl. Bug reports that surface as "OMBackend fails on model X" frequently trace back to malformed `DAE.Exp` or `DAE.Element` produced here. When a backend bug points at OMFrontend output, dump the `(FM, funcs)` from `flattenModel` and inspect it before editing backend code.
