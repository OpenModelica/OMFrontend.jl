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

import .DuplicateTree

abstract type ClassTree end

struct CLASS_TREE_EMPTY_TREE <: ClassTree end

mutable struct CLASS_TREE_FLAT_TREE <: ClassTree
  tree::LookupTree.Tree
  classes::Vector{InstNode}
  components::Vector{InstNode}
  imports::Vector{Import}
  duplicates::DuplicateTree.Tree
end

mutable struct CLASS_TREE_INSTANTIATED_TREE <: ClassTree
  tree::LookupTree.Tree
  classes::Vector{Pointer{InstNode}}
  components::Vector{Pointer{InstNode}}
  localComponents::Vector{Int}
  exts::Vector{InstNode}
  imports::Vector{Import}
  duplicates::DuplicateTree.Tree
end

mutable struct CLASS_TREE_EXPANDED_TREE <: ClassTree
  tree::LookupTree.Tree
  classes::Vector{InstNode}
  components::Vector{InstNode}
  exts::Vector{InstNode}
  imports::Vector{Import}
  duplicates::DuplicateTree.Tree
end

mutable struct CLASS_TREE_PARTIAL_TREE <: ClassTree
  tree::LookupTree.Tree
  classes::Vector{InstNode}
  components::Vector{InstNode}
  exts::Vector{InstNode}
  imports::Vector{Import}
  duplicates::DuplicateTree.Tree
end

#= Empty tree, references to these two variables should be done using deepcopy=#
const EMPTY_CLASS_TREE::CLASS_TREE_PARTIAL_TREE =
  CLASS_TREE_PARTIAL_TREE(
    LookupTree.EMPTY(),
    listArray(nil),
    listArray(nil),
    listArray(nil),
    listArray(nil),
    DuplicateTree.EMPTY(),
  )

const EMPTY_FLAT_CLASS_TREE::CLASS_TREE_FLAT_TREE =
  CLASS_TREE_FLAT_TREE(
    LookupTree.EMPTY(),
    listArray(nil),
    listArray(nil),
    listArray(nil),
    DuplicateTree.EMPTY(),
  )

function isEmptyTree(tree::ClassTree)
  if typeof(tree) isa CLASS_TREE_EMPTY_TREE
    return true
  else
    return false
  end
end

function getComponents(tree::CLASS_TREE_EMPTY_TREE)
  return InstNode[]
end

function getComponents(tree::ClassTree)
  local comps::Vector{InstNode} = tree.components
  return comps
end

getExtends(tree::ClassTree) = tree.exts


function getClasses(tree::ClassTree)
  local clss::Vector{InstNode} = tree.classes
  return clss
end

function enumerateComponents2(
  name::String,
  entry::LookupTree.Entry,
  comps::Vector{<:InstNode},
  components::List{<:InstNode},
)::List{InstNode}

  () = begin
    @match entry begin
      LookupTree.COMPONENT(__) => begin
        components = Cons{InstNode}(comps[entry.index], components)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return components
end

function enumerateComponents(tree::ClassTree)::List{InstNode}
  local components::List{InstNode}
  local ltree::LookupTree.Tree
  local comps::Vector{InstNode}
  @match CLASS_TREE_FLAT_TREE(tree = ltree, components = comps) = tree
  components = LookupTree.fold(ltree, (name, entry, components) -> enumerateComponents2(name, entry, comps, components), nil)
  return components
end

function setClassExtends(extNode::InstNode, tree::ClassTree)::ClassTree

  arrayUpdate(getExtends(tree), 1, extNode)
  return tree
end

function getRedeclaredNode(name::String, tree::ClassTree)::InstNode
  local node::InstNode
  local entry::DuplicateTree.Entry
  entry = DuplicateTree.get(getDuplicates(tree), name)
  entry = entry.children[1]
  if isSome(entry.node)
    @match SOME(node) = entry.node
  else
    entry = resolveEntry(entry.entry, tree)
    if entry isa EMPTY_NODE
      Error.assertion(false, getInstanceName() + " failed on " + name, sourceInfo())
    end
    node = entry.node
  end
  return node
end

function isIdentical(tree1::ClassTree, tree2::ClassTree)::Bool
  local identical::Bool

  identical = true
  return identical
end

function checkDuplicates2(
  name::String,
  entry::DuplicateTree.Entry,
  tree::ClassTree,
)::ClassTree

  local kept::InstNode
  local dup::InstNode

  @match SOME(kept) = entry.node
  if entry.ty != DuplicateTree.EntryType.REDECLARE
    for c in entry.children
      @match SOME(dup) = c.node
      checkIdentical(kept, dup)
    end
  end
  return tree
end

function checkDuplicates(tree::ClassTree)
  return () = begin
    @match tree begin
      CLASS_TREE_INSTANTIATED_TREE(__) where {(!DuplicateTree.isEmpty(tree.duplicates))} => begin
        DuplicateTree.fold(tree.duplicates, checkDuplicates2, tree)
        ()
      end

      _ => begin
        ()
      end
    end
  end
end

function extendsCount(tree::ClassTree)::Int
  local count::Int = arrayLength(getExtends(tree))
  return count
end

function componentCount(tree::ClassTree)
  @match tree begin
    CLASS_TREE_PARTIAL_TREE(__) => begin
      length(tree.components) - length(tree.exts)
    end

    CLASS_TREE_EXPANDED_TREE(__) => begin
      length(tree.components) - length(tree.exts)
    end

    CLASS_TREE_INSTANTIATED_TREE(__) => begin
      length(tree.components)
    end

    CLASS_TREE_FLAT_TREE(__) => begin
      length(tree.components)
    end
  end
end

function classCount(tree::ClassTree)::Int
  local count::Int

  count = begin
    @match tree begin
      CLASS_TREE_PARTIAL_TREE(__) => begin
        arrayLength(tree.classes)
      end

      CLASS_TREE_EXPANDED_TREE(__) => begin
        arrayLength(tree.classes)
      end

      CLASS_TREE_INSTANTIATED_TREE(__) => begin
        arrayLength(tree.classes)
      end

      CLASS_TREE_FLAT_TREE(__) => begin
        arrayLength(tree.classes)
      end
    end
  end
  return count
end

function foldComponents(tree::ClassTree, func::FuncT, arg::ArgT) where {ArgT}

  () = begin
    @match tree begin
      CLASS_TREE_PARTIAL_TREE(__) => begin
        for c in tree.components
          arg = func(c, arg)
        end
        ()
      end

      CLASS_TREE_EXPANDED_TREE(__) => begin
        for c in tree.components
          arg = func(c, arg)
        end
        ()
      end

      CLASS_TREE_INSTANTIATED_TREE(__) => begin
        for c in tree.components
          arg = func(P_Pointer.access(c), arg)
        end
        ()
      end

      CLASS_TREE_FLAT_TREE(__) => begin
        for c in tree.components
          arg = func(c, arg)
        end
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return arg
end

function applyComponents(tree::ClassTree, func::Function)::Nothing
  @match tree begin
    CLASS_TREE_PARTIAL_TREE(__) => begin
      for c in tree.components
        func(c)
      end
    end

    CLASS_TREE_EXPANDED_TREE(__) => begin
      for c in tree.components
        func(c)
      end
    end

    CLASS_TREE_INSTANTIATED_TREE(__) => begin
      for c in tree.components
        func(P_Pointer.access(c))
      end
    end

    CLASS_TREE_FLAT_TREE(__) => begin
      for c in tree.components
        func(c)
      end
    end

    _ => begin
    end
  end
end

using Distributed

function applyLocalComponents(tree::CLASS_TREE_INSTANTIATED_TREE,
                              attributes::Attributes,
                              useBinding::Bool,
                              instLevel::Int,
                              attributeRef::Ref{Attributes})::Nothing
  local components = tree.localComponents
  local componentNodes = COMPONENT_NODE{String, Int8}[]
  local componentInnerOuterNodes = INNER_OUTER_NODE[]
  for i in tree.localComponents
    local arg = P_Pointer.access(@inbounds tree.components[i]::Pointer{InstNode})
    if arg isa COMPONENT_NODE
      push!(componentNodes, arg)
    else
      push!(componentInnerOuterNodes, arg)
    end
  end
  for arg in componentNodes
    comp = component(arg)
    if ! isDefinition(comp)
      checkRecursiveDefinition(classInstance(comp), arg, false)
      return
    end
  end

  for arg in componentNodes
    instComponent(
      arg::COMPONENT_NODE{String, Int8},
      attributes,
      MODIFIER_NOMOD(),
      useBinding::Bool,
      instLevel::Int,
      attributeRef,
      NONE()
    )::Nothing
  end

  for arg in componentInnerOuterNodes
    instComponent(
      arg::INNER_OUTER_NODE,
      attributes,
      MODIFIER_NOMOD(),
      useBinding,
      instLevel,
      attributeRef,
      NONE()
    )::Nothing
  end
  return nothing
end

function applyLocalComponentsWithInstComponentExpressions(tree::CLASS_TREE_INSTANTIATED_TREE)
  for i in tree.localComponents
    local comp::Pointer{InstNode} = @inbounds tree.components[i]
    local arg = P_Pointer.access(comp)
    instComponentExpressions(arg)
  end
  return nothing
end

function applyLocalComponentsWithInstComponentExpressions(::CLASS_TREE_EXPANDED_TREE)
  return nothing
end

using Distributed

