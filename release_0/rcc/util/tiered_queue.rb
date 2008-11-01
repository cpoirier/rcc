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
      
      def queue( object, tier_index )
         ensure_tiers( tier_index ) if @extend
         
         @length += 1
         @tiers[tier_index] << object
      end
      
      
      #
      # queue_all()
      #  - queues up the supplied objects at the end of the specified tier
      #  - if you pass nil for tier_index, supply a block to calculate it from the object
      
      def queue_all( objects, tier_index = nil )
         objects.each do |object|
            if tier_index.nil? then
               calculated_tier_index = yield( object )
               queue( object, calculated_tier_index )
            else
               queue( object, tier_index )
            end
         end
      end
      
      
      #
      # insert()
      #  - adds the supplied object to the start of the specified tier
      
      def insert( object, tier_index )
         ensure_tiers(tier_index) if @extend
         
         @length += 1
         @tiers[tier_index].unshift object
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
      
      
      #
      # first()
      #  - returns the next object from the queue WITHOUT removing it from the queue
      
      def first()
         @tiers.each do |tier|
            unless tier.empty?()
               return tier[0]
            end
         end
         
         return nil
      end
      


    protected
      
      def ensure_tiers( index )
         if index >= @tiers.length then
            (index + 1 - @tiers.length).times do
               @tiers << []
            end
         end
      end
    
   
      
   end # TieredQueue
   


end  # module Util
end  # module RCC
