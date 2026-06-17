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

function printNodeStr(inNode::Tree)::String
  local outString::String
  outString = begin
    @match inNode begin
      NODE(__) => begin
        keyStr(inNode.key)
      end

      LEAF(__) => begin
        keyStr(inNode.key)
      end
    end
  end
  return outString
end

"""Return an empty tree"""
function new()::Tree
  local outTree::Tree = EMPTY()
  return outTree
end

"""Inserts a new node in the tree."""
function add(inTree::Tree, inKey::Key)::Tree
  local tree::Tree = inTree

  tree = begin
    local key::Key
    local key_comp::Int
    local outTree::Tree
    #=  Empty tree.
    =#
    @match tree begin
      EMPTY(__) => begin
        LEAF(inKey)
      end

      NODE(key = key) => begin
        key_comp = keyCompare(inKey, key)
        if key_comp == (-1)
          @assign tree.left = add(tree.left, inKey)
        elseif key_comp == 1
          @assign tree.right = add(tree.right, inKey)
        end
        #=  Replace left branch.
        =#
        #=  Replace right branch.
        =#
        if key_comp == 0
          tree
        else
          balance(tree)
        end
      end

      LEAF(key = key) => begin
        key_comp = keyCompare(inKey, key)
        if key_comp == (-1)
          outTree = NODE(tree.key, 2, LEAF(inKey), EMPTY())
        elseif key_comp == 1
          outTree = NODE(tree.key, 2, EMPTY(), LEAF(inKey))
        else
          outTree = tree
        end
        #=  Replace left branch.
        =#
        #=  Replace right branch.
        =#
        outTree
      end
    end
  end
  #=  No need to balance addition in a leaf
  =#
  return tree
end

"""Adds a list of key-value pairs to the tree."""
function addList(tree::Tree, inValues::List{<:Key})::Tree

  for key in inValues
    @assign tree = add(tree, key)
  end
  return tree
end

"""Gets a value from the tree given a key."""
function hasKey(inTree::Tree, inKey::Key)::Bool
  local comp::Bool = false

  local key::Key
  local key_comp::Int
  local tree::Tree

  @assign key = begin
    @match inTree begin
      NODE(__) => begin
        inTree.key
      end

      LEAF(__) => begin
        inTree.key
      end

      EMPTY(__) => begin
        return
        fail()
      end
    end
  end
  @assign key_comp = keyCompare(inKey, key)
  @assign comp = begin
    @match (key_comp, inTree) begin
      (0, _) => begin
        true
      end

      (1, NODE(right = tree)) => begin
        hasKey(tree, inKey)
      end

      (-1, NODE(left = tree)) => begin
        hasKey(tree, inKey)
      end

      _ => begin
        false
      end
    end
  end
  return comp
end

function isEmpty(tree::Tree)::Bool
  local isEmpty::Bool
  @assign isEmpty = begin
    @match tree begin
      EMPTY(__) => begin
        true
      end
      _ => begin
        false
      end
    end
  end
  return isEmpty
end

"""Converts the tree to a flat list of keys (in order)."""
function listKeys(inTree::Tree, lst::List{<:Key} = nil)::List{Key}

  @assign lst = begin
    @match inTree begin
      LEAF(__) => begin
        _cons(inTree.key, lst)
      end

      NODE(__) => begin
        lst = listKeys(inTree.right, lst)
        lst = _cons(inTree.key, lst)
        lst = listKeys(inTree.left, lst)
        lst
      end

      _ => begin
        lst
      end
    end
  end
  return lst
end

"""Converts the tree to a flat list of keys (in order)."""
function listKeysReverse(inTree::Tree, lst::List{<:Key} = nil)::List{Key}

  @assign lst = begin
    @match inTree begin
      LEAF(__) => begin
        _cons(inTree.key, lst)
      end

      NODE(__) => begin
        lst = listKeysReverse(inTree.left, lst)
        lst = _cons(inTree.key, lst)
        lst = listKeysReverse(inTree.right, lst)
        lst
      end

      _ => begin
        lst
      end
    end
  end
  return lst
end

