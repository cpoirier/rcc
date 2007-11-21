#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"
require "#{$RCCLIB}/scanner/code_generation/ruby/formatter.rb"

module RCC
module Scanner
module CodeGeneration
module Ruby

 
 #============================================================================================================================
 # class Generator
 #  - code generator for Ruby output

   class Generator
      
      @@configuration_help = <<-"end".gsub(/^\s{9}/, "")
         module_context=<module name>
          - if you supply this flag, the generated classes will be declared inside 
            the named Ruby module(s) 
          - example: module_context=MyProgram::CommandLanguage
            
         mode=code
          - by default, rcc builds a tree-based parser, where all the state 
            information is stored in a tree of objects, which the parser walks at 
            run-time
          - if you supply this flag, a code-based parser will be built instead, which 
            will generate a *lot* of case/when statements to process the input
          - NOT YET IMPLEMENTED
               
         build_ast
          - if present, rcc will generate Abstract Syntax Tree classes for your 
            grammar and the parser will build the tree for you
          - if you subclass the parser and implement process_<rule name|form label> 
            methods, they will be called each time the corresponding ASNode is 
            instantiated (you do not have to implement every possible method -- just
            pick and choose the ones you need)
          - you may customize the generated ASNodes by subclassing them (with the same
            name) inside the "Local" module
          - you may customize the base class by subclassing ASNode and supplying the
            name in the "asn_base_class" configuration flag
            
         asn_base_class=<class name>
          - if present, rcc will use the supplied name as the base class for 
            generated Abstract Syntax Tree classes, instead of ASNode
          - your class must derive from ASNode and must exist in the same module as
            that specified in "module_context"; you must also ensure it is loaded
            before the parser code
      end
      
      def self.configuration_help()
         return @@configuration_help
      end
      
      def self.process_configuration_flags( flags )
         configuration = { "build_ast" => false }
         
         flags.each do |flag|
            name, value = flag.split( "=", 2 )
            case name
               when "module_context"
                  configuration["module_contexts"] = value.split("::")
               when "mode"
                  configuration["mode"] = "code" if value == "code"
               when "build_ast"
                  configuration["build_ast"] = true
               when "asn_base_class"
                  configuration["asn_base_class"] = value
               else
                  nyi( "error handling for unrecognized configuration parameter [#{name}]" )
            end
         end
         
         return configuration
      end
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( configuration )
         @configuration = configuration
      end
   
   
      #
      # generate()
      #  - generates a lexer, parser, and AST set for the supplied parser_plan, into the specified directory
      #  - generates to STDOUT if output_directory is nil
      #  - delegates to DynamicGenerator or StaticGenerator, depending on configuration
      
      def generate( parser_plan, output_directory = nil )
         generator_class = (@configuration.member?("mode") and @configuration["mode"] == "code") ? CodeOrientedGenerator : TreeOrientedGenerator
         generator = generator_class.new( @configuration )
         return generator.generate( parser_plan, output_directory )
      end
   




    #---------------------------------------------------------------------------------------------------------------------
    # Lexer Generation
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
      #
      # generate_lexer()
      #  - generates a Lexer and all the related machinery (Token, LineReader, etc.)
      
      def generate_lexer( parser_plan, output_directory )
         
         #
         # Output the lexers.
         
         fill_template("lexer.rb", STDOUT, parser_plan) do |macro_name, formatter|
            case macro_name
               when "LEXERS"
                  
                  pattern_registry  = {}    # name => Regexp
                  fallback_lexers   = {}    # name => LexerPlan
                  fallback_registry = {}    # object_id => name
               
                  
                  #
                  # Generate prioritized lexers for each parser state.
                  
                  parser_plan.state_table.each do |state|
                     lexer_plan    = state.lexer_plan
                     fallback_plan = lexer_plan.fallback_plan
                     
                     #
                     # Register any fallback lexer for later generation.
                     
                     unless fallback_plan.nil?
                        unless fallback_registry.member?(fallback_plan.object_id)
                           name = "lex_using_fallback_#{fallback_registry.length}"
                           
                           fallback_registry[fallback_plan.object_id] = name
                           fallback_lexers[name] = fallback_plan
                        end
                     end
                     
                     #
                     # Generate the state lexer.  Note that some of the states don't need any prioritization, and so will use
                     # a fallback lexer directly.  We'll need to deal with those, or the generator will generate two (or more)
                     # identical functions.
                     
                     description = "Lexer for "
                     state.display( description, "", true )
                     description << "\n"
                     description << "Prioritized symbols: #{state.lookahead.collect{|symbol| Plan::Symbol.describe(symbol)}.join(" ")}"
                     
                     lexer_name = "lex_for_state_#{state.number}"
                     if fallback_registry.member?(lexer_plan.object_id) then
                        generate_function( lexer_name, description, [], formatter ) do 
                           formatter << %[return #{fallback_registry[lexer_plan.object_id]}()]
                        end
                     else
                        process_lexer_plan( lexer_name, lexer_plan, pattern_registry, fallback_registry, formatter, description )
                     end
                     
                  end
                  
                  
                  #
                  # Generate any fallback lexers.
                  
                  work_queue = fallback_lexers.keys.sort
                  until work_queue.empty?
                     lexer_name    = work_queue.shift
                     lexer_plan    = fallback_lexers.delete( lexer_name )
                     fallback_plan = lexer_plan.fallback_plan
                     
                     #
                     # Our fallbacks may have fallbacks, though probably never in practice.  Still . . . .
                     
                     unless fallback_plan.nil?
                        unless fallback_registry.member?(fallback_plan.object_id)
                           name = "lex_using_fallback_#{fallback_registry.length}"
                           
                           fallback_registry[fallback_plan.object_id] = name
                           fallback_lexers[name] = fallback_plan
                        end
                     end
                     
                     #
                     # Generate the lexer.
                     
                     process_lexer_plan( lexer_name, lexer_plan, pattern_registry, fallback_registry, formatter )
                  end
                  
                  
                  #
                  # Finally, output the pattern registry.
                  
                  unless pattern_registry.empty?
                     name_width    = pattern_registry.keys.inject(0)  {|width, name | max(width, name.to_s.length )}
                     pattern_width = pattern_registry.values.inject(0){|width, regex| max(width, regex.to_s.length)}

                     formatter << %[#{prefix}]
                     formatter << %[#{prefix}# ]
                     formatter << %[#{prefix}# Terminal patterns ]
                     formatter << %[#{prefix}]
                     
                     pattern_registry.keys.sort.each do |name|
                        formatter << %[@@#{name.to_s.ljust(name_width)} = Regexp.compile( #{quote_pattern(pattern_registry[name]).ljust(pattern_width+2)} )]
                     end
                  end
                  
                  
               else
                  formatter << macro_name
            end
         end
         
      end


      #
      # process_lexer_plan()
      #  - generates the body of a lexer routine, based on a LexerPlan
      
      def process_lexer_plan( name, plan, pattern_registry, fallback_registry, formatter, description = nil )
         generate_function( name, description, [], formatter ) do
            
            formatter << %[token = nil]
            formatter << %[while token.nil? and input_remaining?()]
            
            formatter.indent do 
            
               #
               # Generate an FSA for the literals in this plan.
      
               unless plan.literal_processor.nil?
                  formatter.comment_block %[Try for a literal first.  We take the longest possible match.]

                  process_lexer_state( plan.literal_processor, formatter )
               end
      
               #
               # After all literals are attempted, we move on to patterns (if any).
      
               unless plan.patterns.empty?
                  formatter.comment_block %[If we didn't get a literal, try our patterns, in order. ]

                  pattern_variable = plan.patterns.collect{|pattern, name| "#{name}_pattern"  }
                  symbol_name      = plan.patterns.collect{|pattern, name| quote_symbol(name) }
                  
                  formatter.columnate( %[string = consume_match( @@], pattern_variable, %[ ) and token = make_token( string, ], symbol_name, %[ ) if token.nil?] )
               end
      
               #
               # After all patterns are attempted, we try the fallback lexer, if present.
         
               unless plan.fallback_plan.nil?
                  formatter.comment_block %[If we still don't have a token, try the fallback lexer.]

                  formatter << %[token = #{fallback_registry[plan.fallback_plan.object_id]}() if token.nil?]
               end

               #
               # Drop the token if it is in the ignore list.
         
               unless plan.ignore_list.empty?
                  formatter.comment_block %[If we got a token, and it is on the discard list for this lexer, discard it.]

                  if plan.ignore_list.length == 1 then
                     formatter << %[token = nil if token.type == #{quote_symbol(plan.ignore_list[0])}]
                  else
                     formatter << %[token = nil if [#{plan.ignore_list.collect{|name| quote_symbol(name)}.join(", ")}].member?(token.type)]
                  end
               end
               
            end
         
            formatter << %[end]
            formatter << %[]
            formatter << %[return token]
         end
      end
      
      
      
      #
      # process_lexer_state()
      #  - generates a fragment of the literal lexer, based on a LexerState
      
      def process_lexer_state( state, formatter, base_la = 1, else_case = nil )
         
         #
         # state.accepted contains a hash of la() characters that we accept.  state.child_states contains a hash of la() 
         # characters we should direct to our children.  Any overlap is sent first to the child state.
         
         order = (state.child_states.keys + state.accepted.keys).uniq.sort
         unless order.empty?
            c = "c"
            c = c + base_la.to_s if base_la > 1
            
            formatter << %[case #{c} = la(#{base_la})]
            order.each do |literal|
               formatter << %[when #{quote_literal(literal)}]
               formatter.indent do 
                  if state.child_states.member?(literal) then
                     process_lexer_state( state.child_states[literal], formatter, base_la + 1, state.accepted[literal] )
                  else
                     formatter << %[token = make_token( consume(#{base_la}), #{quote_symbol(state.accepted[literal])} )]
                  end
               end
            end
            
            unless else_case.nil?
               formatter << %[else]
               formatter.indent do
                  formatter << %[token = make_token( consume(#{base_la-1}), #{quote_symbol(else_case)} )]
               end
            end
            
            formatter << %[end]
         end
      end








    #---------------------------------------------------------------------------------------------------------------------
    # Support code
    #---------------------------------------------------------------------------------------------------------------------
    
    private
         
      #
      # fill_template()
      #  - loads a template file and calls back for non-standard macros it finds there
      #  - your block has complete responsibility for the output of any line passed to it
      #  - at present, there can only be one macro expanded per template line
      
      def fill_template( template_name, output_file, parser_plan )
         File.open( "#{File.dirname(__FILE__)}/templates/#{template_name}" ) do |template_file|
            while line = template_file.gets()
               line.chomp!
               
               if line =~ /%%(\w+)%%/ then
                  formatter = Formatter.new( output_file, $`, $' )
                  
                  case $1
                     when "MODULE_HEADER"
                        if @configuration.member?("module_contexts") then
                           @configuration["module_contexts"].each do |module_context|
                              formatter << %[module #{module_context}]
                           end
                        end
                        
                     when "MODULE_FOOTER"
                        if @configuration.member?("module_contexts") then
                           @configuration["module_contexts"].reverse.each do |module_context|
                              formatter << %[end   # module #{module_context}]
                           end
                        end

                     when "GRAMMAR_NAME"
                        formatter << %[#{parser_plan.name}]
                        
                     when "GRAMMAR_CLASS_NAME"
                        formatter << make_class_name(parser_plan.name)
                        
                     when "GENERATION_DATE"
                        formatter << Time.now.strftime("%Y-%m-%d at %H:%M")
                        
                     else
                        yield( $1, formatter )
                  end
               else
                  output_file.puts line
               end
            end
         end
      end
      
      
      #
      # generate_function()
      #  - outputs the header and footer for a function and calls your block in between
      #  - passes your block the formatter
      
      def generate_function( name, description, parameters, formatter, display_name_and_description = false ) 
            
         #
         # Output the header.
         
         formatter.comment_block do
            formatter << "#{name}()" if description.nil? or display_name_and_description
            
            unless description.nil?
               formatter << description
            end
         end

         if parameters.empty? then
            formatter << "def #{name}()"
         else
            formatter << "def #{name}( #{parameters.join(", ")} )"
         end

         #
         # Yield to the body generator.

         formatter.indent do 
            yield( formatter )
         end
         
         #
         # Output the footer.
         
         formatter << "end"
         formatter.blank_line
         formatter.blank_line
      end
      
   
      #
      # quote_literal()
      #  - given a literal string (ie. for the lexer), returns a quoted ruby string
      
      def quote_literal( string )
         return '"' + string.gsub("\\", "\\\\").gsub("\n", "\\n").gsub("\t", "\\t").gsub("\"", "\\\"") + '"'
      end
      
      
      #
      # quote_pattern()
      #  - given a Regexp, returns a ruby regex in a string
      
      def quote_pattern( regexp )
         return quote_literal(regexp.to_s)
      end
      
         
      #
      # quote_symbol()
      #  - given a symbol name, generates a ruby representation
      
      def quote_symbol( symbol )
         if symbol.nil? then
            return "nil"
         elsif symbol.is_a?(String) then
            return quote_literal( symbol )
         else
            return ":#{symbol.to_s}"
         end
      end
      
      
      #
      # make_class_name()
      #  - given a general name, produces a Ruby class name
      
      def make_class_name( name )
         return name.gsub(/(?:\A|_+)(\w)/){|text| text.upcase.sub("_", "")}
      end
      
      
      #
      # make_general_name()
      #  - given a Ruby class name, produces a general name
      
      def make_general_name( name )
         return name.gsub(/(?:\A|[a-z])([A-Z0-9])/){|match| match.length == 1 ? match.downcase : "_" + match.downcase}
      end
      
      
    
      
   end # Generator
   
   
   
   
   

end  # module Ruby
end  # module CodeGeneration
end  # module Scanner
end  # module RCC



require "#{$RCCLIB}/scanner/code_generation/ruby/code_oriented_generator.rb"
require "#{$RCCLIB}/scanner/code_generation/ruby/tree_oriented_generator.rb"



