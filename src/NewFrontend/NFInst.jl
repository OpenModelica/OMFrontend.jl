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

import Absyn
import SCode
import DAE

import .InstUtil
import .ExecStat

"""
    Instantiates a class given by its fully qualified path.
    The result is the model represented in the DAE format, see DAE.jl.
"""
function instClassInProgram(classPath::Absyn.Path, program::SCode.Program)
  local daeFuncs::DAE.FunctionTree
  local dae::DAE.DAE_LIST
  local top::InstNode
  local cls::InstNode
  local inst_cls::InstNode
  local name::String
  local flat_model::FlatModel
  local funcs::FunctionTree
  name = AbsynUtil.pathString(classPath)
  try
    (flat_model, funcs, inst_cls) = instClassInProgramFM2(classPath::Absyn.Path, program::SCode.Program)
  catch e
    println("The compiler failed to process a model with the following message(s):")
    print(Error.printMessagesStr())
    #= Do not clear messages here so callers (e.g. OMLibraryTesting runner) can capture them =#
    println("Internal stack trace:")
    #@error e
    throw(e)
  end
  (dae, daeFuncs) = convert(flat_model, funcs, name, InstNode_info(inst_cls))
  return (dae, daeFuncs)
end

"""
  Similar to instClassInProgram but returns the flat model instead of the DAE.
  This function is used as a helper function by instClassInProgram.
  Author:johti17
"""
function instClassInProgramFM(classPath::Absyn.Path, program::SCode.Program)::Tuple
  local flat_model, funcs, inst_cls
  try
    (flat_model, funcs, inst_cls) = instClassInProgramFM2(classPath::Absyn.Path, program::SCode.Program)
  catch e
    println("The compiler failed to process a model with the following message(s):")
    print(Error.printMessagesStr())
    Error.clearMessages()
    #=TODO: Add a @static flag later to supress this message. =#
    println("Internal stack trace:")
    bt = catch_backtrace()
    for (i, frame) in enumerate(stacktrace(bt))
      fname = string(frame.file)
      if i <= 40 && (occursin("NF", fname) || occursin("OM", fname) || occursin("ListUtil", fname))
        println("  [$i] $(frame.func) at $(frame.file):$(frame.line)")
      end
    end
    rethrow()
  else
    print(Error.printMessagesStr(;
                                 #=
                                 Incase instatiate was successful,
                                 errors that have been added but have been resolved during instatiation
                                 should not be printed. =#
                                 printErrors = false))
    Error.clearMessages()
  end
  return (flat_model, funcs, inst_cls)
end


"""
Helper function called by instClassInProgram.
The main work is done here. The function dumpFlatModel will dump the flat model at intermediate stages
if the Flags.NF_DUMP_FLAT flag is set to true.
"""
function instClassInProgramFM2(classPath::Absyn.Path, program::SCode.Program)::Tuple
  local top::CLASS_NODE
  local cls::CLASS_NODE
  local inst_cls::CLASS_NODE
  local name::String
  local flat_model::FlatModel
  local funcs::FunctionTree
  #= Add the program currently being translated into the SCode cache. =#
  local currentProgram = listHead(program)
  resetInstDiagnostics()
  setSettingForInst()
  # Reset the execstat wall-time baseline so the first `ExecStat.execStat` call
  # in this translation reports elapsed-since-now, not elapsed-since-module-load.
  if Flags.isSet(Flags.EXEC_STAT)
    ExecStat.execStatResetTimer()
  end
  #=  Create a root node from the given top-level classes. =#
  top = makeTopNode(program)
  name = AbsynUtil.pathString(classPath)
  #=  Look up the class to instantiate and mark it as the root class. =#
  cls = lookupClassName(classPath, top, AbsynUtil.dummyInfo, false)
  cls = setNodeType(ROOT_CLASS(EMPTY_NODE()), cls)
  #=  Initialize the storage for automatically generated inner elements. =#
  top = setInnerOuterCache(top, C_TOP_SCOPE(NodeTree.new(), cls))
  INST_CLASS_DEPTH[] = 0
  @EXECSTAT "instantiate" inst_cls = instantiateN1(cls, EMPTY_NODE())
  ExecStat.execStat("Instantiation")
  insertGeneratedInners(inst_cls, top)
  #=
  Instantiate expressions (i.e. anything that can contains crefs, like
  bindings, dimensions, etc). This is done as a separate step after
  instantiation to make sure that lookup is able to find the correct nodes.
  =#
  INST_EXPR_DEPTH[] = 0
  @EXECSTAT "instExpressions" instExpressions(inst_cls)
  ExecStat.execStat("NFInst.instExpressions(" + name + ")")
  #=  Mark structural parameters. =#
  updateImplicitVariability(inst_cls, Flags.isSet(Flags.EVAL_PARAM)::Bool)
  ExecStat.execStat("NFInst.updateImplicitVariability")
  #=  Type the class. =#
  #"Type the class"
  @EXECSTAT "typeClass:" typeClass(inst_cls, name)
  @EXECSTAT "flatten" flat_model = flatten(inst_cls, name)
  dumpFlatModel(flat_model, string(name, "_", "afterFlatten"))
  #=
  Check if we are to perform recompilation. If true adds the SCode program to the flat model.
  Also check if we have a Connections.branch statement in an if-equation
  =#
  local recompilationEnabled = recompilationDirectiveExists(flat_model.equations)
  local doccs = collectDOCCS(flat_model.equations)
  local modelWithDOCC  = ! isempty(doccs)
  if recompilationEnabled || modelWithDOCC
    @assign flat_model.scodeProgram = SOME(listHead(program))
    if modelWithDOCC
      #=
      1. Evaluate the initial state of the special if-equation (by looking at the condition)
      Either the equation starts with the relevant equation in the model,
      or the equations are added during the simulation.
      (It should also be noted that, the equations are to be removed in some conditions)

      =#
      #= Remove the conditionals themselves from the flat model =#
      local doccSet = Set(doccs)
      local equationsWithoutDOCC = filter(e -> !(e in doccSet), flat_model.equations)
      #=
      Check if the existing equations in the flat model should be extended.
      =#
      initialEqMapping = evalInitialEqMapping(flat_model.initialEquations)
      for eq in doccs
        @assert eq isa EQUATION_IF
        for br in eq.branches
          @assert br isa EQUATION_BRANCH
          tst = evaluateExp(br.condition, Variability.DISCRETE)
          tst = Variable_fromCref(toCref(tst))
          local varAsStr = toString(tst.name)
          if in(varAsStr, keys(initialEqMapping))
            expr = initialEqMapping[varAsStr]
            #=
            Evaluate the expression. It should be a boolean.
            Depending on the value we do two things:
            Either we remove equations from the starting model
            or we add them to the model.
            =#
            @match BOOLEAN_EXPRESSION(active) = expr
            @assign flat_model.equations = if active
              #=
              Equations for this if equation active at the start.
              Mark as active on both branches. Index is assumed to match with each equation.
              =#
              push!(flat_model.active_DOCC_Equations, true)
              vcat(equationsWithoutDOCC, br.body)
            else #= Otherwise these equations are active at some later stage =#
              push!(flat_model.active_DOCC_Equations, false)
              equationsWithoutDOCC
            end
          end
        end
        #= Add the special equations to the flat model =#
        @assign begin
          flat_model.DOCC_equations = arrayList(doccs)
          #= Contains the equations of the system before the virtual connection graph is calculated =#
          flat_model.unresolvedConnectEquations = arrayList(equationsWithoutDOCC)
        end
      end
      #=
      Remove the doccs equations from the set of equations in the flat model
      (If they are to be removed)
      =#
    end
    #= Resolve the connections of the current system. =#
    flat_model = resolveConnections(flat_model, name)
    dumpFlatModel(flat_model, string(name, "_", "afterResolveConnections"))
    if ! recompilationEnabled
      flat_model = evaluate(flat_model)
      dumpFlatModel(flat_model, string(name, "_", "afterEval"))
    end
  else #= Regular system without simulaton time reconfigurations =#
    @EXECSTAT "resolveConnections" flat_model = resolveConnections(flat_model, name)
    dumpFlatModel(flat_model, string(name, "_", "afterResolveConnections"))
    @EXECSTAT "evaluate" flat_model = evaluate(flat_model)
    dumpFlatModel(flat_model, string(name, "_", "afterEval"))
  end
  #= Do unit checking =#
  #TODO  @assign flat_model = UnitCheck.checkUnits(flat_model)
  flat_model = inlineSimpleCalls(flat_model)
  dumpFlatModel(flat_model, string(name, "_", "afterInlining"))
  @EXECSTAT "Simplify" flat_model = simplifyFlatModel(flat_model)
  dumpFlatModel(flat_model, string(name, "_", "afterSimplify"))
  @EXECSTAT "collectFunctions" funcs = collectFunctions(flat_model, name)
  #=  Collect package constants that couldn't be substituted with their values =#
  #=  (e.g. because they where used with non-constant subscripts), and add them to the model. =#
  @EXECSTAT "collectConstants" flat_model = collectConstants(flat_model, funcs)
  #= Scalarize array components in the flat model.=#
  if Flags.isSet(Flags.NF_SCALARIZE)
    @EXECSTAT "scalarize" flat_model = scalarize(flat_model, name)
    dumpFlatModel(flat_model, string(name, "_", "afterScalarize"))
  else
    #=  Remove empty arrays from variables =#
    @assign flat_model.variables = filter( (x) -> !isEmptyArray(x), flat_model.variables)
  end
  #=
  In some cases  array variables remain after scalarization.
  This also seem to occur in the omc.
  We readd these variables to the model.
  (If Scalarize is set to false this function does nothing).
  =#
  InstUtil.restoreMissingArrayVariables!(flat_model)
  InstUtil.adjustIncorrectVariablePaths!(flat_model)
  @EXECSTAT "verify" verify(flat_model)
  dumpFlatModel(flat_model, string(name, "_", "afterVerify"))
  #= TODO: Expand sliced crefs=#
  #= TODO: Combine subscripts =#
  dumpInstDiagnostics(name)
  return (flat_model, funcs, inst_cls)
end

function setSettingForInst()
  #=
  Gather here all the flags to disable expansion
  and scalarization if -d=-nfScalarize is on
  =#
  if ! Flags.isSet(Flags.NF_SCALARIZE)
    FlagsUtil.set(Flags.NF_EXPAND_OPERATIONS, false)
    FlagsUtil.set(Flags.NF_EXPAND_FUNC_ARGS, false)
  else
    #=
    Turn on function argument expansion by default
    so that we do not miss some variables in function calls.
    =#
    FlagsUtil.set(Flags.NF_EXPAND_OPERATIONS, true)
    FlagsUtil.set(Flags.NF_EXPAND_FUNC_ARGS, true)
  end
  #=  make sure we don't expand anything=#
  System.setUsesCardinality(false)
  System.setHasOverconstrainedConnectors(false)
  System.setHasStreamConnectors(false)
end

"""
    Inlines uncomplicated functions.
    Currently it inlines all functions.
    Throws an error if a function is not complex enough.
"""
function inlineSimpleCalls(fm::FlatModel)
  local inlinedEqs = mapExpList(fm.equations, inlineSimpleCall)
  @assign fm.equations = inlinedEqs
  return fm
end

function instantiateN1(node::InstNode, parentNode::InstNode, isRedeclared::Bool = false)
  node = expand(node)
  if !isPartial(node) || isRedeclared
    node = instClass(node, MODIFIER_NOMOD(), DEFAULT_ATTR, Ref{Attributes}(DEFAULT_ATTR), true, 0, parentNode)
  end
  return node
end

function instantiateN1(node::InstNode)
  #@debug "Instantiating!!!! in Inst"
  node = expand(node)
  #@debug "After expansion in inst. Instantiating in class-tree "
  node = instClass(node, MODIFIER_NOMOD(), DEFAULT_ATTR, Ref{Attributes}(DEFAULT_ATTR), true, 0, EMPTY_NODE())
  return node
end

function expand(node::InstNode) ::InstNode
  node = partialInstClass(node)
  node = expandClass(node)
  node
end

"""Creates an instance node from the given list of top-level classes."""
function makeTopNode(topClasses::List{<:SCode.Element}) ::InstNode
  local topNode::InstNode
  local cls_elem::SCode.Element
  local cls::Class
  local elems::ClassTree

  #=  Create a fake SCode.Element for the top scope, so we don't have to make the
  =#
  #=  definition in InstNode an Option only because of this node.
  =#
  cls_elem = SCode.CLASS("<top>", SCode.defaultPrefixes, SCode.NOT_ENCAPSULATED(), SCode.NOT_PARTIAL(), SCode.R_PACKAGE(), SCode.PARTS(topClasses, nil, nil, nil, nil, nil, nil, NONE()), SCode.COMMENT(NONE(), NONE()), AbsynUtil.dummyInfo)
  #=  Make an InstNode for the top scope, to use as the parent of the top level elements.
  =#
  topNode = newClass(cls_elem, EMPTY_NODE(), TOP_SCOPE())
  #=  Create a new class from the elements, and update the inst node with it.
  =#
  cls = fromSCode(topClasses, false, topNode, DEFAULT_PREFIXES)
  #=  The class needs to be expanded to allow lookup in it. The top scope will
  =#
  #=  only contain classes, so we can do this instead of the whole expandClass.
  =#
  cls = initExpandedClass(cls)
  #=  Set the correct for classes with builtin annotation. This
  =#
  #=  could also be done when creating InstNodes, but only top-level classes
  =#
  #=  should have this annotation anyway.
  =#
  elems = classTree(cls)
  mapClasses(elems, markBuiltinTypeNodes)
  cls = setClassTree(elems, cls)
  topNode = updateClass(cls, topNode)
  topNode
end

function markBuiltinTypeNodes(node::InstNode) ::InstNode
  if SCodeUtil.hasBooleanNamedAnnotationInClass(definition(node), "__OpenModelica_builtin")
     node = setNodeType(BUILTIN_CLASS(), node)
  end
  node
end

function partialInstClass(node::InstNode) ::InstNode
  local c::Class
  () = begin
    @match getClass(node) begin
      NOT_INSTANTIATED(__)  => begin
        c = partialInstClass2(definition(node), node)
        node = updateClass(c, node)
        ()
      end
      _  => begin
        ()
      end
    end
  end
  node
end

function partialInstClass2(definition::SCode.Element, scope::InstNode) ::Class
  local cls::Class
  local cdef::SCode.ClassDef
  local ce_cdef::SCode.ClassDef
  local ty::M_Type
  local prefs::Prefixes
#  Error.assertion(SCodeUtil.elementIsClass(definition), getInstanceName() + " got non-class element", sourceInfo())
  @match SCode.CLASS(classDef = cdef) = definition
   prefs = instClassPrefixes(definition)
   cls = begin
    @match cdef begin
      SCode.PARTS(__)  => begin
        fromSCode(cdef.elementLst, false, scope, prefs)
      end
      SCode.CLASS_EXTENDS(composition = ce_cdef && SCode.PARTS(__))  => begin
        if ! SCodeUtil.isElementRedeclare(definition)
          Error.addSourceMessage(Error.CLASS_EXTENDS_MISSING_REDECLARE, list(SCodeUtil.elementName(definition)), SCodeUtil.elementInfo(definition))
        end
        fromSCode(ce_cdef.elementLst, true, scope, prefs)
      end
      SCode.ENUMERATION(__)  => begin
        #=  An enumeration definition, add the literals to a new scope.
        =#
         ty = makeEnumerationType(cdef.enumLst, scope)
        fromEnumeration(cdef.enumLst, ty, prefs, scope)
      end
      _  => begin
        PARTIAL_CLASS(CLASS_TREE_EMPTY_TREE(), MODIFIER_NOMOD(), prefs)
      end
    end
  end
  cls
end

function instClassPrefixes(cls::SCode.Element) ::Prefixes
  local prefixes::Prefixes

  local prefs::SCode.Prefixes

   prefixes = begin
    @match cls begin
      SCode.CLASS(encapsulatedPrefix = SCode.NOT_ENCAPSULATED(__), partialPrefix = SCode.NOT_PARTIAL(__), prefixes = SCode.PREFIXES(finalPrefix = SCode.NOT_FINAL(__), innerOuter = Absyn.NOT_INNER_OUTER(__), replaceablePrefix = SCode.NOT_REPLACEABLE(__)))  => begin
        DEFAULT_PREFIXES
      end

      SCode.CLASS(prefixes = prefs)  => begin
        PREFIXES(cls.encapsulatedPrefix, cls.partialPrefix, prefs.finalPrefix, prefs.innerOuter, prefs.replaceablePrefix)
      end
    end
  end
  prefixes
end

function makeEnumerationType(literals::List{<:SCode.Enum}, scope::InstNode) ::M_Type
  local ty::M_Type

  local lits::List{String}
  local path::Absyn.Path

   path = scopePath(scope)
   lits = list(e.literal for e in literals)
   ty = TYPE_ENUMERATION(path, lits)
  ty
end

function expandClass(node::InstNode) ::InstNode
  node = begin
    @match getClass(node) begin
      PARTIAL_CLASS(__)  => begin
        expandClass2(node)
      end
      _  => begin
        node
      end
    end
  end
  node
end

