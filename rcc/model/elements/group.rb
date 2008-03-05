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
         type_check( name, Model::Name, true )
         
         @name = name
         @member_references = member_references
      end
      
      
      def name=( name )
         type_check( name, Model::Name, true )
         @name = name
      end


      def each()
         @member_references.each do |ref|
            yield( ref )
         end
      end
      
      
      #
      # display()
      
      def display( stream )
         nyi( nil )
         stream.puts( "parse(#{@branches.collect{|s| s.symbol_name}.join("|")})#{@slot_name.exists? ? " as :#{@slot_name}" : ""}" )
      end
      
      
      #
      # <<()
      #  - expects everything added to reduce to a Symbol or Group, and will flatten nested
      #    Groups into this one
       
      def <<( member )
         case member
            when Group
               member.member_references.each do |reference|
                  self << reference
               end
            when References::RuleReference, References::StringReference
               @member_references << member.clone()
            else
               nyi( nil, member )
         end
      end


   end # Group
   


end  # module Elements
end  # module Model
end  # module RCC
