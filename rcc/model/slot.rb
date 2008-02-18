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

 
 #============================================================================================================================
 # class Slot
 #  - represents a single slot within a Rule, and tracks the stuff that can be written there on its behalf

   class Slot
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :name              # The name of this slot
      attr_reader :context           # The Rule this slot is part of
      attr_reader :sources           # A list of *Reference or [PluralizationReference, slot name] or Transformation that write to this slot
      
      def initialize( name, context_rule )
         assert( name.exists?, "you have to name the slot" )
         
         @name    = name
         @context = context_rule
         @sources = []
      end
      
      
      def add_source( source )
         @sources << source unless @sources.member?(source)
      end
      
      
      def add_pluralization_import( pluralizer_reference, aggregated_slot_name )
         assert( aggregated_slot_name.exists?, "you have to name the imported slot" )
         
         source = [pluralizer_reference, aggregated_slot_name]
         add_source( source )
      end
      
      
      
      def direct_sources_only?()
         direct_only = true
         @sources.each do |source|
            warn_nyi( "direct_source_only? exclusion of transformations" )
            if source.is_an?(Array) then
               direct_only = false
               break
            end
         end
         
         return direct_only
      end
      
      
      def indirect_sources()
         return @sources.select {|source| source.is_an?(Array) }
      end
      
      
      
      def display( stream = $stdout )
         nyi( nil )
      end
      
      
      def display_indirect_sources( stream = $stdout )
         if sources = indirect_sources() then
            stream << @name << ": "
            stream.end_line if sources.length > 1
            stream.indent do
               sources.each do |source|
                  case source
                     when Array
                        stream.puts "list of [#{source[1]}] collected from [#{source[0].slot_name}]"
                     else
                        nyi( nil )
                  end
               end
            end
         end
      end
      
      
   end # Slot
   
   
   


 #============================================================================================================================
 # module SlotInfo
 #  - provides common machinery for rule elements that reference other Model elements by name

   module SlotInfo
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :context_rule
      attr_reader :slot_name
      

      #
      # set_slot_name()

      def set_slot_name( context_rule, slot_name )
         assert( @context_rule.nil? , "you cannot assign a second rule context to the same element" )
         assert( @slot_name.nil?    , "you cannot assign a second slot name to the same element"    )
         
         @context_rule = context_rule
         @slot_name    = slot_name
         
         @context_rule.register_direct_slot( slot_name, self )
      end
      
      
      #
      # slot_info()
      
      def slot_info( prefix = " as ", postfix = "" )
         return @slot_name.exists? ? "#{prefix}#{@slot_name}#{postfix}" : ""
      end
      
      
      #
      # display_slot_info()
       
      def display_slot_info( stream = $stdout )
         slot_info = slot_info("as ", ":")
         if slot_info.exists? and !slot_info.empty? then
            stream.end_line
            stream.puts slot_info
            stream.indent do
               yield()
            end
         else
            yield()
         end
      end
      
   end # SlotInfo

   

end  # module Model
end  # module RCC
