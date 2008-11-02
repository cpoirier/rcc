#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright 2007-2008 Chris Poirier (cpoirier@gmail.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the 
# License.  You may obtain a copy of the License at
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" 
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language 
# governing permissions and limitations under the License.
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/system/")[0..-2].join("/system/")}/system/environment.rb"
require "#{RCC_LIBDIR}/model/model.rb"


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
