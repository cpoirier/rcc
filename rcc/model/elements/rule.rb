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
    
      attr_reader   :name         # The name of this rule
      attr_reader   :master_form  # An unflattened ExpressionForm capturing the structure of this rule
      attr_reader   :id_number    # The id number of this rule within the entire grammar
      attr_reader   :forms        # The Forms in this Rule (this is where the real data is)
      attr_accessor :associativity 
      attr_accessor :priority   

      def initialize( name, master_form )
         type_check( name, Scanner::Artifacts::Name, false )
         
         @name            = name
         @master_form     = master_form
         @slots           = Util::OrderedHash.new()     # name => Slot
         @forms           = nil
         @transformations = []
         @associativity   = nil
         @priority        = 0
      end
      
      
      def register_direct_slot( name, object )
         @slots[name] = Slot.new( name, self ) unless @slots.member?(name)
         @slots[name].add_source( object )
      end
      
      
      def register_plural_import( name, object, imported_slot_name )
         type_check( object, References::PluralizationReference )
         @slots[name] = Slot.new( name, self ) unless @slots.member?(name)
         @slots[name].add_pluralization_import( object, imported_slot_name )
      end


      def has_slots?()
         return !@slots.empty?
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
         end
         
      end
      
   end # Rule
   


end  # module Elements
end  # module Model
end  # module RCC

require "#{$RCCLIB}/model/model.rb"
