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
module Model
module Elements

 
 #============================================================================================================================
 # class StringDescriptor
 #  - represents a string that can be produced by the Lexer

   class StringDescriptor
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :name
      attr_reader :form

      def initialize( name, form, is_explicit = true, contraindications = nil )
         @name              = name
         @form              = form
         @is_explicit       = is_explicit
         @contraindications = contraindications
      end
      
      def explicit?()
         return @is_explicit
      end
      
      def has_contraindications?()
         return (@contraindications.exists? and !@contraindications.empty?)
      end
      
      def contraindications()
         @contraindications = [] if @contraindications.nil?
         return @contraindications
      end
            
      def display( stream = $stdout )
         stream.puts "#{@is_explicit ? "explicit" : "implicit"} string form #{@name}:"
         stream.indent do
            @form.display( stream )
         end
      end
      
      
   end # StringDescriptor
   


end  # module Elements
end  # module Model
end  # module RCC