"""Joins two trees by adding the second one to the first."""
function join(tree::Tree, treeToJoin::Tree)::Tree
  tree = begin
    @match treeToJoin begin
      EMPTY(__) => begin
        tree
      end

      NODE(__) => begin
        tree = add(tree, treeToJoin.key)
        tree = join(tree, treeToJoin.left)
        tree = join(tree, treeToJoin.right)
        tree
      end

      LEAF(__) => begin
        add(tree, treeToJoin.key)
      end
    end
  end
  return tree
end

"""
  Prints the tree to a string using UTF-8 box-drawing characters to construct a
  graphical view of the tree.
"""
function printTreeStr(inTree::Tree)::String
  local outString::String
  local left::Tree
  local right::Tree
  outString = begin
    @match inTree begin
      EMPTY(__) => begin
        "EMPTY()"
      end
      LEAF(__) => begin
        printNodeStr(inTree)
      end
      NODE(left = left, right = right) => begin
        printTreeStr2(left, true, "") +
        printNodeStr(inTree) +
        "
        " +
        printTreeStr2(right, false, "")
      end
    end
  end
  return outString
end

function setTreeLeftRight(orig::Tree, left::Tree, right::Tree)::Tree
  setTreeLeftRight(orig; left = left, right = right)
end

function setTreeLeftRight(orig::Tree; left::Tree = EMPTY(), right::Tree = EMPTY())::Tree
  local res::Tree
  res = begin
    @match (orig, left, right) begin
      (NODE(__), EMPTY(__), EMPTY(__)) => begin
        LEAF(orig.key, orig.value)
      end

      (LEAF(__), EMPTY(__), EMPTY(__)) => begin
        orig
      end

      (NODE(__), _, _) => begin
        if referenceEqOrEmpty(orig.left, left) && referenceEqOrEmpty(orig.right, right)
          orig
        else
          NODE(orig.key, orig.value, max(height(left), height(right)) + 1, left, right)
        end
      end

      (LEAF(__), _, _) => begin
        NODE(orig.key, orig.value, max(height(left), height(right)) + 1, left, right)
      end
    end
  end
  return res
end

"""
  Takes two sets and returns the intersection as well as the remainder
  of both sets after removing the duplicates in both sets.
"""
function intersection(tree1::Tree, tree2::Tree)::Tree
  local intersect::Tree = Tree.EMPTY()
  local rest1::Tree = Tree.EMPTY()
  local rest2::Tree = Tree.EMPTY()

  local keylist1::List{Key}
  local keylist2::List{Key}
  local k1::Key
  local k2::Key
  local key_comp::Int

  if isEmpty(tree1)
    @assign rest2 = tree2
    return intersect, rest1, rest2
  end
  if isEmpty(tree2)
    @assign rest1 = tree1
    return intersect, rest1, rest2
  end
  #=  we operate on sorted lists from the trees!
  =#
  @match _cons(k1, keylist1) = listKeys(tree1)
  @match _cons(k2, keylist2) = listKeys(tree2)
  while true
    key_comp = keyCompare(k1, k2)
    if key_comp > 0
      if isPresent(rest2)
        rest2 = add(rest2, k2)
      end
      if listEmpty(keylist2)
        break
      end
      @match _cons(k2, keylist2) = keylist2
    elseif key_comp < 0
      if isPresent(rest1)
        rest1 = add(rest1, k1)
      end
      if listEmpty(keylist1)
        break
      end
      @match _cons(k1, keylist1) = keylist1
    else
      intersect = add(intersect, k1)
      if listEmpty(keylist1) || listEmpty(keylist2)
        break
      end
      @match _cons(k1, keylist1) = keylist1
      @match _cons(k2, keylist2) = keylist2
    end
  end
  #=  equal keys: advance both lists
  =#
  if isPresent(rest1) && !listEmpty(keylist1)
    for key in keylist1
      rest1 = add(rest1, key)
    end
  end
  if isPresent(rest2) && !listEmpty(keylist2)
    for key in keylist2
      rest2 = add(rest2, key)
    end
  end
  return intersect, rest1, rest2
end

function referenceEqOrEmpty(t1::Tree, t2::Tree)::Bool
  local b::Bool

  @assign b = begin
    @match (t1, t2) begin
      (EMPTY(__), EMPTY(__)) => begin
        true
      end

      _ => begin
        referenceEq(t1, t2)
      end
    end
  end
  return b
