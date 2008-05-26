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

module RCC
module Plan
module Actions

 
 #============================================================================================================================
 # class Action
 #  - base class for Parser actions 

   class Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
      end

      def to_s()
         return self.class.name
      end
      
      def display( stream = $stdout )
         stream << self.to_s << "\n"
      end
      
      def explanations()
         return has_explanations? ? @explanations : nil
      end

      def explanations=( explanations )
         @explanations = explanations
      end
      
      def has_explanations?()
         return (defined?(@explanations) and @explanations.set?)
      end
      
   end # Action
   


end  # module Actions
end  # module Plan
end  # module RCC




require "#{$RCCLIB}/plan/actions/shift.rb"
require "#{$RCCLIB}/plan/actions/reduce.rb"
require "#{$RCCLIB}/plan/actions/discard.rb"
require "#{$RCCLIB}/plan/actions/accept.rb"
require "#{$RCCLIB}/plan/actions/attempt.rb"
require "#{$RCCLIB}/plan/actions/read.rb"
require "#{$RCCLIB}/plan/actions/continue.rb"
require "#{$RCCLIB}/plan/actions/group.rb"
require "#{$RCCLIB}/plan/actions/tokenize.rb"
