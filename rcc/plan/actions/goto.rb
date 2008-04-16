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
require "#{$RCCLIB}/plan/actions/action.rb"

module RCC
module Plan
module Actions

 
 #============================================================================================================================
 # class Goto
 #  - a Goto action for the ParserPlan

   class Goto < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :to_state
      attr_reader :commit_point
      
      def initialize( to_state, commit_point )
         @to_state     = to_state
         @commit_point = commit_point
      end
      
      def local_commit?()
         return @commit_point == :local
      end
      
      def global_commit?()
         return @commit_point == :global
      end
      
      def commit?()
         return !@commit_point.nil?
      end
      
      
   end # Goto
   


end  # module Actions
end  # module Plan
end  # module RCC
