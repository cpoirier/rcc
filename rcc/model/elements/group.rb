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
require "#{$RCCLIB}/model/model.rb"


module RCC
module Model
module Elements

 
 #============================================================================================================================
 # class Group
 #  - represents a group of symbols in a rule
 #  - a group is essentially an alias for one or more symbols
 
   class Group
      
            
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :name
      attr_reader :member_references
      
      def initialize( name = nil, member_references = [] )
         type_check( name, Scanner::Artifacts::Name, true )
         
         @name              = name
         @member_references = member_references
         @group_rule        = nil
      end
      
      
      def each()
         @member_references.each do |ref|
            yield( ref )
         end
      end
      
            
      #
      # group_rule()
      #  - returns a Rule capable of processing this Group
      
      def group_rule()
         @group_rule = Rule.new( @name, Util::ExpressionForms::BranchPoint.new(@member_references) ) if @group_rule.nil?
         return @group_rule
      end


      #
      # display()
      
      def display( stream )
         nyi( nil )
         stream.puts( "parse(#{@branches.collect{|s| s.symbol_name}.join("|")})#{@slot_name.exists? ? " as :#{@slot_name}" : ""}" )
      end
      

   end # Group
   


end  # module Elements
end  # module Model
end  # module RCC
