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
 # class OptionalElement
 #  - description

   class OptionalElement < Element
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( element )
         @element = element
      end
   
   
      #
      # each_element()
      #  - loops through each element in this element
      
      def each_element()
         yield( @element )
      end
   




    #---------------------------------------------------------------------------------------------------------------------
    # Plan construction
    #---------------------------------------------------------------------------------------------------------------------
    
    
      #
      # phrases()
      #  - produce an array of Forms representing all the forms of this Series
      
      def phrases( label = nil )
         
         #
         # Our Forms are our child forms plus an empty Form.
         
         optional_phrases = @element.phrases(@label.nil? ? label : @label)
         optional_phrases.each do |optional_phrase|
            optional_phrase.minimal = false
         end
         
         return [ Model::Phrase.new() ].concat( optional_phrases )
      end
         
    
    
      
    

    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "#{@element}?"
      end

      def display( stream )
         stream << "Optional\n"
         stream.indent do
            @element.display( stream )
         end
      end
      
      
      
      
   end # OptionalElement
   


end  # module FormElements
end  # module Model
end  # module RCC
