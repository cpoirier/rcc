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
require "#{RCC_LIBDIR}/scanner/code_generation/formatter.rb"

module RCC
module Scanner
module CodeGeneration
module Ruby

 
 #============================================================================================================================
 # class Formatter
 #  - a Ruby-specific version of the generate code Formatter

   class Formatter < CodeGeneration::Formatter
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( output_stream, line_prefix, line_suffix )
         super
      end
      
      
      #
      # comment_block()
      #  - outputs a standard Ruby comment block
      
      def comment_block( *lines )
         self.blank_line
         self << %[#]
         self.indent( "# " ) do
            lines.each do |line|
               self << line unless line.nil?
            end

            yield( self ) if block_given?
         end
         self.blank_line
      end
      
   end # Formatter
   


end  # module Ruby
end  # module CodeGeneration
end  # module Scanner
end  # module RCC
