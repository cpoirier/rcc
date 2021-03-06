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


require "#{File.expand_path(__FILE__).split("/system/")[0..-2].join("/system/")}/system/environment.rb"
require "#{RCC_LIBDIR}/util/expression_forms/expression_form.rb"

   
module RCC
module Util
module ExpressionForms

 
 #============================================================================================================================
 # class Sequence
 #  - an ExpressionForm that holds one or more sequential elements

   class Sequence < ExpressionForm
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :elements
      attr_writer :minimal
      
      def initialize( *elements )
         @elements = []
         @minimal  = true   # Indicates if this Sequence contains no expanded optional elements (default is true, to simplify .paths())
         
         elements.flatten.each do |element|
            assert( element.exists?, "wtf?" )
            self << element
         end
      end
      
      
      def optional?()
         optional = true
         each_element do |element|
            unless element.optional?
               optional = false 
               break
            end
         end
         
         return true
      end
      
      
      
      #
      # <<()
      #  - adds an element to this Sequence
      #  - if you attempt to add a Sequence as an element, its elements will be rolled up into this one
       
      def <<( element )
         case element
            when Sequence
               @minimal = false unless element.minimal?
               element.elements.each do |child_element|
                  self << child_element
               end
            else
               @elements << element
         end
      end
      
      
      #
      # def ==()
      
      def ==( rhs )
         return @elements == rhs.elements
      end
      

      #
      # paths()
      #  - returns a single BranchPoint containing only flattened Sequences showing every possible
      #    path through this ExpressionForm
      
      def paths()
         
         return BranchPoint.new(Sequence.new()) if @elements.empty?
         
         #
         # First, compile each element to its paths.  We will end up with an array of BranchPoints,
         # one for each element.
         #
         # Example sequence:
         #   a, b, c?, B(S(e, f), S(e, j), S(j, n), s?), a
         #
         # Example verticals:
         #   [B(S(a)), B(S(b)), B(S()), B(S(e, f)), B(S(a)) ]
         #                        S(c)    S(e, j)
         #                                S(j, n)
         #                                S()
         #                                S(s)
         
         verticals = []
         @elements.each do |element|
            if element.is_an?(ExpressionForm) then
               verticals << element.paths()
            else
               verticals << BranchPoint.new(Sequence.new(element))
            end
         end
         
         #
         # Next, work back from the end, building more and more longer and longer Sequences until we have one 
         # BranchPoint of Sequences representing all possible combinations.
         #
         # Example finished result:
         #  B( S(a, b, e, f, a) )      # 1/1, 1/1, 1/2, 1/5, 1/1
         #     S(a, b, e, j, a)        # 1/1, 1/1, 1/2, 2/5, 1/1
         #     S(a, b, j, n, a)        # 1/1, 1/1, 1/2, 3/5, 1/1
         #     S(a, b, a)              # 1/1, 1/1, 1/2, 4/5, 1/1
         #     S(a, b, s, a)           # 1/1, 1/1, 1/2, 5/5, 1/1
         #     S(a, b, c, e, f, a)     # 1/1, 1/1, 2/2, 1/5, 1/1
         #     S(a, b, c, e, j, a)     # 1/1, 1/1, 2/2, 2/5, 1/1
         #     S(a, b, c, j, n, a)     # 1/1, 1/1, 2/2, 3/5, 1/1
         #     S(a, b, c, a)           # 1/1, 1/1, 2/2, 4/5, 1/1
         #     S(a, b, c, s, a)        # 1/1, 1/1, 2/2, 5/5, 1/1
         
         result = BranchPoint.new( verticals.pop )
         result = verticals.pop * result until verticals.empty?
         return result
      end
      
      
      #
      # each_element()
      #  - calls your block once for every contained element
      
      def each_element()
         @elements.each do |element|
            yield( element )
         end
      end


      #
      # element_count()
      #  - returns the number of times your block will be called during each_elements
      
      def element_count()
         return @elements.length
      end


      #
      # minimal?()
      #  - indicates if this is a path contains no optional elements
      
      def minimal?()
         return @minimal
      end
      
      

      
      
   end # Sequence
   


end  # module ExpressionForms
end  # module Util
end  # module RCC



if $0 == __FILE__ then
   require "#{RCC_LIBDIR}/util/expression_forms/branch_point.rb"
   require "#{RCC_LIBDIR}/util/expression_forms/repeater.rb"
   
   def E(*e) ; RCC::Util::ExpressionForms::Element.new(*e) ; end
   def S(*e) ; RCC::Util::ExpressionForms::Sequence.new(*e) ; end
   def B(*e) ; RCC::Util::ExpressionForms::BranchPoint.new(*e) ; end
   def R(*e) ; RCC::Util::ExpressionForms::Repeater.new(*e) ; end
   def O(*e) ; RCC::Util::ExpressionForms::Optional.new(*e) ; end
   
   
   sequence = S( 
      "a", 
      "b", 
      O("c"),
      B(
         S("e", "f"),
         S("e", "j"),
         S("j", "n"),
         O("s")
      ),
      "a"
   )
   
   expected = B(
      S("a", "b", "e", "f", "a"),
      S("a", "b", "e", "j", "a"),
      S("a", "b", "j", "n", "a"),  
      S("a", "b", "a"),         
      S("a", "b", "s", "a"),      
      S("a", "b", "c", "e", "f", "a"),
      S("a", "b", "c", "e", "j", "a"),
      S("a", "b", "c", "j", "n", "a"),
      S("a", "b", "c", "a"),      
      S("a", "b", "c", "s", "a")   
   )
   
   result = sequence.paths
   result.branches.each do |sequence|
      puts sequence.elements.join(", ")
   end
   
   if result == expected then
      puts "PASS"
   else
      puts "FAIL"
   end
   
   
   
   puts "-----------"
   
   sequence = S(
      "a",
      R(S("b", O("c")), 1, 2),
      O("d")
   )
   
   expected = B(
      S("a", "b"),
      S("a", "b", "d"),
      S("a", "b", "c"),
      S("a", "b", "c", "d"),
      S("a", "b", "b"),
      S("a", "b", "b", "d"),
      S("a", "b", "b", "c"),
      S("a", "b", "b", "c", "d"),
      S("a", "b", "c", "b"),
      S("a", "b", "c", "b", "d"),
      S("a", "b", "c", "b", "c"),
      S("a", "b", "c", "b", "c", "d")
   )
   
   result = sequence.paths
   result.branches.each do |sequence|
      puts sequence.elements.join(", ")
   end

   if result == expected then
      puts "PASS"
   else
      puts "FAIL"
   end
   
   exit
end

