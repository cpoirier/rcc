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
module Predicates

 
 #============================================================================================================================
 # class Predicate
 #  - base class for recovery option Predicates

   class Predicate
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( insert = true, replace = true )
         @insert  = insert
         @replace = replace
      end
      
      def insert?()
         return @insert
      end
      
      def replace?()
         return @replace
      end
      
      def to_s()
         return self.class.name
      end
      
      def display( stream = $stdout )
         stream << self.to_s << "\n"
      end
      

      
   end # Predicate
   


end  # module Predicates
end  # module Plan
end  # module RCC




 
require "#{$RCCLIB}/plan/predicates/check_context.rb"
require "#{$RCCLIB}/plan/predicates/check_error_type.rb"
require "#{$RCCLIB}/plan/predicates/try_it.rb"
