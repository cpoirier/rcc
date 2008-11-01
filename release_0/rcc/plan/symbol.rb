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
 # class Symbol
 #  - the Plan's idea of a Symbol; it's analogous to the Model Symbol, but simpler

   class Symbol
      
      @@end_of_input_symbol = nil
      
      def self.end_of_input()
         @@end_of_input_symbol = new( nil, true ) if @@end_of_input_symbol.nil?
         return @@end_of_input_symbol
      end
      
      @@types = [:production, :group, :token, :sequence]
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :name
      attr_reader   :type
      attr_reader   :gateways
      attr_accessor :commit_point
      
      def initialize( name, type, gateways = [] )
         type_check( name, Scanner::Artifacts::Name )
         assert( @@types.member?(type), "type is invalid" )
         
         @name         = name
         @type         = type
         @gateways     = [] + gateways       # A list of symbols to discard (if present) before reading this Symbol
         @commit_point = nil
      end
      
      def symbolic?()
         return true
      end
      
      def refers_to_token?()
         @type == :token
      end
      
      def refers_to_producible_token?()
         (@type == :token and !@name.eof?)
      end
      
      def refers_to_production?()
         @type == :production
      end
      
      def refers_to_group?()
         @type == :group
      end
      
      def refers_to_sequence?()
         @type == :sequence
      end
      
      def refers_to_character?()
         return false
      end
      
      def lexical?()
         @type == :sequence
      end
      
      def syntactic?()
         @type == :production || @type == :group || @type == :token
      end
      
      def producible?()
         return @type == :production || @type == :sequence || (@type == :token and !@name.eof?)
      end
      
      def token_names( master_plan )
         case @type
         when :token
            return [@name]
         when :production
            return []
         when :group
            names = []
            master_plan.group_members[@name].each do |member|
               names << member.name if member.refers_to_token?
            end
            
            return names
         end
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
      
      def signature()
         return @name.signature
      end
      
      def full_description( elide_grammar = nil )
         if @gateways.empty? then
            return @name.description(elide_grammar)
         else
            return @gateways.collect{|gw| "!" + gw.description(elide_grammar)}.join(" ") + " " + @name.description(elide_grammar)
         end
      end
      
      def description(elide_grammar = nil)
         return @name.description(elide_grammar)
      end      
      
      def hash()
         return signature().hash
      end
      
      def ==( rhs )
         return false unless rhs.is_a?(Symbol)
         return @type == rhs.type && @name == rhs.name
      end
      
      def eql?( rhs )
         if rhs.is_a?(Symbol) then
            return @type == rhs.type && @name == rhs.name
         else
            return @name == rhs 
         end
      end
      
      
      def to_s()
         return signature()
      end
      
      # def eql?( rhs )
      #    return false unless rhs.is_a?(Plan::Symbol)
      #    return signature() == rhs.signature
      # end
      # 
      # def to_s()
      #    return (@refers_to_token ? "lex" : "parse") + ":" + (@symbol_name.nil? ? "$" : (@grammar_name + "." + @symbol_name))
      # end
      # 
      # def self.describe( name )
      #    return "$" if name.nil?
      #    return name.to_s
      # end
      
      
   end # Symbol
   


   


end  # module Plan
end  # module RCC
