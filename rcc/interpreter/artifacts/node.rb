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
      attr_reader :original_error_position
      
      alias :symbol :root_symbol
      alias :type   :root_symbol
      
      def initialize( root_symbol, component_symbols )
         @root_symbol = root_symbol
         @token_count = component_symbols.inject(0) {|sum, symbol| symbol.token_count }

         @tainted     = false
         @recoverable = false
         component_symbols.each do |symbol|
            @tainted = true if symbol.tainted?
            
            if symbol.corrected? then
               @corrections = [] if @corrections.nil?
               @corrections.concat( symbol.corrections )
            end
         end
         
         @original_error_position = 0
         @original_error_position = @corrections[-1].original_error_position if defined?(@corrections) and !@corrections.empty?
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
      #  - clears the taint from this Node (any Correction is still linked)
      
      def untaint()
         @tainted = false
      end
      
      
      #
      # corrected?()
      #  - returns true if there are any Corrections associated with this Node
      
      def corrected?()
         return (defined?(@corrections) and @corrections.exists? and !@corrections.empty?)
      end
      
      
      #
      # corrections()
      #  - returns any Correction objects associated with this Node
      
      def corrections()
         return [] if !defined?(@corrections)
         return @corrections 
      end
      
      
      #
      # last_correction()
      #  - returns the last Correction object associated with this Node, or nil
      
      def last_correction()
         return nil if !defined?(@corrections) or @corrections.nil? or @corrections.empty?
         return @corrections[-1]
      end
      
      
      #
      # corrections_cost()
      #  - returns the cost of any Corrections associated with this Token, or 0
      
      def corrections_cost()
         return 0 if !defined?(@corrections) or @corrections.nil?
         return @corrections.inject(0) { |current, correction| current + correction.cost }
      end
      

      #
      # recoverable?
      #  - returns true if this Node can anchor 
      
      attr_writer :recoverable
      
      def recoverable?()
         return @recoverable
      end
      
   end # Node
   


end  # module Artifacts
end  # module Interpreter
end  # module Rethink



require "#{$RCCLIB}/interpreter/artifacts/asn.rb"
require "#{$RCCLIB}/interpreter/artifacts/csn.rb"