function applyLocalComponents(tree::Union{CLASS_TREE_PARTIAL_TREE,
                                                    CLASS_TREE_EXPANDED_TREE},
                                        attributes::Attributes,
                                        useBinding::Bool,
                                        instLevel::Int,
                                        attributeRef::Ref{Attributes}
                                        )
  for c in tree.components
    instComponent(
      c,
      attributes,
      MODIFIER_NOMOD(),
      useBinding,
      instLevel,
      NONE(),
      attributeRef
    ) #func(c)
  end
  return nothing
end

function applyLocalComponents(tree::Union{CLASS_TREE_PARTIAL_TREE,CLASS_TREE_EXPANDED_TREE}, func::Function)
  fail()
  for c in tree.components
    func(c)
  end
  return nothing
end

"""
  Applies a mutating function to each extends node in the class tree.
  A given argument is also folded and returned.
"""
function mapFoldExtends(tree::ClassTree, func::Function, arg::ArgT) where {ArgT}
  local exts::Vector{InstNode} = getExtends(tree)
  local ext::InstNode
  local N = length(exts)
  for i in 1:N
    (ext, arg) = func(arrayGetNoBoundsChecking(exts, i), arg)
    arrayUpdateNoBoundsChecking(exts, i, ext)
  end
  return arg
end

function foldExtends(tree::ClassTree, func::FuncT, arg::ArgT) where {ArgT}

  local exts::Vector{InstNode} = getExtends(tree)

  for ext in exts
    arg = func(ext, arg)
  end
  return arg
end

"""
  Applies a function to each extends node in the class tree, and updates
  the extends array with the returned nodes.
"""
function mapExtends(tree::ClassTree, func::Function)
  local exts::Vector{InstNode} = getExtends(tree)
  for i in 1:length(exts)
    @inbounds res = exts[i]
    @inbounds exts[i] = func(res)
  end
  return
end


function mapExtendsWithExtendsNode(tree::ClassTree, extendsNode::InstNode)
  local exts::Vector{InstNode} = getExtends(tree)
  for i in 1:length(exts)
    @inbounds res = exts[i]
    @inbounds exts[i] = modifyExtends(res, extendsNode)
  end
  return
end


function mapExtends(tree::CLASS_TREE_INSTANTIATED_TREE, parent::CLASS_NODE)
  local exts::Vector{InstNode} = getExtends(tree::CLASS_TREE_INSTANTIATED_TREE)
  for i in 1:length(exts)
    @inbounds res = exts[i]::CLASS_NODE
    @inbounds exts[i] = modifyExtends(res::CLASS_NODE, parent)::CLASS_NODE
  end
  return
end

function mapExtends(tree::CLASS_TREE_INSTANTIATED_TREE, parent::COMPONENT_NODE{String, Int8})
  local exts::Vector{InstNode} = getExtends(tree::CLASS_TREE_INSTANTIATED_TREE)
  for i in 1:length(exts)
    @inbounds res = exts[i]::CLASS_NODE
    @inbounds exts[i] = modifyExtends(res::CLASS_NODE, parent)::CLASS_NODE
  end
  return
end

function mapExtends(tree::ClassTree, attributes::Attributes, useBinding::Bool, visibility, instLevel::Int, attributeRef::Ref{Attributes})::Nothing
  local exts::Vector{InstNode} = getExtends(tree)
  for i in 1:length(exts)
    local res = @inbounds exts[i]::CLASS_NODE
    @inbounds exts[i] = instExtends(res::CLASS_NODE,
                                    attributes,
                                    useBinding,
                                    ExtendsVisibility.PUBLIC,
                                    instLevel + 1,
                                    attributeRef)::CLASS_NODE
  end
  return nothing
end

function applyExtends(tree::ClassTree, func::FuncT)
  local exts::Vector{InstNode} = getExtends(tree)
  return for ext in exts
    func(ext)
  end
end

function foldClasses(tree::ClassTree, func::FuncT, arg::ArgT) where {ArgT}
  local clss::Vector{InstNode} = getClasses(tree)
  for cls in clss
    arg = func(cls, arg)
  end
  return arg
end

function mapClasses(tree::ClassTree, func::FuncT)
  local clss::Vector{InstNode} = getClasses(tree)
  return for i = 1:arrayLength(clss)
    arrayUpdateNoBoundsChecking(clss, i, func(arrayGetNoBoundsChecking(clss, i)))
  end
end

function nthComponent(index::Int, tree::ClassTree)::InstNode
  local component::InstNode

  component = begin
    @match tree begin
      CLASS_TREE_PARTIAL_TREE(__) => begin
        arrayGet(tree.components, index)
      end

      CLASS_TREE_EXPANDED_TREE(__) => begin
        arrayGet(tree.components, index)
      end

      CLASS_TREE_INSTANTIATED_TREE(__) => begin
        P_Pointer.access(arrayGet(tree.components, index))
      end

      CLASS_TREE_FLAT_TREE(__) => begin
        arrayGet(tree.components, index)
      end
    end
  end
  return component
end

function lookupComponentIndex(name::String, tree::ClassTree)::Int
  local index::Int
  @match LookupTree.COMPONENT(index = index) = LookupTree.get(lookupTree(tree), name)
  return index
end

function lookupElementsPtr(name::String, tree::ClassTree)::List{Pointer{InstNode}}
  local elements::List{Pointer{InstNode}}
  local dup_entry::DuplicateTree.Entry
  #=
  TODO: Check if it possible not to use exception here in order to speed it up
  -John 2025
  =#
  try
    local duplicates = getDuplicates(tree)
    if duplicates isa DuplicateTree.EMPTY
      elements = list(lookupElementPtr(name, tree))
      return elements
    else
      dup_entry = DuplicateTree.get(duplicates, name)
      elements = resolveDuplicateEntriesPtr(dup_entry, tree)
    end
  catch
    elements = list(lookupElementPtr(name, tree))
  end
  return elements
end

function lookupElementPtr(name::String, tree::ClassTree)::Pointer{InstNode}
  local element::Pointer{InstNode}
  local entry::LookupTree.Entry
  entry = LookupTree.get(lookupTree(tree), name)
  element = resolveEntryPtr(entry, tree)
  return element
end

"""  Returns the class or component with the given name in the class tree. """
function lookupElement(name::String, classTree::ClassTree)
  local isImport::Bool
  local element::InstNode
  local entry::LookupTree.Entry
  #@info "Looking up element $name in class tree!"
  #@info "Fetching from tree. Soon to report entry"
  #@info "Structure of the tree" LookupTree.printTreeStr(tree.tree)
  lTree = lookupTree(classTree)
  entry = LookupTree.get(lTree, name)
  if entry == LookupTree.FAILURE
    return ENTRY_INFO(EMPTY_NODE(), false)
  end
  return resolveEntry(entry, classTree)
end

"""
Lookup in an empty tree yields a empty node.
"""
function lookupElement(name::String, classTree::CLASS_TREE_EMPTY_TREE)
  #fail()
  return ENTRY_INFO(EMPTY_NODE(), false)
end

function flattenLookupTree2(
  key::LookupTree.Key,
  entry::LookupTree.Entry,
  offsets::Vector{<:Int},
)::LookupTree.Entry
  local outEntry::LookupTree.Entry

  outEntry = begin
    @match entry begin
      LookupTree.COMPONENT(__) => begin
        LookupTree.COMPONENT(
          entry.index - arrayGetNoBoundsChecking(offsets, entry.index),
        )
      end

      _ => begin
        entry
      end
    end
  end
  return outEntry
end

"""
  Traverses a lookup tree and shifts the index of each component entry by
  using the given offset array, such that the lookup tree can be used to
  look up components when any duplicates have been removed from the
  component array.
"""
function flattenLookupTree(
  tree::LookupTree.Tree,
  offsets::Vector{<:Int},
)::LookupTree.Tree
  tree = LookupTree.map(tree, (key, entry) -> flattenLookupTree2(key, entry, offsets))
  return tree
end

"""
  Creates an array of offsets given an element count and a sorted list of
  duplicate indices. The offsets indicate how many positions each element
  is shifted when removing the duplicate elements. The duplicates are
  marked with -1 in the array. For example:
  createFlatOffsets(7, {2, 4, 5}) => {0, -1, 1, -1, -1, 3, 3}
"""
function createFlatOffsets(
  elementCount::Int,
  duplicates::List{<:Int},
)::Vector{Int}
  local offsets::Vector{Int}

  local offset::Int = 0
  local dup::Int
  local rest_dups::List{Int}

  offsets = arrayCreateNoInit(elementCount, 0)
  @match Cons{Int}(dup, rest_dups) = duplicates
  for i = 1:elementCount
    if i == dup
      if listEmpty(rest_dups)
        dup = 0
      else
        @match Cons{Int}(dup, rest_dups) = rest_dups
      end
      offset = offset + 1
      arrayUpdateNoBoundsChecking(offsets, i, -1)
    else
      arrayUpdateNoBoundsChecking(offsets, i, offset)
    end
  end
  return offsets
end

function flattenElementsWithOffset(
  elements::Vector{<:Pointer{<:InstNode}},
  flatElements::Vector{<:InstNode},
  offsets::Vector{<:Int},
)
  local offset::Int

  return for i = 1:arrayLength(elements)
    offset = arrayGetNoBoundsChecking(offsets, i)
    if offset >= 0
      arrayUpdateNoBoundsChecking(
        flatElements,
        i - offset,
        P_Pointer.access(arrayGetNoBoundsChecking(elements, i)),
      )
    end
  end
