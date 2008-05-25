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
      attr_reader   :discard_symbols



      def initialize( name, master_form, discard_symbols = [], transformations = [] )
         type_check( name, Scanner::Artifacts::Name, false )
         
         @name            = name
         @master_form     = master_form
         @slots           = Util::OrderedHash.new()     # name => Slot
         @transformations = []
         @associativity   = nil         
         @priority        = 0
         @transformations = []
         @discard_symbols = discard_symbols
         
         @has_pluralized_slots = false
      end
      
      
      def register_direct_slot( name, object )
         @slots[name] = Slot.new( name, self ) unless @slots.member?(name)
         @slots[name].add_source( object )
      end
      
      
      def register_plural_import( name, object, imported_slot_name )
         type_check( object, Markers::Reference )
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
      #  - passes in the tree slot name, the PluralSubrule rule governing that slot, the (singular) name of the 
      #    source slot from that PluralSubrule, and the (plural) name of the destination slot in this Rule
      
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
         stream.puts "rule #{@name} priority #{@priority}"
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
   
   
   
   
   
   
   
 #============================================================================================================================
 # class Subrule
 #  - represents a subrule that has been factor out for repeating
 
   class Subrule < Rule
      
      Optional = Util::ExpressionForms::Optional
      Sequence = Util::ExpressionForms::Sequence
            
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :rule_form
      attr_reader :singular_form
      
      def initialize( name, singular_form, discard_symbols )
         @singular_form   = singular_form
         
         tree_side = Markers::Reference.new( name )
         rule_form = Sequence.new( Optional.new(tree_side), @singular_form )
         super( name, rule_form, discard_symbols )

         # BUG: this prevents effectively slotless Subrules from being discarded internally, and maybe should be fixed
         tree_side.set_slot_name( self, "__tree" )
      end
      
      
      # def reference( optional = true )
      #    return Markers::SubruleReference.new( self, optional )
      # end
      
      
      def has_slots?()
         return @slots.length > 1
      end
      
      
   end # Subrule
   
   
   
   


end  # module Elements
end  # module Model
end  # module RCC

require "#{$RCCLIB}/model/model.rb"
