#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright 2007-2008 Chris Poirier (cpoirier@gmail.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the 
# License.  You may obtain a copy of the License at
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" 
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language 
# governing permissions and limitations under the License.
#================================================================================================================================


module RCC
module Util
   

 #============================================================================================================================
 # class OrderedHash
 #  - a Hash lookalike that remembers the order in which keys were added

   class OrderedHash

      attr_reader :order
      alias keys order

      #
      # ::new(), initialize()
      #  - initializes the OrderedHash to the empty state
      
      def initialize( auto_fill = nil )
         @hash  = Hash.new()   # { name => Object } - our data, keyed on name
         @order = []           # [ name ]           - the insertion order for our names
         
         #
         # If supplied, this will be used to fill any missing referenced element.
         # It can be a class with a zero-argument constructor, or a Proc to call.
         
         type_check( auto_fill, [Proc, Class], true )
         @auto_fill = auto_fill
      end


      #
      # clear()
      #  - empties the hash
      
      def clear()
         @hash.clear
         @order.clear
      end


      #
      # member?()
      #  - returns true if the specified key is in the hash
      
      def member?( key )
         return @hash.member?( key )
      end


      #
      # values()
      #  - returns a list of values from the hash, in the added order
      
      def values()
         @order.collect do |name|
            @hash[name]
         end
      end
      
      
      #
      # reverse()
      #  - returns an OrderedHash with the reverse order to this one
      
      def reverse()
         reversed = self.class.new( @auto_fill )
         order    = @order.reverse
         hash     = @hash.dup
         
         reversed.instance_eval do
            @order = order
            @hash  = hash
         end
         
         return reversed
      end
      
      
      #
      # reverse!
      #  - reverses our order
      
      def reverse!()
         @order.reverse!
      end


      #
      # []()
      #  - returns the value for the specified key
      
      def []( key )
         if key.is_a?(Numeric) then
            return @hash[@order[key]]
         else
            if !@hash.member?(key) and @auto_fill.exists? then
               case @auto_fill
                  when Class
                     self[key] = @auto_fill.new()
                  when Proc
                     self[key] = @auto_fill.call()
               end
            end
            
            return @hash[key]
         end
      end

      
      #
      # []=()
      #  - sets a value for the specified key
      #  - does not alter existing key ordering; appends to the order if a new key
      
      def []=( key, value )
         if member?(key) then
            @hash[key] = value
         else
            @hash[key] = value
            @order << key
         end
         
         return value
      end
      
      
      #
      # rename()
      #  - changes the key for an existing element, without alter key order
      
      def rename( old_key, new_key )
         value = @hash[old_key]
         @hash.delete(old_key)
         @hash[new_key] = value

         @order.each do |index, key|
            if key == old_key then
               @order[index] = new_key
               break
            end 
         end

         return value
      end


      #
      # delete()
      #  - deletes an element from the hash
      
      def delete( key )
         @hash.delete(key)
         @order.delete(key)
      end


      #
      # length()
      #  - returns the number of elements in the hash
      
      def length()
         return @order.length
      end


      #
      # empty?()
      #  - returns true if the hash is empty
      
      def empty?()
         return @order.empty?
      end

      
      #
      # make_first()
      #  - moves an existing element to the front of the key order
      
      def make_first( key )
         bug( "keyd item not in Namespace" ) unless @order.member?(key)

         @order.delete( key )
         @order.unshift( key )
      end


      #
      # reorder()
      #  - reorders the hash, moving the specified keys to the beginning of the list
      
      def reorder( ordering )
         old    = @order
         @order = []

         ordering.each do |key|
            if old.member?(key) then
               old.delete(key)
               @order << key
            end
         end

         @order.concat( old )
      end


      #
      # each()
      #  - iterates over the elements in the hash
      #  - passes value or key and value to your block
      
      def each( &proc )
         if proc.arity == 1 then
            @order.each do |key|
               begin
                  proc.call( @hash[key] )
               rescue LocalJumpError
                  break
               end
            end
         else
            @order.each do |key|
               begin
                  proc.call( key, @hash[key] )
               rescue LocalJumpError
                  break
               end
            end
         end
      end

      
      #
      # collect()
      #  - iterates over the elements in the hash, returning a list of the results
      #  - passes value or key and value to your block
      
      def collect( &proc )
         results = []
         if proc.arity == 1 then
            each() do |node|
               begin
                  results << proc.call( node )
               rescue LocalJumpError
                  break
               end
            end
         else
            each() do |key, node|
               begin
                  results << proc.call( key, node )
               rescue LocalJumpError
                  break
               end
            end
         end
         results
      end
      
      
      #
      # select()
      #  - iterates over the elements in the has, returning an OrderedHash of any for which
      #    your block returns true
      
      def select()
         result = self.new()
         self.each do |name, value|
            result[name] = value if yield( name, value )
         end
         
         return result
      end
      
      
      #
      # import()
      #  - iterates over a different hash and adds to this OrderedHash any elements for
      #    which your block returns true
      
      def import( hash )
         hash.each do |name, value|
            self[name] = value if yield(name, value)
         end
      end

      
      #
      # each_after_index()
      #  - same as each(), but starts after the specified index into the key list
      
      def each_after_index( index, &proc )
         i = -1

         if proc.arity == 2 then
            each() do |element|
               i += 1
               next if i <= index
               begin
                  proc.call( i, element ) 
               rescue LocalJumpError
                  break
               end
            end
         else
            each() do |element|
               i += 1
               next if i <= index
               begin
                  proc.call( element ) 
               rescue LocalJumpError
                  break
               end
            end
         end
      end


      #
      # each_unique()
      #  - same as each(), but calls your block once for each value object
      
      def each_unique()
         touched = {}  # { id => true } 

         each() do |key, node|
            if touched.member?(node.object_id) then
               true
            else
               touched[node.object_id] = true
               yield( node )
            end
         end
      end


      #
      # dup()
      #  - returns a new copy of the hash
      
      def dup()
         copy = Namespace.new()

         hash  = @hash
         order = @order

         copy.instance_eval do 
            @hash  = hash.dup
            @order = order.dup
         end

         return copy
      end

      
      #
      # as_array()
      #  - returns the values from the hash, in the proper order
      
      def as_array()
         return self.values()
      end


   end


end  # module Util
end  # module RCC
