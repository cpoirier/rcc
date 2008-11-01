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
require "#{$RCCLIB}/plan/symbol.rb"
require "#{$RCCLIB}/plan/production.rb"
require "#{$RCCLIB}/scanner/artifacts/name.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class TokenProduction
 #  - a single compiled lexical Form, ready for use in the Plan

   class TokenProduction < Production
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      def initialize( number, name, symbols, tokenizeable = false, master_plan = nil )
         super( number, name, symbols, master_plan )
         @tokenizeable = tokenizeable
      end

      def tokenizeable?()
         return @tokenizeable
      end
      
      #
      # occlude()
      #  - returns a version of this TokenProduction with the first CharacterRange occluded by the supplied range
      #  - has no effect if the first isn't a CharacterRange
      
      def occlude( range, master_plan = nil )
         return self if @symbols[0].symbolic?
         
         bug( "huh?" ) if master_plan.nil?
         
         remaining = @symbols[0] - range
         if remaining.empty? then
            return nil
         elsif remaining == @symbols[0] then
            return self            
         else
            return self.class.new( @number, @name, [remaining] + @symbols.slice(1..-1), @tokenizeable, master_plan.nil? ? @master_plan : master_plan )
         end
      end
      
      
   end # TokenProduction
   




end  # module Plan
end  # module RCC
