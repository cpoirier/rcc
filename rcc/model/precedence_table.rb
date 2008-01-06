
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

 
 #============================================================================================================================
 # class PrecedenceTable
 #  - a table showing the precedence relationship between various forms and rules

   class PrecedenceTable
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :rows
         
      def initialize()
         @rows = []    # [ [Form|Rule] ], one inner array for each precedence level
      end



      #
      # create_row()
      #  - creates or returns a new empty row that you can add Rules and Forms to
      #  - use << on the returned row
      
      def create_row()
         if @rows.empty? or !@rows[-1].empty? then
            @rows << []
         end
         
         return @rows[-1]
      end
      
      
      
      
   end # PrecedenceTable
   


end  # module Model
end  # module RCC
