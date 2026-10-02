#= /*
* This file is part of OpenModelica.
*
* Copyright (c) 1998-2026, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF AGPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.8.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GNU AGPL
* VERSION 3, ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the OSMC (Open Source Modelica Consortium)
* Public License (OSMC-PL) are obtained from OSMC, either from the above
* address, from the URLs:
* http://www.openmodelica.org or
* https://github.com/OpenModelica/ or
* http://www.ida.liu.se/projects/OpenModelica,
* and in the OpenModelica distribution.
*
* GNU AGPL version 3 is obtained from:
* https://www.gnu.org/licenses/licenses.html#GPL
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*
*/ =#

const EquationFn = Function
const AlgorithmFn = Function
const FoldFn = Function
const MapFn = Function
const EquationFn = Function
const AlgorithmFn = Function
const EquationFn = Function
const AlgorithmFn = Function
#=Necessary redefinitions=#
const Sections = NFSections
const Algorithm = AlgorithmImpl

abstract type NFSections
end

struct SECTIONS_EMPTY <: NFSections
end

mutable struct SECTIONS_EXTERNAL <: NFSections
  name::String
  args::List{Expression}
  outputRef::ComponentRef
  language::String
  ann::Option{SCode.Annotation}
  explicit::Bool
end

mutable struct SECTIONS <: NFSections
  equations::Vector{Equation}
  initialEquations::Vector{Equation}
  algorithms::Vector{Algorithm}
  initialAlgorithms::Vector{Algorithm}
end

function isEmpty(sections::Sections)
  @match sections begin
    SECTIONS_EMPTY(__) => begin
      true
    end
    _ => begin
      false
    end
  end
end

function apply(
  sections::Sections,
  eqFn::EquationFn,
  algFn::AlgorithmFn,
  ieqFn::EquationFn = eqFn,
  ialgFn::AlgorithmFn = algFn,
  )::Nothing
  @match sections begin
    SECTIONS(__) => begin
      for eq in sections.equations
        eqFn(eq)
      end
      for ieq in sections.initialEquations
        ieqFn(ieq)
      end
      for alg in sections.algorithms
        algFn(alg)
      end
      for ialg in sections.initialAlgorithms
        ialgFn(ialg)
      end
      nothing
    end
    _ => begin
      nothing
    end
  end
end

function foldExp(sections::Sections, foldFn::FoldFn, arg::ArgT) where {ArgT}
  @assign arg = begin
    @match sections begin
      SECTIONS(__) => begin
        arg = foldExpList(sections.equations, foldFn, arg)
        arg = foldExpList(sections.initialEquations, foldFn, arg)
        arg = foldExpList(sections.algorithms, foldFn, arg)
        arg = foldExpList(sections.initialAlgorithms, foldFn, arg)
        arg
      end
      SECTIONS_EXTERNAL(__) => begin
        ListUtil.fold(sections.args, foldFn, arg)
      end
      _ => begin
        arg
      end
    end
  end
  return arg
end

"""
  Maps a Sections object using a map function.
"""
function mapExp(sections::Sections, mapFn::MapFn)::Sections
  local eq::Vector{Equation}
  local ieq::Vector{Equation}
  local alg::Vector{Algorithm}
  local ialg::Vector{Algorithm}
  sections = begin
    @match sections begin
      SECTIONS(__) => begin
        eq = mapExpList(sections.equations, mapFn)
        ieq = mapExpList(sections.initialEquations, mapFn)
        alg = mapExpList(sections.algorithms, mapFn)
        ialg = mapExpList(sections.initialAlgorithms, mapFn)
        SECTIONS(eq, ieq, alg, ialg)
      end
      SECTIONS_EXTERNAL(__) => begin
        sections.args = list(mapFn(e) for e in sections.args)
        sections
      end
      _ => begin
        sections
      end
    end
  end
  return sections
end

function map1(
  sections::Sections,
  arg::ArgT,
  eqFn::EquationFn,
  algFn::AlgorithmFn,
  ieqFn::EquationFn = eqFn,
  ialgFn::AlgorithmFn = algFn,
) where {ArgT}
  local eq::List{Equation}
  local ieq::List{Equation}
  local alg::Vector{Algorithm}
  local ialg::Vector{Algorithm}
  () = begin
    @match sections begin
      SECTIONS(__) => begin
        eq = list(eqFn(e, arg) for e in sections.equations)
        ieq = list(ieqFn(e, arg) for e in sections.initialEquations)
        alg = [algFn(a, arg) for a in sections.algorithms]
        ialg = [ialgFn(a, arg) for a in sections.initialAlgorithms]
        sections = SECTIONS(eq, ieq, alg, ialg)
        ()
      end
      _ => begin
        ()
      end
    end
  end
  return sections
