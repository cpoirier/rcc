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
 # class ForkElement
 #  - a descriptor of a literal or symbol token to be read

   class ForkElement < Element
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( )
         @choices = []         
      end
      
      def add_choice( element )
         @choices << element
         return element
      end
      
      
      #
      # each_element()
      #  - loops through each element in this element
      
      def each_element()
         @choices.each do |element|
            yield( element )
         end
      end
    
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Plan construction
    #---------------------------------------------------------------------------------------------------------------------
    
    
      #
      # phrases()
      #  - produce an array of Forms representing all the forms of this Series
      
      def phrases( label = nil )
         forms = []
         
         #
         # Each element will produce an array of forms.  We merge them into a single array which describees
         # all our potential forms.
         
         @choices.each do |element|
            forms.concat element.phrases( @label.nil? ? label : @label )
         end

         return forms
      end
         
    



    
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
        return "(" + @choices.join("|") + ")"
      end

      def display( stream )
         stream << "Fork\n"
         stream.indent do |s|
            @choices.each do |choice|
              choice.display( s )
            end
         end
      end
      
      
      
      
   end # ChoiceElement
   


end  # module FormElements
end  # module Model
end  # module RCC
