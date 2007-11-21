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
require "#{$RCCLIB}/model/form_elements/symbol.rb"


module RCC
module Model
module FormElements

 
 #============================================================================================================================
 # class Terminal
 #  - a descriptor of a literal or symbol token to be read

   class Terminal < Symbol
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :terminal
      
      def initialize( terminal, symbol = nil )
         super( symbol.nil? ? terminal.intern : symbol )
         @terminal = terminal
      end
      
      def text()
         return @terminal
      end
      
      def terminal?()
         return true
      end
      
      
      def ==( rhs )
         @type == rhs.type && @terminal == rhs.terminal
      end
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def display( stream, indent = "" )
         stream << indent << "Terminal #{@type.to_s.downcase} #{@terminal}\n"
      end





   end # Terminal
   


end  # module FormElements
end  # module Model
end  # module RCC
