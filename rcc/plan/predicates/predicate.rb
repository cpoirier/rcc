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
module Predicates

 
 #============================================================================================================================
 # class Predicate
 #  - base class for recovery option Predicates

   class Predicate
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
      end

      def to_s()
         return self.class.name
      end
      
      def display( stream, explain_indent = "" )
         stream << explain_indent << self.to_s << "\n" unless explain_indent.nil?
      end
      

      
   end # Predicate
   


end  # module Predicates
end  # module Plan
end  # module Rethink




 
require "#{$RCCLIB}/plan/predicates/check_context.rb"
require "#{$RCCLIB}/plan/predicates/check_error_type.rb"
require "#{$RCCLIB}/plan/predicates/try_it.rb"
