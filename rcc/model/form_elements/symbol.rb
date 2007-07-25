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
require "rcc/model/form_elements/element.rb"

module RCC
module Model
module FormElements

 
 #============================================================================================================================
 # class Symbol
 #  - the basic Elements that Form Rules

   class Symbol < Element
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :name
      def initialize( name )
         @name = name
      end
      
      def terminal?()
         return false
      end
      
      
      def non_terminal?()
         return false
      end
      
      
      def hash()
         return @name.hash()
      end
      
      
      def eql?( rhs )
         if rhs.is_a?(FormElements::Symbol) then
            return @name == rhs.name
         else
            return @name == rhs
         end
      end
      
      
      def ==( rhs )
         return false unless rhs.is_a?(Symbol)
         return @name == rhs.name
      end


      def to_s()
         return @name.to_s
      end




    #---------------------------------------------------------------------------------------------------------------------
    # Plan construction
    #---------------------------------------------------------------------------------------------------------------------
    
    
      #
      # phrases()
      #  - produce an array of Forms representing all the forms of this Series
      
      def phrases()
         return [ Model::Phrase.new(self) ]
      end
      
      
      
    
   end # Symbol
   


end  # module FormElements
end  # module Model
end  # module Rethink


require "rcc/model/phrase.rb"