# tree.rb - This file is part of the RubyTree package.
#
# = tree.rb - Generic implementation of an N-ary tree data structure.
#
# Provides a generic tree data structure with ability to
# store keyed node elements in the tree.  This implementation
# mixes in the Enumerable module.
#
# Author:: Anupam Sengupta (anupamsg@gmail.com)
#

# Copyright (c) 2006-2022 Anupam Sengupta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# - Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# - Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# - Neither the name of the organization nor the names of its contributors may
#   be used to endorse or promote products derived from this software without
#   specific prior written permission.
#
#   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# frozen_string_literal: true

require 'tree/tree_deps'

# This module provides a *TreeNode* class whose instances are the primary
# objects for representing nodes in the tree.
#
# This module also acts as the namespace for all classes in the *RubyTree*
# package.
module Tree
  # == TreeNode Class Description
  #
  # This class models the nodes for an *N-ary* tree data structure. The
  # nodes are *named*, and have a place-holder for the node data (i.e.,
  # _content_ of the node). The node names are required to be *unique*
  # amongst the sibling/peer nodes. Note that the name is implicitly
  # used as an _ID_ within the data structure).
  #
  # The node's _content_ is *not* required to be unique across
  # different nodes in the tree, and can be +nil+ as well.
  #
  # The class provides various methods to navigate the tree, traverse
  # the structure, modify contents of the node, change position of the
  # node in the tree, and to make structural changes to the tree.
  #
  # A node can have any number of *child* nodes attached to it and
  # hence can be used to create N-ary trees.  Access to the child
  # nodes can be made in order (with the conventional left to right
  # access), or randomly.
  #
  # The node also provides direct access to its *parent* node as well
  # as other superior parents in the path to root of the tree.  In
  # addition, a node can also access its *sibling* nodes, if present.
  #
  # Note that while this implementation does not _explicitly_ support
  # directed graphs, the class itself makes no restrictions on
  # associating a node's *content* with multiple nodes in the tree.
  # However, having duplicate nodes within the structure is likely to
  # cause unpredictable behavior.
  #
  # == Example
  #
  # {include:file:examples/example_basic.rb}
  #
  # @author Anupam Sengupta
  # noinspection RubyTooManyMethodsInspection
  class TreeNode
    include Enumerable
    include Comparable
    include Tree::Utils::TreeMetricsHandler
    include Tree::Utils::TreePathHandler
    include Tree::Utils::JSONConverter
    include Tree::Utils::TreeMergeHandler
    include Tree::Utils::HashConverter

    # @!group Core Attributes

    # @!attribute [r] name
    #
    # Name of this node.  Expected to be unique within the tree.
    #
    # Note that the name attribute really functions as an *ID* within
    # the tree structure, and hence the uniqueness constraint is
    # required.
    #
    # This may be changed in the future, but for now it is best to
    # retain unique names within the tree structure, and use the
    # +content+ attribute for any non-unique node requirements.
    #
    # If you want to change the name, you probably want to call +rename+
    # instead. Note that +name=+ is a protected method.
    #
    # @see content
    # @see rename
    attr_accessor :name

    # @!attribute [rw] content
    # Content of this node.  Can be +nil+.  Note that there is no
    # uniqueness constraint related to this attribute.
    #
    # @see name
    attr_accessor :content

    # @!attribute [r] parent
    # Parent of this node.  Will be +nil+ for a root node.
    attr_reader   :parent

    # @!attribute [r] root
    # Root node for the (sub)tree to which this node belongs.
    # A root node's root is itself.
    #
    # @return [Tree::TreeNode] Root of the (sub)tree.
    def root
      root = self
      root = root.parent until root.root?
      root
    end

    # @!attribute [r] root?
    # Returns +true+ if this is a root node.  Note that
    # orphaned children will also be reported as root nodes.
    #
    # @return [Boolean] +true+ if this is a root node.
    def root?
      @parent.nil?
    end

    alias is_root? root? # @todo: Aliased for eventual replacement

    # @!attribute [r] content?
    # +true+ if this node has content.
    #
    # @return [Boolean] +true+ if the node has content.
    def content?
      @content != nil
    end

    alias has_content? content? # @todo: Aliased for eventual replacement

    # @!attribute [r] leaf?
    # +true+ if this node is a _leaf_ - i.e., one without
    # any children.
    #
    # @return [Boolean] +true+ if this is a leaf node.
    #
    # @see #children?
    def leaf?
      !children?
    end

    alias is_leaf? leaf? # @todo: Aliased for eventual replacement

    # @!attribute [r] parentage
    # An array of ancestors of this node in reversed order
    # (the first element is the immediate parent of this node).
    #
    # Returns +nil+ if this is a root node.
    #
    # @return [Array<Tree::TreeNode>] An array of ancestors of this node
    # @return [nil] if this is a root node.
    def parentage
      return nil if root?

      parentage_array = []
      prev_parent = parent
      while prev_parent
        parentage_array << prev_parent
        prev_parent = prev_parent.parent
      end
      parentage_array
    end

    # @!attribute [r] children?
    # +true+ if the this node has any child node.
    #
    # @return [Boolean] +true+ if child nodes exist.
    #
    # @see #leaf?
    def children?
      !@children.empty?
    end

    alias has_children? children? # @todo: Aliased for eventual replacement

    # @!group Node Creation

    # Creates a new node with a name and optional content.
    # The node name is expected to be unique within the tree.
    #
    # The content can be of any type, and defaults to +nil+.
    #
    # @param [Object] name Name of the node. Conventional usage is to pass a
    #   String (Integer names may cause *surprises*)
    #
    # @param [Object] content Content of the node.
    #
    # @raise [ArgumentError] Raised if the node name is empty.
    #
    # @note If the name is an +Integer+, then the semantics of {#[]} access
    #   method can be surprising, as an +Integer+ parameter to that method
    #   normally acts as an index to the children array, and follows the
    #   _zero-based_ indexing convention.
    #
    # @see #[]
    def initialize(name, content = nil)
      raise ArgumentError, 'Node name HAS to be provided!' if name.nil?

      name = name.to_s if name.is_a?(Integer)
      @name = name
      @content = content

      set_as_root!
      @children_hash = {}
      @children = []
    end

    # Returns a copy of this node, with its parent and children links removed.
    # The original node remains attached to its tree.
    #
    # @return [Tree::TreeNode] A copy of this node.
    def detached_copy
      cloned_content =
        begin
          @content&.clone
        rescue TypeError
          @content
        end
      self.class.new(@name, cloned_content)
    end

    # Returns a copy of entire (sub-)tree from this node.
    #
    # @author Vincenzo Farruggia
    # @since 0.8.0
    #
    # @return [Tree::TreeNode] A copy of (sub-)tree from this node.
    def detached_subtree_copy
      new_node = detached_copy
      children { |child| new_node << child.detached_subtree_copy }
      new_node
    end

    # Alias for {Tree::TreeNode#detached_subtree_copy}
    #
    # @see Tree::TreeNode#detached_subtree_copy
    alias dup detached_subtree_copy

    # Returns a {marshal-dump}[http://ruby-doc.org/core-1.8.7/Marshal.html]
    # representation of the (sub)tree rooted at this node.
    #
    def marshal_dump
      collect(&:create_dump_rep)
    end

    # Creates a dump representation of this node and returns the same as
    # a hash.
    def create_dump_rep # :nodoc:
      { name: @name,
        parent: (root? ? nil : @parent.name),
        content: Marshal.dump(@content) }
    end

    protected :create_dump_rep

    # Loads a marshaled dump of a tree and returns the root node of the
    # reconstructed tree. See the
    # {Marshal}[http://ruby-doc.org/core-1.8.7/Marshal.html] class for
    # additional details.
    #
    # NOTE: This is a potentially *unsafe* method with similar concerns as with
    # the Marshal#load method, and should *not* be used with untrusted user
    # provided data.
    #
    # @todo This method probably should be a class method. It currently clobbers
    #       self and makes itself the root.
    #
    def marshal_load(dumped_tree_array)
      nodes = {}
      dumped_tree_array.each do |node_hash|
        name        = node_hash[:name]
        parent_name = node_hash[:parent]
        content     = Marshal.load(node_hash[:content])

        if parent_name
          nodes[name] = current_node = self.class.new(name, content)
          nodes[parent_name].add current_node
        else
          # This is the root node, hence initialize self.
          initialize(name, content)

          nodes[name] = self # Add self to the list of nodes
        end
      end
    end

    # @!endgroup

    # Returns string representation of this node.
    # This method is primarily meant for debugging purposes.
    #
    # @return [String] A string representation of the node.
    def to_s
      "Node Name: #{@name} Content: #{@content.to_s || '<Empty>'} " \
        "Parent: #{root? ? '<None>' : @parent.name.to_s} "       \
        "Children: #{@children.length} Total Nodes: #{size}"
    end

    # @!group Structure Modification

    # Convenience synonym for {Tree::TreeNode#add} method.
    #
    # This method allows an easy mechanism to add node hierarchies to the tree
    # on a given path via chaining the method calls to successive child nodes.
    #
    # @example Add a child and grand-child to the root
    #   root << child << grand_child
    #
    # @param [Tree::TreeNode] child the child node to add.
    #
    # @return [Tree::TreeNode] The added child node.
    #
    # @see Tree::TreeNode#add
    def <<(child)
      add(child)
    end

    # Adds the specified child node to this node.
    #
    # This method can also be used for *grafting* a subtree into this
    # node's tree, if the specified child node is the root of a subtree (i.e.,
    # has child nodes under it).
    #
    # this node becomes parent of the node passed in as the argument, and
    # the child is added as the last child ("right most") in the current set of
    # children of this node.
    #
    # Additionally you can specify a insert position. The new node will be
    # inserted BEFORE that position. If you don't specify any position the node
    # will be just appended. This feature is provided to make implementation of
    # node movement within the tree very simple.
    #
    # If an insertion position is provided, it needs to be within the valid
    # range of:
    #
    #    -children.size..children.size
    #
    # This is to prevent +nil+ nodes being created as children if a non-existent
    # position is used.
    #
    # If the new node being added has an existing parent node, then it will be
    # removed from this pre-existing parent prior to being added as a child to
    # this node. I.e., the child node will effectively be moved from its old
    # parent to this node. In this situation, after the operation is complete,
    # the node will no longer exist as a child for its old parent.
    #
    # @param [Tree::TreeNode] child The child node to add.
    #
    # @param [optional, Number] at_index The optional position where the node is
    #                                    to be inserted.
    #
    # @return [Tree::TreeNode] The added child node.
    #
    # @raise [RuntimeError] This exception is raised if another child node with
    #                       the same name exists, or if an invalid insertion
    #                       position is specified.
    #
    # @raise [ArgumentError] This exception is raised if a +nil+ node is passed
    #                        as the argument.
    #
    # @see #<<
    def add(child, at_index = -1)
      # Only handles the immediate child scenario
      raise ArgumentError, 'Attempting to add a nil node' unless child

      raise ArgumentError, 'Attempting add node to itself' if equal?(child)

      raise ArgumentError, 'Attempting add root as a child' if child.equal?(root)

      # Lazy man's unique test, won't test if children of child are unique in
      # this tree too.
      raise "Child #{child.name} already added!"\
            if @children_hash.include?(child.name)

      child.parent&.remove! child # Detach from the old parent

      if insertion_range.include?(at_index)
        @children.insert(at_index, child)
      else
        raise 'Attempting to insert a child at a non-existent location'\
              " (#{at_index}) "\
              'when only positions from '\
              "#{insertion_range.min} to #{insertion_range.max} exist."
      end

      @children_hash[child.name] = child
      child.parent = self
      child
    end

    # Return a range of valid insertion positions.  Used in the #add method.
    def insertion_range
      max = @children.size
      min = -(max + 1)
      min..max
    end

    private :insertion_range

    # Renames the node and updates the parent's reference to it
    #
    # @param [Object] new_name Name of the node. Conventional usage is to pass a
    #                          String (Integer names may cause *surprises*)
    #
    # @return [Object] The old name
    def rename(new_name)
      old_name = @name

      if root?
        self.name = new_name
      else
        @parent.rename_child old_name, new_name
      end

      old_name
    end

    # Renames the specified child node
    #
    # @param [Object] old_name old Name of the node. Conventional usage is to
    #                     pass a String (Integer names may cause *surprises*)
    #
    # @param [Object] new_name new Name of the node. Conventional usage is to
    #   pass a String (Integer names may cause *surprises*)
    def rename_child(old_name, new_name)
      raise ArgumentError, "Invalid child name specified: #{old_name}"\
            unless @children_hash.key?(old_name)

      @children_hash[new_name] = @children_hash.delete(old_name)
      @children_hash[new_name].name = new_name
    end

    # Replaces the specified child node with another child node on this node.
    #
    # @param [Tree::TreeNode] old_child The child node to be replaced.
    # @param [Tree::TreeNode] new_child The child node to be replaced with.
    #
    # @return [Tree::TreeNode] The removed child node
    def replace!(old_child, new_child)
      child_index = @children.find_index(old_child)

      old_child = remove! old_child
      add new_child, child_index

      old_child
    end

    # Replaces the node with another node
    #
    # @param [Tree::TreeNode] node The node to replace this node with
    #
    # @return [Tree::TreeNode] The replaced child node
    def replace_with(node)
      @parent.replace!(self, node)
    end

    # Removes the specified child node from this node.
    #
    # This method can also be used for *pruning* a sub-tree, in cases where the removed child node is
    # the root of the sub-tree to be pruned.
    #
    # The removed child node is orphaned but accessible if an alternate reference exists.  If accessible via
    # an alternate reference, the removed child will report itself as a root node for its sub-tree.
    #
    # @param [Tree::TreeNode] child The child node to remove.
    #
    # @return [Tree::TreeNode] The removed child node, or +nil+ if a +nil+ was passed in as argument.
    #
    # @see #remove_from_parent!
    # @see #remove_all!
    def remove!(child)
      return nil unless child

      @children_hash.delete(child.name)
      @children.delete(child)
      child.set_as_root!
      child
    end

    # Protected method to set the parent node for this node.
    # This method should *NOT* be invoked by client code.
    #
    # @param [Tree::TreeNode] parent The parent node.
    #
    # @return [Tree::TreeNode] The parent node.
    def parent=(parent) # :nodoc:
      @parent = parent
      @node_depth = nil
    end

    protected :parent=, :name=

    # Removes this node from its parent. This node becomes the new root for its
    # subtree.
    #
    # If this is the root node, then does nothing.
    #
    # @return [Tree:TreeNode] +self+ (the removed node) if the operation is
    #                                successful, +nil+ otherwise.
    #
    # @see #remove_all!
    def remove_from_parent!
      @parent.remove!(self) unless root?
    end

    # Removes all children from this node. If an independent reference exists to
    # the child nodes, then these child nodes report themselves as roots after
    # this operation.
    #
    # @return [Tree::TreeNode] this node (+self+)
    #
    # @see #remove!
    # @see #remove_from_parent!
    def remove_all!
      @children.each(&:remove_all!)

      @children_hash.clear
      @children.clear
      self
    end

    # Protected method which sets this node as a root node.
    #
    # @return +nil+.
    def set_as_root! # :nodoc:
      self.parent = nil
    end

    protected :set_as_root!

    # Freezes all nodes in the (sub)tree rooted at this node.
    #
    # The nodes become immutable after this operation.  In effect, the entire tree's
    # structure and contents become _read-only_ and cannot be changed.
    def freeze_tree!
      each(&:freeze)
    end

    # @!endgroup

    # @!group Tree Traversal

    # Returns the requested node from the set of immediate children.
    #
    # - If the +name+ argument is an _Integer_, then the in-sequence
    #   array of children is accessed using the argument as the
    #   *index* (zero-based).
    #
    # - If the +name+ argument is *NOT* an _Integer_, then it is taken to
    #   be the *name* of the child node to be returned.
    #
    # - To use an _Integer_ as the name, convert it to a _String_ first using
    #   +<integer>.to_s+.
    #
    # @param [String|Number] name_or_index Name of the child, or its
    #   positional index in the array of child nodes.
    #
    # @return [Tree::TreeNode] the requested child node.  If the index
    #   in not in range, or the name is not present, then a +nil+
    #   is returned.
    #
    # @raise [ArgumentError] Raised if the +name_or_index+ argument is +nil+.
    #
    # @see #add
    # @see #initialize
    def [](name_or_index)
      raise ArgumentError, 'Name_or_index needs to be provided!' if name_or_index.nil?

      if name_or_index.is_a?(Integer)
        @children[name_or_index]
      else
        @children_hash[name_or_index]
      end
    end

    # Traverses each node (including this node) of the (sub)tree rooted at this
    # node by yielding the nodes to the specified block.
    #
    # The traversal is *depth-first* and from *left-to-right* in pre-ordered
    # sequence.
    #
    # @yieldparam node [Tree::TreeNode] Each node.
    #
    # @see #preordered_each
    # @see #breadth_each
    #
    # @return [Tree::TreeNode] this node, if a block if given
    # @return [Enumerator] an enumerator on this tree, if a block is *not* given
    # noinspection RubyUnusedLocalVariable
    def each # :yields: node
      return to_enum unless block_given?

      node_stack = [self] # Start with this node

      until node_stack.empty?
        current = node_stack.shift # Pop the top-most node
        next unless current # Might be 'nil' (esp. for binary trees)

        yield current # and process it
        # Stack children of the current node at top of the stack
        node_stack = current.children.concat(node_stack)
      end

      self if block_given?
    end

    # Traverses the (sub)tree rooted at this node in pre-ordered sequence.
    # This is a synonym of {Tree::TreeNode#each}.
    #
    # @yieldparam node [Tree::TreeNode] Each node.
    #
    # @see #each
    # @see #breadth_each
    #
    # @return [Tree::TreeNode] this node, if a block if given
    # @return [Enumerator] an enumerator on this tree, if a block is *not* given
    def preordered_each(&block) # :yields: node
      each(&block)
    end

    # Traverses the (sub)tree rooted at this node in post-ordered sequence.
    #
    # @yieldparam node [Tree::TreeNode] Each node.
    #
    # @see #preordered_each
    # @see #breadth_each
    # @return [Tree::TreeNode] this node, if a block if given
    # @return [Enumerator] an enumerator on this tree, if a block is *not* given
    # noinspection RubyUnusedLocalVariable
    def postordered_each
      return to_enum(:postordered_each) unless block_given?

      # Using a marked node in order to skip adding the children of nodes that
      # have already been visited. This allows the stack depth to be controlled,
      # and also allows stateful backtracking.
      marked_node = Struct.new(:node, :visited)
      node_stack = [marked_node.new(self, false)] # Start with self

      until node_stack.empty?
        peek_node = node_stack[0]
        if peek_node.node.children? && !peek_node.visited
          peek_node.visited = true
          # Add the children to the stack. Use the marking structure.
          marked_children =
            peek_node.node.children.map { |node| marked_node.new(node, false) }
          node_stack = marked_children.concat(node_stack)
          next
        else
          yield node_stack.shift.node # Pop and yield the current node
        end
      end

      self if block_given?
    end

    # Performs breadth-first traversal of the (sub)tree rooted at this node. The
    # traversal at a given level is from *left-to-right*. this node itself is
    # the first node to be traversed.
    #
    # @yieldparam node [Tree::TreeNode] Each node.
    #
    # @see #preordered_each
    # @see #breadth_each
    #
    # @return [Tree::TreeNode] this node, if a block if given
    # @return [Enumerator] an enumerator on this tree, if a block is *not* given
    # noinspection RubyUnusedLocalVariable
    def breadth_each
      return to_enum(:breadth_each) unless block_given?

      node_queue = [self] # Create a queue with self as the initial entry

      # Use a queue to do breadth traversal
      until node_queue.empty?
        node_to_traverse = node_queue.shift
        yield node_to_traverse
        # Enqueue the children from left to right.
        node_to_traverse.children { |child| node_queue.push child }
      end

      self if block_given?
    end

    # An array of all the immediate children of this node. The child
    # nodes are ordered "left-to-right" in the returned array.
    #
    # If a block is given, yields each child node to the block
    # traversing from left to right.
    #
    # @yieldparam child [Tree::TreeNode] Each child node.
    #
    # @return [Tree::TreeNode] This node, if a block is given
    #
    # @return [Array<Tree::TreeNode>] An array of the child nodes, if no block
    #                                 is given.
    def children(&block)
      if block_given?
        @children.each(&block)
        self
      else
        @children.clone
      end
    end

    # Yields every leaf node of the (sub)tree rooted at this node to the
    # specified block.
    #
    # May yield this node as well if this is a leaf node.
    # Leaf traversal is *depth-first* and *left-to-right*.
    #
    # @yieldparam node [Tree::TreeNode] Each leaf node.
    #
    # @see #each
    # @see #breadth_each
    #
    # @return [Tree::TreeNode] this node, if a block if given
    # @return [Array<Tree::TreeNode>] An array of the leaf nodes
    # noinspection RubyUnusedLocalVariable
    def each_leaf
      if block_given?
        each { |node| yield(node) if node.leaf? }
        self
      else
        self.select(&:leaf?)
      end
    end

    # Yields every level of the (sub)tree rooted at this node to the
    # specified block.
    #
    # Will yield this node as well since it is considered the first level.
    #
    # @yieldparam level [Array<Tree::TreeNode>] All nodes in the level
    #
    # @return [Tree::TreeNode] this node, if a block if given
    # @return [Enumerator] an enumerator on this tree, if a block is *not* given
    def each_level
      if block_given?
        level = [self]
        until level.empty?
          yield level
          level = level.map(&:children).flatten
        end
        self
      else
        each
      end
    end

    # @!endgroup

    # @!group Navigating the Child Nodes

    # First child of this node.
    # Will be +nil+ if no children are present.
    #
    # @return [Tree::TreeNode] The first child, or +nil+ if none is present.
    def first_child
      @children.first
    end

    # Last child of this node.
    # Will be +nil+ if no children are present.
    #
    # @return [Tree::TreeNode] The last child, or +nil+ if none is present.
    def last_child
      @children.last
    end

    # @!group Navigating the Sibling Nodes

    # First sibling of this node. If this is the root node, then returns
    # itself.
    #
    # 'First' sibling is defined as follows:
    #
    # First sibling:: The left-most child of this node's parent, which may be
    # this node itself
    #
    # @return [Tree::TreeNode] The first sibling node.
    #
    # @see #first_sibling?
    # @see #last_sibling
    def first_sibling
      root? ? self : parent.children.first
    end

    # Returns +true+ if this node is the first sibling at its level.
    #
    # @return [Boolean] +true+ if this is the first sibling.
    #
    # @see #last_sibling?
    # @see #first_sibling
    def first_sibling?
      first_sibling == self
    end

    alias is_first_sibling? first_sibling? # @todo: Aliased for eventual replacement

    # Last sibling of this node.  If this is the root node, then returns
    # itself.
    #
    # 'Last' sibling is defined as follows:
    #
    # Last sibling:: The right-most child of this node's parent, which may be
    # this node itself
    #
    # @return [Tree::TreeNode] The last sibling node.
    #
    # @see #last_sibling?
    # @see #first_sibling
    def last_sibling
      root? ? self : parent.children.last
    end

    # Returns +true+ if this node is the last sibling at its level.
    #
    # @return [Boolean] +true+ if this is the last sibling.
    #
    # @see #first_sibling?
    # @see #last_sibling
    def last_sibling?
      last_sibling == self
    end

    alias is_last_sibling? last_sibling? # @todo: Aliased for eventual replacement

    # An array of siblings for this node. This node is excluded.
    #
    # If a block is provided, yields each of the sibling nodes to the block.
    # The root always has +nil+ siblings.
    #
    # @yieldparam sibling [Tree::TreeNode] Each sibling node.
    #
    # @return [Array<Tree::TreeNode>] Array of siblings of this node. Will
    #                                 return an empty array for *root*
    #
    # @return [Tree::TreeNode] This node, if no block is given
    #
    # @see #first_sibling
    # @see #last_sibling
    def siblings
      if block_given?
        parent.children.each { |sibling| yield sibling if sibling != self }
        self
      else
        return [] if root?

        siblings = []
        parent.children do |my_sibling|
          siblings << my_sibling if my_sibling != self
        end
        siblings
      end
    end

    # +true+ if this node is the only child of its parent.
    #
    # As a special case, a root node will always return +true+.
    #
    # @return [Boolean] +true+ if this is the only child of its parent.
    #
    # @see #siblings
    def only_child?
      root? ? true : parent.children.size == 1
    end

    alias is_only_child? only_child? # @todo: Aliased for eventual replacement

    # Next sibling for this node.
    # The _next_ node is defined as the node to right of this node.
    #
    # Will return +nil+ if no subsequent node is present, or if this is a root
    # node.
    #
    # @return [Tree::treeNode] the next sibling node, if present.
    #
    # @see #previous_sibling
    # @see #siblings
    def next_sibling
      return nil if root?

      idx = parent.children.index(self)
      parent.children.at(idx + 1) if idx
    end

    # Previous sibling of this node.
    # _Previous_ node is defined to be the node to left of this node.
    #
    # Will return +nil+ if no predecessor node is present, or if this is a root
    # node.
    #
    # @return [Tree::treeNode] the previous sibling node, if present.
    #
    # @see #next_sibling
    # @see #siblings
    def previous_sibling
      return nil if root?

      idx = parent.children.index(self)
      parent.children.at(idx - 1) if idx&.positive?
    end

    # @!endgroup

    # Provides a comparison operation for the nodes.
    #
    # Comparison is based on the natural ordering of the node name objects.
    #
    # @param [Tree::TreeNode] other The other node to compare against.
    #
    # @return [Integer] +1 if this node is a 'successor', 0 if equal and -1 if
    #                   this node is a 'predecessor'. Returns 'nil' if the other
    #                   object is not a 'Tree::TreeNode'.
    def <=>(other)
      return nil if other.nil? || !other.is_a?(Tree::TreeNode)

      name <=> other.name
    end

    # Provides a new comparison operation for the nodes.
    #
    # Comparison is based on the ordering of either {#each} or {#breadth_each}
    # according to the keyword parameter +policy+. Alternatively, if +policy+
    # is +:direct_or_sibling+, this returns +nil+ unless self and +other+
    # are in the direct line, that is, either must be an ancestor of the other
    # or both must be the direct siblings to eath other. If +:direct_only+,
    # even those in a sibling-relationship would return +nil+.
    # Finally, if +:name+, they are compared on the basis of {#name}.
    #
    # @param [Tree::TreeNode] other The other node to compare against.
    # @param [Symbol] policy One of +:each+, +:breadth_each+, +:direct_or_sibling+, +:direct_only+., and +:name+
    # @return [Integer, NilClass] +1 if this node is a 'successor', 0 if equal and -1 if
    #                   this node is a 'predecessor'. Returns 'nil' if the other
    #                   object is not like a {Tree::TreeNode}.
    def cmp(other, policy: :each)
      # @note Technically, the algorithm can be significantly simplified.
      #   For example, the index of +tree+ for {#breadth_each} can be given with
      #     tree.root.send(:breadth_each).to_a.find_index{|i| i == tree}
      #   as implemented in _get_index_in_each() in /test/test_tree.rb
      #   In that case, +:direct_only+ can be judged with
      #     self == other || parentage.include?(other) || other.parentage.include?(self)
      #
      #   See the method _spaceship_through_each() in /test/test_tree.rb
      #   for the real implementation, which is used in the test code for
      #   this method test_cmp() for verification.
      #
      #   However, such a simple algorithm can be slow and memory-hungry
      #   when the tree structure to examine is huge because they traverse
      #   all the elements from the ROOT always.  The algorithm below is
      #   much more efficient in such cases.

      #return super if %i(parentage root? breadth_each).any?{|i| !other.respond_to?(i)} # super should be used if this method is named "<=>"
      return(self <=> other) if %i(breadth_each parent children).any?{|i| !other.respond_to?(i)}
      return 0 if self == other
      return(self.name <=> other.name) if :name == policy

      # Constructs Arrays of [Root.name, Integer(sibling_rank(0<=x)), Integer, ...]
      arself, arother = _make_arrays_for_cmp(other)

      # ROOTs differ (n.b., arrays are destructively modified)
      return nil if arself.shift != arother.shift

      case policy
      when :breadth_each
        size_cmp = (arself.size <=> arother.size)
        return((size_cmp != 0) ? size_cmp : (arself <=> arother))

      when :each, :direct_only, :direct_or_sibling
        arself.zip(arother).each_with_index do |ea, i|
          case (res = (ea[0] <=> ea[1]))
          when 1, -1
            case policy
            when :each
              return res
            when :direct_or_sibling
              return(((i == arself.size-1) && (i == arother.size-1)) ? res : nil)
            else # :direct_only
              return nil
            end
          when nil  # ea[1] is nil, meaning other is an ancestor of self.
            return 1
          end
        end
        return(-1)  # meaning self is an ancestor of other, including the case where self is ROOT.
      else
        raise ArgumentError, "option policy (#{policy.inspect}) is none of :each, :breadth_each, :direct_or_sibling, :direct_only and :name"
      end
    end

    # Constructs Arrays for {#cmp}
    #
    # Retruns a doulbe Array (self, other). Each Array consists of
    #   [Root.name, Integer(sibling_rank(0<=x)), Integer, ...]
    #
    # For example, if self is a third grandchild of the eldest child of theroot
    # with the name "Root1", the array is
    #   ["Root1", 0, 2]
    #
    # @param [Tree::TreeNode] other The other node to compare against.
    # @return [Array] Double array(array_for_self, array_for_other)
    def _make_arrays_for_cmp(other)
      [self, other].map{ |tre|
        arret = []
        ctree = tre
        loop do
          (paren = ctree.parent) || break
          arret << paren.children.find_index{|i| i == ctree}
          ctree = paren
        end
        arret << ctree.name
        arret.reverse
      }
    end
    private :_make_arrays_for_cmp

    # Pretty prints the (sub)tree rooted at this node.
    #
    # @param [Integer] level The indentation level (4 spaces) to start with.
    # @param [Integer] max_depth optional maximum depth at which the printing
    #                            with stop.
    # @param [Proc] block optional block to use for rendering
    def print_tree(level = node_depth, max_depth = nil,
                   block = lambda { |node, prefix|
                             puts "#{prefix} #{node.name}"
                           })
      prefix = ''.dup # dup NEEDs to be invoked to make this mutable.

      if root?
        prefix << '*'
      else
        prefix << '|' unless parent.last_sibling?
        prefix << (' ' * (level - 1) * 4)
        prefix << (last_sibling? ? '+' : '|')
        prefix << '---'
        prefix << (children? ? '+' : '>')
      end

      block.call(self, prefix)

      # Exit if the max level is defined, and reached.
      return unless max_depth.nil? || level < max_depth

      # Child might be 'nil'
      children do |child|
        child&.print_tree(level + 1, max_depth, block)
      end
    end
  end
end