function expandClass2(node::InstNode) ::InstNode


  local def::SCode.Element = definition(node)
  local cdef::SCode.ClassDef
  local info::SourceInfo

  @match SCode.CLASS(classDef = cdef, info = info) = def
   node = begin
    @match cdef begin
      SCode.PARTS(__)  => begin
        expandClassParts(def, node, info)
      end

      SCode.CLASS_EXTENDS(__)  => begin
        expandClassParts(def, node, info)
      end

      SCode.DERIVED(__)  => begin
        expandClassDerived(def, cdef, node, info)
      end

      _  => begin
        #=  A short class definition, e.g. class A = B.
        =#
        Error.assertion(false, getInstanceName() + " got unknown class:\\n" + SCodeDump.unparseElementStr(def), sourceInfo())
        fail()
      end
    end
  end
  node
end

function expandClassParts(def::SCode.Element, node::InstNode, info::SourceInfo) ::InstNode
  local cls::Class
  local cls_tree::ClassTree
  local mod::Modifier
  local builtin_ext::InstNode
  local prefs::Prefixes
  local res::Restriction
  cls = getClass(node)
  #=  Change the class to an empty expanded class, to avoid instantiation loops. =#
  cls = initExpandedClass(cls)
   node = updateClass(cls, node)
  @match EXPANDED_CLASS(elements = cls_tree, modifier = mod, prefixes = prefs) = cls
  builtin_ext = mapFoldExtends(cls_tree, expandExtends, EMPTY_NODE())
  if name(builtin_ext) == "ExternalObject"
     node = expandExternalObject(cls_tree, node)
  else
    if ! isEmpty(builtin_ext)
      checkBuiltinTypeExtends(builtin_ext, cls_tree, node)
    end
     cls_tree = expand(cls_tree)
     res = fromSCode(SCodeUtil.getClassRestriction(def))
     cls = EXPANDED_CLASS(cls_tree, mod, prefs, res)
     node = updateClass(cls, node)
  end
  node
end

function expandExtends(ext::InstNode, builtinExt::InstNode = EMPTY_NODE()) ::Tuple{InstNode, InstNode}
  local def::SCode.Element
  local base_path::Absyn.Path
  local base_nodes::List{InstNode}
  local scope::InstNode
  local base_node::InstNode
  local vis::SCode.Visibility
  local smod::SCode.Mod
  local ann::Option{SCode.Annotation}
  local info::SourceInfo
  if isEmpty(ext)
    return (ext, builtinExt)
  end
  def = definition(ext)
  () = begin
    @match def begin
      SCode.EXTENDS(base_path, vis, smod, ann, info)  => begin
        #=  Look up the base class and expand it.
        =#
        scope = parent(ext)
        #@match (@match _cons(base_node, _) = base_nodes) = lookupBaseClassName(base_path, scope, info)
        base_nodes = lookupBaseClassName(base_path, scope, info) #Modification by me:) Corresponds to the above
        base_node = listHead(base_nodes)
        checkExtendsLoop(base_node, base_path, info)
        checkReplaceableBaseClass(base_nodes, base_path, info)
        base_node = expand(base_node)
        ext = setNodeType(BASE_CLASS(scope, def), base_node)
        #=  If the extended class is a builtin class, like Real or any type derived
        =#
        #=  from Real, then return it so we can handle it properly in expandClass.
        =#
        #=  We don't care if builtinExt is already SOME, since that's not legal and
        =#
        #=  will be caught by expandBuiltinExtends.
        =#
        if isBuiltin(base_node) || isBuiltin(getClass(base_node))
           builtinExt = ext
        end
        ()
      end

      _  => begin
        ()
      end
    end
  end
  (ext, builtinExt)
end

"""
  Gives an error if a base node is in the process of being expanded itself,
  since that means we have an extends loop in the model.
"""
function checkExtendsLoop(node::InstNode, path::Absyn.Path, info::SourceInfo)
   () = begin
    @match getClass(node) begin
      EXPANDED_CLASS(elements = CLASS_TREE_PARTIAL_TREE(__))  => begin
        #=  expand begins by changing the class to an EXPANDED_CLASS, but keeps the
        =#
        #=  class tree. So finding a PARTIAL_TREE here means the class is in the
        =#
        #=  process of being expanded.
        =#
        Error.addSourceMessage(Error.EXTENDS_LOOP, list(AbsynUtil.pathString(path)), info)
        fail()
      end

      _  => begin
        ()
      end
    end
  end
end

"""
  Checks that all parts of a name used as a base class are transitively
  non-replaceable.
"""
function checkReplaceableBaseClass(baseClasses::List{<:InstNode}, basePath::Absyn.Path, info::SourceInfo)
  local i::Int = 0
  local pos::Int
  local name::String
  local rest::List{InstNode}
  for base in baseClasses
     i = i + 1
    if SCodeUtil.isElementReplaceable(definition(base))
      if listLength(baseClasses) > 1
        rest = baseClasses
        name = ""
        for j in 1:i - 1
          name = "." + name(listHead(rest)) + name
          rest = listRest(rest)
        end
        name = "<" + name(listHead(rest)) + ">" + name
        rest = listRest(rest)
        for n in rest
          name = name(n) + "." + name
        end
      else
        name = AbsynUtil.pathString(basePath)
      end
      #TODO      Error.addMultiSourceMessage(Error.REPLACEABLE_BASE_CLASS, list(name(base), name), list(InstNode_info(base), info))
      @error "Error: Class  $name in base replaceable..."
      fail()
    end
  end
  #=  The path might contain several classes with the same name, so mark the
  =#
  #=  class in the path string to make it clear which one we mean.
  =#
end

function expandExternalObject(clsTree::ClassTree, node::InstNode) ::InstNode


  local eo_ty::ComplexType
  local c::Class

  #=  Construct the ComplexType for the external object.
  =#
   eo_ty = makeExternalObjectType(clsTree, node)
  #=  Construct the Class for the external object. We use an empty class
  =#
  #=  tree here, since the constructor and destructor is embedded in the
  =#
  #=  ComplexType instead. Using an empty class tree makes sure it's not
  =#
  #=  possible to call the constructor or destructor explicitly.
  =#
  c = PARTIAL_BUILTIN(TYPE_COMPLEX(node, eo_ty),
                      deepcopy(EMPTY_FLAT_CLASS_TREE),
                      MODIFIER_NOMOD(),
                      DEFAULT_PREFIXES,
                      RESTRICTION_EXTERNAL_OBJECT())
   node = updateClass(c, node)
  node
end

function checkBuiltinTypeExtends(builtinExtends::InstNode, tree::ClassTree, node::InstNode)
  #=  A class extending from a builtin type may not have other components or baseclasses.
  =#
  if componentCount(tree) > 0 || extendsCount(tree) > 1
    #Error.addSourceMessage(Error.BUILTIN_EXTENDS_INVALID_ELEMENTS, list(name(builtinExtends)), InstNode_info(node))
    @error "Extends invalid elements!"
    fail()
  end
  #=  ***TODO***:
  Find the invalid element and use its info to make the error
  message more accurate.
  =#
end

"""
  Constructs a ComplexType for an external object, and also checks that the
  external object declaration is valid.
"""
function makeExternalObjectType(tree::ClassTree, node::InstNode) ::ComplexType
  local ty::ComplexType

  local base_path::Absyn.Path
  local constructor::InstNode = EMPTY_NODE()
  local destructor::InstNode = EMPTY_NODE()

  ty = begin
    @match tree begin
      CLASS_TREE_PARTIAL_TREE(__)  => begin
        #=  An external object may not contain components.
        =#
        for comp in tree.components
          if isComponent(comp)
            Error.addSourceMessage(Error.EXTERNAL_OBJECT_INVALID_ELEMENT, list(name(node), name(comp)), Component_info(comp))
            fail()
          end
        end
        #=  An external object may not contain extends other than the ExternalObject one.
        =#
        if arrayLength(tree.exts) > 1
          for ext in tree.exts
            if name(ext) != "ExternalObject"
              @match CLASS_NODE(nodeType = BASE_CLASS(definition = SCode.EXTENDS(baseClassPath = base_path))) = ext
              Error.addSourceMessage(Error.EXTERNAL_OBJECT_INVALID_ELEMENT, list(name(node), "extends " + AbsynUtil.pathString(base_path)), InstNode_info(ext))
              fail()
            end
          end
        end
        #=  An external object must have exactly two functions called constructor and
        =#
        #=  destructor.
        =#
        for cls in tree.classes
          () = begin
            @match name(cls) begin
              "constructor" where (SCodeUtil.isFunction(definition(cls)))  => begin
                constructor = cls
                ()
              end

              "destructor" where (SCodeUtil.isFunction(definition(cls)))  => begin
                destructor = cls
                ()
              end

              _  => begin
                #=  Found some other element => error.
                =#
                Error.addSourceMessage(Error.EXTERNAL_OBJECT_INVALID_ELEMENT, list(name(node), name(cls)), InstNode_info(cls))
                fail()
              end
            end
          end
        end
        if isEmpty(constructor)
          Error.addSourceMessage(Error.EXTERNAL_OBJECT_MISSING_STRUCTOR, list(name(node), "constructor"), InstNode_info(node))
          fail()
        end
        #=  The constructor is missing.
        =#
        if isEmpty(destructor)
          Error.addSourceMessage(Error.EXTERNAL_OBJECT_MISSING_STRUCTOR, list(name(node), "destructor"), InstNode_info(node))
          fail()
        end
        #=  The destructor is missing.
        =#
        COMPLEX_EXTERNAL_OBJECT(constructor, destructor)
      end
    end
  end
  ty
end

function expandClassDerived(element::SCode.Element, definition::SCode.ClassDef, node::InstNode, info::SourceInfo) ::InstNode


  local ty::Absyn.TypeSpec
  local ext_node::InstNode
  local cls::Class
  local prefs::Prefixes
  local sattrs::SCode.Attributes
  local attrs::Attributes
  local dims::List{Dimension}
  local mod::Modifier
  local res::Restriction

  @match SCode.DERIVED(typeSpec = ty, attributes = sattrs) = definition
  #=  Look up the class that's being derived from and expand it.
  =#
  @match Cons{InstNode}(ext_node, _) = lookupBaseClassName(AbsynUtil.typeSpecPath(ty), parent(node), info)
  #=  Check that the class isn't extending itself, i.e. class A = A.
  =#
  if referenceEq(ext_node, node)
    Error.addSourceMessage(Error.RECURSIVE_SHORT_CLASS_DEFINITION, list(name(node), Dump.unparseTypeSpec(ty)), info)
    fail()
  end
   ext_node = expand(ext_node)
   ext_node = clone(ext_node)
  #=  Fetch the needed information from the class definition and construct a EXPANDED_DERIVED.
  =#
   cls = getClass(node)
   prefs = getPrefixes(cls)
   attrs = instDerivedAttributes(sattrs)
   dims = list(DIMENSION_RAW_DIM(d) for d in AbsynUtil.typeSpecDimensions(ty))
   mod = getModifier(cls)
   res = fromSCode(SCodeUtil.getClassRestriction(element))
   cls = EXPANDED_DERIVED(ext_node, mod, listArray(dims), prefs, attrs, res)
   node = updateClass(cls, node)
  node
end