end

"""
  Copies elements from one array to another while removing the Mutable
  container for each element.
"""
function flattenElements(
  elements::Vector,
  flatElements::Vector{<:InstNode},
)
  return for i = 1:arrayLength(elements)
    arrayUpdateNoBoundsChecking(
      flatElements,
      i,
      P_Pointer.access(arrayGetNoBoundsChecking(elements, i)),
    )
  end
end

"""
  Flattens a class tree by creating new arrays for the classes and
  components with any duplicates removed and with the elements no longer
  being mutable references.
"""
function flatten(tree::ClassTree)::ClassTree

  tree = begin
    local clss::Vector{InstNode}
    local comps::Vector{InstNode}
    local comp_offsets::Vector{Int}
    local clsc::Int
    local compc::Int
    local dup_comp::List{Int}
    local ltree::LookupTree.Tree
    @match tree begin
      CLASS_TREE_INSTANTIATED_TREE(__) => begin
        #=  Create a list of indices for any duplicates.
        =#
        (_, dup_comp) = enumerateDuplicates(tree.duplicates)
        #=  Allocate new arrays for classes and components.
        =#
        clsc = arrayLength(tree.classes)
        compc = arrayLength(tree.components) - listLength(dup_comp)
        clss = arrayCreateNoInit(clsc, EMPTY_NODE())
        comps = arrayCreateNoInit(compc, EMPTY_NODE())
        #=  Class duplicates can be ignored since classes are only accessed
        =#
        #=  through name lookup and not index, so there's no need to spend
        =#
        #=  time on filtering them out.
        =#
        flattenElements(tree.classes, clss)
        #=
        Component duplicates should be removed though, since we don't
        want any duplicates in the flat model.
        =#
        if listEmpty(dup_comp)
          flattenElements(tree.components, comps)
          ltree = tree.tree
        else
          comp_offsets = createFlatOffsets(arrayLength(tree.components), dup_comp)
          flattenElementsWithOffset(tree.components, comps, comp_offsets)
          ltree = flattenLookupTree(tree.tree, comp_offsets)
        end
        #=  No duplicates, just copy to new array.
        =#
        #=  Duplicates, create an array of offsets and use it to fill the
        =#
        #=  new array and update the lookup tree.
        =#
        CLASS_TREE_FLAT_TREE(ltree, clss, comps, tree.imports, tree.duplicates)
      end

      _ => begin
        tree
      end
    end
  end
  return tree
end

"""
Appends a list of local components to an instantiated class tree.
"""
function appendComponentsToInstTree(
  components::List{<:Pointer{<:InstNode}},
  tree::ClassTree,
  )::ClassTree
  if listEmpty(components)
    return tree
  end
  local comp_idx::Int
  local local_comps::Vector{Int} = Int[]
  @match tree begin
    CLASS_TREE_INSTANTIATED_TREE(__) => begin
      comp_idx = arrayLength(tree.components)
      local tmpComponents = ArrayUtil.appendList(tree.components, components)
      local n_new = listLength(components)
      local_comps = copy(tree.localComponents)
      sizehint!(local_comps, length(local_comps) + n_new)
      for i = (comp_idx + 1):(comp_idx + n_new)
        push!(local_comps, i)
      end
      localComponentsTmp = local_comps
      return CLASS_TREE_INSTANTIATED_TREE(tree.tree,
                                          tree.classes,
                                          tmpComponents,
                                          localComponentsTmp,
                                          tree.exts,
                                          tree.imports, tree.duplicates)
    end
  end
end

"""
  This function replaces all duplicate elements with the element that is
  kept, such that lookup in the extends nodes will find the correct node.
"""
replaceDuplicates(tree::ClassTree) = tree
function replaceDuplicates(tree::CLASS_TREE_INSTANTIATED_TREE)
  @match tree begin
    CLASS_TREE_INSTANTIATED_TREE(__) where {(!DuplicateTree.isEmpty(tree.duplicates))} => begin
      local treeDuplicates = DuplicateTree.map(tree.duplicates, (name, entry) -> replaceDuplicates2(name, entry, tree))
      CLASS_TREE_INSTANTIATED_TREE(tree.tree, tree.classes, tree.components, tree.localComponents, tree.exts, tree.imports, treeDuplicates)
    end
    _ => begin
      tree
    end
  end
  return tree
end

function mapRedeclareChains(tree::ClassTree, func::FuncT)
  @match tree begin
    CLASS_TREE_INSTANTIATED_TREE(__) where {(!DuplicateTree.isEmpty(tree.duplicates))} => begin
      DuplicateTree.map(
        tree.duplicates,
        (name, entry) -> mapRedeclareChain(name, entry, func, tree),
      )
      ()
    end
    _ => begin
      ()
    end
  end
end

function mapRedeclareChains(tree::ClassTree, func::Function, instLevel::Int)
  @match tree begin
    CLASS_TREE_INSTANTIATED_TREE(__) where {(!DuplicateTree.isEmpty(tree.duplicates))} => begin
      local closedFunc = (chain) -> func(chain, instLevel)
      DuplicateTree.map(
        tree.duplicates,
        (name, entry) -> mapRedeclareChain(name, entry, closedFunc, tree),
      )
      ()
    end
    _ => begin
      ()
    end
  end
end

function clone(tree::ClassTree)::ClassTree
  local outTree::ClassTree

  outTree = begin
    local clss::Vector{InstNode}
    @match tree begin
      CLASS_TREE_EXPANDED_TREE(__) => begin
        clss = arrayCopy(tree.classes)
        clss = ArrayUtil.mapNoCopy(clss, clone)
        CLASS_TREE_EXPANDED_TREE(
          tree.tree,
          clss,
          tree.components,
          tree.exts,
          tree.imports,
          tree.duplicates,
        )
      end

      _ => begin
        tree
      end
    end
  end
  return outTree
end

function fromRecordConstructor(fields::List{<:InstNode}, out::InstNode)::ClassTree
  local tree::ClassTree = deepcopy(EMPTY_CLASS_TREE)

  local ltree::LookupTree.Tree = LookupTree.new()
  local i::Int = 1
  local comps::Vector{InstNode}

  comps = arrayCreateNoInit(listLength(fields) + 1, EMPTY_NODE())
  for ci in fields
    comps[i] = ci
    ltree =
      addLocalElement(name(ci), LookupTree.COMPONENT(i), tree, ltree)
    i = i + 1
  end
  comps[i] = out
  ltree =
    addLocalElement(name(out), LookupTree.COMPONENT(i), tree, ltree)
  tree =
    CLASS_TREE_FLAT_TREE(ltree, listArray(nil), comps, listArray(nil), DuplicateTree.new())
  return tree
end

