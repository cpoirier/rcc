#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "rcc/environment.rb"

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
      
      def phrases()
         
         #
         # Our Forms are our child forms plus an empty Form.
         
         return [ Model::Phrase.new() ].concat( @element.phrases() )
      end
         
    
    
      
    

    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "#{@element}?"
      end

      def display( stream, indent = "" )
         stream << indent << "Optional\n"
         @element.display( stream, indent + "   " )
      end
      
      
      
      
   end # OptionalElement
   


end  # module FormElements
end  # module Model
end  # module Rethink