function instDerivedAttributes(scodeAttr::SCode.Attributes) ::Attributes
  local attributes::Attributes
  local cty::ConnectorType.TYPE
  local var::VariabilityType
  local dir::DirectionType
  attributes = begin
    @match scodeAttr begin
      SCode.ATTR(connectorType = SCode.POTENTIAL(__), variability = SCode.VAR(__), direction = Absyn.BIDIR(__))  => begin
        DEFAULT_ATTR
      end
      _  => begin
        cty = fromSCode(scodeAttr.connectorType)
        var = variabilityFromSCode(scodeAttr.variability)
        dir = directionFromSCode(scodeAttr.direction)
        ATTRIBUTES(cty, Parallelism.NON_PARALLEL, var, dir, InnerOuter.NOT_INNER_OUTER, false, false, NOT_REPLACEABLE(), false #= Should not in a derived class. =#)
      end
    end
  end
  attributes
end

function instClass(node::InstNode, modifier::Modifier, attributes::Attributes, attributeRef::Ref{Attributes}, useBinding::Bool = false, instLevel::Int = 0, parent = EMPTY_NODE())::CLASS_NODE
  INST_CLASS_DEPTH[] += 1
  INST_CLASS_TOTAL_CALLS[] += 1
  if INST_CLASS_TOTAL_CALLS[] > INST_CLASS_TOTAL_CALLS_LIMIT
    nodeName = try name(node) catch; "<unknown>" end
    parentName = try name(parent) catch; "<unknown>" end
    top3 = sort(Base.collect(REINSTANTIATION_CLASSES), by=last, rev=true)[1:min(5, length(REINSTANTIATION_CLASSES))]
    @warn "instClass total call limit reached" total=INST_CLASS_TOTAL_CALLS[] reinstantiations=REINSTANTIATION_COUNT[] top_classes=top3
    Error.addSourceMessage(
      Error.INST_RECURSION_LIMIT_REACHED,
      list("instClass total calls > $(INST_CLASS_TOTAL_CALLS_LIMIT) (depth=$(INST_CLASS_DEPTH[]), reinstantiations=$(REINSTANTIATION_COUNT[])): node=$(nodeName), parent=$(parentName)"),
      InstNode_info(node))
    fail()
  end
  if INST_CLASS_DEPTH[] > INST_CLASS_DEPTH_LIMIT
    nodeName = try name(node) catch; "<unknown>" end
    parentName = try name(parent) catch; "<unknown>" end
    @warn "instClass recursion limit reached (depth=$(INST_CLASS_DEPTH[])): node=$(nodeName), parent=$(parentName)"
    Error.addSourceMessage(
      Error.INST_RECURSION_LIMIT_REACHED,
      list("instClass depth > $(INST_CLASS_DEPTH_LIMIT): node=$(nodeName), parent=$(parentName)"),
      InstNode_info(node))
    fail()
  end
  try
  local cls::Class
  local outer_mod::Modifier
   cls = getClass(node)
   outer_mod = getModifier(cls)
  #=  Give an error for modifiers such as (A = B), i.e. attempting to replace a =#
  #=  class without using redeclare. =#
  if hasBinding(outer_mod)
    Error.addSourceMessage(Error.MISSING_REDECLARE_IN_CLASS_MOD, list(name(node)), Binding_getInfo(binding(outer_mod)))
    fail()
  end
  return instClassDef(cls, modifier, attributes, useBinding, node, parent, instLevel, attributeRef)::CLASS_NODE
  finally
    INST_CLASS_DEPTH[] -= 1
  end
end

"""On failure call the generic function."""
function instClassDef(cls::Class)
  @error "Unknown class during instantiation"
  fail()
end

function instClassDef(cls::INSTANCED_CLASS,
                      outerMod::Modifier,
                      attributes::Attributes,
                      useBinding::Bool,
                      node::InstNode,
                      parentArg::InstNode,
                      instLevel::Int,
                      attributeRef::Ref{Attributes})::CLASS_NODE
  local par::InstNode
  local base_node::InstNode
  local inst_cls::Class
  local cls_tree::ClassTree
  local mod::Modifier
  local outer_mod::Modifier
  local res::Restriction
  local ty::M_Type
  local attrs::Attributes
  #= Track re-instantiation for diagnostics =#
  REINSTANTIATION_COUNT[] += 1
  cn = try name(node) catch; "?" end
  REINSTANTIATION_CLASSES[cn] = get(REINSTANTIATION_CLASSES, cn, 0) + 1
  if REINSTANTIATION_COUNT[] % 5000 == 0
    top5 = sort(Base.collect(REINSTANTIATION_CLASSES), by=last, rev=true)[1:min(5, length(REINSTANTIATION_CLASSES))]
    @warn "Re-instantiation count: $(REINSTANTIATION_COUNT[]) (total instClass calls: $(INST_CLASS_TOTAL_CALLS[]))" top_classes=top5
  end
  #=  If a class has an instance of a encapsulating class, then the encapsulating
  =#
  #=  class will have been fully instantiated to allow lookup in it. This is a
  =#
  #=  rather uncommon case hopefully, so in that case just reinstantiate the class.
  =#
  node = replaceClass(NOT_INSTANTIATED(), node)
  node = setNodeType(NORMAL_CLASS(), node)
  node = expand(node)
  node = instClass(node, outerMod, attributes, attributeRef, useBinding, instLevel, parentArg)
  updateComponentType(parentArg, node)
  return node
end

function instClassDef(cls::PARTIAL_BUILTIN,
                      outerMod::Modifier,
                      attributes::Attributes,
                      useBinding::Bool,
                      node::CLASS_NODE,
                      parentArg::InstNode,
                      instLevel::Int,
                      attributeRef::Ref{Attributes})::CLASS_NODE
  @match cls begin
    PARTIAL_BUILTIN(restriction = RESTRICTION_EXTERNAL_OBJECT(__))  => begin
      inst_cls = INSTANCED_BUILTIN(cls.ty, cls.elements, cls.restriction)
      node = replaceClass(inst_cls, node)
      updateComponentType(parentArg, node)
      instExternalObjectStructors(cls.ty, parentArg)
    end
    PARTIAL_BUILTIN(ty = ty, restriction = res)  => begin
      (node, _, _, _) = instantiate(node, parentArg)
      updateComponentType(parentArg, node)
      cls_tree = classTree(getClass(node))
      mod = fromElement(definition(node), list(node), parent(node))
      outer_mod = merge(outerMod, addParent(node, cls.modifier))
      mod = merge(outer_mod, mod)
      applyModifier(mod, cls_tree, name(node))
      inst_cls = INSTANCED_BUILTIN(ty, cls_tree, res)
      node = updateClass(inst_cls, node)
    end
  end
  attributeRef.x = attributes
  return node
end

function instClassDef(cls::EXPANDED_DERIVED,
                      outerMod::Modifier,
                      attributes::Attributes,
                      useBinding::Bool,
                      node::InstNode,
                      parentArg::InstNode,
                      instLevel::Int,
                      attributeRef::Ref{Attributes})::CLASS_NODE
  (node, par,_ , _) = instantiate(node, parentArg)
  node = setNodeType(DERIVED_CLASS(nodeType(node)), node)
  @match EXPANDED_DERIVED(baseClass = base_node) = getClass(node)
  #=  Merge outer modifiers and attributes.
  =#
  mod = fromElement(definition(node), list(node), rootParent(node))
  outer_mod = merge(outerMod, addParent(node, cls.modifier))
  mod = merge(outer_mod, mod)
  #strMod = toString(mod, true)
  #@debug "Merged mod EXPANDED_DERIVED: $strMod"
  attrs = updateClassConnectorType(cls.restriction, cls.attributes)
  attributes = mergeDerivedAttributes(attrs, attributes, parentArg)
  #=  Instantiate the base class and update the nodes.
  =#
  base_node = instClass(base_node, mod, attributes, attributeRef, useBinding, instLevel, par)
  attributes = attributeRef.x
  cls = EXPANDED_DERIVED(base_node,
                         cls.modifier,
                         arrayCopy(cls.dims),
                         cls.prefixes,
                         attributes,
                         cls.restriction)
  #=  Update the parentArg's type with the new class instance. =#
  node = updateClass(cls, node)
  updateComponentType(parentArg, node)
  return node
end

function instClassDef(cls::EXPANDED_CLASS,
                      outerMod::Modifier,
                      attributes::Attributes,
                      useBinding::Bool,
                      node::CLASS_NODE,
                      parentArg::InstNode,
                      instLevel::Int,
                      attributeRef::Ref{Attributes})::CLASS_NODE
  local par::InstNode
  local base_node::InstNode
  local inst_cls::Class
  local cls_tree::ClassTree
  local mod::Modifier
  local outer_mod::Modifier
  local res::Restriction
  local ty::M_Type
  local attrs::Attributes
  res = cls.restriction
  #=  Skip instantiating the class tree if the class is a base class,
    it has (hopefully) already been instantiated in that case.
  =#
  if isBaseClass(node)
    par = parentArg
  else
    @match (node::CLASS_NODE, par, _, _) = instantiate(node::CLASS_NODE, parentArg)
  end
  updateComponentType(parentArg, node)
  attributes = updateClassConnectorType(res, attributes)
  inst_cls = getClass(node)
  cls_tree = inst_cls.elements
  #=  Fetch modification on the class definition (for class extends). =#
  mod = fromElement(definition(node), nil, par)
  #=  Merge with any outer modifications. =#
  outer_mod = merge(outerMod, cls.modifier)
  mod = merge(outer_mod, mod)
  #=  Apply the modifiers of extends nodes. =#
  mapExtends(cls_tree, par)
  #=  Apply the modifiers of this scope. =#
  applyModifier(mod, cls_tree, name(node))
  #=  Apply element redeclares. =#
  mapRedeclareChains(cls_tree, redeclareElements, instLevel)
  #=  Redeclare classes with redeclare modifiers. Redeclared components could
    also be handled here, but since each component is only instantiated once
    it's more efficient to apply the redeclare when instantiating them instead.
  =#
  redeclareClasses(cls_tree)
  #=  Instantiate the extends nodes. =#
  mapExtends(cls_tree, attributes, useBinding, ExtendsVisibility.PUBLIC, instLevel + 1, attributeRef)
  applyLocalComponents(cls_tree, attributes, useBinding, instLevel + 1, attributeRef)
  #=  Remove duplicate elements. =#
  cls_tree = replaceDuplicates(cls_tree)
  checkDuplicates(cls_tree)
  updateClass(setClassTree(cls_tree, inst_cls), node)
  #= Update the attributes=#
  attributeRef.x = attributes
  return node
end

"""Sets the class instance of a component node."""
function updateComponentType(component::T0, cls::T1)::T0 where {T0, T1}
  if isComponent(component)
    component = componentApply(component, setClassInstance, cls)
  end
  component
end

function updateClassConnectorType(res::Restriction, attrs::Attributes) ::Attributes
  if isExpandableConnector(res)
    @assign attrs.connectorType = setExpandable(attrs.connectorType)
  elseif isConnector(res)
    @assign attrs.connectorType = setConnector(attrs.connectorType)
  end
  attrs
end

"""Instantiates the constructor and destructor for an ExternalObject class."""
function instExternalObjectStructors(@nospecialize(ty::M_Type), parentNode::InstNode)
  local constructor::InstNode
  local destructor::InstNode
  local par::InstNode

  #=  The constructor and destructor have function parameters that are instances
  =#
  #=  of the external object class, and we instantiate the structors when we
  =#
  #=  instantiate such instances. To break that loop we check that we're not
  =#
  #=  inside the external object class before instantiating the structors.
  =#
   par = parent(parent(parentNode))
  if ! (isClass(par) && isExternalObject(getClass(par)))
    @match TYPE_COMPLEX(complexTy = COMPLEX_EXTERNAL_OBJECT(constructor, destructor)) = ty
    instFunctionNode(constructor)
    instFunctionNode(destructor)
  end
end

"""
  This function instantiates a package given a package node. If the package has
  already been instantiated, then the cached instance from the node is
  returned. Otherwise the node is fully instantiated, the instance is added to
  the node's cache, and the instantiated node is returned.
"""
function instPackage(node::InstNode; isRedeclared::Bool = false)::CLASS_NODE
  local cache::CachedData
  local inst::InstNode
  local state::Int
  cache = getPackageCache(node)
  if cache isa C_PACKAGE
    inst = cache.instance
    state = cache.state.x
    if state == CACHE_STATE_INSTANTIATED || state == CACHE_STATE_PROCESSING
      return inst
    end
    if isRedeclared && state == CACHE_STATE_PARTIALLY_INSTANTIATED
      inst = instantiateN1(inst, EMPTY_NODE(), true)
      instExpressions(inst)
      setPackageCache(node, C_PACKAGE(inst, CACHE_STATE_INSTANTIATED))
      return inst
    end
    return inst
  else
    inst = node
    state = CACHE_STATE_NOT_INSTANTIATED
  end
    #=  Cache the package node itself first, to avoid instantiation loops if
    =#
    #=  the package uses itself somehow.
    =#

  node = setPackageCache(node, C_PACKAGE(node, CACHE_STATE_PROCESSING))
  inst = instantiateN1(node, EMPTY_NODE(), isRedeclared)
  node = setPackageCache(node, C_PACKAGE(inst, CACHE_STATE_PARTIALLY_INSTANTIATED))
  if !isPartial(inst) || isRedeclared
    instExpressions(inst)
    node = setPackageCache(node, C_PACKAGE(inst, CACHE_STATE_INSTANTIATED))
  end
  node = inst

    #end
  return node
end

function modifyExtends(extendsNode::InstNode, scope::InstNode)
  local elem::SCode.Element
  local ext_mod::Modifier
  local ext_node::InstNode
  local info::SourceInfo
  local cls::Class
  local cls_tree::ClassTree

  cls = getClass(extendsNode)
  cls_tree = classTree(cls)
  #=  Create a modifier from the extends.
  =#
  @match BASE_CLASS(definition = elem) = nodeType(extendsNode)
  ext_mod = fromElement(elem, nil, scope)
  ext_mod = merge(getModifier(extendsNode), ext_mod)
  if ! isBuiltin(cls)
    mapExtendsWithExtendsNode(cls_tree, extendsNode)
    () = begin
      @match elem begin
        SCode.EXTENDS(__)  => begin
          #=  TODO: Lookup the base class and merge its modifier. =#
          ext_node = listHead(lookupBaseClassName(elem.baseClassPath, scope, elem.info))
          #=  Finding a different element than before expanding extends
          =#
          #=  (probably an inherited element) is an error.
          =#
          if ! referenceEq(definition(extendsNode), definition(ext_node))
            # Error.addMultiSourceMessage(Error.FOUND_OTHER_BASECLASS, list(AbsynUtil.pathString(elem.baseClassPath)), list(InstNode_info(extendsNode), InstNode_info(ext_node)))
            fail("Found another base class")
          end
          ()
        end

        SCode.CLASS(__)  => begin
          ()
        end
      end
    end
  end
  applyModifier(ext_mod, cls_tree, name(extendsNode))
  extendsNode
end

struct ExtendsVisabilityStruct{T <: Int}
  PUBLIC::T
  DERIVED_PROTECTED::T
  PROTECTED::T
end
const ExtendsVisibility::ExtendsVisabilityStruct{Int} = ExtendsVisabilityStruct(1, 2, 3)
const ExtendsVisibilityType = Int



function instExtends(node::CLASS_NODE,
                               attributes::Attributes,
                               useBinding::Bool,
                               visibility::ExtendsVisibilityType,
                               instLevel::Int,
                               attributeRef::Ref{Attributes})::CLASS_NODE
  local cls::Class
  local inst_cls::Class
  local cls_tree::ClassTree
  local vis::ExtendsVisibilityType = visibility
  cls = getClass(node)
  @match cls begin
    EXPANDED_CLASS(elements = cls_tree && CLASS_TREE_INSTANTIATED_TREE(__))  => begin
      if vis == ExtendsVisibility.PUBLIC && isProtectedBaseClass(node) || vis == ExtendsVisibility.DERIVED_PROTECTED
        vis = ExtendsVisibility.PROTECTED
      end
      #=  Protect components and classes if the extends is protected, except
      =#
      #=  if they've already been protected by an extends higher up.
      =#
      if vis == ExtendsVisibility.PROTECTED && visibility != ExtendsVisibility.PROTECTED
        for c in cls_tree.classes
          P_Pointer.update(c, protectClass(P_Pointer.access(c)))
        end
        for c in cls_tree.components
          P_Pointer.update(c, protectComponent(P_Pointer.access(c)))
        end
      end
      noMod = MODIFIER_NOMOD()
      mapExtends(cls_tree::CLASS_TREE_INSTANTIATED_TREE, attributes, useBinding, vis, instLevel, attributeRef)
      applyLocalComponents(cls_tree::CLASS_TREE_INSTANTIATED_TREE, attributes, useBinding::Bool, instLevel::Int, attributeRef)
    end
    EXPANDED_DERIVED(__)  => begin
      if vis == ExtendsVisibility.PUBLIC && isProtectedBaseClass(node)
        vis = ExtendsVisibility.DERIVED_PROTECTED
      end
      cls.baseClass = instExtends(cls.baseClass, attributes, useBinding, vis, instLevel, attributeRef)::CLASS_NODE
      node = updateClass(cls, node)
    end
    PARTIAL_BUILTIN(__)  => begin
      inst_cls = INSTANCED_BUILTIN(cls.ty, cls.elements, cls.restriction)
      node = updateClass(inst_cls, node)
    end
    _  => begin
    end
  end
  node
end


"""
Applies a modifier in the given scope, by splitting the modifier and merging
each part with the relevant element in the scope.
"""
function applyModifier(modifier::Modifier, cls::ClassTree, clsName::String) ::ClassTree
  local mods::List{Modifier}
  local node_ptrs::List{Pointer{InstNode}}
  local node::InstNode
  local comp::Component
  #=  Split the modifier into a list of submodifiers.
  =#
  mods = toList(modifier)
  if listEmpty(mods)
    return cls
  end
  () = begin
    @match cls begin
      CLASS_TREE_FLAT_TREE(__)  => begin
        for mod in mods
          try
            @match ENTRY_INFO(node, _) = lookupElement(name(mod), cls)
          catch e
            #Error.addSourceMessage(Error.MISSING_MODIFIED_ELEMENT, list(name(mod), clsName), Mofifier_info(mod))
            @error "Missing modified element!. Error was $(e)"
            fail()
          end
          componentApply(node, mergeModifier, mod)
        end
        ()
      end

      _  => begin
        for mod in mods
          try
            node_ptrs = lookupElementsPtr(name(mod), cls)
          catch e
            @error "Missing modified element! "
            Error.addSourceMessage(Error.MISSING_MODIFIED_ELEMENT, list(name(mod), clsName), Modifier_info(mod))
            fail()
          end
          for node_ptr in node_ptrs
            node = resolveOuter(P_Pointer.access(node_ptr))
            if isComponent(node)
              local n2 = componentApply(node, mergeModifier, mod)
              if n2 !== node
                P_Pointer.update(node_ptr, n2)
              end
            else
              if isOnlyOuter(node)
                Error.addSourceMessage(Error.OUTER_ELEMENT_MOD, list(toString(mod, false), name(mod)), info(mod))
                fail()
              end
              partialInstClass(node)
              node = replaceClass(mergeModifier(mod, getClass(node)), node)
              node = clearPackageCache(node)
              P_Pointer.update(node_ptr, node)
            end
          end
        end
        ()
      end
    end
  end
  cls
end

function redeclareClasses(tree::ClassTree) ::ClassTree
  local cls_node::InstNode
  local redecl_node::InstNode
  local cls::Class
  local mod::Modifier
   () = begin
    @match tree begin
      CLASS_TREE_INSTANTIATED_TREE(__)  => begin
        for cls_ptr in tree.classes
           cls_node = P_Pointer.access(cls_ptr)
           cls = getClass(resolveOuter(cls_node))
           mod = getModifier(cls)
          if isRedeclare(mod)
            @match MODIFIER_REDECLARE(element = redecl_node, mod = mod) = mod
            cls_node = redeclareClass(redecl_node, cls_node, mod)
            P_Pointer.update(cls_ptr, cls_node)
          end
        end
        ()
      end
      _  => begin
        ()
      end
    end
  end
  tree
end

function redeclareElements(chain::List, instLevel::Int)
  local node::InstNode
  local node_ptr::Pointer{InstNode}

   node = P_Pointer.access(listHead(chain))
   node_ptr = listHead(chain)
  if isClass(node)
    for cls_ptr in listRest(chain)
       node_ptr = redeclareClassElement(cls_ptr, node_ptr)
    end
     node = P_Pointer.access(node_ptr)
  else
    for comp_ptr in listRest(chain)
       node_ptr = redeclareComponentElement(comp_ptr, node_ptr, instLevel)
    end
     node = P_Pointer.access(node_ptr)
  end
  for cls_ptr in chain
    P_Pointer.update(cls_ptr, node)
  end
end

function redeclareClassElement(redeclareCls::Pointer{InstNode}, replaceableCls::Pointer{InstNode})::Pointer{InstNode}
  local outCls::Pointer{InstNode}
  local rdcl_node::InstNode
  local repl_node::InstNode
   rdcl_node = P_Pointer.access(redeclareCls)
   repl_node = P_Pointer.access(replaceableCls)
   rdcl_node = redeclareClass(rdcl_node, repl_node, MODIFIER_NOMOD())
   outCls = P_Pointer.create(rdcl_node)
  outCls
end

function redeclareComponentElement(redeclareComp::Pointer{InstNode}, replaceableComp::Pointer{InstNode}, instLevel::Int) ::Pointer{InstNode}
  local outComp::Pointer{InstNode}
  local rdcl_node::InstNode
  local repl_node::InstNode
  rdcl_node = P_Pointer.access(redeclareComp)
  repl_node = P_Pointer.access(replaceableComp)
  instComponent(repl_node, DEFAULT_ATTR, MODIFIER_NOMOD(), true, instLevel, Ref{Attributes}(DEFAULT_ATTR))
  redeclareComponent(rdcl_node, repl_node, MODIFIER_NOMOD(), MODIFIER_NOMOD(), DEFAULT_ATTR, rdcl_node, instLevel)
   outComp = P_Pointer.create(rdcl_node)
  outComp
end

function redeclareClass(redeclareNode::InstNode, originalNode::InstNode, outerMod::Modifier) ::InstNode
  local redeclaredNode::InstNode
  local orig_node::InstNode
  local orig_cls::Class
  local rdcl_cls::Class
  local new_cls::Class
  local prefs::Prefixes
  local node_ty::InstNodeType
  #=  Check that the redeclare element is actually a class.
  =#
  if ! isClass(redeclareNode)
    Error.addMultiSourceMessage(Error.INVALID_REDECLARE_AS, list(typeName(originalNode), name(originalNode), typeName(redeclareNode)), list(InstNode_info(redeclareNode), InstNode_info(originalNode)))
    fail()
  end
  partialInstClass(originalNode)
   orig_cls = getClass(originalNode)
  partialInstClass(redeclareNode)
   rdcl_cls = getClass(redeclareNode)
   prefs = mergeRedeclaredClassPrefixes(getPrefixes(orig_cls), getPrefixes(rdcl_cls), redeclareNode)
  if SCodeUtil.isClassExtends(definition(redeclareNode))
     orig_node = expand(originalNode)
     orig_cls = getClass(orig_node)
     new_cls = begin
      @match (orig_cls, rdcl_cls) begin
        (_, PARTIAL_CLASS(__)) where (isBuiltin(orig_cls))  => begin
          #=  Class extends of a builtin type. Not very useful, but technically allowed
          =#
          #=  if the redeclaring class is empty.
          =#
          if ! SCodeUtil.isEmptyClassDef(SCodeUtil.getClassDef(definition(redeclareNode)))
            Error.addSourceMessage(Error.BUILTIN_EXTENDS_INVALID_ELEMENTS, list(name(redeclareNode)), InstNode_info(redeclareNode))
            fail()
          end
          #=  Class extends of a builtin type is only allowed if the extending class is empty,
          =#
          #=  otherwise it violates the rules of extending a builtin type.
          =#
          setPrefixes(prefs, orig_cls)
        end

        (EXPANDED_CLASS(__), PARTIAL_CLASS(__))  => begin
          #=  Class extends of a long class declaration. =#
           node_ty = BASE_CLASS(parent(orig_node), definition(orig_node))
           orig_node = setNodeType(node_ty, orig_node)
          @assign begin
            rdcl_cls.elements = setClassExtends(orig_node, rdcl_cls.elements)
            rdcl_cls.modifier = merge(outerMod, rdcl_cls.modifier)
            rdcl_cls.prefixes = prefs
          end
          rdcl_cls
        end

        (EXPANDED_DERIVED(__), PARTIAL_CLASS(__))  => begin
          #=  Class extends of a short class declaration.
          =#
          @assign rdcl_cls.prefixes = prefs
          rdcl_cls
        end

        _  => begin
          Error.assertion(false, getInstanceName() + " got unknown classes", sourceInfo())
          fail()
        end
      end
    end
  else
    @assign new_cls = begin
      @match (orig_cls, rdcl_cls) begin
        (PARTIAL_BUILTIN(__), _)  => begin
          redeclareEnum(rdcl_cls, orig_cls, prefs, outerMod, redeclareNode, originalNode)
        end

        (_, PARTIAL_CLASS(__))  => begin
          @assign rdcl_cls.prefixes = prefs
          @assign rdcl_cls.modifier = merge(outerMod, rdcl_cls.modifier)
          rdcl_cls
        end

        _  => begin
          Error.assertion(false, getInstanceName() + " got unknown classes", sourceInfo())
          fail()
        end
      end
    end
  end
  redeclaredNode = replaceClass(new_cls, redeclareNode)
  node_ty = REDECLARED_CLASS(parent(originalNode), nodeType(originalNode))
  redeclaredNode = setNodeType(node_ty, redeclaredNode)
  redeclaredNode
end

function redeclareEnum(redeclareClass::Class, originalClass::Class, prefixes::Prefixes, outerMod::Modifier, redeclareNode::InstNode, originalNode::InstNode) ::Class
  local redeclaredClass::Class = redeclareClass

  @assign redeclaredClass = begin
    local lits1::List{String}
    local lits2::List{String}
    @match (redeclaredClass, originalClass) begin
      (PARTIAL_BUILTIN(ty = TYPE_ENUMERATION(literals = lits1)), PARTIAL_BUILTIN(ty = TYPE_ENUMERATION(literals = lits2)))  => begin
        if ! (listEmpty(lits2) || ListUtil.isEqualOnTrue(lits1, lits2, stringEq))
          Error.addMultiSourceMessage(Error.REDECLARE_ENUM_NON_SUBTYPE, list(name(originalNode)), list(InstNode_info(redeclareNode), InstNode_info(originalNode)))
          fail()
        end
        @assign redeclaredClass.prefixes = prefixes
        @assign redeclaredClass.modifier = merge(outerMod, redeclaredClass.modifier)
        redeclaredClass
      end

      _  => begin
        Error.addMultiSourceMessage(Error.REDECLARE_CLASS_NON_SUBTYPE, list(toString(restriction(originalClass)), name(originalNode)), list(InstNode_info(redeclareNode), InstNode_info(originalNode)))
        fail()
      end
    end
  end
  redeclaredClass
end

function instComponent(node::InstNode,
                       attributes::Attributes ,
                       innerMod::Modifier,
                       useBinding::Bool,
                       instLevel::Int,
                       attributeRef::Ref{Attributes},
                       originalAttr = NONE())::Nothing
  local comp::Component
  local def::SCode.COMPONENT
  local comp_node::COMPONENT_NODE{String, Int8}
  local rdcl_node::InstNode
  local outer_mod::Modifier
  local cc_mod::Modifier = innerMod
  local cc_smod::SCode.Mod
  local nameStr::String
  local parentNode::InstNode
  comp_node = resolveOuter(node)
  comp = component(comp_node)
  parentNode = parent(comp_node)
  #=  Skip already instantiated components. =#
  if ! isDefinition(comp)
    checkRecursiveDefinition(classInstance(comp), comp_node, false)
    return
  end
  #=  An already instantiated component might be due to an instantiation loop, check it. =#
  @match COMPONENT_DEF(definition = def, modifier = outer_mod) = comp
  if isRedeclare(outer_mod)
    checkOuterComponentMod(outer_mod, def, comp_node)
    instComponentDef(def::SCode.COMPONENT, MODIFIER_NOMOD(), MODIFIER_NOMOD(),
                     DEFAULT_ATTR, useBinding, comp_node, parentNode,
                     instLevel, attributeRef, originalAttr, #=isRedeclared =# true)::Nothing
    @match MODIFIER_REDECLARE(element = rdcl_node, mod = outer_mod) = outer_mod
    cc_smod = SCodeUtil.getConstrainingMod(def)
    if ! SCodeUtil.isEmptyMod(cc_smod)
      nameStr = name(node)
      cc_mod = create(cc_smod, nameStr, SCOPE_COMPONENT(nameStr), nil, parentNode)
    end
    outer_mod = merge(getModifier(rdcl_node), outer_mod)
    setModifier(outer_mod, rdcl_node)
    redeclareComponent(rdcl_node, node, MODIFIER_NOMOD(), cc_mod, attributes, node, instLevel, attributeRef)
  else
    instComponentDef(def::SCode.COMPONENT,
                     outer_mod,
                     cc_mod,
                     attributes,
                     useBinding,
                     comp_node::COMPONENT_NODE,
                     parentNode,
                     instLevel,
                     attributeRef,
                     originalAttr)::Nothing
  end
  return nothing
end

function instComponentDef(component::SCode.COMPONENT,
                          outerMod::Modifier,
                          innerMod::Modifier,
                          attributes::Attributes,
                          useBinding::Bool,
                          node::COMPONENT_NODE,
                          parentNode::InstNode,
                          instLevel::Int,
                          attributeRef::Ref{Attributes},
                          originalAttr = NONE(),
                          isRedeclared::Bool = false)::Nothing
  local decl_mod::Modifier
  local mod::Modifier
  local cc_mod::Modifier
  local ty_dims::List
  local bindingVar::Binding
  local attr::Attributes
  local ty_attr::Attributes
  local ty_node::CLASS_NODE
  local res::Restriction
  decl_mod = fromElement(component, nil, parentNode)
  cc_mod = instConstrainingMod(component, parentNode)
  mod = merge(decl_mod, cc_mod)
  mod = merge(mod, innerMod)
  mod = merge(outerMod, mod)
  mod = addParent(node, mod)
  checkOuterComponentMod(mod, component, node)
  local dims = listEmpty(component.attributes.arrayDims) ? EMPTY_RAW_DIMS :
               DIMENSION_RAW_DIM[DIMENSION_RAW_DIM(d) for d in component.attributes.arrayDims]
  bindingVar = if useBinding
    binding(mod)
  else
    EMPTY_BINDING
  end
  local condition = fromAbsyn(component.condition, false, list(node), parentNode, component.info)
  #=  Instantiate the component's attributes, and merge them with the =#
  #=  attributes of the component's parent (e.g. constant SomeComplexClass c). =#
  local parent_res = restriction(getClass(parentNode))
  attr = instComponentAttributes(component.attributes, component.prefixes)
  attr = checkDeclaredComponentAttributes(attr, parent_res, node)
  attr = mergeComponentAttributes(attributes, attr, node, parent_res)
  if isSome(originalAttr)
    attr = mergeRedeclaredComponentAttributes(Util.getOption(originalAttr), attr, node)
  end
  if ! attr.isFinal && isFinal(mod)
    attr.isFinal = true
  end
  #=
  Create the untyped component and update the node with it. We need the
  untyped component in instClass to make sure everything is scoped
  correctly during lookup, but the class node the component should have
  is created by instClass. To break the circle we leave the class node
  empty here, and let instClass set it for us instead.
  =#
  local inst_comp = UNTYPED_COMPONENT(EMPTY_NODE(),
                                      dims,
                                      bindingVar,
                                      condition,
                                      attr,
                                      SOME(component.comment),
                                      false,
                                      component.info)
  updateComponent!(inst_comp, node)
  #=  Instantiate the type of the component. =#
  local typeSpecCond = useBinding && ! isBound(bindingVar)
  ty_node = instTypeSpec(component.typeSpec, mod, attr, typeSpecCond, parentNode, node, component.info, instLevel, attributeRef; isRedeclared = isRedeclared)
  ty_attr = attributeRef.x
  local ty = getClass(ty_node)
  #=  Update the component's variability based on its type (e.g. Integer is discrete). =#
  ty_attr = updateComponentVariability(ty_attr, ty, ty_node)
  #=  Update the component's connector type now that we have its type. =#
  res = restriction(getClass(ty_node))
  ty_attr = updateComponentConnectorType(ty_attr, res, isRedeclared, node)
  if ! referenceEq(attr, ty_attr)
    componentApply(node, setAttributes, ty_attr)
  end
  nothing
end

function instConstrainingMod(element::SCode.Element, parent::InstNode) ::Modifier
  local ccMod::Modifier
  ccMod = begin
    local smod::SCode.Mod
    @match element begin
      SCode.CLASS(prefixes = SCode.PREFIXES(replaceablePrefix = SCode.REPLACEABLE(cc = SOME(SCode.CONSTRAINCLASS(modifier = smod)))))  => begin
        create(smod, element.name, cope.CLASS(element.name), nil, parent)
      end
      SCode.COMPONENT(prefixes = SCode.PREFIXES(replaceablePrefix = SCode.REPLACEABLE(cc = SOME(SCode.CONSTRAINCLASS(modifier = smod)))))  => begin
        create(smod, element.name, SCOPE_COMPONENT(element.name), nil, parent)
      end
      _  => begin
        MODIFIER_NOMOD()
      end
    end
  end
  ccMod
end

function updateComponentConnectorType(attributes::Attributes, restriction::Restriction, isRedeclared::Bool, component::InstNode) ::Attributes
  local cty = attributes.connectorType
  if isConnectorType(cty)
    if isConnector(restriction)
      if isExpandableConnector(restriction)
        cty = setPresent(cty)
      else
        cty = intBitAnd(cty, intBitNot(ConnectorType.EXPANDABLE))
      end
    else
      cty = intBitAnd(cty, intBitNot(intBitOr(ConnectorType.CONNECTOR, ConnectorType.EXPANDABLE)))
    end
    if ! isFlowOrStream(cty)
      cty = setPotential(cty)
    end
    if cty != attributes.connectorType
      @assign attributes.connectorType = cty
    end
  elseif isFlowOrStream(cty) && ! isRedeclared
    #Error.addStrictMessage(Error.CONNECTOR_PREFIX_OUTSIDE_CONNECTOR, list(toString(cty)), Copmonent_info(component)) TODO
    @warn "CONNECTOR_PREFIX_OUTSIDE_CONNECTOR: list(toString(cty))"
    @assign attributes.connectorType = unsetFlowStream(cty)
  end
  attributes
end

function redeclareComponent(redeclareNode::InstNode, originalNode::InstNode, outerMod::Modifier, constrainingMod::Modifier, outerAttr::Attributes, redeclaredNode::InstNode, instLevel::Int, attributeRef::Ref{Attributes})
  local orig_comp::Component
  local rdcl_comp::Component
  local new_comp::Component
  local bindingVar::Binding
  local condition::Binding
  local attr::Attributes
  local dims::Vector{Dimension}
  local cmt::Option{SCode.Comment}
  local rdcl_node::InstNode
  local rdcl_type::InstNodeType

  #=  Check that the redeclare element actually is a component.
  =#
  if ! isComponent(redeclareNode)
    Error.addMultiSourceMessage(Error.INVALID_REDECLARE_AS, list(typeName(originalNode), name(originalNode), typeName(redeclareNode)), list(InstNode_info(redeclareNode), InstNode_info(originalNode)))
    fail()
  end
  orig_comp = component(originalNode)
  rdcl_type = REDECLARED_COMP(parent(originalNode))
  rdcl_node = setNodeType(rdcl_type, redeclareNode)
  rdcl_node = copyInstancePtr(originalNode, rdcl_node)
  rdcl_node = updateComponent!(component(redeclareNode), rdcl_node)
  instComponent(rdcl_node, outerAttr, constrainingMod, true, instLevel, attributeRef, SOME(getAttributes(orig_comp)))
  rdcl_comp = component(rdcl_node)
  new_comp = begin
    @match (orig_comp, rdcl_comp) begin
      (UNTYPED_COMPONENT(__), UNTYPED_COMPONENT(__))  => begin
        #=  Take the binding from the outer modifier, the redeclare, or the
        =#
        #=  original component, in that order of priority.
        =#
        bindingVar = binding(outerMod)
        if isUnbound(bindingVar)
          bindingVar = if isBound(rdcl_comp.binding)
            rdcl_comp.binding
          else
            orig_comp.binding
          end
        end
        #=  A redeclare is not allowed to have a condition expression.
        =#
        if isBound(rdcl_comp.condition)
          Error.addSourceMessage(Error.REDECLARE_CONDITION, list(name(redeclareNode)), InstNode_info(redeclareNode))
          fail()
        end
        condition = orig_comp.condition
        attr = rdcl_comp.attributes
        #=  Use the dimensions of the redeclare if any, otherwise take them from the original.
        =#
        dims = if arrayEmpty(rdcl_comp.dimensions)
          orig_comp.dimensions
        else
          rdcl_comp.dimensions
        end
        #=  TODO: Use comment of redeclare if available?
        =#
        cmt = orig_comp.comment
        UNTYPED_COMPONENT(rdcl_comp.classInst, dims, bindingVar, condition, attr, cmt, false, rdcl_comp.info)
      end

      _  => begin
        Error.assertion(false, getInstanceName() + " got unknown components", sourceInfo())
        fail()
      end
    end
  end
  updateComponent!(new_comp, redeclaredNode)
end

"""
  Prints an error message and fails if it gets an outer component and a
  non-empty modifier.
"""
function checkOuterComponentMod(mod::Modifier, component::SCode.Element, node::InstNode)
  if ! isEmpty(mod) && AbsynUtil.isOnlyOuter(SCodeUtil.prefixesInnerOuter(SCodeUtil.elementPrefixes(component)))
    Error.addSourceMessage(Error.OUTER_ELEMENT_MOD, list(toString(mod, false), name(node)), InstNode_info(node))
    fail()
  end
end

"""
  This function instantiates component attributes.
  It uses ´DEFAULT_ATTR´ or some special modifier depending on the component prefix.
"""
function instComponentAttributes(compAttr::SCode.Attributes, compPrefs)::Attributes
  #= Plain field tests: matching on a constructed (attr, prefs) tuple costs
     an allocation and pattern machinery per component, and the default case
     dominates. =#
  if compAttr.connectorType isa SCode.POTENTIAL &&
     compAttr.parallelism isa SCode.NON_PARALLEL &&
     compAttr.variability isa SCode.VAR &&
     compAttr.direction isa Absyn.BIDIR &&
     compAttr.isField === false &&
     compAttr.mode === false &&
     compPrefs.redeclarePrefix isa SCode.NOT_REDECLARE &&
     compPrefs.finalPrefix isa SCode.NOT_FINAL &&
     compPrefs.innerOuter isa Absyn.NOT_INNER_OUTER &&
     compPrefs.replaceablePrefix isa SCode.NOT_REPLACEABLE
    return DEFAULT_ATTR
  end
  local cty = fromSCode(compAttr.connectorType)
  local par = parallelismFromSCode(compAttr.parallelism)
  local var = variabilityFromSCode(compAttr.variability)
  local dir = directionFromSCode(compAttr.direction)
  local io = innerOuterFromSCode(compPrefs.innerOuter)
  local fin = SCodeUtil.finalBool(compPrefs.finalPrefix)
  local redecl = SCodeUtil.redeclareBool(compPrefs.redeclarePrefix)
  return ATTRIBUTES(cty, par, var, dir, io, fin, redecl, NOT_REPLACEABLE(), compAttr.mode)
end

function mergeComponentAttributes(outerAttr::Attributes, innerAttr::Attributes, node::InstNode, parentRestriction::Restriction) ::Attributes
  local attr::Attributes

  local cty::ConnectorType.TYPE
  local par::ParallelismType
  local var::VariabilityType
  local dir::DirectionType
  local fin::Bool
  local redecl::Bool
  local repl::Replaceable

  if referenceEq(outerAttr, DEFAULT_ATTR) && innerAttr.connectorType == 0
    attr = innerAttr
  elseif referenceEq(innerAttr, DEFAULT_ATTR)
    cty = merge(outerAttr.connectorType, innerAttr.connectorType, node)
    attr = ATTRIBUTES(cty, outerAttr.parallelism,
                      outerAttr.variability, outerAttr.direction, innerAttr.innerOuter, outerAttr.isFinal,
                      innerAttr.isRedeclare, innerAttr.isReplaceable, innerAttr.isStructuralMode #=TODO: VSS Unsure if this should propagate like this=#)
  else
    cty = merge(outerAttr.connectorType, innerAttr.connectorType, node)
    par = mergeParallelism(outerAttr.parallelism, innerAttr.parallelism, node)
    var = variabilityMin(outerAttr.variability, innerAttr.variability)
    if isFunction(parentRestriction)
      dir = innerAttr.direction
    else
      dir = mergeDirection(outerAttr.direction, innerAttr.direction, node)
    end
    fin = outerAttr.isFinal || innerAttr.isFinal
    redecl = innerAttr.isRedeclare
    repl = innerAttr.isReplaceable
    # outerAttr.connectorType = cty
    # outerAttr.parallelism = par
    # outerAttr.variability = var
    # outerAttr.direction = dir
    # outerAttr.innerOuter = innerAttr.innerOuter
    # outerAttr.isFinal = fin
    # outerAttr.isRedeclare = redecl
    # outerAttr.isReplaceable = repl
    # outerAttr.isStructuralMode = innerAttr.isStructuralMode
    # attr = outerAttr
    attr = ATTRIBUTES(cty, par, var, dir, innerAttr.innerOuter, fin, redecl, repl,innerAttr.isStructuralMode #= TODO: VSS Unsure if this should propagate like this=#)
  end
  attr
end

function checkDeclaredComponentAttributes(attr::Attributes, parentRestriction::Restriction, component::InstNode) ::Attributes
   () = begin
    @match parentRestriction begin
     RESTRICTION_CONNECTOR(__)  => begin
        #=  Components of a connector may not have prefixes 'inner' or 'outer'.
        =#
        assertNotInnerOuter(attr.innerOuter, component, parentRestriction)
        if parentRestriction.isExpandable
          assertNotFlowStream(attr.connectorType, component, parentRestriction)
          attr.connectorType = intBitOr(attr.connectorType, ConnectorType.POTENTIALLY_PRESENT)
        end
        #=  Components of an expandable connector may not have the prefix 'flow'.
        =#
        #=  Mark components in expandable connectors as potentially present.
        =#
        ()
      end

      RESTRICTION_RECORD(__)  => begin
        #=  Elements of a record may not have prefixes 'input', 'output', 'inner', 'outer', 'stream', or 'flow'.
        =#
        assertNotInputOutput(attr.direction, component, parentRestriction)
        assertNotInnerOuter(attr.innerOuter, component, parentRestriction)
        assertNotFlowStream(attr.connectorType, component, parentRestriction)
        ()
      end

      _  => begin
        ()
      end
    end
  end
  attr
end

function invalidComponentPrefixError(prefix::String, node::InstNode, restriction)
  Error.addSourceMessage(Error.INVALID_COMPONENT_PREFIX, list(prefix, name(node), toString(restriction)), InstNode_info(node))
end

function assertNotInputOutput(dir, node::InstNode, restriction)
  if dir != Direction.NONE
    invalidComponentPrefixError(directionString(dir), node, restriction)
    fail()
  end
end

function assertNotInnerOuter(io, node::InstNode, restriction)
  if io != InnerOuter.NOT_INNER_OUTER
    invalidComponentPrefixError(innerOuterString(io), node, restriction)
    fail()
  end
end

function assertNotFlowStream(cty::ConnectorType.TYPE, node::InstNode, restriction)
  if isFlowOrStream(cty)
    invalidComponentPrefixError(toString(cty), node, restriction)
    fail()
  end
end

function mergeDerivedAttributes(outerAttr::Attributes, innerAttr::Attributes, node::InstNode) ::Attributes
  local attr::Attributes
  local cty::ConnectorType.TYPE
  local par::ParallelismType
  local var::VariabilityType
  local dir::DirectionType
  local io::Int8
  local fin::Bool
  local redecl::Bool
  local repl#::Replaceable type conversion work with this change?
  if referenceEq(innerAttr, DEFAULT_ATTR) && outerAttr.connectorType == 0
    attr = outerAttr
  elseif referenceEq(outerAttr, DEFAULT_ATTR) && innerAttr.connectorType == 0
    attr = innerAttr
  else
    #= The present error is here =#
    @match ATTRIBUTES(cty, par, var, dir, io, fin, redecl, repl, mo) || IMMUTABLE_ATTRIBUTES(cty, par, var, dir, io, fin, redecl, repl, mo) = outerAttr
    cty = merge(cty, innerAttr.connectorType, node, true)
    var = variabilityMin(var, innerAttr.variability)
    dir = mergeDirection(dir, innerAttr.direction, node, #= allowSame = true=# true)
    attr = ATTRIBUTES(cty, par, var, dir, io, fin, redecl, repl, mo)
  end
  attr
end

function mergeRedeclaredComponentAttributes(origAttr::Attributes, redeclAttr::Attributes, node::InstNode)::Attributes
  local attr::Attributes
  local cty::ConnectorType.TYPE
  local rcty::ConnectorType.TYPE
  local cty_fs::ConnectorType.TYPE
  local rcty_fs::ConnectorType.TYPE
  local par::ParallelismType
  local rpar::ParallelismType
  local var::VariabilityType
  local rvar::VariabilityType
  local dir::DirectionType
  local rdir::DirectionType
  local io::InnerOuterType
  local rio::InnerOuterType
  local fin::Bool
  local redecl::Bool
  local repl::Replaceable
  if referenceEq(origAttr, DEFAULT_ATTR)
    attr = redeclAttr
  elseif referenceEq(redeclAttr, DEFAULT_ATTR)
    attr = origAttr
  else
    @match ATTRIBUTES(cty, par, var, dir, io, _, _, _) = origAttr
    @match ATTRIBUTES(rcty, rpar, rvar, rdir, rio, fin, redecl, repl) = redeclAttr
    rcty_fs = intBitAnd(rcty, ConnectorType.FLOW_STREAM_MASK)
    cty_fs = intBitAnd(cty, ConnectorType.FLOW_STREAM_MASK)
    if rcty_fs > 0
      if cty_fs > 0 && rcty_fs != cty_fs
        printRedeclarePrefixError(node, ConnectorType.toString(rcty), ConnectorType.toString(cty))
      end
    end
    if rpar != Parallelism.NON_PARALLEL
      if par != Parallelism.NON_PARALLEL && par != rpar
        printRedeclarePrefixError(node, parallelismString(rpar), parallelismString(par))
      end
      par = rpar
    end
    if rvar != Variability.CONTINUOUS
      if rvar > var
        printRedeclarePrefixError(node, variabilityString(rvar), variabilityString(var))
      end
      var = rvar
    end
    if rdir != Direction.NONE
      if dir != Direction.NONE && rdir != dir
        printRedeclarePrefixError(node, directionString(rdir), directionString(dir))
      end
      dir = rdir
    end
    if rio != InnerOuter.NOT_INNER_OUTER
      if io != InnerOuter.NOT_INNER_OUTER && rio != io
        printRedeclarePrefixError(node, innerOuterString(rio), innerOuterString(io))
      end
      io = rio
    end
    attr = ATTRIBUTES(rcty, par, var, dir, io, fin, redecl, repl, false)
  end
  attr
end

function mergeRedeclaredClassPrefixes(origPrefs::Prefixes, redeclPrefs::Prefixes, node::InstNode) ::Prefixes
  local prefs::Prefixes
  local enc::SCode.Encapsulated
  local par::SCode.Partial
  local fin::SCode.Final
  local io::Absyn.InnerOuter
  local rio::Absyn.InnerOuter
  local repl::SCode.Replaceable

  if referenceEq(origPrefs, DEFAULT_PREFIXES)
    @assign prefs = redeclPrefs
  else
    @match PREFIXES(innerOuter = io) = origPrefs
    @match PREFIXES(enc, par, fin, rio, repl) = redeclPrefs
    @assign io = begin
      @match (io, rio) begin
        (Absyn.NOT_INNER_OUTER(__), _)  => begin
          rio
        end

        (_, Absyn.NOT_INNER_OUTER(__))  => begin
          io
        end

        (Absyn.INNER(__), Absyn.INNER(__))  => begin
          io
        end

        (Absyn.OUTER(__), Absyn.OUTER(__))  => begin
          io
        end

        (Absyn.INNER_OUTER(__), Absyn.INNER_OUTER(__))  => begin
          io
        end

        _  => begin
          printRedeclarePrefixError(node, innerOuterString(innerOuterFromSCode(rio)), innerOuterString(innerOuterFromSCode(io)))
          fail()
        end
      end
    end
    @assign prefs = PREFIXES(enc, par, fin, io, repl)
  end
  prefs
end

function printRedeclarePrefixError(node::InstNode, prefix1::String, prefix2::String)
  Error.addSourceMessageAndFail(Error.REDECLARE_MISMATCHED_PREFIX, list(prefix1, name(node), prefix2), InstNode_info(node))
end

function updateComponentVariability(attr::Attributes, cls::Class, clsNode::InstNode) ::Attributes
  local var::VariabilityType = attr.variability
  if referenceEq(attr, DEFAULT_ATTR) && isDiscreteClass(clsNode)
    attr = IMPL_DISCRETE_ATTR
  elseif var == Variability.CONTINUOUS && isDiscreteClass(clsNode)
    attr.variability = Variability.IMPLICITLY_DISCRETE
  end
  attr
end

function isDiscreteClass(clsNode::InstNode) ::Bool
  local discrete::Bool
  local base_node::InstNode
  local cls::Class
  local exts::Vector{InstNode}
  base_node = lastBaseClass(clsNode)
  cls = getClass(base_node)
  discrete = begin
    @match cls begin
      EXPANDED_CLASS(restriction = RESTRICTION_TYPE(__))  => begin
        exts = getExtends(cls.elements)
        if arrayLength(exts) == 1
          isDiscreteClass(exts[1])
        else
          false
        end
      end
      _  => begin
        isDiscrete(getType(cls, base_node))
      end
    end
  end
  discrete
end

function instTypeSpec(typeSpec::Absyn.TPATH,
                      modifier::Modifier,
                      attributes::Attributes,
                      useBinding::Bool,
                      scope::InstNode,
                      parent::InstNode,
                      info::SourceInfo,
                      instLevel::Int,
                      attributeRef::Ref{Attributes};
                      isRedeclared::Bool = false)::CLASS_NODE
  local node::InstNode = lookupClassName(typeSpec.path, scope, info; isRedeclared = isRedeclared)
  if instLevel >= 100
    checkRecursiveDefinition(node, parent, limitReached = true)
  end
  node = expand(node)
  instClass(node, modifier, attributes, attributeRef, useBinding, instLevel, parent)
end


function instTypeSpec(typeSpec::Absyn.TCOMPLEX,
                      modifier::Modifier,
                      attributes::Attributes,
                      useBinding::Bool,
                      scope::InstNode,
                      parent::InstNode,
                      info::SourceInfo,
                      instLevel::Int)
  @error("NFInst.instTypeSpec: $(typeof(typeSpec)) not implemented.\\n")
  fail()
end


"""
  Prints an error if a component causes a loop in the instance tree, for
  example because it has the same type as one of its parents. If the depth
  limit of the instance tree is reached, indicated by limitReached = true, then
  some error is always given. Otherwise an error is only given if an actual
  issue can be detected.
"""
function checkRecursiveDefinition(componentType::InstNode, component::InstNode, limitReached::Bool)
  local parentVar::InstNode = parent(component)
  local parent_type::InstNode
  #=
  Functions can contain instances of a parent, e.g. in equalityConstraint
  functions, so skip this check for functions.
  =#
  if ! isFunction(getClass(parentVar))
    while ! isEmpty(parentVar)
      parent_type = classScope(parentVar)
      if referenceEq(definition(componentType), definition(parent_type))
        Error.addSourceMessage(Error.RECURSIVE_DEFINITION, list(name(component), name(classScope(parent(component)))), InstNode_info(component))
        fail()
      end
      parentVar = parent(parentVar)
    end
  end
  #=  If we couldn't determine the exact cause of the recursion, print a generic error. =#
  if limitReached
    Error.addSourceMessage(Error.INST_RECURSION_LIMIT_REACHED, list(AbsynUtil.pathString(scopePath(component))), InstNode_info(component))
    fail()
  end
end

function instDimension(dimension::Dimension, scope::InstNode, info::SourceInfo) ::Dimension
  dimension = begin
    local dim::Absyn.Subscript
    local exp::Expression
    @match dimension begin
      DIMENSION_RAW_DIM(dim = dim)  => begin
        begin
          @match dim begin
            Absyn.NOSUB(__)  => begin
              DIMENSION_UNKNOWN()
            end

            Absyn.SUBSCRIPT(__)  => begin
              exp = instExp(dim.subscript, scope, info)
              DIMENSION_UNTYPED(exp, false)
            end
          end
        end
      end

      _  => begin
        dimension
      end
    end
  end
  dimension
end

const BUILTIN_PREFIX = "__OpenModelica_builtinType"

const INST_EXPR_DEPTH = Ref(0)
const INST_EXPR_DEPTH_LIMIT = 100
const INST_CLASS_DEPTH = Ref(0)
const INST_CLASS_DEPTH_LIMIT = 100

#= Diagnostic counters for detecting exponential blowup (monotonically increasing) =#
const INST_CLASS_TOTAL_CALLS = Ref(0)
const INST_CLASS_TOTAL_CALLS_LIMIT = 200_000
const REINSTANTIATION_COUNT = Ref(0)
const REINSTANTIATION_CLASSES = Dict{String, Int}()

function resetInstDiagnostics()
  INST_CLASS_TOTAL_CALLS[] = 0
  REINSTANTIATION_COUNT[] = 0
  empty!(REINSTANTIATION_CLASSES)
  INST_CLASS_DEPTH[] = 0
  INST_EXPR_DEPTH[] = 0
  empty!(CLASS_PTR_WRITES)
  empty!(COMPONENT_PTR_WRITES)
  empty!(CLASS_PTR_WRITERS)
  empty!(COMPONENT_PTR_WRITERS)
  empty!(FROZEN_ATTR_NODES)
  resetLookupCache()
end

"""
  Dumps the per-class re-instantiation breakdown for one translation. Useful
  to decide whether sibling parallelism in `applyLocalComponents` is safe
  unguarded (most siblings hit different class pointers) or needs locking
  (a few classes account for most of the work).

  Gated on env var `OMFRONTEND_INST_PROFILE=true`. Reads the env at call time
  so toggling does not require a Julia restart.

  Output: total `instClass` calls, total re-instantiations, concentration ratio
  (top-5 share of total), and the top-`topN` most re-instantiated classes.
"""
function dumpInstDiagnostics(modelName::String; topN::Int = 20)
  if get(ENV, "OMFRONTEND_INST_PROFILE", "false") != "true"
    return
  end
  local total = INST_CLASS_TOTAL_CALLS[]
  local reinst = REINSTANTIATION_COUNT[]
  local uniq = length(REINSTANTIATION_CLASSES)
  local sorted = sort(Base.collect(REINSTANTIATION_CLASSES), by = last, rev = true)
  local top5sum = sum(c for (_, c) in sorted[1:min(5, length(sorted))]; init = 0)
  local conc = total > 0 ? round(100 * top5sum / total; digits = 1) : 0.0
  println()
  println("==== Inst diagnostics for ", modelName, " ====")
  println("  total instClass calls : ", total)
  println("  reinstantiations      : ", reinst)
  println("  unique class names    : ", uniq)
  println("  top-5 share of total  : ", conc, " %")
  println("  top-", min(topN, length(sorted)), " classes by reinstantiation count:")
  for (i, (cn, count)) in enumerate(sorted[1:min(topN, length(sorted))])
    println("    ", lpad(i, 4), "  ", lpad(count, 8), "  ", cn)
  end
  # Pointer-write counters (broader signal: every updateClass / updateComponent! call is recorded).
  local classWrites = Base.collect(values(CLASS_PTR_WRITES))
  local compWrites  = Base.collect(values(COMPONENT_PTR_WRITES))
  local classTotal = sum(c for (_, c) in classWrites; init = 0)
  local compTotal  = sum(c for (_, c) in compWrites;  init = 0)
  local classMulti = count(x -> x[2] > 1, classWrites)
  local compMulti  = count(x -> x[2] > 1, compWrites)
  local classMax   = isempty(classWrites) ? 0 : maximum(c for (_, c) in classWrites)
  local compMax    = isempty(compWrites)  ? 0 : maximum(c for (_, c) in compWrites)
  println("  Pointer-write summary:")
  println("    class pointers      : ", length(classWrites), " unique, ", classTotal, " writes total, ",
          classMulti, " written more than once, max ", classMax, " writes on a single pointer")
  println("    component pointers  : ", length(compWrites), " unique, ", compTotal, " writes total, ",
          compMulti, " written more than once, max ", compMax, " writes on a single pointer")
  # Aliasing audit: distinct node identities per Ref cell. >1 == genuine multi-writer alias.
  local classWriters = Base.collect(values(CLASS_PTR_WRITERS))
  local compWriters  = Base.collect(values(COMPONENT_PTR_WRITERS))
  local classAliased = count(s -> length(s) > 1, classWriters)
  local compAliased  = count(s -> length(s) > 1, compWriters)
  local classMaxW    = isempty(classWriters) ? 0 : maximum(length, classWriters)
  local compMaxW     = isempty(compWriters)  ? 0 : maximum(length, compWriters)
  println("  Aliasing audit (distinct node identities per Ref):")
  println("    class Refs           : ", classAliased, " shared by >1 node (max ", classMaxW, " nodes on one Ref)")
  println("    component Refs        : ", compAliased, " shared by >1 node (max ", compMaxW, " nodes on one Ref)")
  if classAliased == 0 && compAliased == 0
    println("    => NO multi-writer Refs. Approach A (inline payload) is safe wholesale.")
  else
    println("    => MULTI-WRITER Refs EXIST. Approach A needs a hybrid carve-out for shared cells.")
  end
  local lookupHits = LOOKUP_CLASS_HITS[]
  local lookupMisses = LOOKUP_CLASS_MISSES[]
  local lookupTotal = lookupHits + lookupMisses
  if lookupTotal > 0
    local hitRate = round(100 * lookupHits / lookupTotal; digits = 1)
    println("  lookupClassName cache : ", lookupHits, " hits, ", lookupMisses, " misses (",
            hitRate, " % hit rate, cache size ", length(LOOKUP_CLASS_CACHE), ")")
  else
    println("  lookupClassName cache : disabled (set OMFRONTEND_LOOKUP_CACHE=true to enable)")
  end
  if classMulti > 0
    local sortedClass = sort(Base.collect(CLASS_PTR_WRITES), by = e -> last(last(e)), rev = true)
    println("  top-", min(topN, length(sortedClass)), " class pointers by write count:")
    for (i, (_, (nm, count))) in enumerate(sortedClass[1:min(topN, length(sortedClass))])
      count > 1 || break
      println("    ", lpad(i, 4), "  ", lpad(count, 8), "  ", nm)
    end
  end
  if compMulti > 0
    local sortedComp = sort(Base.collect(COMPONENT_PTR_WRITES), by = e -> last(last(e)), rev = true)
    println("  top-", min(topN, length(sortedComp)), " component pointers by write count:")
    for (i, (_, (nm, count))) in enumerate(sortedComp[1:min(topN, length(sortedComp))])
      count > 1 || break
      println("    ", lpad(i, 4), "  ", lpad(count, 8), "  ", nm)
    end
  end
  println()
end

function instExpressions(node::InstNode,
                         scope::InstNode = node,
                         sections::Sections = SECTIONS_EMPTY())
  INST_EXPR_DEPTH[] += 1
  if INST_EXPR_DEPTH[] > INST_EXPR_DEPTH_LIMIT
    nodeName = try name(node) catch; "<unknown>" end
    scopeName = try name(scope) catch; "<unknown>" end
    @warn "instExpressions recursion limit reached (depth=$(INST_EXPR_DEPTH[])): node=$(nodeName), scope=$(scopeName)"
    Error.addSourceMessage(
      Error.INST_RECURSION_LIMIT_REACHED,
      list("instExpressions depth > $(INST_EXPR_DEPTH_LIMIT): node=$(nodeName), scope=$(scopeName)"),
      InstNode_info(node))
    fail()
  end
  try
  local cls::Class = getClass(node)
  local inst_cls::Class
  local local_comps::Vector{InstNode}
  local exts::Vector{InstNode}
  local cls_tree::ClassTree
  local res::Restriction
  local dims::Vector{Dimension}
  local dim_scope::InstNode
  local info::SourceInfo
  local ty::NFType
  @match cls begin
    EXPANDED_CLASS(elements = cls_tree, restriction = RESTRICTION_TYPE(__))  => begin
      #=  Long class declaration of a type.
      =#
      #=  Instantiate expressions in the extends nodes.
      =#
      exts = getExtends(cls_tree)
      for ext in exts
         instExpressions(ext, ext, sections)
       end
      #=  A type must extend a basic type.
      =#
      if arrayLength(exts) == 1
        ty = TYPE_COMPLEX(node, COMPLEX_EXTENDS_TYPE(exts[1]))
      elseif SCodeUtil.hasBooleanNamedAnnotationInClass(definition(node), BUILTIN_PREFIX)
        ty = TYPE_COMPLEX(node, COMPLEX_CLASS())
      else
        Error.addSourceMessage(Error.MISSING_TYPE_BASETYPE, list(name(node)), infoInstNode_info(node))
        fail()
      end
      cls_tree = flatten(cls_tree)
      inst_cls = INSTANCED_CLASS(ty, cls_tree, SECTIONS_EMPTY(), cls.restriction)
      updateClass(inst_cls, node)
      ()
    end

    EXPANDED_CLASS(elements = cls_tree)  => begin
      #=  Instantiate expressions in the extends nodes.
      =#
      for ext in getExtends(cls_tree)
        sections = instExpressions(ext, ext, sections)
      end
      #=  Instantiate expressions in the local components.
      =#
      applyLocalComponentsWithInstComponentExpressions(cls_tree)
      #=  Flatten the class tree so we don't need to deal with extends anymore.
      =#
      local elements = flatten(cls_tree)
      cls = EXPANDED_CLASS(elements, cls.modifier, cls.prefixes, cls.restriction)
      updateClass(cls, node)
      #=  Instantiate local equation/algorithm sections.
      =#
      sections = instSections(node, scope, sections, isFunction(cls.restriction))
      ty = makeComplexType(cls.restriction, node, cls)
      inst_cls = INSTANCED_CLASS(ty, cls.elements, sections, cls.restriction)
      updateClass(inst_cls, node)
      instComplexType(ty)
      ()
    end

    EXPANDED_DERIVED(dims = dims)  => begin
      sections = instExpressions(cls.baseClass, scope, sections)
      dim_scope = parent(node)
      info = InstNode_info(node)
      for i in 1:arrayLength(dims)
        dims[i] = instDimension(dims[i], dim_scope, info)
      end
      if isRecord(cls.restriction)
        instRecordConstructor(node)
      end
      ()
    end

    INSTANCED_BUILTIN(elements = CLASS_TREE_FLAT_TREE(components = local_comps))  => begin
      for comp in local_comps
        instComponentExpressions(comp)
      end
      ()
    end

    INSTANCED_BUILTIN(__)  => begin
      ()
    end

    INSTANCED_CLASS(__)  => begin
      ()
    end

    _  => begin
      Error.assertion(false, getInstanceName() + " got invalid class", sourceInfo())
      fail()
    end
  end
  sections
  finally
    INST_EXPR_DEPTH[] -= 1
  end #= try/finally for instExpressions depth guard =#
end

function makeComplexType(restriction::Restriction, node::InstNode, cls::Class)::NFType
  local ty::NFType
  local cty::ComplexType
  cty = begin
    @match restriction begin
      RESTRICTION_RECORD(__)  => begin
        makeRecordComplexType(classScope(getDerivedNode(node)), cls)
      end
      _  => begin
        COMPLEX_CLASS()
      end
    end
  end
  TYPE_COMPLEX(node, cty)
end

function makeRecordComplexType(node::InstNode, cls::Class) ::ComplexType
  local ty::ComplexType

  local cls_node::InstNode
  local fields::List{Field}

  cls_node = if SCodeUtil.isOperatorRecord(definition(node))
    classScope(node)
  else
    classScope(getDerivedNode(node))
  end
  COMPLEX_RECORD(cls_node, nil)
end

function instComplexType(ty::NFType)
   () = begin
    local node::InstNode
    local cache::CachedData
    @match ty begin
      TYPE_COMPLEX(complexTy = COMPLEX_RECORD(node)) where (! isModel(node))  => begin
        #=  Make sure it's really a record, and not e.g. a record inherited by a model.
        =#
        #=  TODO: This check should really be InstNode.isRecord(node), but that
        =#
        #=        causes issues with e.g. ComplexInput/ComplexOutput.
        =#
        instRecordConstructor(node)
        ()
      end
      _  => begin
        ()
      end
    end
  end
end

function instRecordConstructor(node::InstNode)
  local cache::CachedData
  cache = getFuncCache(node)
  () = begin
    @match cache begin
      C_FUNCTION(__)  => begin
        ()
      end
      _  => begin
        cacheInitFunc(node)
        if SCodeUtil.isOperatorRecord(definition(node))
          instConstructor(scopePath(node, includeRoot = true), node, InstNode_info(node))
        else
          node = instDefaultConstructor(scopePath(node, includeRoot = true), node, InstNode_info(node))
        end
        ()
      end
    end
  end
  return node
end


function instBuiltinAttribute(attribute::MODIFIER_REDECLARE, node::InstNode)
  #=  Redeclaration of builtin attributes is not allowed. =#
  Error.addSourceMessage(Error.INVALID_REDECLARE_IN_BASIC_TYPE, list(name(attribute)), Modifier_info(attribute))
  fail()
end

function instBuiltinAttribute(attribute::Modifier, node::InstNode)
  return attribute
end

function instBuiltinAttribute(attribute::MODIFIER_MODIFIER, node::InstNode)
  # strMod1 = toString(attribute, true)
  #@debug ">instBuiltinAttribute($strMod1)"
  local bindingVar = attribute.binding
  local outAttr
  local bv = addParent(node, bindingVar)
  attributeBinding = instBinding(bv)
  outAttr = attribute
  outAttr.binding = attributeBinding
  # MODIFIER_MODIFIER(
  #   attribute.name,
  #   attribute.finalPrefix,
  #   attribute.eachPrefix,
  #   attributeBinding,
  #   attribute.subModifiers,
  #   attribute.info,
  #

  #strMod2 = toString(attribute, true)
  #@debug "<instBuiltinAttribute($strMod2)"
  return outAttr
end

function instComponentExpressions(componentArg::InstNode)::Nothing
  local node::InstNode = resolveOuter(componentArg)
  local c::Component = component(node)
  local dims::Vector{Dimension}
  @match c begin
    UNTYPED_COMPONENT(dimensions = dims, instantiated = false) where c.binding isa UNBOUND  => begin
      c.binding = instBinding(c.binding)::UNBOUND
      c.condition = instBinding(c.condition)
      instExpressions(c.classInst, node)
      for i in 1:arrayLength(dims)
        @inbounds dims[i] = instDimension(dims[i], parent(node), c.info)
      end
      #=  This is to avoid instantiating the same component multiple times,
      =#
      #=  which can otherwise happen with duplicate components at this stage.
      =#
      c.instantiated = true
      updateComponent!(c, node)
    end

    UNTYPED_COMPONENT(dimensions = dims, instantiated = false) => begin
      c.binding = instBinding(c.binding)
      c.condition = instBinding(c.condition)
      instExpressions(c.classInst, node)
      for i in 1:arrayLength(dims)
        @inbounds dims[i] = instDimension(dims[i], parent(node), c.info)
      end
      #=  This is to avoid instantiating the same component multiple times,
      =#
      #=  which can otherwise happen with duplicate components at this stage.
      =#
      c.instantiated = true
      updateComponent!(c, node)
      nothing
    end

    UNTYPED_COMPONENT(__)  => begin
      nothing
    end

    ENUM_LITERAL_COMPONENT(__)  => begin
      nothing
    end

    TYPE_ATTRIBUTE(modifier = MODIFIER_NOMOD(__))  => begin
      nothing
    end

    TYPE_ATTRIBUTE(__)  => begin
      c.modifier = instBuiltinAttribute(c.modifier, componentArg)
      updateComponent!(c, node)
      nothing
    end
    _  => begin
      #@error "Relaxed instantation for: " + name(componentArg)
      Error.assertion(false, getInstanceName() + " got invalid component", sourceInfo())
      fail()
    end
  end
  return nothing
end

function instBinding(bindingVar::Binding)
  bindingVar = begin
    local bind_exp::Expression
    @match bindingVar begin
      RAW_BINDING(__)  => begin
        bind_exp = instExp(bindingVar.bindingExp, bindingVar.scope, bindingVar.info)
        #= TODO: Convert the array in binding exp to a vector =#
        bind_exp = BINDING_EXP(bind_exp, TYPE_UNKNOWN(), TYPE_UNKNOWN(), bindingVar.parents, bindingVar.isEach)
        UNTYPED_BINDING(bind_exp, false, bindingVar.scope, bindingVar.isEach, bindingVar.info)
      end
      _  => begin
        bindingVar
      end
    end
  end
  bindingVar
end

function instExpOpt(absynExp::Option{<:Absyn.Exp}, scope::InstNode, info::SourceInfo) ::Option{Expression}
  local exp::Option{Expression}
  @assign exp = begin
    local aexp::Absyn.Exp
    @match absynExp begin
      NONE()  => begin
        NONE()
      end
      SOME(aexp)  => begin
        SOME(instExp(aexp, scope, info))
      end
    end
  end
  exp
end

@nospecializeinfer function instExp(@nospecialize(absynExp::Absyn.Exp), scope::InstNode, info::SourceInfo)::Expression
  local exp::Expression
  exp = begin
    local e1::Expression
    local e2::Expression
    local e3::Expression
    local oe::Option{Expression}
    local op::Operator
    local expl::List{Expression}
    local expll::Vector{Vector{Expression}}
    @match absynExp begin
      Absyn.INTEGER(__)  => begin
        INTEGER_EXPRESSION(absynExp.value)
      end

      Absyn.REAL(__)  => begin
        REAL_EXPRESSION(stringReal(absynExp.value))
      end

      Absyn.STRING(__)  => begin
        STRING_EXPRESSION(System.unescapedString(absynExp.value))
      end

      Absyn.BOOL(__)  => begin
        BOOLEAN_EXPRESSION(absynExp.value)
      end

      Absyn.CREF(__)  => begin
        instCref(absynExp.componentRef, scope, info)
      end

      Absyn.ARRAY(__)  => begin
        local expV = Expression[instExp(e, scope, info) for e in absynExp.arrayExp]
        makeArray(TYPE_UNKNOWN(), expV)
      end

      Absyn.MATRIX(__)  => begin
        expll = Vector{Expression}[
          Expression[instExp(e, scope, info) for e in el] for el in absynExp.matrix]
        MATRIX_EXPRESSION(expll)
      end

      Absyn.RANGE(__)  => begin
         e1 = instExp(absynExp.start, scope, info)
         oe = instExpOpt(absynExp.step, scope, info)
         e3 = instExp(absynExp.stop, scope, info)
        RANGE_EXPRESSION(TYPE_UNKNOWN(), e1, oe, e3)
      end

      Absyn.TUPLE(__)  => begin
         expl = list(instExp(e, scope, info) for e in absynExp.expressions)
        TUPLE_EXPRESSION(TYPE_UNKNOWN(), expl)
      end

      Absyn.BINARY(__)  => begin
        e1 = instExp(absynExp.exp1, scope, info)
        e2 = instExp(absynExp.exp2, scope, info)
        op = fromAbsyn(absynExp.op)
        BINARY_EXPRESSION(e1, op, e2)
      end

      Absyn.UNARY(__)  => begin
         e1 = instExp(absynExp.exp, scope, info)
         op = fromAbsyn(absynExp.op)
        UNARY_EXPRESSION(op, e1)
      end

      Absyn.LBINARY(__)  => begin
         e1 = instExp(absynExp.exp1, scope, info)
         e2 = instExp(absynExp.exp2, scope, info)
         op = fromAbsyn(absynExp.op)
        LBINARY_EXPRESSION(e1, op, e2)
      end

      Absyn.LUNARY(__)  => begin
         e1 = instExp(absynExp.exp, scope, info)
         op = fromAbsyn(absynExp.op)
        LUNARY_EXPRESSION(op, e1)
      end

      Absyn.RELATION(__)  => begin
         e1 = instExp(absynExp.exp1, scope, info)
         e2 = instExp(absynExp.exp2, scope, info)
         op = fromAbsyn(absynExp.op)
        RELATION_EXPRESSION(e1, op, e2)
      end

      Absyn.IFEXP(__)  => begin
         e3 = instExp(absynExp.elseBranch, scope, info)
        for branch in listReverse(absynExp.elseIfBranch)
           e1 = instExp(Util.tuple21(branch), scope, info)
           e2 = instExp(Util.tuple22(branch), scope, info)
           e3 = IF_EXPRESSION(e1, e2, e3)
        end
         e1 = instExp(absynExp.ifExp, scope, info)
         e2 = instExp(absynExp.trueBranch, scope, info)
        IF_EXPRESSION(e1, e2, e3)
      end

      Absyn.CALL(__)  => begin
        instantiate(absynExp.function_, absynExp.functionArgs, scope, info)
      end

      Absyn.PARTEVALFUNCTION(__)  => begin
        instPartEvalFunction(absynExp.function_, absynExp.functionArgs, scope, info)
      end

      Absyn.END(__)  => begin
        END_EXPRESSION()
      end
      _  => begin
        @error "UNKNOWN EXPRESSION!"
        fail()
      end
    end
  end
  #@info "Calling instExp result was" toString(exp)
  exp
end

function instCref(absynCref::Absyn.ComponentRef, scope::InstNode, info::SourceInfo)::Expression
  local crefExp::Expression
  local cref::ComponentRef
  local prefixed_cref::ComponentRef
  local found_scope::InstNode
  local ty::M_Type
  local comp::Component
  cref  = begin
    @match absynCref begin
      Absyn.WILD(__)  => begin
        found_scope = scope
        COMPONENT_REF_WILD()
      end
      Absyn.ALLWILD(__)  => begin
        found_scope = scope
        COMPONENT_REF_WILD()
      end
      _  => begin
        local scopeRef = Ref{InstNode}(EMPTY_NODE())
        found_cref = lookupComponent(absynCref, scope, scopeRef, info)
        found_scope = scopeRef.x
        found_cref
      end
    end
  end
  #@info "Calling instExpCref0 result was" toString(cref)
  cref = instCrefSubscripts(cref, scope, info)
  #@info "Calling instExpCref00 result was" toString(cref)
   crefExp = begin
    @match cref begin
      COMPONENT_REF_CREF(__)  => begin
        begin
          @match cref.node begin
            COMPONENT_NODE(__)  => begin
              instCrefComponent(cref, cref.node, found_scope, info)
            end
            CLASS_NODE(__)  => begin
              if isFunction(getClass(cref.node))
                instCrefFunction(cref, info)
              else
                instCrefTypename(cref, cref.node, info)
              end
            end
            _  => begin
              Error.assertion(false, getInstanceName() + " got invalid instance node", sourceInfo())
              fail()
            end
          end
        end
      end
      _  => begin
        CREF_EXPRESSION(TYPE_UNKNOWN(), cref)
      end
    end
   end
  #@info "Calling instExpCref result was" toString(crefExp)
  crefExp
end

function instCrefComponent(cref::ComponentRef, node::InstNode, scope::InstNode, info::SourceInfo) ::Expression
  local crefExp::Expression
  local comp::Component
  local prefixed_cref::ComponentRef
   comp = component(node)
   crefExp = begin
    @match comp begin
      ITERATOR_COMPONENT(__)  => begin
        checkUnsubscriptableCref(cref, info)
        CREF_EXPRESSION(TYPE_UNKNOWN(), makeIterator(node, comp.ty))
      end
      ENUM_LITERAL_COMPONENT(__)  => begin
        checkUnsubscriptableCref(cref, info)
        comp.literal
      end
      TYPE_ATTRIBUTE(__)  => begin
        Error.addSourceMessage(Error.LOOKUP_VARIABLE_ERROR, list(name(node), name(parent(node))), info)
        fail()
      end
      _  => begin
        #@info "slst 1"
        #local sLst = scopeList(scope)
        #@info "slst 2"
        local sLst2 = scopeList(scope)
        prefixed_cref = fromNodeList(sLst2)
        prefixed_cref = if isEmpty(prefixed_cref)
          cref
        else
          appendCref!(cref, prefixed_cref)
        end
        CREF_EXPRESSION(TYPE_UNKNOWN(), prefixed_cref)
      end
    end
  end
  crefExp
end

function instCrefFunction(cref::ComponentRef, info::SourceInfo) ::Expression
  local crefExp::Expression

  local fn_ref::ComponentRef

   (fn_ref, _, _) = instFunctionRef(cref, info)
   crefExp = CREF_EXPRESSION(TYPE_UNKNOWN(), fn_ref)
  crefExp
end

function instCrefTypename(cref::ComponentRef, node::InstNode, info::SourceInfo)::Expression
  local crefExp::Expression
  local ty::NFType
  checkUnsubscriptableCref(cref, info)
   ty = getType(node)
   ty = begin
    @match ty begin
      TYPE_BOOLEAN(__)  => begin
        TYPE_ARRAY(ty, list(DIMENSION_BOOLEAN()))
      end
      TYPE_ENUMERATION(__)  => begin
        TYPE_ARRAY(ty, list(DIMENSION_ENUM(ty)))
      end
      _  => begin
        #Error.assertion(false, getInstanceName() + " got unknown class node " + name(node), sourceInfo())
        fail()
      end
    end
  end
   crefExp = TYPENAME_EXPRESSION(ty)
  crefExp
end

function checkUnsubscriptableCref(cref::ComponentRef, info::SourceInfo)
  if hasSubscripts(cref)
    Error.addSourceMessage(Error.WRONG_NUMBER_OF_SUBSCRIPTS, list(ComponentRef.toString(cref), String(listLength(ComponentRef.getSubscripts(cref))), "0"), info)
    fail()
  end
end

instCrefSubscripts(cref::ComponentRef, scope::InstNode, info::SourceInfo) = cref

function instCrefSubscripts(cref::COMPONENT_REF_CREF, scope::InstNode, info::SourceInfo) ::ComponentRef
  local rest_cr::ComponentRef
  if ! listEmpty(cref.subscripts)
    local crefSubscripts = list(instSubscript(s, scope, info) for s in cref.subscripts)
    cref = COMPONENT_REF_CREF(cref.node, crefSubscripts, cref.ty, cref.origin, cref.restCref)
  end
  local rest_cr = instCrefSubscripts(cref.restCref, scope, info)
  if ! referenceEq(rest_cr, cref.restCref)
    cref = COMPONENT_REF_CREF(cref.node, cref.subscripts, cref.ty, cref.origin, rest_cr)
  end
  cref
end

function instSubscript(subscript::Subscript, scope::InstNode, info::SourceInfo)::Subscript
  local outSubscript::Subscript
  local exp::Expression
  local absynSub::Absyn.Subscript
  @match SUBSCRIPT_RAW_SUBSCRIPT(subscript = absynSub) = subscript
  outSubscript = begin
    @match absynSub begin
      Absyn.NOSUB(__)  => begin
        SUBSCRIPT_WHOLE()
      end
      Absyn.SUBSCRIPT(__)  => begin
        exp = instExp(absynSub.subscript, scope, info)
        fromExp(exp)
      end
    end
  end
  outSubscript
end

function instPartEvalFunction(func::Absyn.ComponentRef, funcArgs::Absyn.FunctionArgs, scope::InstNode, info::SourceInfo) ::Expression
  local outExp::Expression
  local fn_ref::ComponentRef
  local nargs::List{Absyn.NamedArg}
  local args::List{Expression}
  local arg_names::List{String}
  @match Absyn.FUNCTIONARGS(argNames = nargs) = funcArgs
  @assign outExp = instCref(func, scope, info)
  if ! listEmpty(nargs)
    @assign fn_ref = toCref(outExp)
    @assign args = list(instExp(arg.argValue, scope, info) for arg in nargs)
    @assign arg_names = list(arg.argName for arg in nargs)
    @assign outExp = PARTIAL_FUNCTION_APPLICATION_EXPRESSION(fn_ref, args, arg_names, TYPE_UNKNOWN())
  end
  outExp
end

function instSections(node::InstNode, scope::InstNode, sections::Sections, isFunction::Bool) ::Sections
  local el::SCode.Element = definition(node)
  local def::SCode.ClassDef
  @assign sections = begin
    @match el begin
      SCode.CLASS(classDef = SCode.PARTS(__))  => begin
        instSections2(el.classDef, scope, sections, isFunction)
      end
      SCode.CLASS(classDef = SCode.CLASS_EXTENDS(composition = def && SCode.PARTS(__)))  => begin
        instSections2(def, scope, sections, isFunction)
      end
      _  => begin
        sections
      end
    end
  end
  sections
end

function instSections2(parts::SCode.ClassDef, scope::InstNode, sections::Sections, isFunction::Bool) ::Sections
  sections = begin
    local eq::Vector{Equation}
    local ieq::Vector{Equation}
    local alg::Vector{Algorithm}
    local ialg::Vector{Algorithm}
    local ext_decl::SCode.ExternalDecl
    local origin::ORIGIN_Type
    local iorigin::ORIGIN_Type
    #= Plain conditionals instead of matching on a constructed tuple; the
       non-PARTS case keeps its MatchFailure via the single-record match. =#
    if sections isa SECTIONS_EXTERNAL
      Error.addSourceMessage(Error.MULTIPLE_SECTIONS_IN_FUNCTION, list(name(scope)), info(scope))
      fail()
    end
    @match SCode.PARTS(__) = parts
    if isSome(parts.externalDecl)
      instExternalDecl(Util.getOption(parts.externalDecl), scope)
    else
      origin = if isFunction
        ORIGIN_FUNCTION
      else
        ORIGIN_CLASS
      end
      iorigin = setFlag(origin, ORIGIN_INITIAL)
      eq = instEquations(parts.normalEquationLst, scope, origin)
      ieq = instEquations(parts.initialEquationLst, scope, iorigin)
      alg = instAlgorithmSections(parts.normalAlgorithmLst, scope, origin)
      ialg = instAlgorithmSections(parts.initialAlgorithmLst, scope, iorigin)
      join(new(eq, ieq, alg, ialg), sections)
    end
  end
  sections
end

function instExternalDecl(extDecl::SCode.ExternalDecl, scope::InstNode) ::Sections
  local sections::Sections
  @assign sections = begin
    local nameVar::String
    local lang::String
    local args::List{Expression}
    local ret_cref::ComponentRef
    local info::SourceInfo
    @match extDecl begin
      SCode.EXTERNALDECL(__)  => begin
        @assign info = InstNode_info(scope)
        @assign nameVar = Util.getOptionOrDefault(extDecl.funcName, name(scope))
        @assign lang = Util.getOptionOrDefault(extDecl.lang, "C")
        checkExternalDeclLanguage(lang, info)
        @assign args = list(instExp(arg, scope, info) for arg in extDecl.args)
        if isSome(extDecl.output_)
          (ret_cref, _) = lookupLocalComponent(Util.getOption(extDecl.output_), scope, info)
        else
          @assign ret_cref = COMPONENT_REF_EMPTY()
        end
        SECTIONS_EXTERNAL(nameVar, args, ret_cref, lang, extDecl.annotation_, isSome(extDecl.funcName))
      end
    end
  end
  sections
end

"""  Checks that the language declared for an external function is valid. """
function checkExternalDeclLanguage(language::String, info::SourceInfo)
   () = begin
    @match language begin
      "C"  => begin
        ()
      end

      "FORTRAN 77"  => begin
        ()
      end

      "Fortran 77"  => begin
        ()
      end

      "builtin"  => begin
        ()
      end

      _  => begin
        #=  The specification also allows for C89, C99, and C11, but our code
        =#
        #=  generation only seems to support C.
        =#
        #=  Not in the specification, but used by libraries and allowed by other tools.
        =#
        Error.addSourceMessage(Error.INVALID_EXTERNAL_LANGUAGE, list(language), info)
        fail()
      end
    end
  end
end

function instEquations(scodeEql::List{<:SCode.Equation}, scope::InstNode, origin::ORIGIN_Type)
  instEql = Equation[instEquation(eq, scope, origin) for eq in scodeEql]
  return instEql
end

function instEquation(scodeEq::SCode.Equation, scope::InstNode, origin::ORIGIN_Type) ::Equation
  local instEq::Equation
  local eq::SCode.EEquation
  @match SCode.EQUATION(eEquation = eq) = scodeEq
  @assign instEq = instEEquation(eq, scope, origin)
  instEq
end

function instEEquations(scodeEql::List{SCode.EEquation}, scope::InstNode, origin::ORIGIN_Type)
  instEql = Equation[instEEquation(eq, scope, origin) for eq in scodeEql]
  return instEql
end

function instEEquation(@nospecialize(scodeEq::SCode.EEquation), @nospecialize(scope::InstNode), origin::ORIGIN_Type)
  local instEq::Equation
  @assign instEq = begin
    local exp1::Expression
    local exp2::Expression
    local exp3::Expression
    local oexp::Option{Expression}
    local expl::List{Expression}
    local eql::Vector{Equation}
    local branches::Vector{Equation_Branch}
    local info::SourceInfo
    local for_scope::InstNode
    local iter::InstNode
    local lhs_cr::ComponentRef
    local rhs_cr::ComponentRef
    local next_origin::ORIGIN_Type
    @match scodeEq begin
      SCode.EQ_EQUALS(info = info)  => begin
        exp1 = instExp(scodeEq.expLeft, scope, info)
        exp2 = instExp(scodeEq.expRight, scope, info)
        EQUATION_EQUALITY(exp1, exp2, TYPE_UNKNOWN(), makeSource(scodeEq.comment, info))
      end

      SCode.EQ_CONNECT(info = info)  => begin
        if flagSet(origin, ORIGIN_WHEN)
          Error.addSourceMessage(Error.CONNECT_IN_WHEN, list(Dump.printComponentRefStr(scodeEq.crefLeft), Dump.printComponentRefStr(scodeEq.crefRight)), info)
          fail()
        end
        exp1 = instConnectorCref(scodeEq.crefLeft, scope, info)
        exp2 = instConnectorCref(scodeEq.crefRight, scope, info)
        EQUATION_CONNECT(exp1, exp2, makeSource(scodeEq.comment, info))
      end

      SCode.EQ_FOR(info = info)  => begin
        oexp = instExpOpt(scodeEq.range, scope, info)
        checkIteratorShadowing(scodeEq.index, scope, scodeEq.info)
        (for_scope, iter) = addIteratorToScope(scodeEq.index, scope, scodeEq.info)
        next_origin = setFlag(origin, ORIGIN_FOR)
        eql = instEEquations(scodeEq.eEquationLst, for_scope, next_origin)
        EQUATION_FOR(iter, oexp, eql, makeSource(scodeEq.comment, info))
      end

      SCode.EQ_IF(info = info)  => begin
        #=  Instantiate the conditions.=#
        expl = list(instExp(c, scope, info) for c in scodeEq.condition)
        #=  Instantiate each branch and pair it up with a condition.
        =#
        next_origin = setFlag(origin, ORIGIN_IF)
        branches = Equation_Branch[]
        for branch in scodeEq.thenBranch
          eql = instEEquations(branch, scope, next_origin)
          @match Cons{Expression}(exp1, expl) = expl
          push!(branches, makeBranch(exp1, eql))
        end
        #=  Instantiate the else-branch, if there is one, and make it a branch
        =#
        #=  with condition true (so we only need a simple list of branches).
        =#
        if ! listEmpty(scodeEq.elseBranch)
          eql = instEEquations(scodeEq.elseBranch, scope, next_origin)
          push!(branches, makeBranch(BOOLEAN_EXPRESSION(true), eql))
        end
        EQUATION_IF(branches, makeSource(scodeEq.comment, info))
      end

      SCode.EQ_WHEN(info = info)  => begin
        if flagSet(origin, ORIGIN_WHEN)
          Error.addSourceMessageAndFail(Error.NESTED_WHEN, nil, info)
        elseif flagSet(origin, ORIGIN_INITIAL)
          Error.addSourceMessageAndFail(Error.INITIAL_WHEN, nil, info)
        end
        next_origin = setFlag(origin, ORIGIN_WHEN)
        exp1 = instExp(scodeEq.condition, scope, info)
        eql = instEEquations(scodeEq.eEquationLst, scope, next_origin)
        branches = Equation_Branch[makeBranch(exp1, eql)]
        for branch in scodeEq.elseBranches
          exp1 = instExp(Util.tuple21(branch), scope, info)
          eql = instEEquations(Util.tuple22(branch), scope, next_origin)
          push!(branches, makeBranch(exp1, eql))
        end
        EQUATION_WHEN(branches, makeSource(scodeEq.comment, info))
      end

      SCode.EQ_RECONFIGURE(info = info) => begin
        local instConds = [instExp(clause.condition, scope, info)
                           for clause in scodeEq.whenClauses]
        local instCons = [begin
            @match clause begin
              Absyn.WHEN_CONDITIONAL(__) => SOME(instExp(clause.constraint, scope, info))
              _ => NONE()
            end
          end
          for clause in scodeEq.whenClauses]
        local instPrompt = instExpOpt(scodeEq.prompt, scope, info)
        EQUATION_RECONFIGURE(
          scodeEq.variables,
          instConds,
          instCons,
          instPrompt,
          scodeEq.initialEquations,
          makeSource(scodeEq.comment, info),
        )
      end

      SCode.EQ_ASSERT(info = info)  => begin
        exp1 = instExp(scodeEq.condition, scope, info)
        exp2 = instExp(scodeEq.message, scope, info)
        exp3 = instExp(scodeEq.level, scope, info)
        EQUATION_ASSERT(exp1, exp2, exp3, makeSource(scodeEq.comment, info))
      end

      SCode.EQ_TERMINATE(info = info)  => begin
        @assign exp1 = instExp(scodeEq.message, scope, info)
        EQUATION_TERMINATE(exp1, makeSource(scodeEq.comment, info))
      end

      SCode.EQ_REINIT(info = info)  => begin
        if flagNotSet(origin, ORIGIN_WHEN)
          Error.addSourceMessage(Error.REINIT_NOT_IN_WHEN, nil, info)
          fail()
        end
        exp1 = instExp(scodeEq.cref, scope, info)
        exp2 = instExp(scodeEq.expReinit, scope, info)
        EQUATION_REINIT(exp1, exp2, makeSource(scodeEq.comment, info))
      end

      SCode.EQ_NORETCALL(info = info)  => begin
        @assign exp1 = instExp(scodeEq.exp, scope, info)
        EQUATION_NORETCALL(exp1, makeSource(scodeEq.comment, info))
      end

      _  => begin
        Error.assertion(false, getInstanceName() + " got unknown equation", sourceInfo())
        fail()
      end
    end
end
instEq
end

function instConnectorCref(absynCref::Absyn.ComponentRef, scope::InstNode, info::SourceInfo) ::Expression
  local cref::ComponentRef
  local prefix::ComponentRef
  local found_scope::InstNode
  (cref, found_scope) = lookupConnector(absynCref, scope, info)
  cref = instCrefSubscripts(cref, scope, info)
  prefix = fromNodeList(scopeList(found_scope))
  if ! isEmpty(prefix)
    cref = append(cref, prefix)
  end
  CREF_EXPRESSION(TYPE_UNKNOWN(), cref)
end

function makeSource(comment::SCode.Comment, info::SourceInfo)
  local source::DAE.ElementSource
  source = DAE.SOURCE(info, nil, "TODO Dummy", nil, nil, nil, list(comment))
  source
end

function addIteratorToScope(name::String, scope::InstNode, info::SourceInfo, iter_type::NFType = TYPE_UNKNOWN()) ::Tuple{InstNode, InstNode}
  local iterator::InstNode
  local iter_comp::Component
  scope = openImplicitScope(scope)
  iter_comp = ITERATOR_COMPONENT(iter_type, Variability.CONTINUOUS, info)
  iterator = fromComponent(name, iter_comp, scope)
  scope = addIterator(iterator, scope)
  (scope, iterator)
end

"""
  Gives a warning if the given iterator name is already used in an outer
  implicit scope.
"""
function checkIteratorShadowing(nameArg::String, scope::InstNode, infoArg::SourceInfo)
  () = begin
    @match scope begin
      IMPLICIT_SCOPE(__)  => begin
        for iter in scope.locals
          if name(iter) == nameArg
            Error.addMultiSourceMessage(Error.SHADOWED_ITERATOR, list(nameArg), list(InstNode_info(iter), infoArg))
            return
          end
        end
        ()
      end
      _  => begin
        ()
      end
    end
  end
end

"""
Inner elements can be generated automatically during instantiation if they're
                   missing, and are stored in the cache of the top scope since that's easily
                   accessible during lookup. This function copies any such inner elements into
                   the class we're instantiating, so that they are typed and flattened properly.
"""
function insertGeneratedInners(node::InstNode, topScope::InstNode)
  local inner_tree::NodeTree.Tree
  local inner_nodes::List{Tuple{String, InstNode}}
  local inner_comps::List{Pointer{InstNode}}
  local n::InstNode
  local name::String
  local str::String
  local cls::Class
  local cls_tree::ClassTree
  local base_node::InstNode
#@debug "Calling insert generate inners!"
  @match C_TOP_SCOPE(addedInner = inner_tree) = getInnerOuterCache(topScope)
  #=  Empty tree => nothing more to do. =#
  if NodeTree.isEmpty(inner_tree)
    #@debug "EMPTY NODE TREE"
    return
  end
  inner_nodes = NodeTree.toList(inner_tree)
  inner_comps = nil
  for e in inner_nodes
    (name, n) = e
    Error.addSourceMessage(Error.MISSING_INNER_ADDED, list(typeName(n), name), InstNode_info(n))
    if isComponent(n)
      instComponent(n, DEFAULT_ATTR, MODIFIER_NOMOD(), true, 0, Ref{Attributes}(DEFAULT_ATTR))
      try
        local absynStr::Absyn.STRING = SCodeUtil.getElementNamedAnnotation(definition(classScope(n)), "missingInnerMessage")
        Error.addSourceMessage(Error.MISSING_INNER_MESSAGE, list(System.unescapedString(str)), InstNode_info(n))
      catch
      end
      @assign inner_comps = Cons{Pointer{InstNode}}(P_Pointer.create(n), inner_comps)
    end
  end
  if ! listEmpty(inner_comps)
    base_node = lastBaseClass(node)
    cls = getClass(base_node)
    cls_tree = appendComponentsToInstTree(inner_comps, classTree(cls))
    updateClass(setClassTree(cls_tree, cls), base_node)
  end
end

function updateImplicitVariability(node::InstNode, evalAllParams::Bool)::Nothing
  local cls::Class = getClass(node)
  local cls_tree::ClassTree
  updateImplicitVariabilityCls(cls, evalAllParams)::Nothing
end

function updateImplicitVariabilityCls(cls::Class, evalAllParams::Bool)::Nothing
  if cls isa INSTANCED_CLASS && cls.elements isa CLASS_TREE_FLAT_TREE
    local components = cls.elements.components::Vector{InstNode}
    local len = length(components)
    local i = 1
    while i ≤ len
      local c::COMPONENT_NODE{String, Int8} = resolveOuter(components[i])
      updateImplicitVariabilityComp(c, evalAllParams::Bool)::Nothing
      i += 1
    end
    apply(cls.sections, updateImplicitVariabilityEq, updateImplicitVariabilityAlg)::Nothing
    return nothing
  elseif cls isa EXPANDED_DERIVED
    for dim in cls.dims
      markStructuralParamsDim(dim)
    end
    updateImplicitVariability(cls.baseClass, evalAllParams)::Nothing
    return nothing
  elseif cls isa INSTANCED_BUILTIN && cls.elements isa CLASS_TREE_FLAT_TREE
    local components = cls.elements.components
    local len = length(components)
    local i = 1
    while i ≤ len
      local c::COMPONENT_NODE{String, Int8} = resolveOuter(components[i])
      updateImplicitVariabilityComp(c, evalAllParams)::Nothing
      i += 1
    end
    return nothing
  else
    return nothing
  end
end

function updateImplicitVariabilityComp(co::INNER_OUTER_NODE, evalAllParams::Bool)::Nothing
  local node::InstNode = resolveOuter(co)
  updateImplicitVariabilityComp(node, evalAllParams::Bool)::Nothing
end

function updateImplicitVariabilityComp(node::COMPONENT_NODE{String, Int8}, evalAllParams::Bool)::Nothing
  local c::Component = component(node)
  local bnd::Binding
  local condition::Binding
  @match c begin
    UNTYPED_COMPONENT(binding = bnd, condition = condition)  => begin
      if isStructuralComponent(c, c.attributes, bnd, node, evalAllParams)
        markStructuralParamsComp(c, node)
      end
      #=  Parameters used in array dimensions are structural.
      =#
      for dim in c.dimensions
        markStructuralParamsDim(dim)
      end
      #=  Parameters that determine the size of a component binding are structural.
      =#
      if isBound(bnd)
        markStructuralParamsExpSize(getUntypedExp(bnd))
      end
      #=  Parameters used in a component condition are structural.
      =#
      if isBound(condition)
        markStructuralParamsExp(getUntypedExp(condition))
      end
      local classInst = c.classInst
      return updateImplicitVariability(classInst, evalAllParams)::Nothing
    end

    TYPE_ATTRIBUTE(__)  => begin
      if node.name != "fixed" || node.name != "stateSelect"
        return nothing
      end
      bnd = binding(c.modifier)
      if isBound(bnd)
        markStructuralParamsExp(getUntypedExp(bnd))
      end
      return nothing
    end

    _  => begin
      return nothing
    end
  end
end

function isStructuralComponent(component::Component, compAttrs::Attributes, compBinding::Binding, compNode::InstNode, evalAllParams::Bool) ::Bool
  local isStructural::Bool
  local is_fixed::Bool
  if compAttrs.variability != Variability.PARAMETER
     isStructural = false
  elseif evalAllParams || getEvaluateAnnotation(component)
    if ! getFixedAttribute(component)
       isStructural = false
    elseif isExternalObject(component)
       isStructural = false
    elseif ! hasBinding(compNode)
      if ! evalAllParams && ! Flags.getConfigBool(Flags.CHECK_MODEL)
        Error.addSourceMessage(Error.UNBOUND_PARAMETER_EVALUATE_TRUE, list(name(compNode)), info(compNode))
      end
       isStructural = false
    elseif isBindingNotFixed(compBinding, #= requireFinal = =# false)
       isStructural = false
    else
       isStructural = true
    end
  else
     isStructural = false
  end
  isStructural
end

function isBindingNotFixed(binding::Binding, requireFinal::Bool, maxDepth::Int = 4) ::Bool
  local isNotFixed::Bool
  if maxDepth == 0
     isNotFixed = true
    return isNotFixed
  end
  if hasExp(binding)
     isNotFixed = isExpressionNotFixed(getBindingExp(getExp(binding)), requireFinal = requireFinal, maxDepth = maxDepth)
  else
     isNotFixed = true
  end
  isNotFixed
end

function isComponentBindingNotFixed(comp::Component, node::InstNode, requireFinal::Bool, maxDepth::Int, isRecordB::Bool = false) ::Bool
  local isNotFixed::Bool

  local binding::Binding
  local parentNode::InstNode

  binding = getBinding(comp)
  if isUnbound(binding)
    if isRecordB || isRecord(node)
      isNotFixed = false
    else
      parentNode = parent(node)
      if isComponent(parentNode) && isRecord(parentNode)
        isNotFixed = isComponentBindingNotFixed(component(parentNode), parentNode, requireFinal, maxDepth, true)
      else
        isNotFixed = true
      end
    end
  else
    isNotFixed = isBindingNotFixed(binding, requireFinal, maxDepth)
  end
  #=  TODO: Check whether the record fields have bindings or not.
  =#
  isNotFixed
end

const EXPRESSION_NOT_FIXED_DEPTH = Ref(0)
const EXPRESSION_NOT_FIXED_DEPTH_LIMIT = 256

function isExpressionNotFixed(@nospecialize(exp::Expression); requireFinal::Bool = false, maxDepth::Int = 4) ::Bool
  EXPRESSION_NOT_FIXED_DEPTH[] += 1
  if EXPRESSION_NOT_FIXED_DEPTH[] > EXPRESSION_NOT_FIXED_DEPTH_LIMIT
    EXPRESSION_NOT_FIXED_DEPTH[] -= 1
    return true  # Conservatively assume not fixed to prevent stack overflow
  end
  local isNotFixed::Bool

  try
  @assign isNotFixed = begin
    local nodeVar::InstNode
    local c::Component
    local var::VariabilityType
    local e::Expression
    @match exp begin
      CREF_EXPRESSION(__)  => begin
        @assign nodeVar = node(exp.cref)
        if isComponent(nodeVar)
          @assign c = component(nodeVar)
          @assign var = variability(c)
          if var <= Variability.STRUCTURAL_PARAMETER
            @assign isNotFixed = false
          elseif var == Variability.PARAMETER && (! requireFinal || isFinal(c)) && ! isExternalObject(c) && getFixedAttribute(c)
            @assign isNotFixed = isComponentBindingNotFixed(c, nodeVar, requireFinal, maxDepth - 1)
          else
            @assign isNotFixed = true
          end
        else
          @assign isNotFixed = true
        end
        isNotFixed || containsShallow(exp, (x) -> isExpressionNotFixed(x; requireFinal = requireFinal, maxDepth = maxDepth))
      end

      SIZE_EXPRESSION(__)  => begin
        if isSome(exp.dimIndex)
          @assign isNotFixed = isExpressionNotFixed(Util.getOption(exp.dimIndex), requireFinal = requireFinal, maxDepth = maxDepth)
        else
          @assign isNotFixed = false
        end
        isNotFixed
      end

      CALL_EXPRESSION(__)  => begin
        if isImpure(exp.call) || isExternal(exp.call)
          @assign isNotFixed = true
        else
          @assign isNotFixed = containsShallow(exp, (x) -> isExpressionNotFixed(x; requireFinal = requireFinal, maxDepth = maxDepth))
        end
        isNotFixed
      end

      _  => begin
        containsShallow(exp, (exp) -> isExpressionNotFixed(exp))
      end
    end
  end
  return isNotFixed
  finally
    EXPRESSION_NOT_FIXED_DEPTH[] -= 1
  end
end

function getRecordFieldBinding(comp::Component, node::InstNode) ::Binding
  local binding::Binding
  local parent::InstNode
  binding = getBinding(comp)
  if isUnbound(binding)
    parent = parent(node)
    if isComponent(parent) && isRecord(restriction(getClass(parent)))
      binding = getRecordFieldBinding(component(parent), parent)
    end
  end
  binding
end

function markStructuralParamsDim(dimension::Dimension)::Nothing
  @match dimension begin
    DIMENSION_UNTYPED(__)  => begin
      markStructuralParamsExp(dimension.dimension)
    end
    DIMENSION_EXP(__)  => begin
      markStructuralParamsExp(dimension.exp)
    end
    _  => begin
    end
  end
  return nothing
end

function markStructuralParamsExp(@nospecialize(exp::Expression))::Nothing
  apply(exp, markStructuralParamsExp_traverser)
end

function markStructuralParamsExp_traverser(@nospecialize(exp::Expression))::Nothing
  local node::InstNode
  local comp::Component
  local binding::Option{Expression}
  @match exp begin
    CREF_EXPRESSION(cref = COMPONENT_REF_CREF(node = node, origin = Origin.CREF))  => begin
      if isComponent(node)
        comp = component(node)
        if variability(comp) == Variability.PARAMETER || variability(comp) == Variability.NON_STRUCTURAL_PARAMETER
          markStructuralParamsComp(comp, node)
        end
      end
      return nothing
    end
    _  => begin
      return nothing
    end
  end
end

function markStructuralParamsComp(component::Component, node::InstNode)::Nothing
  local comp::Component
  local binding::Option{Expression}
  comp = setVariability(Variability.STRUCTURAL_PARAMETER, component)
  updateComponent!(comp, node)
  binding = untypedExp(getBinding(comp))
  if isSome(binding)
    markStructuralParamsExp(Util.getOption(binding))
  end
  return nothing
end

function markStructuralParamsExpSize(@nospecialize(exp::Expression))
  apply(exp, markStructuralParamsExpSize_traverser)
end


markStructuralParamsExpSize_traverser(exp::Expression) = nothing
function markStructuralParamsExpSize_traverser(exp::CALL_EXPRESSION)
  local iters::List{Tuple{InstNode, Expression}}
  @match exp begin
    CALL_EXPRESSION(call = UNTYPED_ARRAY_CONSTRUCTOR(iters = iters))  => begin
      for iter in iters
        markStructuralParamsExp(last(iter))
      end
      return nothing
    end
    _  => begin
      return nothing
    end
  end
end

function updateImplicitVariabilityEql(eql::Vector{Equation}, inWhen::Bool = false)::Nothing
  for eq in eql
    updateImplicitVariabilityEq(eq, inWhen)
  end
end

function updateImplicitVariabilityEq(eq::Equation, inWhen::Bool = false)::Nothing
  local exp::Expression
  local eql::Vector{Equation}
  @match eq begin
    EQUATION_EQUALITY(__)  => begin
      if inWhen
        markImplicitWhenExp(eq.lhs)
      end
      nothing
    end
    EQUATION_CONNECT(__)  => begin
      fold(eq.lhs, markStructuralParamsSubs, 0)
      fold(eq.rhs, markStructuralParamsSubs, 0)
      nothing
    end
    EQUATION_FOR(__)  => begin
      updateImplicitVariabilityEql(eq.body, inWhen)
      nothing
    end
    EQUATION_IF(__)  => begin
      for branch in eq.branches
        @match branch begin
          EQUATION_BRANCH(__)  => begin
            updateImplicitVariabilityEql(branch.body, inWhen)
            nothing
          end
        end
      end
      nothing
    end
    EQUATION_WHEN(__)  => begin
      for branch in eq.branches
        @match branch begin
          EQUATION_BRANCH(__)  => begin
            updateImplicitVariabilityEql(branch.body, #= inWhen =# true)
            nothing
          end
        end
      end
      nothing
    end
    _  => begin
      nothing
    end
  end
end

function markStructuralParamsSub(sub::Subscript, dummy::Int = 0) ::Int
   () = begin
    @match sub begin
      SUBSCRIPT_UNTYPED(__)  => begin
        markStructuralParamsExp(sub.exp)
        ()
      end
      SUBSCRIPT_INDEX(__)  => begin
        markStructuralParamsExp(sub.index)
        ()
      end
      SUBSCRIPT_SLICE(__)  => begin
        markStructuralParamsExp(sub.slice)
        ()
      end
      _  => begin
        ()
      end
    end
  end
  dummy
end

function markImplicitWhenExp(@nospecialize(exp::Expression))
    apply(exp, markImplicitWhenExp_traverser)
end

function markImplicitWhenExp_traverser(@nospecialize(exp::Expression))
   () = begin
    local node::InstNode
    local comp::Component
    @match exp begin
      CREF_EXPRESSION(cref = COMPONENT_REF_CREF(node = node))  => begin
        if isComponent(node)
          comp = component(node)
          if variability(comp) == Variability.CONTINUOUS
            comp = setVariability(Variability.IMPLICITLY_DISCRETE, comp)
            updateComponent!(comp, node)
          end
        end
        ()
      end
      _  => ()
    end
  end
end

#= Per-session session id and log root for OMFrontend dumps. Mirrors the helper
   in OMBackend; duplicated because the two packages do not share code. All
   frontend flat-model dumps go under a single OS-appropriate directory instead
   of the current working directory. =#
const OMFRONTEND_SESSION_ID = string(getpid(), "_", round(Int, time()))

function logDir()
  return get(ENV, "OMJL_LOG_DIR", joinpath(tempdir(), "OMJL", OMFRONTEND_SESSION_ID))
end

function logPath(stage::AbstractString, filename::AbstractString)
  dir = joinpath(logDir(), stage)
  isdir(dir) || mkpath(dir)
  return joinpath(dir, filename)
end

"""
  Dumps the flat model if the correct debug flag is activated.
"""
function dumpFlatModel(flatModel, phaseAsStr::String)
  if Flags.isSet(Flags.NF_DUMP_FLAT)
    local outFile = logPath("frontend/flat", string(phaseAsStr, ".mo"))
    @info "Dumping the system... at phase: $(phaseAsStr) -> $(outFile)"
    write(outFile, replace(toFlatString(flatModel, nil), "\\n" => "\n"))
  end
end
