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
require "#{$RCCLIB}/plan/lexer_state.rb"
require "#{$RCCLIB}/util/ordered_hash.rb"
require "#{$RCCLIB}/util/sparse_array.rb"


module RCC
module Plan

 
 #============================================================================================================================
 # class LexerPlan
 #  - a representation of the overall plan for lexing the Grammar's terminals

   class LexerPlan

      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :literal_processor
      attr_reader :closed_patterns
      attr_reader :open_patterns
      attr_reader :fallback_plan
      attr_reader :order
      
      
      def initialize( fallback_plan = nil, closed_patterns = Util::OrderedHash.new(), open_patterns = Util::OrderedHash.new() )
         @closed_patterns = closed_patterns       # ExpressionForm patterns that are not complex and do not overlap, and should be tried first
         @open_patterns   = open_patterns         # ExpressionForm patterns that may be complex and must be tried in order
         @fallback_plan   = fallback_plan         # Another LexerPlan to be tried if this one generates no token
         @lexer_state     = nil
         @order           = @closed_patterns.order + @open_patterns.order
      end
      
      
      #
      # add_closed_pattern()
      #  - adds a closed pattern to the plan
      #  - closed patterns can be processed in any order, and must be unique across all closed patterns
      
      def add_closed_pattern( name, expression )
         type_check( name, Scanner::Artifacts::Name )
         assert( @lexer_state.nil?, "you cannot add_pattern()s to this LexerPlan after close()ing it" )
         @closed_patterns[name] = expression
         @exemplars[name]       = make_exemplar( expression )
      end
      
      
      #
      # add_open_pattern()
      #  - adds an open pattern to the plan
      #  - open patterns must be processed in added order, and may overlap each other
      
      def add_open_pattern( name, expression )
         type_check( name, Scanner::Artifacts::Name )
         assert( @lexer_state.nil?, "you cannot add_pattern()s to this LexerPlan after close()ing it" )
         @open_patterns[name] = expression
         @exemplars[name]     = make_exemplar( expression )
      end
      
      
      #
      # lexer_state()
      
      def lexer_state()
         
         if @lexer_state.nil? then
            
            #
            # Organize the @closed_patterns into something that can be represented by a LexerState.
            # Closed patterns have no branching or anything else, so we can just convert them to arrays
            # of SparseRanges.  We'll vectorize the data, to make it more palatable for the LexerState
            # constructor.
         
            vectors = []
            @closed_patterns.each do |name, expression|
               vectors << (expression.elements + [name])
            end

            @lexer_state = LexerState.new( vectors )
         end
         
         return @lexer_state
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Context-sensitizing
    #---------------------------------------------------------------------------------------------------------------------
    
      #
      # prioritize()
      #  - returns a copy of this LexerPlan in which the named symbols will be identified first
      #  - prioritization is local to this LexerPlan, so be sure you pick an appropriate LexerPlan
      #    to prioritize
      
      def prioritize( names )
         
         closed_patterns = Util::OrderedHash.new()
         open_patterns   = Util::OrderedHash.new()

         #
         # Collect the expressions we are prioritizing.  We do not assume the supplied names are
         # in any particular order, but we want to process them in declaration order.  So, we
         # build an index of the requested names and then process our elements in order and 
         # compare against it.
         
         index = names.to_hash(true)
         
         closed_patterns.import( @closed_patterns ) {|name, value| index.member?(name) }
         open_patterns.import( @open_patterns )     {|name, value| index.member?(name) }
         
            
         #
         # If there is no effective change in order between the produced set and this LexerPlan,
         # just return self.  Otherwise, construct a new LexerPlan.

         return self if (open_patterns.empty? and closed_patterns.empty?)
         return self if open_patterns.keys == @open_patterns.keys.slice(0..open_patterns.length) and closed_patterns == @closed_patterns.keys.slice(0..closed_patterns.length)
         return self.class.new( self, closed_patterns, open_patterns )
      end




    
    #---------------------------------------------------------------------------------------------------------------------
    # Exemplar construction
    #---------------------------------------------------------------------------------------------------------------------

    protected
          
      #
      # make_exemplar()
      #  - creates a text example of something that matches the supplied ExpressionForm
      
      def make_exemplar( form, so_far = "" )
         method_name = form.specialize_method_name( "make_examplar" ) 
         if self.class.method_defined?(method_name) then
            send( method_name, form )
         else
            nyi( "support for examplar creation from form type [#{form.class.name}]; please define a method named [#{method_name}]", form )
         end
      end
      
      
      def make_example_sequence( sequence )
         
      end
      

   end # LexerPlan
   




end  # module Plan
end  # module RCC
