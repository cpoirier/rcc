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
module Interpreter
module Artifacts
   
 
 #============================================================================================================================
 # class Solution
 #  - encapsulates the product of a Parser run
 #  - provides services on the data


   class Solution
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :error_map
      attr_reader :error_list
      
      def initialize( complete_solutions, partial_solutions )
         @complete_solutions = complete_solutions
         @partial_solutions  = partial_solutions
         
         @valid      = (@complete_solutions.length == 1 and @complete_solutions.corrections_cost == 0)
         @error_map  = map_errors()
         @error_list = order_errors()
      end
      
      
      #
      # valid?
      #  - returns true if the parse produced a single, valid solution (ie. encountered no errors)
      
      def valid?()
         return @valid
      end
      
      
      #
      # each_error()
      #  - calls your block for each Error in the error map, in source order
      
      def each_error()
      end
      
      
      #
      # report_errors()
      #  - generate and output error messages based on a list of complete and partial solutions produced by 
      #    the parser

      def report_errors( explain_indent = nil )
         
         @complete_solutions.each do |solution|
            STDOUT.puts "#{explain_indent}SOLUTION#{solution.original_error_position.joined_positions.empty? ? "" : " (has alternates)"}"
            solution.corrections.each do |correction|
               STDOUT.puts "#{explain_indent}#{correction.class.name}"
               STDOUT.puts "   #{explain_indent}   DELETE: #{correction.deleted_token.description}"  if correction.deletes_token?
               STDOUT.puts "   #{explain_indent}   INSERT: #{correction.inserted_token.description}" if correction.inserts_token?
               STDOUT.puts "   #{explain_indent}   #{correction.sample}"
            end
         end
         
         # #
         # # Display the results.
         # 
         # count = 0
         # @complete_solutions.each do |solution|
         #    count += 1
         #    
         #    STDOUT.puts ""
         #    STDOUT.puts ""
         #    STDOUT.puts "ABSTRACT SYNTAX TREE: #{solution.corrections_cost}" 
         #    STDOUT.puts "========================"
         #    STDOUT.puts ""
         #    
         #    solution.node.format().each do |line|
         #       STDOUT.puts line
         #    end
         # end
         # 
         # @partial_solutions.each do |solution|
         #    count += 1
         #    
         #    STDOUT.puts ""
         #    STDOUT.puts ""
         #    STDOUT.puts "PARTIAL SOLUTION: #{solution.corrections_cost}" 
         #    STDOUT.puts "========================"
         #    STDOUT.puts ""
         #    
         #    solution.display( STDOUT, "" )
         # end
         # 
         # STDERR.puts "   total output: #{count}"
      end






    #---------------------------------------------------------------------------------------------------------------------
    # Error/Recovery Mapping
    #---------------------------------------------------------------------------------------------------------------------


      #
      # class Error
      #  - marks a single "original" source error, and the set of recoveries used to get past it
      
      class Error
         attr_reader :error_token
         attr_reader :signature
         attr_reader :recoveries
         attr_reader :ranks
         attr_reader :incoming_recovery_count
         attr_reader :context_recovery_count
         
         def initialize( recovery_context )
            @error_token    = recovery_context.next_token
            @signature      = recovery_context.signature
            @context_errors = []
            @recoveries     = []
            @ranks          = []
            @reliability    = 1.0
            @incoming_recovery_count = 0
            @context_recovery_count  = 0
         end
         
         def add_recovery( corrections, next_error )
            nyi(" ")
            next_error.context_errors << self unless next_error.context_errors.member?(self)
         end
         
         def add_context( context_error )
            @context_errors << context_error
         end
         
         def average_rank()
            sum = @ranks.inject(0){|sum, rank| sum + rank}
            return sum / @ranks.length
         end
         
         #
         # assign_rank()
         #  - assigns a rank to this Error, measured as the distance from the root Error + 1
         #  - NOTE: depends on the the error map being acyclic
         
         def assign_rank( rank )
            unless @ranks.member?(rank)
               @ranks << rank
            
               @recoveries.each do |recovery|
                  unless recovery.next_error.nil?
                     recovery.next_error.assign_rank( rank + 1 )
                  end
               end
            end
         end
         
         #
         # assign_weight()
         #  - propagates a "weight" that indicates . . . . something
         
         def assign_weight( )
            
            #
            # Calculate the "incoming" weight.
            
            if @context_errors.empty? then
               @weight_numerator   = 1
               @weight_denominator = 1
            else
               incoming_numerators   = []
               incoming_denominators = []
               
               @context_errors.each do |context_error|
                  context_error.recoveries.each do |recovery|
                     if recovery.next_error == self then
                        incoming_numerators   << recovery.weight_numerator
                        incoming_denominators << recovery.incoming_denominators
                     end
                  end
               end
               
               @weight_denominator = incoming_denominators.inject(1){|product, denominator| product * denominator}
               @weight_denominator = 0
               incoming_numerators.length.times do |i|
                  @weight_denominator += incoming_numerators[i] * (@weight_denominator / incoming_denominators[i])
               end
            end
            
            #
            # Distribute the "outgoing" weight to our @recoveries.
            
            @recoveries.each do |recovery|
               recovery.weight_numerator   = @weight_numerator
               recovery.weight_denominator = @weight_denominator * @recoveries.length
            end
            
            #
            # Recurse.
            
            @recoveries.each do |recovery|
               recovery.next_error.assign_reliability()
            end
         end
         
         
         #
         # assign_reliability()
         #  - assigns a measure of "reliability" indicating how "sure" the recovery system is that this Error
         #    is a real error
         #  - pass degrade_factor to reduce the reliability of downline errors
         
         def assign_reliability( degrade_factor = 1.0 )
            if @weight_numerator == 1 and @weight_denominator == 1 then
               @reliability = 1.0
            else
               @reliability = (@weight_numerator / @weight_denomiator)
               @reliability *= (degrade_factor ** average_rank()) if degrade_factor != 1.0
            end
         end
         
      end
   
   
      #
      # class Recovery
      #  - a single recovery used to get past an Error
      #  - holds the set of Corrections that formm the Recovery
      
      class Recovery
         attr_reader   :corrections
         attr_reader   :next_error
         attr_accessor :weight_numerator
         attr_accessor :weight_denominator
         
      end
          
          
          
      #
      # map_errors()
      #  - builds a map of all the errors and recoveries in the solution
      
      def map_errors()
         return nil if valid?

         error_registry      = {}
         work_queue          = []
         root_error_position = nil
         
         (@complete_solutions + @partial_solutions).each do |final_position|
            
            root_error_position = final_position.node.corrections[0].recovery_context if root_error_position.nil?
            
            #
            # Group the corrections by recovery context.
            
            grouped_corrections = []
            final_position.node.corrections.each do |correction|
               if grouped_corrections.empty? or correction.recovery_context.signature != grouped_corrections[-1][0].recovery_context.signature then
                  grouped_corrections << [correction]
               else
                  grouped_corrections[-1] << correction
               end
            end
            
            #
            # Add them to the work queue: [error position, recoveries, next error position].
            
            next_error = nil
            group_corrections.reverse.each do |group|
               work_queue << [group[0].recovery_context, group, next_error]
               next_error = group[0].recovery_context
            end
         end
         
         
         #
         # Process the work_queue, building Errors and Recoveries at each step.  For the first
         # time we see any given error position, process any joined recoveries.
         
         until work_queue.empty?
            error_position, corrections, next_error_position = work_queue.shift
            error_signature = error_position.signature
            error_object    = nil
            
            #
            # Find/create the Error object for the current error.
            
            if error_registry.member?(error_signature) then
               error_object = error_registry[error_signature]
            else
               error_object = Error.new( error_position )
               
               #
               # Add any joined recoveries to the work_queue.
               
               error_position.joined_positions.each do |joined_position|
                  grouped_corrections = []
                  joined_position.node.corrections.each do |correction|
                     if grouped_corrections.empty? or correction.recovery_context.signature != grouped_corrections[-1][0].recovery_context.signature then
                        grouped_corrections << [correction]
                     else
                        grouped_corrections[-1] << correction
                     end
                  end

                  next_error = error_position
                  group_corrections.reverse.each do |group|
                     work_queue << [group[0].recovery_context, group, next_error]
                     next_error = group[0].recovery_context
                  end
               end
            end
            
            #
            # Add the corrections to the Error object.
            
            error_object.add_recovery( corrections, next_error_position ) 
         end
         
         
         #
         # Pick and return the root Error, after generating some additional statistics.
         
         root_error = error_registry[root_error_position.signature]
         root_error.assign_rank( 1 )
         root_error.assign_weight()

         return root_error
      end
      
      
      
      #
      # order_errors()
      #  - generates a list of Errors in source order
      
      def order_errors()
         
         #
         # First up, flatten the error map to a list of unique Errors.
         
         errors = []
         work_queue = [@error_map]
         until work_queue.empty?
            error = work_queue.shift
            error.recoveries.each do |recovery|
               work_queue << recovery.next_error unless recovery.next_error.nil? or errors.member?(recovery.next_error)
            end
            
            errors << error unless errors.member?(error)
         end
         
         #
         # Sort and return the error list.
         
         errors.sort{|a, b| a.error_token.start_position <=> b.error_token.start_position }
         
         return errors
      end
      
      
      
   end # Solution
   


end  # module Artifacts
end  # module Interpreter
end  # module Rethink
