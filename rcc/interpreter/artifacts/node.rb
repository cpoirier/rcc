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

module RCC
module Interpreter
module Artifacts
   

 
 #============================================================================================================================
 # class Node
 #  - a base class for Nodes in syntax trees produced by the Interpreter

   class Node
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :root_symbol         # The Symbol this Node represents
      attr_reader :token_count         # The number of Tokens in this and all sub CSNs
      
      alias :symbol :root_symbol
      alias :type   :root_symbol
      
      def initialize( root_symbol, component_symbols )
         @root_symbol = root_symbol
         @token_count = component_symbols.inject(0) {|sum, symbol| symbol.token_count }
         
         @tainted = false
         @component_symbols.each do |symbol|
            @tainted = true if symbol.tainted?
            
            if symbol.corrected? then
               @corrections = [] if @corrections.nil?
               @corrections.concat( symbol.corrections )
            end
         end
      end
      
      def follow_position()
         return last_token().follow_position()
      end
      
      def description()
         return "#{@root_symbol}"
      end
      
      def terminal?()
         return false
      end      
      





    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery 
    #---------------------------------------------------------------------------------------------------------------------


      #
      # tainted?
      #  - returns true if this CSN carries Correction taint
      
      def tainted?()
         return @tainted
      end
      
      
      #
      # untaint()
      #  - clears the taint from this CSN (any Correction is still linked)
      
      def untaint()
         @tainted = false
      end
      
      
      #
      # corrected?()
      #  - returns true if there are any Corrections associated with this Token
      #  - for Tokens (only), tainted? implies corrected? and vice versa
      
      def corrected?()
         return (defined(@corrections) and @corrections.exists? and !@corrections.empty?)
      end
      
      
      #
      # corrections()
      #  - returns any Correction objects associated with this Token
      
      def corrections()
         return [] if !defined(@corrections)
         return @corrections 
      end
      
      
      #
      # corrections_cost()
      #  - returns the cost of any Corrections associated with this Token, or 0
      
      def corrections_cost()
         return 0 if !defined(@corrections) or @corrections.nil?
         return @corrections.inject(0) { |current, correction| current + correction.cost }
      end
      
    
      
   end # Node
   


end  # module Artifacts
end  # module Interpreter
end  # module Rethink
