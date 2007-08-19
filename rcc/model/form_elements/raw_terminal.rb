#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"
require "#{$RCCLIB}/model/form.rb"
require "#{$RCCLIB}/model/form_elements/terminal.rb"


module RCC
module Model
module FormElements

 
 #============================================================================================================================
 # class RawTerminal
 #  - a raw Terminal described directly inline

   class RawTerminal < Terminal
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( symbol )
         super( symbol, symbol )
         @label = "ignore"
      end
      


      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "'" + @name.gsub("'", "''") + "'" 
      end

      def display( stream, indent = "" )
         stream << indent << "RawTerminal #{@name}\n"
      end





   end # RawTerminal
   


end  # module FormElements
end  # module Model
end  # module Rethink
