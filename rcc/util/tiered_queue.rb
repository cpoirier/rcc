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
module Util

 
 #============================================================================================================================
 # class TieredQueue
 #  - a tiered queue for managing pending Corrections

   class TieredQueue
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( tier_count = nil )
         @tiers = []
         @extend = tier_count.nil?
         
         unless tier_count.nil?
            tier_count.times do |index|
               @tiers[index] = []
            end
         end
         
         @length = 0
      end


      #
      # empty?()
      #  - returns true if the queue is empty
      
      def empty?()
         return @length == 0
      end
      
      
      #
      # clear()
      #  - clears the queue
      
      def clear()
         if @extend then
            @tiers.clear
         else
            @tiers.each do |tier|
               tier.clear
            end
         end
         
         @length = 0
      end
      

      #
      # queue()
      #  - adds the supplied object to the end of the specified tier
      
      def queue( object, tier_number )
         ensure_tiers( tier_number ) if @extend
         
         @length += 1
         @tiers[tier_number - 1] << object
      end
      
      
      #
      # queue_all()
      #  - queues up the supplied objects at the end of the specified tier
      #  - if you pass nil for tier_number, supply a block to calculate it from the object
      
      def queue_all( objects, tier_number = nil )
         objects.each do |object|
            if tier_number.nil? then
               calculated_tier_number = yield( object )
               queue( object, calculated_tier_number )
            else
               queue( object, tier_number )
            end
         end
      end
      
      
      #
      # insert()
      #  - adds the supplied object to the start of the specified tier
      
      def insert( object, tier_number )
         ensure_tiers(tier_number) if @extend
         
         @length += 1
         @tiers[tier_number - 1].unshift object
      end
            
      
      #
      # shift()
      #  - returns the next object from the queue
      
      def shift()
         @tiers.each do |tier|
            unless tier.empty?()
               @length -= 1
               return tier.shift
            end
         end
         
         return nil
      end


    protected
      
      def ensure_tiers( to )
         if to > @tiers.length then
            (to - @tiers.length).times do
               @tiers << []
            end
         end
      end
    
   
      
   end # TieredQueue
   


end  # module Util
end  # module Rethink
