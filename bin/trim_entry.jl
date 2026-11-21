#=
  juliac entry: forwards command-line args to OMFrontend.julia_main.
  Julia 1.12 juliac requires the @main convention.

  The static reachability analysis in --trim does not always trace through
  ccall library-name expressions. OpenModelicaParser uses the pattern
      ccall((:parseFile, ensure_installed_lib_path()), ...)
  which leaves `ensure_installed_lib_path` (and the error-path helpers it
  pairs with) reachable only via the ccall lowering. To keep their no-arg
  specializations in the trimmed binary we reference them as ordinary Julia
  calls from `@main` itself. The `_pinTrimAnchors` call is a no-op at
  runtime: it only forces the methods into the compilation closure.
=#

using OMFrontend
import OpenModelicaParser

@noinline function _pinTrimAnchors()
    try
        OpenModelicaParser.ensure_installed_lib_path()
        OpenModelicaParser.last_parse_error_message()
    catch
        # ensure_installed_lib_path may legitimately throw if the native
        # library is missing; that is a runtime concern, not a trim concern.
    end
    return nothing
end

function (@main)(args)::Cint
    _pinTrimAnchors()
    empty!(Base.ARGS)
    append!(Base.ARGS, args)
    return OMFrontend.julia_main()
end
