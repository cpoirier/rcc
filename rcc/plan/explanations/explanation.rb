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
module Plan
module Explanations

 
 #============================================================================================================================
 # class Explanation
 #  - base class for things that explain why actions where produced the way they were

   class Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( )
      end
      
      def to_s()
         return self.class.name
      end
      
      def display( stream, indent = "" )
         stream << indent << self.to_s << "\n"
      end
      
      
      
   end # Explanation
   



end  # module Explanations
end  # module Plan
end  # module Rethink



require "#{$RCCLIB}/plan/explanations/selected_action.rb"
require "#{$RCCLIB}/plan/explanations/only_one_choice.rb"
require "#{$RCCLIB}/plan/explanations/reductions_sorted.rb"
require "#{$RCCLIB}/plan/explanations/shift_trumps_reduce.rb"
require "#{$RCCLIB}/plan/explanations/reduce_trumps_shift.rb"
require "#{$RCCLIB}/plan/explanations/initial_options.rb"
require "#{$RCCLIB}/plan/explanations/favourite_chosen.rb"
require "#{$RCCLIB}/plan/explanations/backtracking_activated.rb"

