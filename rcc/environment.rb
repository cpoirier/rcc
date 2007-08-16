#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

   $RCC_LIBRARY_PATH = File.dirname(__FILE__)
   
   require "rcc/util/quality.rb"
   
   def max( a, b )
      a > b ? a : b
   end
   
   def min( a, b )
      a < b ? a : b
   end
   

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

   end
   
   
   class Object
      def each()
         yield( self )
      end
   end
   
   class NilClass
      def each()
      end
   end
   
   
   class Time
      
      #
      # Time.measure()
      #  - returns the duration of the supplied block in seconds (floating point)

      def Time.measure()
         start = Time.now
         yield()
         return Time.now - start
      end
      
   end