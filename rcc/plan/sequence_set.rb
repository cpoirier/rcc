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
module Plan

 
 #============================================================================================================================
 # class SequenceSet
 #  - a set of one or more Symbol sequences (arrays of Symbols)
 #  - provides set-oriented manipulation 

   class SequenceSet
      
      
      #
      # ::single()
      #  - convenience factory, builds a SequenceSet with only one sequence
      
      def self.single( sequence )
         return SequenceSet.new( [sequence] )
      end
      
      
      #
      # ::merge()
      #  - given an array of SequenceSets, produces a single SequenceSet with all the members
      
      def self.merge( sets )
         merged = SequenceSet.new()
         sets.each do |set|
            type_check( set, SequenceSet )
            set.sequences.each do |sequence|
               merged << sequence
            end
         end
         
         return merged
      end
      
      
      #
      # ::end_of_input_set()
      #  - returns a set with only the end_of_input Symbol
      
      @@end_of_input_set = nil
      
      def self.end_of_input_set()
         @@end_of_input_set = SequenceSet.new( [[Symbol.end_of_input]] ) if @@end_of_input_set.nil?
         return @@end_of_input_set
      end
      
      
      #
      # ::empty_set()
      #  - returns a set with no sequences
      
      @@empty_set = nil
      
      def self.empty_set()
         @@empty_set = SequenceSet.new() if @@empty_set.nil?
         return @@empty_set
      end



    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :sequences
      
      def initialize( sequences = [], unique = true )
         @sequences  = []
         @signatures = unique ? {} : nil
         @lookahead  = nil
         
         sequences.each do |sequence|
            add_sequence( sequence )
         end
      end
      
      def length()
         if @sequences.empty? then
            return 0
         else
            return @sequences[0].length
         end
      end
      
      def add_sequence( sequence )
         if @signatures.nil? then
            @sequences << sequence
         else
            signature = sequence.collect{|symbol| symbol.signature}.join( " " )
            unless @signatures.member?(signature)
               @sequences << sequence
               @signatures[signature] = sequence
            end
         end
         
         @lookahead = nil
      end
      
      def <<( sequence )
         add_sequence( sequence )
      end
      
      
      #
      # prefix()
      #  - returns a SequenceSet with each sequence in this set prefixed by the symbols in your sequence
      
      def prefix( sequence )
         return SequenceSet.new( @sequences.collect{|old_sequence| sequence + old_sequence} )
      end
      
      
      #
      # slice()
      #  - returns a SequenceSet with a slice of the individual sequences in this set
      
      def slice( *parameters )
         set = SequenceSet.new()
         
         @sequences.each do |sequence|
            set << sequence.slice( *parameters )
         end
         
         return set
      end


      #
      # to_s()
      
      def to_s()
         
      end



    #---------------------------------------------------------------------------------------------------------------------
    # Services
    #---------------------------------------------------------------------------------------------------------------------
    
      #
      # lookahead()
      #  - returns a set of all token Symbols that can start any of the sequences in this set
      
      def lookahead( master_plan, loop_detection=[] )
         return @lookahead unless @lookahead.nil? 
         return [] if loop_detection.member?(self.object_id)
         
         lookahead = {}
         @sequences.collect{|sequence| sequence[0]}.each do |start_symbol|
            if start_symbol.refers_to_token? then
               lookahead[start_symbol.signature] = start_symbol
            else
               if set = master_plan.production_sets[start_symbol.name] then
                  set.lookahead(master_plan, loop_detection + [self.object_id]).each do |lookahead_symbol|
                     lookahead[lookahead_symbol.signature] = lookahead_symbol
                  end
               end
               
               if start_symbol.refers_to_group? then
                  master_plan.group_members[start_symbol.name].each do |member_symbol|
                     if member_symbol.refers_to_token? then
                        lookahead[member_symbol.signature] = member_symbol
                     end
                  end
               end
            end
         end
         
         @lookahead = lookahead.values
         return @lookahead
      end
      
    

       
   end # SequenceSet
   


end  # module Plan
end  # module RCC
