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
require "#{$RCCLIB}/util/recursion_loop_detector.rb"

module RCC
module Model
module Elements

 
 #============================================================================================================================
 # class Rule
 #  - a rule in the grammar
 #  - when generating output, each Rule will produce one ASN and its slots

   class Rule
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader   :name              # The name of this rule
      attr_reader   :master_form       # An unflattened ExpressionForm capturing the structure of this rule
      attr_reader   :id_number         # The id number of this rule within the entire grammar
      attr_reader   :slots
      attr_accessor :associativity 
      attr_accessor :priority 
      attr_accessor :transformations  

      def initialize( name, master_form, transformations = [] )
         type_check( name, Scanner::Artifacts::Name, false )
         
         @name            = name
         @master_form     = master_form
         @slots           = Util::OrderedHash.new()     # name => Slot
         @transformations = []
         @associativity   = nil         
         @priority        = 0
         @transformations = []
         
         @has_pluralized_slots = false
      end
      
      
      def generate_pluralization_()
         slots.each do |name, slot|
            slot.each_pluralization() do |pluralization, source_slot|
               
            end
         end
      end
      
      
      def register_direct_slot( name, object )
         @slots[name] = Slot.new( name, self ) unless @slots.member?(name)
         @slots[name].add_source( object )
      end
      
      
      def register_plural_import( name, object, imported_slot_name )
         type_check( object, Markers::PluralizationReference )
         @slots[name] = Slot.new( name, self ) unless @slots.member?(name)
         @slots[name].add_pluralization_import( object, imported_slot_name )
         @has_pluralized_slots = false
      end
      
      
      def has_slots?()
         return !@slots.empty?
      end
      
      
      def has_pluralized_slots?()
         return @has_pluralized_slots
      end
      
      
      #
      # each_plural_import()
      #  - calls your block once for each plural import
      #  - passes in the tree slot name, the Pluralization rule governing that slot, the (singular) name of the 
      #    source slot from that Pluralization, and the (plural) name of the destination slot in this Rule
      
      def each_plural_import()
         @slots.each do |name, slot|
            slot.each_pluralized_source do |tree_slot, pluralization, source_slot|
               
               
               
               
               yield( tree_slot, pluralization, source_slot, name )
            end
         end
      end
      
      
      
      
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "Rule #{@name}"
      end

      def display( stream = $stdout )
         stream.puts "rule #{@name}"
         stream.indent do
            @master_form.display( stream )
            
            additional_slots = @slots.values.select {|slot| !slot.direct_sources_only?}
            unless additional_slots.empty?
               stream.puts "additional slots:"
               stream.indent do
                  additional_slots.each do |slot|
                     slot.display_indirect_sources( stream )
                  end
               end
            end
            
            unless @transformations.empty?
               stream.puts "transformations:"
               stream.indent do
                  @transformations.each do |transformation|
                     stream << transformation
                  end
               end
            end
         end
         
      end
      
   end # Rule
   


end  # module Elements
end  # module Model
end  # module RCC

require "#{$RCCLIB}/model/model.rb"
