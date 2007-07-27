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
      
      def display( stream, indent = "" )
         stream << indent << self.to_s << "\n"
      end
      

      
   end # Action
   


end  # module Actions
end  # module Plan
end  # module Rethink





require "rcc/plan/actions/shift.rb"
require "rcc/plan/actions/reduce.rb"
require "rcc/plan/actions/goto.rb"
require "rcc/plan/actions/accept.rb"
require "rcc/plan/actions/attempt.rb"
