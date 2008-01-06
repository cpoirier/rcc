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
module Util

 
 #============================================================================================================================
 # class RecursionLoopDetector
 #  - provides services to code that traverses pointer graphs
 #  - detects recursion loops with the intention that the caller will return immediately on such detection
 #  - knows which calls received incomplete results because of this shortcutting

   class RecursionLoopDetector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
         @order   = []    # Maintained as a reversed stack (working point at the front, instead of at the back)
         @entries = {}    # scope => complete results flag
      end
      
      
      #
      # enter()
      #  - tells the monitor a scope is being entered
      #  - returns false (and does not mark the entry) if the entry would cause a loop
      
      def enter( scope )
         
         #
         # If the scope has already been entered, it is going to have to shortcut out.  This means that anybody who
         # called it is going to get incomplete results, until the successful entry of that same scope (further up the 
         # stack) exits.  We mark this in entries.
         
         if @entries.member?(scope) then
            @order.each do |item|
               break if item == scope
               @entries[item] = false
            end
            return false
         else
            @entries[scope] = true
            @order.unshift( scope )
            return true
         end
      end
      
      
      #
      # exit()
      #  - tells the monitor a scope is exiting (only call this if enter() returned true)
      #  - returns false if the data the entry collected is incomplete (because a child call shortcutted out)
      
      def exit( scope )
         bug( "exit() does not match last enter()" ) unless scope == @order[0]
         @order.shift()
         return @entries.delete(scope)
      end
      
      
      #
      # monitor()
      #  - calls enter() and exit() appropriately around your block
      #  - does not call your block at all if enter() fails
      #  - returns nil if your block was never called; returns the exit() result, otherwise
      
      def monitor( scope )
         complete = nil
         
         if enter(scope) then
            begin
               yield()
            ensure
               complete = exit( scope )
            end
         end
         
         return complete
      end
      
      
      
   end # RecursionMonitor
   


end  # module Util
end  # module RCC