end

function map(
  sections::Sections,
  eqFn::EquationFn,
  algFn::AlgorithmFn,
  ieqFn::EquationFn = eqFn,
  ialgFn::AlgorithmFn = algFn,
)
  local eq::Vector{Equation}
  local ieq::Vector{Equation}
  local alg::Vector{Algorithm}
  local ialg::Vector{Algorithm}
  () = begin
    @match sections begin
      SECTIONS(__) => begin
        eq = Equation[eqFn(e) for e in sections.equations]
        ieq = Equation[ieqFn(e) for e in sections.initialEquations]
        alg = Algorithm[algFn(a) for a in sections.algorithms]
        ialg = Algorithm[ialgFn(a) for a in sections.initialAlgorithms]
        sections = SECTIONS(eq, ieq, alg, ialg)
        ()
      end
      _ => begin
        ()
      end
    end
  end
  return sections
end

function join(sections1::Sections, sections2::Sections)::Sections
  local sections::Sections
  sections = begin
    @match (sections1, sections2) begin
      (SECTIONS_EMPTY(__), _) => begin
        sections2
      end

      (_, SECTIONS_EMPTY(__)) => begin
        sections1
      end

      (SECTIONS(__), SECTIONS(__)) => begin
        SECTIONS(
          vcat(sections1.equations, sections2.equations),
          vcat(sections1.initialEquations, sections2.initialEquations),
          vcat(sections1.algorithms, sections2.algorithms),
          vcat(sections1.initialAlgorithms, sections2.initialAlgorithms),
        )
      end
    end
  end
  return sections
end

function append(
  equations::Vector{Equation},
  initialEquations::Vector{Equation},
  algorithms::Vector{Algorithm},
  initialAlgorithms::Vector{Algorithm},
  sections::Sections,
)
  sections = begin
    @match sections begin
      SECTIONS(__) => begin
        SECTIONS(
          vcat(sections.equations, equations),
          vcat(sections.initialEquations, initialEquations),
          vcat(sections.algorithms, algorithms),
          vcat(sections.initialAlgorithms, initialAlgorithms),
        )
      end

      _ => begin
        SECTIONS(equations, initialEquations, algorithms, initialAlgorithms)
      end
    end
  end
  return sections
end

function prependAlgorithm(
  alg::Algorithm,
  sections::Sections,
  isInitial::Bool = false,
)::Sections

  @assign sections = begin
    @match sections begin
      SECTIONS(__) => begin
        if isInitial
          sections.initialAlgorithms = _cons(alg, sections.initialAlgorithms)
        else
          sections.algorithms = _cons(alg, sections.algorithms)
        end
        sections
      end

      EMPTY(__) => begin
        if isInitial
          SECTIONS(nil, nil, nil, list(alg))
        else
          SECTIONS(nil, nil, list(alg), nil)
        end
      end

      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " got invalid Sections to prepend algorithm to",
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return sections
end