"""
  This function instantiates an expanded tree. clsNode is the class to
  be instantiated, while instance is the instance the clsNode belongs to.
  instance is usually the component which has the class as its type. In
  some cases the class itself is the instance, like for the top-level
  model that's being instantiated or packages used for lookup. Because the
  actual instance of clsNode will then be the cloned clsNode created by
  this function it's not possible to send in the correct instance in that
  case, so setting the instance to an empty node is interpreted by this
  function to mean that the instance should be set to the cloned clsNode.
"""
function instantiate(
  clsNode::CLASS_NODE,
  instance::InstNode,
  scope::InstNode = EMPTY_NODE(),
  )::Tuple{CLASS_NODE, InstNode, Int, Int} #where {CLS_NODE}
  local compCount::Int = 0
  local classCount::Int = 0
  local cls::Class
  local tree::ClassTree
  local ext_tree::ClassTree
  local ltree::LookupTree.Tree
  local exts::Vector{InstNode}
  local old_clss::Vector{InstNode}
  local old_comps::Vector{InstNode}
  local imps::Vector{Import}
  local clss::Vector{Pointer{InstNode}}
  local comps::Vector{Pointer{InstNode}}
  local ext_clss::Vector{Pointer{InstNode}}
  local cls_idx::Int = 1
  local comp_idx::Int = 1
  local cls_count::Int
  local comp_count::Int
  local node::InstNode
  local parent_scope::InstNode
  local inner_node::InstNode
  local inst_scope::InstNode
  local dups::DuplicateTree.Tree
  local comp::Component
  local ext_def::SCode.Element
  local is_typish::Bool
  #@debug "Instantiating in class tree"
  #=  TODO: If we don't have any extends we could probably generate a flat
  =#
  #=  tree directly and skip a lot of this.
  =#
  #=  Clone the class node by replacing the class in the node with itself.
  =#
  cls = getClass(clsNode)
  clsNode = replaceClass(cls, clsNode)
  @match cls begin
    EXPANDED_CLASS(elements = CLASS_TREE_INSTANTIATED_TREE(__)) => begin
    end
    EXPANDED_CLASS(__) => begin
      #=  If the instance is an empty node, use the cloned clsNode as the instance.
      =#
      if isEmpty(instance)
        instance = clsNode
        parent_scope = parent(clsNode)
      else
        parent_scope = instance
        inst_scope = scope
      end
      inst_scope = if isEmpty(scope)
        instance
      else
        scope
      end
      #=  Fetch the elements from the class tree.
      =#
      @match CLASS_TREE_EXPANDED_TREE(ltree, old_clss, old_comps, exts, imps, dups) = cls.elements
      #=  Count the number of local classes and components we have.
      =#
      classCount = arrayLength(old_clss)
      #=  The component array contains placeholders for extends, so the length of the
      =#
      #=  extends array needs to be subtracted here to get the number of components.
      =#
      compCount = arrayLength(old_comps) - arrayLength(exts)
      #=  Make a new extends array, and recursively instantiate the extends nodes.
      =#
      exts = copy(exts)
      for i = 1:arrayLength(exts)
        node = exts[i]
        @match BASE_CLASS(definition = ext_def) = nodeType(node)
        node =
          setNodeType(BASE_CLASS(instance, ext_def), node)
        (node, tmp, cls_count, comp_count) = instantiate(node, EMPTY_NODE(), inst_scope)
        exts[i] = node
        classCount = cls_count + classCount
        compCount = comp_count + compCount
      end
      #=  Update the parent of the extends to be the new instance.
      =#
      #=  Instantiate the class tree of the extends.
      =#
      #=  Add the inherited elements to the class/component counts.
      =#
      #=  Create new arrays that can hold both local and inherited elements.
      =#
      comps =
        arrayCreateNoInit(compCount, P_Pointer.create(EMPTY_NODE(), InstNode))
      #= /*dummy*/ =#
      clss =
        arrayCreateNoInit(classCount, P_Pointer.create(EMPTY_NODE(), InstNode))
      #= /*dummy*/ =#
      #=  Copy the local classes into the new class array, and set the
      =#
      #=  class we're instantiating to be their parent.
      =#
      is_typish =
        isType(cls.restriction) ||
        isOperatorRecord(cls.restriction) ||
        isOperator(cls.restriction)
      for c in old_clss
        if is_typish
          c = setParent(clsNode, c)
        else
          c = clone(c)
          c = setParent(instance, c)
        end
        if isOuter(c)
          checkOuterClass(c)
          c = linkInnerOuter(c, parent_scope)
        end
        @inbounds clss[cls_idx] = P_Pointer.create(c, InstNode)
        cls_idx = cls_idx + 1
      end
      for ext in exts
        @match classTree(getClass(ext)) begin
          CLASS_TREE_INSTANTIATED_TREE(classes = ext_clss) => begin
            cls_count = arrayLength(ext_clss)
            if cls_count > 0
              ArrayUtil.copyRange(ext_clss, clss, 1, cls_count, cls_idx)
              cls_idx = cls_idx + cls_count
            end
          end
          _ => begin
          end
        end
      end
      #=  Copy both local and inherited components into the new array. =#
      local local_comps::Vector{Int} = Int[]
      sizehint!(local_comps, compCount)
      for c in old_comps
          @match c begin
            COMPONENT_NODE(__) => begin
              #=  Set the component's parent and create a unique instance for it. =#
              node = setParentAndReplaceComponent(instance, c)
              #=
              If the component is outer, link it with the corresponding inner component.
              =#
              if isOuter(component(node))
                node = linkInnerOuter(node, inst_scope)
              end
              #=  Add the node to the component array. =#
              comps[comp_idx] = P_Pointer.create(node, InstNode)
              push!(local_comps, comp_idx)
              comp_idx = comp_idx + 1
            end
            REF_NODE(__) => begin
              comp_idx = instExtendsComps(exts[c.index], comps, comp_idx)
            end
          end
      end
      reverse!(local_comps)
      #=  Sanity check.
      =#
      if comp_idx != compCount + 1
        Error.assertion(
          false,
          getInstanceName() + " miscounted components in " + name(clsNode),
          sourceInfo(),
        )
      end
      if cls_idx != classCount + 1
        Error.assertion(
          false,
          getInstanceName() + " miscounted classes in " + name(clsNode),
          sourceInfo(),
        )
      end
      #=  Create a new class tree and update the class in the node.
      =#
      local newClassTree = CLASS_TREE_INSTANTIATED_TREE(ltree, clss, comps, local_comps, exts, imps, dups)
      cls = EXPANDED_CLASS(newClassTree,
                           cls.modifier,
                           cls.prefixes,
                           cls.restriction)
    end
    EXPANDED_DERIVED(baseClass = node) => begin
      node = setNodeType(
        BASE_CLASS(clsNode, definition(node)),
        node,
      )
      tmp = instantiate(node, instance, scope)
      (node, instance, classCount, compCount) = tmp
      cls = EXPANDED_DERIVED(node, cls.modifier, cls.dims, cls.prefixes, cls.attributes, cls.restriction)
    end
    PARTIAL_BUILTIN(elements = tree && CLASS_TREE_FLAT_TREE(components = old_comps)) =>
      begin
        instance = if isEmpty(instance)
          clsNode
        else
          instance
        end
        old_comps = arrayCopy(old_comps)
        for i = 1:arrayLength(old_comps)
          old_comps[i] = setParentAndReplaceComponent(instance, old_comps[i])
        end
        tree = CLASS_TREE_FLAT_TREE(tree.tree, tree.classes, old_comps, tree.imports, tree.duplicates)
        cls = PARTIAL_BUILTIN(cls.ty, tree, cls.modifier, cls.prefixes, cls.restriction)
        compCount = length(old_comps)
      end
    PARTIAL_BUILTIN(__) => begin
    end
    _ => begin
      ###Error.assertion(false, getInstanceName() + " got invalid class", sourceInfo())
      str = clsNode.name
      @error "Got an invalid class $cls for $(str)"
      fail()
    end
  end
  updateClass(cls, clsNode)
  return (clsNode, instance, classCount, compCount)
end

"""
  This function adds all local and inherited class and component names to
  the lookup tree. Note that only their names are added, the elements
  themselves are added to their respective arrays by the instantiation
  function below.
"""
function expand(tree::ClassTree)::ClassTree
  local ltree::LookupTree.Tree
  local lentry::LookupTree.Entry
  local exts::Vector{InstNode}
  local clss::Vector{InstNode}
  local comps::Vector{InstNode}
  local imps::Vector{Import}
  local ext_idxs::List{Tuple{Int, Int}} = nil
  local ccount::Int
  local cls_idx::Int
  local comp_idx::Int = 1
  local dups::DuplicateTree.Tree
  local dups_ptr::Pointer{DuplicateTree.Tree}

  @match CLASS_TREE_PARTIAL_TREE(ltree, clss, comps, exts, imps, dups) = tree
  cls_idx = arrayLength(clss) + 1
  #=  Since we now know the names of both local and inherited components we
  =#
  #=  can add them to the lookup tree. First we add the local components'
  =#
  #=  names, to be able to catch duplicate local elements easier.
  =#
  for c in comps
    () = begin
      @match c begin
        COMPONENT_NODE(__) => begin
          #=  A component. Add its name to the lookup tree.
          =#
          lentry = LookupTree.COMPONENT(comp_idx)
          ltree = addLocalElement(name(c), lentry, tree, ltree)
          #=  If the component is an element redeclare, add an entry in the duplicate
          =#
          #=  tree so we can check later that it actually redeclares something.
          =#
          if isRedeclare(c)
            dups =
              DuplicateTree.add(dups, c.name, DuplicateTree.newRedeclare(lentry))
          end
          comp_idx = comp_idx + 1
          ()
        end

        REF_NODE(__) => begin
          ext_idxs = Cons{Tuple{Int, Int}}((cls_idx - 1, comp_idx - 1), ext_idxs)
          (cls_idx, comp_idx) =
            countInheritedElements(exts[c.index], cls_idx, comp_idx)
          ()
        end
        _ => begin
          Error.assertion(false, getInstanceName() + " got invalid component", sourceInfo())
          fail()
        end
      end
    end
  end
  dups_ptr = P_Pointer.create(dups, DuplicateTree.Tree)
  #=  Add the names of inherited components and classes to the lookup tree. =#
  if !listEmpty(ext_idxs)
    ext_idxs = listReverseInPlace(ext_idxs)
    for ext in exts
      @match Cons{Tuple{Int, Int}}((cls_idx, comp_idx), ext_idxs) = ext_idxs
      ltree = expandExtends(ext, ltree, cls_idx, comp_idx, dups_ptr)
    end
  end
  tree = CLASS_TREE_EXPANDED_TREE(ltree, clss, comps, exts, imps, P_Pointer.access(dups_ptr))
  return tree
end

"""
  Adds a list of class and/or component nodes as elements to a flat class
  tree, in the same order as they are listed. Name conflicts will result in
  an duplicate element error, and trying to add nodes that are not pure
  class or component nodes will result in undefined behaviour.
"""
function addElementsToFlatTree(elements::List{<:InstNode}, tree::ClassTree)::ClassTree
  local ltree::LookupTree.Tree
  local cls_arr::Vector{InstNode}
  local comp_arr::Vector{InstNode}
  local imports::Vector{Import}
  local duplicates::DuplicateTree.Tree
  local cls_idx::Int
  local comp_idx::Int
  local lentry::LookupTree.Entry
  @match CLASS_TREE_FLAT_TREE(ltree, cls_arr, comp_arr, imports, duplicates) = tree
  cls_idx = arrayLength(cls_arr)
  comp_idx = arrayLength(comp_arr)
  for e in elements
    if isComponent(e)
      comp_idx = comp_idx + 1
      lentry = LookupTree.COMPONENT(comp_idx)
      push!(comp_arr, e)
    else
      cls_idx = cls_idx + 1
      lentry = LookupTree.CLASS(cls_idx)
      push!(cls_arr, e)
    end
    ltree = addLocalElement(name(e), lentry, tree, ltree)
  end
  for e in cls_arr
    push!(cls_arr, e)
  end
  for c in comp_arr
    push!(comp_arr, c)
  end
  tree = CLASS_TREE_FLAT_TREE(ltree, cls_arr, comp_arr, imports, duplicates)
  return tree
