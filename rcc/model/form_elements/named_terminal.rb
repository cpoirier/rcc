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
require "#{$RCCLIB}/model/form.rb"
require "#{$RCCLIB}/model/form_elements/terminal.rb"


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


      def display( stream = $stdout )
         stream << "NamedTerminal #{@name}\n"
      end





   end # NamedTerminal
   


end  # module FormElements
end  # module Model
end  # module RCC
