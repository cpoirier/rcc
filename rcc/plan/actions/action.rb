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
      
      def display( stream )
         stream << self.to_s << "\n"
      end
      

      
   end # Action
   


end  # module Actions
end  # module Plan
end  # module RCC





require "#{$RCCLIB}/plan/actions/shift.rb"
require "#{$RCCLIB}/plan/actions/reduce.rb"
require "#{$RCCLIB}/plan/actions/goto.rb"
require "#{$RCCLIB}/plan/actions/accept.rb"
require "#{$RCCLIB}/plan/actions/attempt.rb"