end

"""Creates a class tree for an enumeration type."""
function fromEnumeration(
  literals::List{<:SCode.Enum},
  enumType::M_Type,
  enumClass::InstNode,
)::ClassTree #= The InstNode of the enumeration type =#
  local tree::ClassTree
  local comps::Vector{InstNode}
  local attr_count::Int = 5
  local i::Int = 0
  local comp::InstNode
  local ltree::LookupTree.Tree
  local name::String
  comps = arrayCreateNoInit(listLength(literals) + attr_count, EMPTY_NODE())
  ltree = NFBuiltin.GET_ENUM_LOOKUP_TREE()
  arrayUpdateNoBoundsChecking(
    comps,
    1,
    fromComponent(
      "quantity",
      TYPE_ATTRIBUTE(TYPE_STRING(), MODIFIER_NOMOD()),
      enumClass,
    ),
  )
  arrayUpdateNoBoundsChecking(
    comps,
    2,
    fromComponent(
      "min",
      TYPE_ATTRIBUTE(enumType, MODIFIER_NOMOD()),
      enumClass,
    ),
  )
  arrayUpdateNoBoundsChecking(
    comps,
    3,
    fromComponent(
      "max",
      TYPE_ATTRIBUTE(enumType, MODIFIER_NOMOD()),
      enumClass,
    ),
  )
  arrayUpdateNoBoundsChecking(
    comps,
    4,
    fromComponent(
      "start",
      TYPE_ATTRIBUTE(enumType, MODIFIER_NOMOD()),
      enumClass,
    ),
  )
  arrayUpdateNoBoundsChecking(
    comps,
    5,
    fromComponent(
      "fixed",
      TYPE_ATTRIBUTE(TYPE_BOOLEAN(), MODIFIER_NOMOD()),
      enumClass,
    ),
  )
#  @info "Before"
#  @info LookupTree.printTreeStr(ltree)
  for l in literals
    nameStr = l.literal
    i = i + 1
    comp =
      fromComponent(nameStr, newEnum(enumType, nameStr, i), enumClass)
    arrayUpdateNoBoundsChecking(comps, i + attr_count, comp)
    ltree = LookupTree.add(
      ltree,
      nameStr,
      LookupTree.COMPONENT(i + attr_count),
      (x, y, z) -> addEnumConflict(x, y, z, comp),
    )
  end
  #=  Make a new component node for the literal and add it to the lookup tree.
  =#
  #=  Enumerations can't contain extends, so we can go directly to a flat tree here.
  =#
  tree =
    CLASS_TREE_FLAT_TREE(ltree, listArray(nil), comps, listArray(nil), DuplicateTree.EMPTY())
  return tree
end

"""Creates a new class tree from a list of SCode elements."""
function fromSCode(
  elements::List{<:SCode.Element},
  isClassExtends::Bool,
  parent::InstNode,
)::ClassTree
  local tree::ClassTree

  local ltree::LookupTree.Tree
  local lentry::LookupTree.Entry
  local clsc::Int
  local compc::Int
  local extc::Int
  local i::Int
  local clss::Vector{InstNode}
  local comps::Vector{InstNode}
  local exts::Vector{InstNode}
  local cls_idx::Int = 0
  local ext_idx::Int = 0
  local comp_idx::Int = 0
  local dups::DuplicateTree.Tree
  local imps::List{Import} = nil
  local imps_arr::Vector{Import}
  local info::SourceInfo

  ltree = LookupTree.new()
  #=  Count the different types of elements.
  =#
  (clsc, compc, extc) = countElements(elements)
  #=  If the class is a class extends, reserve space for the extends.
  =#
  if isClassExtends
    extc = extc + 1
  end
  #=  Preallocate arrays for the elements. We can't do this for imports
  =#
  #=  though, since an import clause might import multiple elements.
  =#
  clss = arrayCreate(clsc, EMPTY_NODE())
  comps = arrayCreate(compc + extc, EMPTY_NODE())
  exts = arrayCreate(extc, EMPTY_NODE())
  dups = DuplicateTree.new()
  #=  Make a temporary class tree so we can do lookup for error reporting.
  =#
  tree = CLASS_TREE_PARTIAL_TREE(ltree, clss, comps, exts, listArray(nil), dups)
  #=  If the class is a class extends, fill in the first extends with an
  =#
  #=  empty node so we don't have unassigned memory after this step.
  =#
  if isClassExtends
    exts[1] = EMPTY_NODE()
    comps[1] = REF_NODE(1)
    ext_idx = ext_idx + 1
    comp_idx = comp_idx + 1
  end
  for e in elements
    () = begin
      @match e begin
        SCode.CLASS(__) => begin
          #=  A class, add it to the class array and add an entry in the lookup tree.
          =#
          cls_idx = cls_idx + 1
          arrayUpdate(clss, cls_idx, newClass(e, parent))
          lentry = LookupTree.CLASS(cls_idx)
          ltree = addLocalElement(e.name, lentry, tree, ltree)
          #=  If the class is an element redeclare, add an entry in the duplicate
          =#
          #=  tree so we can check later that it actually redeclares something.
          =#
          if SCodeUtil.isElementRedeclare(e) || SCodeUtil.isClassExtends(e)
            dups =
              DuplicateTree.add(dups, e.name, DuplicateTree.newRedeclare(lentry))
          end
          ()
        end

        SCode.COMPONENT(__) => begin
          #=  A component, add it to the component array but don't add an entry
          =#
          #=  in the lookup tree. We need to preserve the components' order, but
          =#
          #=  won't know their actual indices until we've expanded the extends.
          =#
          #=  We don't really need to be able to look up components until after
          =#
          #=  that happens, so we add them to the lookup tree later instead.
          =#
          comp_idx = comp_idx + 1
          arrayUpdate(comps, comp_idx, newComponent(e))
          ()
        end

        SCode.EXTENDS(__) => begin
          #=  An extends clause, add it to the list of extends, and also add a
          =#
          #=  reference in the component array so we can preserve the order of
          =#
          #=  components.
          =#
          ext_idx = ext_idx + 1
          arrayUpdate(exts, ext_idx, newExtends(e, parent))
          comp_idx = comp_idx + 1
          arrayUpdate(comps, comp_idx, REF_NODE(ext_idx))
          ()
        end

        SCode.IMPORT(imp = Absyn.UNQUAL_IMPORT(__), info = info) => begin
          #=  An unqualified import clause. We need to know which names are
          =#
          #=  imported by the clause, so it needs to be instantiated.
          =#
          imps = instUnqualified(e.imp, parent, info, imps)
          ()
        end

        SCode.IMPORT(__) => begin
          #=  A qualified import clause. Since the import itself gives the name
          =#
          #=  of the imported element we can delay resolving the path until we
          =#
          #=  need it (i.e. when the name is used). Doing so avoids some
          =#
          #=  dependency issues, like when a package is imported into one of it's
          =#
          #=  enclosing scopes.
          =#
          imps = Cons{Import}(UNRESOLVED_IMPORT(e.imp, parent, e.info), imps)
          ()
        end
      end
    end
  end
  #= else
  =#
  #=   algorithm
  =#
  #=     print(getInstanceName() + \" skipping:\\n\" +
  =#
  #=       SCodeDump.unparseElementStr(e) + \"\\n\");
  =#
  #=   then
  =#
  #=     ();
  =#
  #=  Add all the imported names to the lookup tree.
  =#
  imps_arr = listArray(imps)
  i = 1
  for e in imps
    ltree = addImport(e, i, ltree, imps_arr)
    i = i + 1
  end
  tree = CLASS_TREE_PARTIAL_TREE(ltree, clss, comps, exts, imps_arr, dups)
  return tree
end

"""
  Checks that a class used as outer is valid, i.e. is a short class
  definition with no modifier.
"""
function checkOuterClass(outerCls::InstNode)
  local def::SCode.ClassDef

  return if isOnlyOuter(outerCls)
    def = SCodeUtil.getClassDef(definition(outerCls))
    () = begin
      @match def begin
        SCode.DERIVED(modifications = SCode.NOMOD(__)) => begin
          ()
        end

        SCode.DERIVED(__) => begin
          #=  Outer short class definition without mod is ok.
          =#
          #=  Outer short class definition with mod is an error.
          =#
          Error.addSourceMessage(
            Error.OUTER_ELEMENT_MOD,
            list(SCodeDump.printModStr(def.modifications), name(outerCls)),
            info(outerCls),
          )
          fail()
        end

        _ => begin
          #=  Outer long class definition is an error.
          =#
          Error.addSourceMessage(
            Error.OUTER_LONG_CLASS,
            list(name(outerCls)),
            info(outerCls),
          )
          fail()
        end
      end
    end
  end
end