function toFlatStream(sections, scopeName::Absyn.Path, s::IOStream_M.IOSTREAM; inFunction = false)
  local ann::SCode.Annotation;
  local mod::SCode.Mod, modLib::SCode.Mod
  local modInc::SCode.Mod, modLibDir::SCode.Mod, modIncDir::SCode.Mod
  @match sections begin
    SECTIONS() => begin
      for alg in sections.algorithms
        s = IOStream_M.append(s, "algorithm\n")
        s = toFlatStreamList(alg.statements, "  ", s; inFunction = inFunction)
      end
      s
    end
    SECTIONS_EXTERNAL() => begin
      s = IOStream_M.append(s, "external \"")
      s = IOStream_M.append(s, sections.language)
      s = IOStream_M.append(s, "\"")
      if sections.explicit
        if ! isEmpty(sections.outputRef)
          s = IOStream_M.append(s, " ")
          s = IOStream_M.append(s, toFlatString(sections.outputRef))
          s = IOStream_M.append(s, " =")
        end
        s = IOStream_M.append(s, " ")
        s = IOStream_M.append(s, sections.name)
        s = IOStream_M.append(s, "(")
        s = IOStream_M.append(s, stringDelimitList(list(toFlatString(e) for e in sections.args), ", "))
        s = IOStream_M.append(s, ")")
      end
      if isSome(sections.ann)
        @match SOME(ann) = sections.ann
        mod = ann.modification
        modLib = SCodeUtil.filterSubMods(mod, (x) -> SCodeUtil.filterGivenSubModNames(x;namesToKeep=list("Library")))
        modInc = SCodeUtil.filterSubMods(mod, (x) -> SCodeUtil.filterGivenSubModNames(x;namesToKeep=list("Include")))
        if SCodeUtil.isEmptyMod(modLib)
          modLibDir = SCode.NOMOD()
        else
          modLibDir = SCodeUtil.filterSubMods(mod, (x) -> SCodeUtil.filterGivenSubModNames(x;namesToKeep=list("LibraryDirectory")))
          if SCodeUtil.isEmptyMod(modLibDir)
            modLibDir = SCode.MOD(SCode.NOT_FINAL()
                                  , SCode.NOT_EACH()
            , list(SCode.NAMEMOD("LibraryDirectory"
                                 , SCode.MOD(SCode.NOT_FINAL()
                                             ,SCode.NOT_EACH()
                                             ,nil
                                             ,SOME(Absyn.STRING("modelica://" + AbsynUtil.pathFirstIdent(scopeName) + "/Resources/Library")), AbsynUtil.dummyInfo))), NONE(), AbsynUtil.dummyInfo)
          end
        end
        if SCodeUtil.isEmptyMod(modInc)
          modIncDir = SCode.NOMOD()
        else
          modIncDir = SCodeUtil.filterSubMods(mod, (x) -> SCodeUtil.filterGivenSubModNames(x;namesToKeep=list("IncludeDirectory")))
          if SCodeUtil.isEmptyMod(modLibDir)
            modLibDir = SCode.MOD(SCode.NOT_FINAL(), SCode.NOT_EACH(), list(SCode.NAMEMOD("IncludeDirectory", SCode.MOD(SCode.NOT_FINAL(), SCode.NOT_EACH(), list(), SOME(Absyn.STRING("modelica://" + AbsynUtil.pathFirstIdent(scopeName) + "/Resources/Include")), AbsynUtil.dummyInfo))), NONE(), AbsynUtil.dummyInfo)
          end
        end
        @assign ann.modification = SCodeUtil.mergeSCodeMods(SCodeUtil.mergeSCodeMods(modLib, modLibDir), SCodeUtil.mergeSCodeMods(modInc, modIncDir))
        s = IOStream_M.append(s, SCodeDump.printAnnotationStr(SCode.COMMENT(SOME(ann), NONE())))
      end
      s = IOStream_M.append(s, ";\n")
    end
    _ #=NOP=# => s
  end #match
end

function prependEquation(
  eq::Equation,
  sections::Sections,
  isInitial::Bool = false,
)::Sections
  sections = begin
    @match sections begin
      SECTIONS(__) => begin
        if isInitial #I think I can avoid the assignment here.. since we modify the reference.
          #@assign sections.initialEquations = push!(sections.initialEquations, eq)
          push!(sections.initialEquations, eq)
        else
          #@assign sections.equations = push!(sections.equations, eq)
          push!(sections.equations, eq)
        end
        sections
      end

      SECTIONS_EMPTY(__) => begin
        if isInitial
          SECTIONS(Equation[], Equation[eq], Algorithm[], Algorithm[])
        else
          SECTIONS([eq], Equation[], Algorithm[], Algorithm[])
        end
      end

      _ => begin
        Error.assertion(
          false,
          getInstanceName() + " got invalid Sections to prepend equation to",
          sourceInfo(),
        )
        fail()
      end
    end
  end
  return sections
end

function prepend(
  equations::Vector{Equation},
  initialEquations::Vector{Equation},
  algorithms::Vector{Algorithm},
  initialAlgorithms::Vector{Algorithm},
  sections::Sections,
)
  sections = begin
    @match sections begin
      SECTIONS(__) => begin
        SECTIONS(
          vcat(equations, sections.equations),
          vcat(initialEquations, sections.initialEquations),
          vcat(algorithms, sections.algorithms),
          vcat(initialAlgorithms, sections.initialAlgorithms),
        )
      end
      _ => begin
        SECTIONS(equations, initialEquations, algorithms, initialAlgorithms)
      end
    end
  end
  return sections
end

function new(
  equations::Vector{Equation},
  initialEquations::Vector{Equation},
  algorithms::Vector{Algorithm},
  initialAlgorithms::Vector{Algorithm},
  )
  local sections::Sections
  if isempty(equations) &&
     isempty(initialEquations) &&
     isempty(algorithms) &&
     isempty(initialAlgorithms)
    sections = SECTIONS_EMPTY()
  else
    sections = SECTIONS(equations, initialEquations, algorithms, initialAlgorithms)
  end
  return sections
end
