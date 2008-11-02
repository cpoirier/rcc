#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright 2007-2008 Chris Poirier (cpoirier@gmail.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the 
# License.  You may obtain a copy of the License at
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" 
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language 
# governing permissions and limitations under the License.
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/system/")[0..-2].join("/system/")}/system/environment.rb"

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
         @leaders    = nil
         @lookahead  = nil
         @lexical_lookahead = nil
         
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
      # leaders()
      #  - returns an array of Symbols that lead this sequence set
      
      def leaders()
         @leaders = @sequences.select{|sequence| !sequence.empty?}.collect{|sequence| sequence[0]} if @leaders.nil?
         return @leaders
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
      
      def lookahead( master_plan, loop_detection=[], already_done={} )
         return @lookahead unless @lookahead.nil? 
         return [] if loop_detection.member?(self.object_id)

         complete  = already_done.empty?
         lookahead = {}
         
         # @sequences.select{|sequence| !sequence.empty?}.collect{|sequence| sequence[0]}.each do |start_symbol|
         warn_bug( "does uniq work with SequenceSet.leaders()?" )
         leaders().each do |start_symbol|
            next if already_done.member?(start_symbol.name)
            already_done[start_symbol.name] = true
            
            if start_symbol.refers_to_token? then
               lookahead[start_symbol.signature] = start_symbol
            else
               if set = master_plan.production_sets[start_symbol.name] then
                  set.lookahead(master_plan, loop_detection + [self.object_id], already_done).each do |lookahead_symbol|
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
         
         if complete then
            @lookahead = lookahead.values
            return @lookahead
         else
            return lookahead.values
         end
      end
      
      
      def lexical_lookahead( master_plan, loop_detection=[], already_done={} )
         return @lexical_lookahead unless @lexical_lookahead.nil? 
         return [] if loop_detection.member?(self.object_id)

         complete  = already_done.empty?
         lookahead = CharacterRange.new()

         # @sequences.select{|sequence| !sequence.empty?}.collect{|sequence| sequence[0]}.each do |start_symbol|
         warn_bug( "does uniq work with SequenceSet.leaders()?" )
         leaders().each do |start_symbol|
            if start_symbol.refers_to_character? then
               lookahead += start_symbol
            else
               next if already_done.member?(start_symbol.name)
               already_done[start_symbol.name] = true

               if set = master_plan.production_sets[start_symbol.name] then
                  lookahead += set.lexical_lookahead( master_plan, loop_detection + [self.object_id], already_done )
               end
            end
         end

         @lexical_lookahead = lookahead if complete
         return lookahead
      end
    


      
      
      # #
      # # Known working versions, without optimizations.
      # 
      # 
      # #
      # # lookahead()
      # #  - returns a set of all token Symbols that can start any of the sequences in this set
      # 
      # def lookahead( master_plan, loop_detection=[] )
      #    return @lookahead unless @lookahead.nil? 
      #    return [] if loop_detection.member?(self.object_id)
      #    
      #    if loop_detection.empty? then
      #       puts ""
      #       puts ""
      #       puts "======================="
      #    end
      #    
      #    lookahead = {}
      #    @sequences.select{|sequence| !sequence.empty?}.collect{|sequence| sequence[0]}.each do |start_symbol|
      #       p "#{object_id}.lookahead: #{start_symbol}"
      #       if start_symbol.refers_to_token? then
      #          lookahead[start_symbol.signature] = start_symbol
      #       else
      #          if set = master_plan.production_sets[start_symbol.name] then
      #             set.lookahead(master_plan, loop_detection + [self.object_id]).each do |lookahead_symbol|
      #                lookahead[lookahead_symbol.signature] = lookahead_symbol
      #             end
      #          end
      #       
      #          if start_symbol.refers_to_group? then
      #             master_plan.group_members[start_symbol.name].each do |member_symbol|
      #                if member_symbol.refers_to_token? then
      #                   lookahead[member_symbol.signature] = member_symbol
      #                end
      #             end
      #          end
      #       end
      #    end
      #    
      #    @lookahead = lookahead.values
      #    return @lookahead
      # end
      # 
      # 
      # def lexical_lookahead( master_plan, loop_detection=[] )
      #    return @lexical_lookahead unless @lexical_lookahead.nil? 
      #    return [] if loop_detection.member?(self.object_id)
      #    
      #    if loop_detection.empty? then
      #       puts ""
      #       puts ""
      #       puts "======================="
      #    end
      #    
      #    duration = Time.measure do
      #       lookahead = CharacterRange.new()   # can uniq always be applied?
      #       @sequences.select{|sequence| !sequence.empty?}.collect{|sequence| sequence[0]}.each do |start_symbol|
      #          p "#{object_id}.lexical_lookahead: #{start_symbol}"
      #          if start_symbol.refers_to_character? then
      #             lookahead += start_symbol
      #          else
      #             if set = master_plan.production_sets[start_symbol.name] then
      #                $stdout.indent do 
      #                   set.lexical_lookahead(master_plan, loop_detection + [self.object_id]).each do |lookahead_symbol|
      #                      lookahead += lookahead_symbol
      #                   end
      #                end
      #             end
      #          end
      #       end
      #    
      #       @lexical_lookahead = lookahead
      #    end
      #    
      #    puts "#{object_id()}.lexical_lookahead took #{duration}s"
      #    if duration > 0.1 then
      #       @sequences.each do |sequence|
      #          next if sequence.empty?
      #          puts sequence[0]
      #       end
      #    end
      #    return @lexical_lookahead
      # end
      #     
      
       
   end # SequenceSet
   


end  # module Plan
end  # module RCC