"""
  Looks up the corresponding inner node for the given outer node,
  and returns an INNER_OUTER_NODE containing them both.
"""
function linkInnerOuter(outerNode::InstNode, scope::InstNode)::InstNode
  local innerOuterNode::InstNode

  local inner_node::InstNode

  inner_node = lookupInner(outerNode, scope)
  #=  Make sure we found a node of the same kind.
  =#
  if valueConstructor(outerNode) != valueConstructor(inner_node)
    Error.addMultiSourceMessage(
      Error.FOUND_WRONG_INNER_ELEMENT,
      list(
        typeName(inner_node),
        name(outerNode),
        typeName(outerNode),
      ),
      list(info(outerNode), info(inner_node)),
    )
    fail()
  end
  innerOuterNode = INNER_OUTER_NODE(inner_node, outerNode)
  return innerOuterNode
end

function replaceDuplicates4(
  entry::DuplicateTree.DUPLICATE_TREE_ENTRY,
  node::InstNode,
  )
  local replacedEntry = DuplicateTree.DUPLICATE_TREE_ENTRY(entry.entry, SOME(node), entry.children, entry.ty)
  local f = @closure c -> replaceDuplicates4(c, node)
  map!(f, replacedEntry.children, replacedEntry.children)
  return replacedEntry
end

function replaceDuplicates3(
  entry::DuplicateTree.DUPLICATE_TREE_ENTRY,
  kept::InstNode,
  tree::ClassTree,
)::DuplicateTree.Entry
  local node_ptr::Pointer{InstNode}
  local node::InstNode
  node_ptr = resolveEntryPtr(entry.entry, tree)
  node = P_Pointer.access(node_ptr)
  local replacedEntry = DuplicateTree.DUPLICATE_TREE_ENTRY(entry.entry, SOME(node), entry.children, entry.ty)
  P_Pointer.update(node_ptr, kept)
  local f = @closure c -> replaceDuplicates3(c, kept, tree)
  #@assign entry.children = DuplicateTree.Entry[replaceDuplicates3(c, kept, tree) for c in entry.children]
  map!(f, replacedEntry.children, replacedEntry.children)
  return replacedEntry
end

function replaceDuplicates2(
  name::String,
  entry::DuplicateTree.DUPLICATE_TREE_ENTRY,
  tree::ClassTree,
)::DuplicateTree.Entry
  local kept
  local node_ptr::Pointer{InstNode}
  local kept_entry::DuplicateTree.Entry
  node_ptr = resolveEntryPtr(entry.entry, tree)
    if entry.ty == DuplicateTree.EntryType.REDECLARE
        kept = P_Pointer.access(resolveEntryPtr(entry.entry, tree))
        entry = replaceDuplicates4(entry, kept)
    elseif entry.ty == DuplicateTree.EntryType.DUPLICATE
        kept = P_Pointer.access(node_ptr)
        local replacedEntry = DuplicateTree.DUPLICATE_TREE_ENTRY(entry.entry, SOME(kept), entry.children, entry.ty)
        entry = replacedEntry
        local f = @closure c -> replaceDuplicates3(c, kept, tree)
        map!(f, entry.children, entry.children)
    end
  return entry
end

function getRedeclareChain(
  entry::DuplicateTree.Entry,
  tree::ClassTree,
  chain::List{<:Pointer{<:InstNode}} = nil,
)::List{Pointer{InstNode}}

  local node_ptr::Pointer{InstNode}
  local node::InstNode
  chain = if entry.ty == DuplicateTree.EntryType.REDECLARE
      node_ptr = resolveEntryPtr(entry.entry, tree)
      if isempty(entry.children)
        node = P_Pointer.access(node_ptr)
        if SCodeUtil.isClassExtends(definition(node))
          Error.addSourceMessage(
            Error.CLASS_EXTENDS_TARGET_NOT_FOUND,
            list(name(node)),
            info(node),
          )
        else
          Error.addSourceMessage(
            Error.REDECLARE_NONEXISTING_ELEMENT,
            list(name(node)),
            info(node),
          )
        end
        fail()
      end
      getRedeclareChain(entry.children[1], tree, Cons{Pointer{InstNode}}(node_ptr, chain))
  elseif entry.ty == DuplicateTree.EntryType.ENTRY
      node_ptr = resolveEntryPtr(entry.entry, tree)
      Cons{Pointer{InstNode}}(node_ptr, chain)
  else
      chain
  end
  return chain
end

function mapRedeclareChain(
  name::String,
  entry::DuplicateTree.Entry,
  func::FuncT,
  tree::ClassTree,
)::DuplicateTree.Entry

  local chain::List{Pointer{InstNode}}

  chain = getRedeclareChain(entry, tree)
  if !listEmpty(chain)
    func(chain)
  end
  return entry
end

function enumerateDuplicates4(
  entry::LookupTree.Entry,
  classes::List{Int},
  components::List{Int},
)::Tuple{List{Int}, List{Int}}

  () = begin
    @match entry begin
      LookupTree.CLASS(__) => begin
        #= classes := entry.index :: classes;
        =#
        ()
      end

      LookupTree.COMPONENT(__) => begin
        components = Cons{Int}(entry.index, components)
        ()
      end
    end
  end
  return (classes, components)
end

function enumerateDuplicates3(
  entry::DuplicateTree.Entry,
  classes::List{Int},
  components::List{Int},
)::Tuple{List{Int}, List{Int}}

  (classes, components) = enumerateDuplicates4(entry.entry, classes, components)
  for c in entry.children
    (classes, components) = enumerateDuplicates3(c, classes, components)
  end
  return (classes, components)
end

function enumerateDuplicates2(
  name::String,
  entry::DuplicateTree.Entry,
  classes::List{Int},
  components::List{Int},
)::Tuple{List{Int}, List{Int}}

  for c in entry.children
    (classes, components) = enumerateDuplicates3(c, classes, components)
  end
  return (classes, components)
end

"""
  Returns the indices of the duplicate classes and components,
  not including the ones that should be kept.
"""
function enumerateDuplicates(
  duplicates::DuplicateTree.Tree,
)::Tuple{List{Int}, List{Int}}
  local components::List{Int}
  local classes::List{Int}

  if DuplicateTree.isEmpty(duplicates)
    classes = nil
    components = nil
  else
    (classes, components) =
      DuplicateTree.fold_2(duplicates, enumerateDuplicates2, nil, nil)
    classes = ListUtil.sort(classes, intGt)
    components = ListUtil.sort(components, intGt)
  end
  return (classes, components)
end

"""Joins two duplicate tree entries together."""
function joinDuplicates(
  newEntry::DuplicateTree.Entry,
  oldEntry::DuplicateTree.Entry,
  name::String,
  )
  local entry::DuplicateTree.Entry = oldEntry

  #=  Add the new entry as a child of the old entry.
  =#
  entryChildren = [newEntry ; entry.children]
  return DuplicateTree.DUPLICATE_TREE_ENTRY(oldEntry.entry, oldEntry.node, entryChildren, oldEntry.ty)
end

function offsetDuplicate(
  entry::LookupTree.Entry,
  classOffset::Int,
  componentOffset::Int,
)::LookupTree.Entry
  local offsetEntry::LookupTree.Entry

  offsetEntry = begin
    @match entry begin
      LookupTree.CLASS(__) => begin
        LookupTree.CLASS(entry.index + classOffset)
      end

      LookupTree.COMPONENT(__) => begin
        LookupTree.COMPONENT(entry.index + componentOffset)
      end
    end
  end
  return offsetEntry
end

"""
Offsets all values in the given entry so that they become valid for the
inheriting class.
"""
function offsetDuplicates(
  name::String,
  entry::DuplicateTree.Entry,
  classOffset::Int,
  componentOffset::Int,
)::DuplicateTree.Entry
  local offsetEntry::DuplicateTree.Entry
  local parent::LookupTree.Entry
  local children::Vector{DuplicateTree.Entry}
  parent = offsetDuplicate(entry.entry, classOffset, componentOffset)
  children =
    DuplicateTree.Entry[offsetDuplicates(name, c, classOffset, componentOffset) for c in entry.children]
  offsetEntry = DuplicateTree.DUPLICATE_TREE_ENTRY(parent, NONE(), children, entry.ty)
  return offsetEntry
end