end

"""Balances a Tree"""
function balance(inTree::Tree)
  local outTree::Tree = inTree
  outTree = begin
    local lh::Int
    local rh::Int
    local diff::Int
    local child::Tree
    local balanced_tree::Tree
    @match outTree begin
      LEAF(__) => begin
        inTree
      end
      NODE(__) => begin
        lh = height(outTree.left)
        rh = height(outTree.right)
        diff = lh - rh
        if diff < (-1)
          balanced_tree = if calculateBalance(outTree.right) > 0
            rotateLeft(setTreeLeftRight(
              outTree,
              left = outTree.left,
              right = rotateRight(outTree.right),
            ))
          else
            rotateLeft(outTree)
          end
        elseif diff > 1
          balanced_tree = if calculateBalance(outTree.left) < 0
            rotateRight(setTreeLeftRight(
              outTree,
              left = rotateLeft(outTree.left),
              right = outTree.right,
            ))
          else
            rotateRight(outTree)
          end
        elseif outTree.height != max(lh, rh) + 1
          @assign outTree.height = max(lh, rh) + 1
          balanced_tree = outTree
        else
          balanced_tree = outTree
        end
        balanced_tree
      end
    end
  end
  return outTree
end

function height(inNode::Tree)::Int
  local outHeight::Int
  @assign outHeight = begin
    @match inNode begin
      NODE(__) => begin
        inNode.height
      end
      LEAF(__) => begin
        1
      end
      _ => begin
        0
      end
    end
  end
  return outHeight
end

function calculateBalance(inNode::Tree)::Int
  local outBalance::Int

  outBalance = begin
    @match inNode begin
      NODE(__) => begin
        height(inNode.left) - height(inNode.right)
      end

      LEAF(__) => begin
        0
      end

      _ => begin
        0
      end
    end
  end
  return outBalance
end

"""Performs an AVL left rotation on the given tree."""
function rotateLeft(inNode::Tree)::Tree
  local outNode::Tree = inNode

  @assign outNode = begin
    local node::Tree
    local child::Tree
    @match outNode begin
      NODE(right = child && NODE(__)) => begin
        node = setTreeLeftRight(outNode, outNode.left, child.left)
        setTreeLeftRight(child, node, child.right)
      end

      NODE(right = child && LEAF(__)) => begin
        node = setTreeLeftRight(outNode, outNode.left, EMPTY())
        setTreeLeftRight(child, node, EMPTY())
      end

      _ => begin
        inNode
      end
    end
  end
  return outNode
end

"""Performs an AVL right rotation on the given tree."""
function rotateRight(inNode::Tree)::Tree
  local outNode::Tree = inNode

  @assign outNode = begin
    local node::Tree
    local child::Tree
    @match outNode begin
      NODE(left = child && NODE(__)) => begin
        node = setTreeLeftRight(outNode, left = child.right, right = outNode.right)
        setTreeLeftRight(child, right = node, left = child.left)
      end

      NODE(left = child && LEAF(__)) => begin
        node = setTreeLeftRight(outNode, left = EMPTY(), right = outNode.right)
        setTreeLeftRight(child, right = node, left = EMPTY())
      end
      _ => begin
        inNode
      end
    end
  end
  return outNode
end

"""Helper function to printTreeStr."""
function printTreeStr2(inTree::Tree, isLeft::Bool, inIndent::String)::String
  local outString::String
  local val_node::Option{ValueNode}
  local left::Option{Tree}
  local right::Option{Tree}
  local left_str::String
  local right_str::String
  outString = begin
    @match inTree begin
      NODE(__) => begin
        printTreeStr2(inTree.left, true, inIndent + (
          if isLeft
            "     "
          else
            " │   "
          end
        )) +
        inIndent +
        (
          if isLeft
            " ┌"
          else
            " └"
          end
        ) +
        "────" +
        printNodeStr(inTree) +
        "
        " +
        printTreeStr2(inTree.right, false, inIndent + (
          if isLeft
            " │   "
          else
            "     "
          end
        ))
      end

      _ => begin
        ""
      end
    end
  end
  return outString
end
