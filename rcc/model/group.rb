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
require "#{$RCCLIB}/util/expression_forms/branch_point.rb"


module RCC
module Model

 
 #============================================================================================================================
 # class Group
 #  - represents a group of symbols in a rule
 #  - a group is essentially an alias for one or more symbols
 
   class Group < Util::ExpressionForms::BranchPoint
      
            
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :symbol_name
      attr_reader :slot_name
      
      def initialize( symbol_name = nil, member_symbols = [] )
         super( *member_symbols )
         @symbol_name = symbol_name
         @slot_name   = nil
      end
      
      
      #
      # slot_name=()

      def slot_name=( slot_name )
         @slot_name = slot_name
         
         each_element do |member_symbol|
            member_symbol.slot_name = slot_name
         end
         
         return self
      end
      
      
      
      #
      # display()
      
      def display( stream )
         stream.puts( "parse(#{@branches.collect{|s| s.symbol_name}.join("|")})#{@slot_name.exists? ? " as :#{@slot_name}" : ""}")
      end
      
      
      #
      # <<()
      #  - expects everything added to reduce to a Symbol or Category, and will flatten nested
      #    Categories into this one
       
      def <<( member )
         case member
            when Group
               member.each_element do |symbol|
                  self << symbol.clone()
               end
            when Symbol
               member.slot_name = @slot_name
               super( member )
            else
               member.each_element do |element|
                  self << element
               end
         end
      end


      #
      # instantiate()
      #  - the Group can be either a template or an element in a rule; this routine returns the latter
      
      def instantiate( symbol_name )
         return Group.new( symbol_name, [] + @branches )
      end



      
   end # Group
   


end  # module Model
end  # module RCC
