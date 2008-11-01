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
require "#{$RCCLIB}/plan/symbol.rb"
require "#{$RCCLIB}/plan/production.rb"
require "#{$RCCLIB}/scanner/artifacts/name.rb"


module RCC
module Plan

 
 #============================================================================================================================
 # class SyntaxProduction
 #  - a single compiled syntactic Form, ready for use in the Plan

   class SyntaxProduction < Production
      
      
      def self.start_production( start_rule_name, discards = [] )
         symbols = [Plan::Symbol.new(start_rule_name, :production), Plan::Symbol.new(Scanner::Artifacts::Name.end_of_file_type, :token)]
         slots   = [nil, nil]
         
         return self.new( 0, Scanner::Artifacts::Name.any_type, symbols, slots, nil, 0, nil, discards, false )
      end
      
      
      def start_version()
         symbols = @symbols + [Plan::Symbol.new(Scanner::Artifacts::Name.end_of_file_type, :token)]
         slots   = @slots   + [nil]
         
         return self.class.new( @number, @name, symbols, slots, @associativity, @priority, @ast_class, @discards, @generate_error_recoveries )
      end
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :slots                  # A slot name or nil for each Symbol
      attr_reader   :associativity          # nil, :left, :right, or :none
      attr_reader   :priority
      attr_reader   :discards
      attr_accessor :ast_class
      attr_writer   :commit_point

      def initialize( number, name, symbols, slots, associativity, priority, ast_class, discards, generate_error_recoveries, master_plan = nil )
         super( number, name, symbols, master_plan )

         @slots         = slots
         @associativity = associativity
         @priority      = priority
         @ast_class     = ast_class
         @commit_point  = nil
         @discards      = discards
                  
         @generate_error_recoveries = generate_error_recoveries
      end
      
      def syntactic?()
         return true
      end
      
      def generate_error_recoveries?()
         return @generate_error_recoveries
      end
      
      def commit_point?()
         !@commit_point.nil?
      end
      
      def local_commit_point?()
         @commit_point == :local
      end
      
      def global_commit_point?()
         @commit_point == :global
      end
      
      
      #
      # new_transfer_version()
      #  - returns a copy of this production with an additional (disposable) symbol inserted at some point
      #  - registers the new production with the master_plan, if you pass it
      
      def new_transfer_version( symbol, at, master_plan = nil )
         symbols = @symbols.dup()
         symbols[at, 0] = symbol
         
         slots = nil
         if @slots then
            slots = @slots.dup()
            slots[at, 0] = nil
         end
         
         transfer_version = self.class.new( -1, @name, symbols, slots, :left, @priority, @ast_class, false, @master_plan )
         
         if master_plan then
            return master_plan.register_transfer_production( transfer_version )
         else
            return transfer_version
         end
      end
      
      
      def display( stream = $stdout )
         stream.puts "#{@name} =>"
         stream.indent do
            length().times do |i|
               stream << @symbols[i].description
               stream.puts( @slots[i].nil? ? ", then discard" : ", store in #{@slots[i]}" )  
            end
            stream.puts( "Discarded symbols: " + @discards.join(", ") )
         end
      end
      
      
   end # SyntaxProduction
   





end  # module Plan
end  # module RCC
