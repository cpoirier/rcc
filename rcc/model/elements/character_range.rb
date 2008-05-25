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
require "#{$RCCLIB}/model/model.rb"
require "#{$RCCLIB}/util/sparse_range.rb"


module RCC
module Model
module Elements

 
 #============================================================================================================================
 # class CharacterRange
 #  - represents a group of symbols in a rule
 #  - a group is essentially an alias for one or more symbols
 
   class CharacterRange < Util::SparseRange
      
            
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    

   end # CharacterRange
   


end  # module Elements
end  # module Model
end  # module RCC
