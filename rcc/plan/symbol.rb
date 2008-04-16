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
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :name
      attr_reader   :prefilter
      attr_accessor :commit_point
      
      def initialize( name, type, prefilter = nil )
         assert( type == :token || type == :production || type == :group || type == :discarder, "type is invalid" )
         
         @name            = name
         @type            = type
         @prefilter       = prefilter       # A Symbol that might be need to be Discarded before reading this one
         @commit_point = nil
      end
      
      def refers_to_token?()
         @type == :token
      end
      
      def refers_to_production?()
         @type == :production || @type == :discarder
      end
      
      def refers_to_group?()
         @type == :group
      end
      
      def refers_to_discarder?()
         @type == :discarder
      end
      
      def token_names( master_plan )
         case @type
         when :token
            return [@name]
         when :production
            return []
         when :group
            names = []
            master_plan.group_members[self].each do |member|
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
      
      def description(elide_grammar = nil)
         return @name.description(elide_grammar)
      end      
      
      def hash()
         return signature().hash
      end
      
      def to_s()
         return description()
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
