#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright (C) 2007-2008 Chris Poirier (cpoirier@gmail.com)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation 
# files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
# modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
# is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE 
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR 
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#================================================================================================================================


class Array
   
   #
   # inject()
   #  - calls the block for each element, passing in the last value generated to each next item
   #  - returns the final value

   def inject( seed ) 
      each() do |element|
         result = yield( seed, element )
         next if result.nil?
         seed = result
      end
      return seed
   end
   
   
   #
   # select()
   #  - returns an array containing only those elements for which your block returns true
   
   def select()
      selected = []
      
      each() do |element|
         selected << element if yield(element)
      end
      
      return selected
   end
   
        
   #
   # remove_if()
   #  - just like delete_if(), except it returns an array of the deleted elements
   
   def remove_if()
      removed = []
      
      delete_if() do |element|
         if yield(element) then
            removed << element
            true
         else
            false
         end
      end
      
      return removed
   end
   
   
   #
   # accumulate()
   #  - appends your value to a list at the specified index
   #  - creates the array if not present
   
   def accumulate( key, value )
      self[key] = [] unless self.member?(key)
      self[key] << value
   end
   
   
   #
   # subsets()
   #  - treating this list as a set, returns all possible subsets
   #  - by way of definitions, sets have no intended order and no duplicate elements
   
   def subsets( pretty = true )
      set     = self.uniq
      subsets = [ [] ]
      until set.empty?
         work_point = [set.shift]
         work_queue = subsets.dup
         until work_queue.empty?
            subsets.unshift work_queue.shift + work_point
         end
         
      end
      
      subsets.sort!{|lhs, rhs| rhs.length == lhs.length ? lhs <=> rhs : rhs.length <=> lhs.length } if pretty

      return subsets
   end
   
   
   #
   # to_hash( )
   #  - converts the elements of this array to keys in a hash and returns it
   #  - the item itself will be used as value if the value you specify is :value_is_element
   #  - if you supply a block, it will be used to obtain keys from the element
   
   def to_hash( value = nil )
      hash = {}
      
      self.each do |element|
         key = block_given? ? yield( element ) : element
         if value == :value_is_element then
            hash[key] = element
         else
            hash[key] = value
         end
      end
      
      return hash
   end
   
   
   #
   # merge()
   #  - equivalant to (a + b).uniq(), but uses hashes to make the operation faster
   
   def merge( rhs )
      index = {}
      self.each do |e|
         index[e] = true
      end
      rhs.each do |e|
         index[e] = true
      end
      
      return index.keys
   end
   
   
   #
   # rest()
   #  - returns all but the first element
   
   def rest()
      return self[1..-1]
   end
   
   
   #
   # all?()
   #  - returns true if your block returns true for all of the elements
   
   def if_all?()
      matches = true
      each do |element|
         unless yield(element)
            matches = false
            break
         end
      end
      
      return matches
   end
   
   
   #
   # any?()
   #  - returns true if your block returns true for any of the elements
   
   def any?()
      matches = false
      each do |element|
         if yield(element) then
            matches = true
            break
         end
      end
      
      return matches
   end


   #
   # to_a()
   
   def to_a()
      return self
   end
   
   
   #
   # collect_from()
   #  - converts some data structure into an array by simulating collect()
   
   def Array.collect_from( container, method = :each, *parameters )
      collection = []
      container.send( method, *parameters ) do |element|
         if block_given? then
            collection << yield(element)
         else 
            collection << element
         end
      end
      
      return collection
   end
   
   #
   # select_from()
   #  - converts some data structure into an array by simulating select()
   
   def Array.select_from( container, method = :each, *parameters )
      collection = []
      container.send( method, *parameters ) do |element|
         collection << element if yield(element)
      end
      
      return collection
   end
   
   
   
end
