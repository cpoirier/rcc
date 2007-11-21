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
      
      def initialize( complete_solutions, partial_solutions, exemplars )
         @complete_solutions = complete_solutions
         @partial_solutions  = partial_solutions
         
         @exemplars  = exemplars
         @valid      = (@complete_solutions.length == 1 and @complete_solutions[0].corrections_cost == 0)
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

      def report_errors( stream, degrade_factor = 1.0, explain_indent = nil )
         
         @error_list.each do |error|
            reliability = (error.reliability(degrade_factor) * 100).to_i
            chance      = reliability == 100 ? "" : " (#{reliability}% chance)"
            token       = error.error_token
            token_text  = '"' + token.to_s.gsub('"', '\\"') + '"'
            sample      = token.sample
            
            #
            # Output the error header.
            
            if token.type == token then
               stream.puts "Error#{chance}: unexpected #{token_text} at #{error.location}"
            else
               stream.puts "Error#{chance}: unexpected #{token.type} #{token_text} at #{error.location}"
            end
            
            #
            # Output a marked sample from the source error.
            
            stream.puts "   source: #{sample}"
            stream.puts "           " + (" " * (token.column_number - 1)) + ("^" * token.to_s.length)
            
            #
            # Output the recoveries.
            
            error.recoveries.each do |recovery|
               underline_extents = {}
               samples           = {}
               deltas            = {}
               
               #
               # Corrections can take place on any number of lines.  We'll prepare corrected samples for each.
               
               recovery.corrections.each do |correction|
                  line_number = correction.line_number
                  
                  unless samples.member?(correction.line_number)
                     samples[line_number]           = correction.sample.dup
                     underline_extents[line_number] = []
                     deltas[line_number]            = 0
                  end
                  
                  sample       = samples[correction.line_number]
                  extents      = underline_extents[correction.line_number]
                  delta        = deltas[line_number]
                  slice_from   = nil
                  slice_length = 0
                  old_text     = ""
                  text         = ""
                  prefix       = ""
                  suffix       = ""
                  
                  if correction.deletes_token? then
                     slice_from   = correction.deleted_token.column_number - 1
                     slice_length = correction.deleted_token.length
                     old_text     = correction.deleted_token.to_s
                  end
                  
                  if correction.inserts_token? then
                     slice_from    = correction.inserted_token.column_number - 1 if slice_from.nil?
                     inserted_type = correction.inserted_token.type
                     if @exemplars.member?(inserted_type) then
                        text = @exemplars[inserted_type]
                     else
                        text = inserted_type.to_s
                     end
                  end
                  
                  if text.length > 0 and text !~ /\s/ then
                     prefix = " " if slice_from > 0 and sample[delta + slice_from - 1, 1] !~ / /
                     suffix = " " if sample[delta + slice_from + slice_length, 1] !~ / /
                  end
                  
                  sample[slice_from + delta, slice_length] = "#{prefix}#{text}#{suffix}"
                  extents << [slice_from + delta + prefix.length, slice_from + delta + text.length]
                  
                  deltas[line_number] += prefix.length + text.length + suffix.length - old_text.length
               end
               
               #
               # Prep and output the corrected samples for this Recovery.

               highest_line_number = samples.keys.inject(0){|highest, line_number| max(highest, line_number)}
               width = highest_line_number.to_s.length
               same_line = (samples.length == 1 and samples.keys[0] == error.error_token.line_number)
               
               stream.puts "   option:" unless same_line
               samples.keys.sort.each do |line_number|
                  sample  = samples[line_number]
                  extents = underline_extents[line_number]
                  
                  underline = ""
                  extents.each do |extent|
                     underline << (" " * (extent[0] - underline.length))
                     underline << ("^" * (extent[1] - extent[0]))
                  end
                  
                  first_line = true
                  sample.split("\n").each do |line|
                     line.slice!(0, 1) if !first_line and line.slice(0, 1) == " "
                     line_underline = underline.slice!(0..(line.length+1))
                     if !first_line then
                        stream.puts "           #{line}"
                        stream.puts "           #{line_underline}"
                     elsif same_line then
                        stream.puts "   option: #{line}"
                        stream.puts "           #{line_underline}"
                     else
                        line_text = "line #{line_number.to_s.rjust(width)}"
                        spaces    = " " * line_text.length
                     
                        stream.puts "      #{line_text}: #{line}"
                        stream.puts "      #{spaces   }  #{line_underline}"
                     end
                     
                     first_line = false
                  end
               end
            end

            stream.puts ""
         end
         
         
         # @complete_solutions.each do |position|
         #    STDERR.puts ""
         #    STDERR.puts ""
         #    STDERR.puts ""
         #    STDOUT.puts "ABSTRACT SYNTAX TREE" 
         #    STDOUT.puts "===================="
         #    STDOUT.puts ""
         # 
         #    position.node.format().each do |line|
         #       STDERR.puts line
         #    end
         # end
         
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
         attr_reader :context_errors
         attr_reader :incoming_recovery_count
         attr_reader :context_recovery_count
         
         def initialize( recovery_context )
            @error_token             = recovery_context.next_token
            @signature               = recovery_context.signature
            @context_errors          = []
            @recoveries              = []
            @recovery_signatures     = []
            @ranks                   = []
            @incoming_recovery_count = 0
            @context_recovery_count  = 0
         end
         
         def location()
            return "#{@error_token.source_descriptor.descriptor} line #{@error_token.line_number}"
         end
         
         def add_recovery( corrections, next_error )
            recovery = Recovery.new( corrections, next_error )
            unless @recovery_signatures.member?(recovery.signature)
               @recoveries << recovery
               next_error.context_errors << self unless next_error.nil? or next_error.context_errors.member?(self)
            end
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
                        incoming_denominators << recovery.weight_denominator
                     end
                  end
               end
               
               @weight_denominator = incoming_denominators.inject(1){|product, denominator| product * denominator}
               @weight_numerator = 0
               incoming_numerators.length.times do |i|
                  @weight_numerator += incoming_numerators[i] * (@weight_denominator / incoming_denominators[i])
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
               recovery.next_error.assign_weight() unless recovery.next_error.nil?
            end
         end
         
         
         #
         # reliability()
         #  - returns a measure of "reliability" indicating how "sure" the recovery system is that this Error
         #    is a real error
         #  - pass degrade_factor to reduce the reliability of downline errors
         
         def reliability( degrade_factor = 1.0 )
            bug( "you must assign_weight() before you check reliability()" ) if @weight_numerator.nil? or @weight_denominator.nil?
            
            reliability = 1.0
            reliability = (@weight_numerator.to_f / @weight_denominator.to_f) unless @weight_numerator == 1 and @weight_denominator == 1
            reliability *= (degrade_factor ** (average_rank() - 1)) if degrade_factor != 1.0
            
            return reliability
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
         attr_reader   :signature
         
         def initialize( corrections, next_error )
            @corrections = corrections
            @next_error  = next_error
            @signature   = @corrections.collect{|correction| correction.signature}.join("|")
         end
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
            grouped_corrections.reverse.each do |group|
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
               error_registry[error_signature] = error_object
               
               #
               # Add any joined recoveries to the work_queue.
               
               error_position.joined_positions.each do |joined_position|
                  grouped_corrections = []
                  joined_position.corrections.each do |correction|
                     if grouped_corrections.empty? or correction.recovery_context.signature != grouped_corrections[-1][0].recovery_context.signature then
                        grouped_corrections << [correction]
                     else
                        grouped_corrections[-1] << correction
                     end
                  end
               
                  next_error = error_position
                  grouped_corrections.reverse.each do |group|
                     work_queue << [group[0].recovery_context, group, next_error]
                     next_error = group[0].recovery_context
                  end
               end
            end
            
            #
            # Add the corrections to the Error object.
            
            error_object.add_recovery( corrections, next_error_position.nil? ? nil : error_registry[next_error_position.signature] )
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
