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
require "#{$RCCLIB}/model/model.rb"


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
      
      def initialize( symbol_name = nil, member_symbols = [] )
         super( *member_symbols )
         @symbol_name = symbol_name
      end
      
      
      #
      # display()
      
      def display( stream )
         nyi( nil )
         stream.puts( "parse(#{@branches.collect{|s| s.symbol_name}.join("|")})#{@slot_name.exists? ? " as :#{@slot_name}" : ""}")
      end
      
      
      #
      # <<()
      #  - expects everything added to reduce to a Symbol or Group, and will flatten nested
      #    Groups into this one
       
      def <<( member )
         case member
            when Group
               member.each_element do |symbol|
                  self << symbol.clone()
               end
            when RuleReference
               super( member )
            when StringReference
               super( member )
            else
               member.each_element do |element|
                  self << element
               end
         end
      end


   end # Group
   


end  # module Model
end  # module RCC