""" Conflict handler for addInheritedComponent. """
function addInheritedElementConflict(
  newEntry::LookupTree.Entry,
  oldEntry::LookupTree.Entry,
  name::String,
  duplicates::Pointer{<:DuplicateTree.Tree},
  extDuplicates::DuplicateTree.Tree,
)::LookupTree.Entry
  local entry::LookupTree.Entry
  local dups::DuplicateTree.Tree
  local opt_dup_entry::Option{DuplicateTree.DUPLICATE_TREE_ENTRY}
  local dup_entry::DuplicateTree.DUPLICATE_TREE_ENTRY
  local new_id::Int = LookupTree.index(newEntry)
  local old_id::Int = LookupTree.index(oldEntry)
  local ty::Int
  #=
      Overwrite the existing entry if it's an import. This happens when a
      class both imports and inherits the same name.
  =#
  if LookupTree.isImport(oldEntry)
    entry = newEntry
    return entry
  end
  dups = P_Pointer.access(duplicates)
  opt_dup_entry = DuplicateTree.getOpt(dups, name)
  if isNone(opt_dup_entry)
    if new_id < old_id
      entry = newEntry
      dup_entry = DuplicateTree.newDuplicate(newEntry, oldEntry)
    else
      entry = oldEntry
      dup_entry = DuplicateTree.newDuplicate(oldEntry, newEntry)
    end
    dups = DuplicateTree.add(dups, name, dup_entry)
    P_Pointer.update(duplicates, dups)
  else
    @match SOME(dup_entry) = opt_dup_entry
    ty = dup_entry.ty
    if !DuplicateTree.idExistsInEntry(newEntry, dup_entry)
      if ty == DuplicateTree.EntryType.REDECLARE
        entry = newEntry
        local dup_entryChildren = [DuplicateTree.newEntry(newEntry) ; dup_entry.children]
        dup_entry = DuplicateTree.DUPLICATE_TREE_ENTRY(dup_entry.entry, dup_entry.node, dup_entryChildren, dup_entry.ty)
      else
        if new_id < old_id
          entry = newEntry
          dup_entry = DuplicateTree.DUPLICATE_TREE_ENTRY(
            newEntry,
            NONE(),
            [DuplicateTree.newEntry(oldEntry) ; dup_entry.children],
            dup_entry.ty,
          )
        else
          entry = oldEntry
          local dup_entryChildren = [DuplicateTree.newEntry(newEntry) ; dup_entry.children]
          dup_entry = DuplicateTree.DUPLICATE_TREE_ENTRY(dup_entry.entry, dup_entry.node, dup_entryChildren, dup_entry.ty)
        end
      end
      dups = DuplicateTree.update(dups, name, dup_entry)
      P_Pointer.update(duplicates, dups)
    elseif !DuplicateTree.idExistsInEntry(oldEntry, dup_entry)
      if ty == DuplicateTree.EntryType.REDECLARE || new_id < old_id
        entry = newEntry
        local dup_entryChildren = [DuplicateTree.newEntry(oldEntry) ; dup_entry.children]
        dup_entry = DuplicateTree.DUPLICATE_TREE_ENTRY(dup_entry.entry, dup_entry.node, dup_entryChildren, dup_entry.ty)
      else
        entry = newEntry
        dup_entry = DuplicateTree.DUPLICATE_TREE_ENTRY(
          newEntry,
          NONE(),
          [DuplicateTree.newEntry(oldEntry) ; dup_entry.children],
          dup_entry.ty,
        )
      end
      dups = DuplicateTree.update(dups, name, dup_entry)
      P_Pointer.update(duplicates, dups)
    else
      entry = if new_id < old_id
        newEntry
      else
        oldEntry
      end
    end
  end
  return entry
end

function addInheritedElement(
  name::String,
  entry::LookupTree.Entry,
  classOffset::Int,
  componentOffset::Int,
  conflictFunc::LookupTree.ConflictFunc,
  tree::LookupTree.Tree,
  )

    @match entry begin
      LookupTree.CLASS(__) => begin
        #@assign entry.index = entry.index + classOffset
        local newEntry = LookupTree.CLASS(entry.index + classOffset)
        tree = LookupTree.add(tree, name, newEntry, conflictFunc)
        ()
      end

      LookupTree.COMPONENT(__) => begin
        #@assign entry.index = entry.index + componentOffset
        local newEntry = LookupTree.COMPONENT(entry.index + componentOffset)
        tree = LookupTree.add(tree, name, newEntry, conflictFunc)
        ()
      end

      _ => begin
        ()
      end
    end
  #=  Ignore IMPORT, since imports aren't inherited. =#
  return tree
end

function expandExtends(
  extendsNode::InstNode,
  tree::LookupTree.Tree,
  classOffset::Int,
  componentOffset::Int,
  duplicates::Pointer{<:DuplicateTree.Tree},
)::LookupTree.Tree #= Duplicate elements info. =#

  local cls_tree::ClassTree
  local ext_tree::LookupTree.Tree
  local ext_dups::DuplicateTree.Tree
  local dups::DuplicateTree.Tree
  local conf_func::LookupTree.ConflictFunc

  #=  The extends node's lookup tree should at this point contain all the
  =#
  #=  entries we need, so we don't need to recursively traverse its
  =#
  #=  elements. Instead we can just take each entry in the extends node's
  =#
  #=  lookup tree, add the class or component index as an offset, and then
  =#
  #=  add the entry to the given lookup tree.
  =#
  cls_tree = classTree(getClass(extendsNode))
  (ext_tree, ext_dups) = begin
    @match cls_tree begin
      CLASS_TREE_EXPANDED_TREE(__) => begin
        (cls_tree.tree, cls_tree.duplicates)
      end

      CLASS_TREE_FLAT_TREE(__) => begin
        (cls_tree.tree, cls_tree.duplicates)
      end

      _ => begin
        return (tree, DuplicateTree.new())
      end
    end
  end
  #=  Copy entries from the extends node's duplicate tree if there are any.
  =#
  if !DuplicateTree.isEmpty(ext_dups)
    dups = DuplicateTree.map(
      ext_dups,
      (name, entry) ->
        offsetDuplicates(name, entry, classOffset, componentOffset),
    )
    dups = DuplicateTree.join(P_Pointer.access(duplicates), dups, joinDuplicates)
    P_Pointer.update(duplicates, dups)
  end
  #=  Offset the entries so they're correct for the inheriting class tree.
  =#
  #=  Join the two duplicate trees together.
  =#
  conf_func =
    (newEntry, oldEntry, name) ->
      addInheritedElementConflict(newEntry, oldEntry, name, duplicates, ext_dups)
  #=  Copy entries from the extends node's lookup tree.
  =#
  foldFunc = (nameX, entryX, treeX) -> addInheritedElement(
      nameX,
      entryX,
      classOffset,
      componentOffset,
      conf_func,
      treeX,
    )
  tree = LookupTree.fold(
    ext_tree,
    foldFunc,
    tree,
  )
  return tree #= The lookup tree to add names to =#
end

function countInheritedElements(
  extendsNode::InstNode,
  classCount::Int = 0,
  componentCount::Int = 0,
)::Tuple{Int, Int}

  local clss::Vector{InstNode}
  local comps::Vector{InstNode}
  local exts::Vector{InstNode}

  () = begin
    @match classTree(getClass(extendsNode)) begin
      CLASS_TREE_EXPANDED_TREE(classes = clss, components = comps, exts = exts) => begin
        #=  The component array contains placeholders for extends, which need to be
        =#
        #=  subtracted to get the proper component count.
        =#
        componentCount = componentCount + arrayLength(comps) - arrayLength(exts)
        classCount = classCount + arrayLength(clss)
        for ext in exts
          (classCount, componentCount) =
            countInheritedElements(ext, classCount, componentCount)
        end
        ()
      end

      CLASS_TREE_FLAT_TREE(classes = clss, components = comps) => begin
        componentCount = componentCount + arrayLength(comps)
        classCount = classCount + arrayLength(clss)
        ()
      end

      _ => begin
        ()
      end
    end
  end
  return (classCount, componentCount)
end

"""
  Counts the number of classes, components and extends clauses in a list of
  SCode elements.
"""
function countElements(elements::List{<:SCode.Element})::Tuple{Int, Int, Int}
  local extCount::Int = 0
  local compCount::Int = 0
  local classCount::Int = 0

  for e in elements
    () = begin
      @match e begin
        SCode.CLASS(__) => begin
          classCount = classCount + 1
          ()
        end

        SCode.COMPONENT(__) => begin
          compCount = compCount + 1
          ()
        end

        SCode.EXTENDS(__) => begin
          extCount = extCount + 1
          ()
        end

        _ => begin
          ()
        end
      end
    end
  end
  return (classCount, compCount, extCount)
end

function resolveImport(index::Int, tree::ClassTree)::InstNode
  local element::InstNode
  local imports::Vector{Import}
  local imp::Import
  local changed::Bool
  imports = tree.imports
  #=  Imports are resolved on demand, i.e. here. =#
  local isChangedImportRef = Ref{Bool}(false)
  local importTyRef = Ref{Import}(EMPTY_IMPORT())
  element = resolve(imports[index], isChangedImportRef, importTyRef)
  changed = isChangedImportRef.x
  imp = importTyRef.x
  #=  Save the import if it wasn't already resolved. =#
  if changed
    imports[index] = imp
  end
  return element
end

function resolveComponent(index::Int, tree::ClassTree)::InstNode
  local element::InstNode
  element = begin
    @match tree begin
      CLASS_TREE_INSTANTIATED_TREE(__) => begin
        P_Pointer.access(arrayGet(tree.components, index))
      end

      CLASS_TREE_FLAT_TREE(__) => begin
        tree.components[index]
      end
      CLASS_TREE_EXPANDED_TREE(__) => begin
        tree.components[index]
      end
    end
  end
  return element
end


resolveClass(index::Int, tree::CLASS_TREE_INSTANTIATED_TREE) = P_Pointer.access(tree.classes[index])
resolveClass(index::Int, tree::ClassTree) = tree.classes[index]

function resolveDuplicateEntriesPtr(
  entry::DuplicateTree.Entry,
  tree::ClassTree,
  elements::List{<:Pointer{<:InstNode}} = nil,
)::List{Pointer{InstNode}}

  local node_ptr::Pointer{InstNode}

  node_ptr = resolveEntryPtr(entry.entry, tree)
  elements = Cons{Pointer{InstNode}}(node_ptr, elements)
  for child in entry.children
    elements = resolveDuplicateEntriesPtr(child, tree, elements)
  end
  return elements
end

