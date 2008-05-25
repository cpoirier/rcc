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
require "#{$RCCLIB}/scanner/artifacts/name.rb"

module RCC
module Scanner
module Artifacts
   

 
 #============================================================================================================================
 # class Node
 #  - a base class for Nodes in syntax trees produced by the Scanner

   class Node
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :type
         
      def initialize( type )
         type_check( type, Scanner::Artifacts::Name )
         @type = type
      end
      
      def description( elide_grammar = nil )
         return @type.description(elide_grammar)
      end
      
      def follow_position()
         return last_token().follow_position()
      end
      
      def token?()
         return false
      end   
      
      def character?()
         return false
      end
      
      def first_token()
         bug( "you must override first_token()" )
      end

      def last_token()
         bug( "you must override last_token()" )
      end
      
      def token_count()
         bug( "you must override token_count()" )
      end
      
      def usurped?()
         return false
      end

      
      #
      # duplicate()
      #  - does a deep copy of this Node
      #  - if you supply a block, you will be passed the duplicated copy of this Node and
      #    what you return will be returned by the function
      
      def duplicate()
         bug( "you must override duplicate()" )
      end


      #
      # commit()
      #  - called to indicate this Node is finished, happy, and will never be used again in error recovery
      #  - for ASNs, this is where Transformations are applied
      
      def commit( recurse = true )
         return true
      end


      #
      # committed?()
      #  - if known, indicates if commit() has been called
      #  - not all node types remember!
      
      def committed?()
         return nil
      end




    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery 
    #---------------------------------------------------------------------------------------------------------------------


      #
      # tainted?
      #  - returns true if this CSN carries Correction taint
      
      def tainted?()
         return corrected?
      end
      
      
      #
      # untaint()
      #  - clears the taint from this Node (any Correction is still linked)
      
      def untaint()
         bug( "you must override untaint()" )
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
      #  - returns true if this Node can anchor a recovery
      
      def recoverable?()
         return false
      end
      
      
   end # Node
   


end  # module Artifacts
end  # module Scanner
end  # module RCC


require "#{$RCCLIB}/scanner/artifacts/nodes/character.rb"
require "#{$RCCLIB}/scanner/artifacts/nodes/token.rb"
require "#{$RCCLIB}/scanner/artifacts/nodes/subtree.rb"
