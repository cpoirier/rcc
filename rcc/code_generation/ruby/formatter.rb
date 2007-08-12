#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "rcc/environment.rb"
require "rcc/code_generation/formatter.rb"

module RCC
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
end  # module Rethink