function resolveEntryPtr(entry::LookupTree.Entry, tree::ClassTree)::Pointer{InstNode}
  local element::Pointer{InstNode}

  local elems::Vector{Pointer{InstNode}}

  element = begin
    @match entry begin
      LookupTree.CLASS(__) => begin
        @match CLASS_TREE_INSTANTIATED_TREE(classes = elems) = tree
        arrayGet(elems, entry.index)
      end

      LookupTree.COMPONENT(__) => begin
        @match CLASS_TREE_INSTANTIATED_TREE(components = elems) = tree
        arrayGet(elems, entry.index)
      end
    end
  end
  return element
end

struct ENTRY_INFO{T0 <: InstNode, T1 <: Bool}
  node::T0
  isImport::T1
end

"""Resolves a lookup tree entry to an inst node."""
function resolveEntry(entry::LookupTree.Entry, tree::ClassTree)
  local isImported::Bool = false
  local element::InstNode
  element =  @match entry begin
    LookupTree.CLASS(__) => begin
      resolveClass(entry.index, tree)
    end
    LookupTree.COMPONENT(__) => begin
      resolveComponent(entry.index, tree)
    end
    LookupTree.IMPORT(__) => begin
      isImported = true
      resolveImport(entry.index, tree)
    end
    _ #= Else we did not find anything...=# => begin
      isImported = false
      EMPTY_NODE()
    end
  end
  return ENTRY_INFO(element, isImported)
end

function addDuplicateConflict(
  newEntry::DuplicateTree.Entry,
  oldEntry::DuplicateTree.Entry,
  name::String,
)::DuplicateTree.Entry
  local entry::DuplicateTree.Entry

  #=  The previously kept entry should be either kept or dup, since it's the
  =#
  #=  one found during lookup. So we can ignore it here.
  =#
  entry = DuplicateTree.DUPLICATE_TREE_ENTRY(
    newEntry.entry,
    NONE(),
    [newEntry.children[1] ; oldEntry.children],
    DuplicateTree.EntryType.DUPLICATE,
  )
  return entry
end

"""Adds an entry to the duplicates tree."""
function addDuplicate(
  name::String,
  duplicateEntry::LookupTree.Entry,
  keptEntry::LookupTree.Entry,
  duplicates::Pointer{<:DuplicateTree.Tree},
)::Pointer{DuplicateTree.Tree}

  P_Pointer.update(
    duplicates,
    DuplicateTree.add(
      P_Pointer.access(duplicates),
      name,
      DuplicateTree.newDuplicate(keptEntry, duplicateEntry),
      addDuplicateConflict,
    ),
  )
  return duplicates
end

function addImportConflict(
  newEntry::LookupTree.Entry,
  oldEntry::LookupTree.Entry,
  name::String,
  imports::Vector{<:Import},
)::LookupTree.Entry
  local entry::LookupTree.Entry

  entry = begin
    local imp1::Import
    local imp2::Import
    @match (newEntry, oldEntry) begin
      (LookupTree.IMPORT(__), LookupTree.IMPORT(__)) => begin
        imp1 = imports[newEntry.index]
        imp2 = imports[oldEntry.index]
        #=  Check what kind of imports we have. In case of an error we replace the import
        =#
        #=  with the error information, and only print the error if the name is looked up.
        =#
        entry = begin
          @match (imp1, imp2) begin
            (Import.UNRESOLVED_IMPORT(__), Import.UNRESOLVED_IMPORT(__)) => begin
              #=  Two qualified imports of the same name gives an error.
              =#
              arrayUpdate(
                imports,
                oldEntry.index,
                Import.CONFLICTING_IMPORT(imp1, imp2),
              )
              oldEntry
            end

            (Import.RESOLVED_IMPORT(__), Import.RESOLVED_IMPORT(__)) => begin
              #=  A name imported from several unqualified imports gives an error.
              =#
              arrayUpdate(
                imports,
                oldEntry.index,
                Import.CONFLICTING_IMPORT(imp1, imp2),
              )
              oldEntry
            end

            (Import.UNRESOLVED_IMPORT(__), _) => begin
              newEntry
            end

            _ => begin
              oldEntry
            end
          end
        end
        #=  Qualified import overwrites an unqualified.
        =#
        #=  oldEntry is either qualified or a delayed error, keep it.
        =#
        entry
      end

      _ => begin
        oldEntry
      end
    end
  end
  #=  Other elements overwrite an imported name.
  =#
  return entry
end

function addImport(
  imp::Import,
  index::Int,
  tree::LookupTree.Tree,
  imports::Vector{<:Import},
)::LookupTree.Tree

  tree = LookupTree.add(
    tree,
    name(imp),
    LookupTree.IMPORT(index),
    (newE, oldE, n) -> addImportConflict(newE, oldE, n, imports),
  )

  return tree
end

"""Conflict handler for fromEnumeration."""
function addEnumConflict(
  newEntry::LookupTree.Entry,
  oldEntry::LookupTree.Entry,
  nameStr::String,
  literal::InstNode,
)::LookupTree.Entry
  local entry::LookupTree.Entry
  Error.addSourceMessage(
    Error.DOUBLE_DECLARATION_OF_ELEMENTS,
    list(name(literal)),
    info(literal),
  )
  fail()
  return entry
end

"""
  Helper function to addLocalElementConflict. Looks up an entry in a
  partial class tree.
"""
function findLocalConflictElement(entry::LookupTree.Entry, classTree::ClassTree)::InstNode
  local node::InstNode

  node = begin
    local comps::Vector{InstNode}
    local exts::Vector{InstNode}
    local i::Int
    #=  For classes we can just use the normal resolveClass function.
    =#
    @match entry begin
      LookupTree.CLASS(__) => begin
        resolveClass(entry.index, classTree)
      end

      LookupTree.COMPONENT(__) => begin
        #=  Components are more complicated, since they are given indices based
        =#
        #=  on where they will end up once inherited elements have been inserted
        =#
        #=  into the component array. We therefore just count components until we
        =#
        #=  get to the given index. Not very efficient, but it doesn't really
        =#
        #=  matter at this point since we're just going to show an error and fail.
        =#
        i = 0
        @match CLASS_TREE_PARTIAL_TREE(components = comps, exts = exts) = classTree
        for c in comps
          i = begin
            @match c begin
              COMPONENT_NODE(__) => begin
                i + 1
              end

              REF_NODE(__) => begin
                (_, i) = countInheritedElements(exts[c.index], 0, i)
                i
              end
            end
          end
          if i == entry.index
            node = c
            break
          end
        end
        #=  Make extra sure that we actually found the component.
        =#
        Error.assertion(
          i == entry.index,
          getInstanceName() + " got invalid entry index",
          sourceInfo(),
        )
        node
      end

      _ => begin
        Error.assertion(false, getInstanceName() + " got invalid entry", sourceInfo())
        fail()
      end
    end
  end
  return node
end

function addLocalElementConflict(
  newEntry::LookupTree.Entry,
  oldEntry::LookupTree.Entry,
  name::String,
  classTree::ClassTree,
)::LookupTree.Entry
  local entry::LookupTree.Entry
  local n1::InstNode
  local n2::InstNode
  entry = begin
    @match (newEntry, oldEntry) begin
      (_, LookupTree.IMPORT(__)) => begin
        newEntry
      end
      _ => begin
        #=  Local elements overwrite imported elements with same name. =#
        #=  Otherwise we have two local elements with the same name, which is an error. =#
        n1 = findLocalConflictElement(newEntry, classTree)
        n2 = findLocalConflictElement(oldEntry, classTree)
        Error.addMultiSourceMessage(
          Error.DOUBLE_DECLARATION_OF_ELEMENTS,
          list(name),
          list(InstNode_info(n2), InstNode_info(n1)),
        )
        fail()
      end
    end
  end
  return entry
end

function addLocalElement(
  name::String,
  entry::LookupTree.Entry,
  classTree::ClassTree,
  tree::LookupTree.Tree,
)::LookupTree.Tree
  tree = LookupTree.add(
    tree,
    name,
    entry,
    (newEntryArg, oldEntryArg ,nameArg) -> addLocalElementConflict(newEntryArg,
                                                                   oldEntryArg,
                                                                   nameArg,
                                                                   classTree)
  )
  return tree
end

function lookupTree(ctree::ClassTree)::LookupTree.Tree
  local ltree::LookupTree.Tree
  ltree = ctree.tree
  return ltree
end

function getDuplicates(tree::ClassTree)::DuplicateTree.Tree
  return tree.duplicates
end

function instExtendsComps(
  extNode::InstNode,
  comps::Vector{<:Pointer{<:InstNode}},
  index::Int,
)::Int #= The first free index in comps =#
  local ext_comps_ptrs::Vector{Pointer{InstNode}}
  local ext_comps::Vector{InstNode}
  local comp_count::Int
  local ext_comp::InstNode
  () = begin
    @match classTree(getClass(extNode)) begin
      CLASS_TREE_INSTANTIATED_TREE(components = ext_comps_ptrs) => begin
        comp_count = arrayLength(ext_comps_ptrs)
        if comp_count > 0
          ArrayUtil.copyRange(ext_comps_ptrs, comps, 1, comp_count, index)
          index = index + comp_count
        end
        ()
      end
      CLASS_TREE_FLAT_TREE(components = ext_comps) => begin
        comp_count = arrayLength(ext_comps)
        if comp_count > 0
          for i = index:(index + comp_count - 1)
            arrayUpdate(comps, i, P_Pointer.create(ext_comps[i], InstNode))
          end
          index = index + comp_count
        end
        ()
      end
      _ => begin
        ()
      end
    end
  end
  return index #= The first free index in comps =#
end
