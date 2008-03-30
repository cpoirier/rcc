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
module Model
module Markers

 
 #============================================================================================================================
 # class RecoveryCommit
 #  - a marker showing a recovery commit in a Rule

   class RecoveryCommit
      include Model::Elements::SlotInfo
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
         
      end
      
   end # RecoveryCommit
   


end  # module Markers
end  # module Model
end  # module RCC
