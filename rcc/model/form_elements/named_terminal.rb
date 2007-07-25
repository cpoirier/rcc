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
require "rcc/model/form.rb"
require "rcc/model/form_elements/terminal.rb"


module RCC
module Model
module FormElements

 
 #============================================================================================================================
 # class NamedTerminal
 #  - a named Terminal, referencing a Terminal defined in the Terminals section

   class NamedTerminal < Terminal
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( symbol )
         super( symbol )
      end
      


      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------


      def display( stream, indent = "" )
         stream << indent << "NamedTerminal #{@name}\n"
      end





   end # NamedTerminal
   


end  # module FormElements
end  # module Model
end  # module Rethink
