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

      def initialize( complete_solutions, partial_solutions )
         @complete_solutions = complete_solutions
         @partial_solutions  = partial_solutions
      end
      
      
      #
      # valid?
      #  - returns true if the parse produced a single, valid solution (ie. encountered no errors)
      
      def valid?()
         return (@complete_solutions.length == 1 and @complete_solutions[0].corrections_cost == 0)
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
      
      
      
   end # Solution
   


end  # module Artifacts
end  # module Interpreter
end  # module Rethink
