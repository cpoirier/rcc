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
 # class Attempt
 #  - a Action that allows a set of Actions to be attempted, in sequence, until one of them succeeds

   class Attempt < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
      
      attr_reader :actions
      attr_reader :attempt_span
      attr_reader :last_is_longest
      
      def initialize( actions, attempt_span, last_is_longest )
         @actions         = actions
         @attempt_span    = attempt_span
         @last_is_longest = last_is_longest
      end
      
      def to_s()
         return "Attempt:\n   " + @actions.collect{|action| action.to_s}.join("\n   ")
      end
      
   end # Attempt
   


end  # module Actions
end  # module Plan
end  # module RCC
