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
module Explanations

 
 #============================================================================================================================
 # class Explanation
 #  - base class for things that explain why actions where produced the way they were

   class Explanation
      
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
      
      
      
   end # Explanation
   



end  # module Explanations
end  # module Plan
end  # module RCC



require "#{$RCCLIB}/plan/explanations/backtracking_activated.rb"
require "#{$RCCLIB}/plan/explanations/initial_options.rb"
require "#{$RCCLIB}/plan/explanations/items_do_not_meet_threshold.rb"
require "#{$RCCLIB}/plan/explanations/only_one_choice.rb"
require "#{$RCCLIB}/plan/explanations/left_assoc_reduce_eliminates_shift.rb"
require "#{$RCCLIB}/plan/explanations/right_assoc_reduce_eliminated.rb"
require "#{$RCCLIB}/plan/explanations/left_assoc_reduce_eliminated.rb"

