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
 # class TrailMarker
 #  - provides services to code that traverses pointer graphs
 #  - detects recursion loops with the intention that the caller will return immediately on such detection
 #  - knows which calls received incomplete results because of this shortcutting

   class TrailMarker
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
         @order   = []    # Maintained as a reversed stack (working point at the front, instead of at the back)
         @entries = {}    # scope => complete results flag
         @marks   = {}    # scope => objects marked in that scope
         @origins = {}    # object => scope where the object was marked
      end
      
      
      #
      # enter()
      #  - tells the monitor a scope is being entered
      #  - returns false (and does not mark the entry) if the entry would cause a loop
      #  - if you pass a block, it will be called between an enter() and exit() call
      #     - in this case, returns nil if your block was never called, returns exit() result otherwise
      
      def enter( scope )
         
         #
         # If a block is given, we enclose the content in a enter()/exit() pair and return completeness.
         
         if block_given? then
            complete = nil

            if enter(scope) then
               begin
                  yield()
               ensure
                  complete = exit( scope )
               end
            end

            return complete

            
         #
         # Otherwise, we just try to enter the scope and return a flag indicating if we succeeded.
         
         else
            
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
      # mark()
      #  - marks an object as visited by your graph-walker
      #  - returns false if the object has already been visited
      #  - alters exit() codes appropriately where the failure should cause incomplete results
      
      def mark( object, affects_completeness = true )
         
         marked = false
         
         #
         # It the object has already been marked, then this pass won't be processing it 
         # again, and will be producing incomplete results.  Find the origin, and if it is
         # still in play, mark all scopes up to (but not including) it incomplete.  If it
         # isn't in play, mark everything on the stack incomplete, up to (but not including)
         # the first scope from the marks list that is still in play.

         if @origins.member?(object) then
            origin = @origins[object]
            if @entries.member?(origin) then
               @order.each do |item|
                  break if item == origin
                  @entries[item] = false
               end
            else
               complete_in = nil
               @marks[object].each do |item|
                  if @entries.member?(item) then
                     complete_in = item
                     break
                  end
               end
               
               @order.each do |item|
                  break if item == complete_in
                  @entries[item] = false
               end
            end
            
         #
         # Otherwise, it is virgin territory, and we mark its origin, and all scopes in which
         # it has been covered (all currently on the order stack).
         
         else
            @origins[object] = @order[0]
            @order.each do |scope|
               @marks[object] = [] + @order
            end
            
            marked = true
         end
         
         return marked
      end
      
      
      
   end # TrailMarker
   


end  # module Util
end  # module RCC
