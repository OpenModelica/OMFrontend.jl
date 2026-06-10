"""
    @shareUnchanged orig Ctor(args...)

Rebuild `Ctor(...)` only if at least one mapped child actually changed under
`referenceEq`; otherwise return `orig` and preserve structural sharing.

Each constructor argument is one of two forms:

- `oldfield => newvalue` — a *mapped* argument. The macro evaluates `newvalue`
  once, compares it against `oldfield` with `referenceEq`, and uses the
  evaluated value in the rebuild path.
- any other expression — a *frozen* argument. Passed through to `Ctor`
  unchanged. Frozen args do not participate in the equality check.

If every mapped pair is `referenceEq`, the macro returns `orig` and never calls
`Ctor`. If any pair differs, all mapped values plus the frozen args are fed
into `Ctor` exactly once.

Example:

    @shareUnchanged exp BINARY_EXPRESSION(
        exp.exp1 => map(exp.exp1, func),
        exp.operator,
        exp.exp2 => map(exp.exp2, func),
    )

is equivalent to:

    let \\_new1 = map(exp.exp1, func), \\_new2 = map(exp.exp2, func)
        if referenceEq(exp.exp1, \\_new1) && referenceEq(exp.exp2, \\_new2)
            exp
        else
            BINARY_EXPRESSION(\\_new1, exp.operator, \\_new2)
        end
    end

This is the macro form of `reuseIfRefEqual` for the N-field constructor case,
specialised at expansion time so it does not pay the parametric-type cost
documented for `reuseIfRefEqual` on `SUBSCRIPT_INDEX{T}` / `SUBSCRIPT_UNTYPED{T}`.

Errors:
- The second argument must be a call expression `Ctor(args...)`.
- At least one argument must be a `=>` pair, otherwise the macro would always
  rebuild and is pointless.
"""
macro shareUnchanged(orig, ctor_call)
    if !(ctor_call isa Expr && ctor_call.head === :call)
        error("@shareUnchanged: second argument must be a constructor call `Ctor(args...)`, got $(ctor_call)")
    end
    ctor = ctor_call.args[1]
    raw_args = ctor_call.args[2:end]

    mapped = Tuple{Symbol,Any,Any}[]
    rebuild_args = Any[]
    for a in raw_args
        if a isa Expr && a.head === :call && length(a.args) == 3 && a.args[1] === :(=>)
            oldfield = a.args[2]
            newvalue = a.args[3]
            tmp = gensym(:su)
            push!(mapped, (tmp, oldfield, newvalue))
            push!(rebuild_args, tmp)
        else
            push!(rebuild_args, esc(a))
        end
    end

    if isempty(mapped)
        error("@shareUnchanged: no `oldfield => newvalue` pair found in $(ctor_call); the macro would always rebuild")
    end

    let_bindings = [Expr(:(=), tmp, esc(newvalue)) for (tmp, _, newvalue) in mapped]
    eq_terms = [:(referenceEq($(esc(oldfield)), $tmp)) for (tmp, oldfield, _) in mapped]
    all_eq = length(eq_terms) == 1 ? eq_terms[1] :
             reduce((acc, t) -> :($acc && $t), eq_terms)
    rebuild = Expr(:call, esc(ctor), rebuild_args...)

    quote
        let $(let_bindings...)
            if $all_eq
                $(esc(orig))
            else
                $rebuild
            end
        end
    end
end
