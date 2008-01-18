#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

module RCC
module Model
module FormElements

 
 #============================================================================================================================
 # class SeriesElement
 #  - a descriptor of a sequence of elements to be processed

   class SeriesElement < Element
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( elements = [] )
         @elements = []         
      end
      
      
      def add_element( element )
         @elements << element
         return element
      end
      
      
      #
      # each_element()
      #  - loops through each element in this element
      
      def each_element()
         @elements.each do |element|
            yield( element )
         end
      end
      





    #---------------------------------------------------------------------------------------------------------------------
    # Plan construction
    #---------------------------------------------------------------------------------------------------------------------
    
    
      #
      # phrases( label = nil )
      #  - produce an array of Forms representing all the forms of this Series
      
      def phrases()
         
         return [] if @elements.empty?
         
         #
         # First, compile each element to its Forms.  We will end up with an array of arrays of Forms, one child
         # array for each element.
         #
         # Example rule body:
         #   a b c d? ( e f g | e j k | j n m | s t ) a
         #
         # Example raw_forms:
         #  [   [F(a, b, c)],   [ F()  ],   [ F(e, f, g) ],   [ F(a) ]   ]
         #  |                   | F(d) |    | F(e, j, k) |               |
         #  |                               | F(j, n, m) |               |
         #  |                               | F(s, t)    |               |
         
         raw_forms = []
         @elements.each do |element|
            raw_forms << element.phrases( @label.nil? ? label : @label )
         end
         
         #
         # Next, work back from the end, building more and more longer and longer Forms until we have one array
         # of Forms representing all possible combinations.
         #
         # Example finished built_forms:
         #  [ F(a, b, c, e, f, g, a)    ]    # 0, 0, 0, 0
         #  | F(a, b, c, e, j, k, a)    |    # 0, 0, 1, 0
         #  | F(a, b, c, j, n, m, a)    |    # 0, 0, 2, 0
         #  | F(a, b, c, s, t, a)       |    # 0, 0, 3, 0
         #  | F(a, b, c, d, e, f, g, a) |    # 0, 1, 0, 0
         #  | F(a, b, c, d, e, j, k, a) |    # 0, 1, 1, 0
         #  | F(a, b, c, d, j, n, m, a) |    # 0, 1, 2, 0
         #  | F(a, b, c, d, s, t, a)    |    # 0, 1, 3, 0
         
         built_forms = raw_forms.slice!(-1)
         until raw_forms.empty?
            current_forms = raw_forms.slice!(-1)
            tail_forms    = built_forms
            built_forms   = []

            current_forms.each do |current_form|
               tail_forms.each do |tail_form|
                  built_forms << current_form + tail_form
               end
            end
         end
         
         return built_forms
      end
      
    
    
    
      


    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
        return @elements.join(" ")
      end

      def display( stream )
         stream << "Series\n"
         stream.indent do |s|
            @elements.each do |element|
               element.display( s )
            end
         end
      end
      
   
      
   end # SeriesElement
   


end  # module FormElements
end  # module Model
end  # module RCC
