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

module RCC
module CodeGeneration
module Ruby

 
 #============================================================================================================================
 # class Generator
 #  - code generator for Ruby output

   class Generator
      
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
      
      def generate( parser_plan, output_directory = nil )
         generate_lexer( parser_plan, output_directory )
      end
   
   
   
   
   


    #---------------------------------------------------------------------------------------------------------------------
    # Generators
    #---------------------------------------------------------------------------------------------------------------------
    
    private
    
      #
      # generate_lexer()
      #  - generates a Lexer and all the related machinery (Token, LineReader, etc.)
      
      def generate_lexer( parser_plan, output_directory )
         
         #
         # Output the lexers.
         
         fill_template("lexer.rb", STDOUT, parser_plan) do |output_file, macro_name, prefix, suffix|
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
                     # Generate the state lexer.
                     
                     description = "Lexer for "
                     state.display( description, "", true )
                     description << "\n"
                     description << "Prioritized symbols: #{state.lookahead.collect{|symbol| Plan::Symbol.describe(symbol)}.join(" ")}"
                     
                     
                     process_lexer_plan( "lex_for_state_#{state.state_number}", lexer_plan, pattern_registry, fallback_registry, output_file, prefix, suffix, description )
                     
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
                     
                     process_lexer_plan( lexer_name, lexer_plan, pattern_registry, fallback_registry, output_file, prefix, suffix )
                  end
                  
                  
                  #
                  # Finally, output the pattern registry.
                  
                  unless pattern_registry.empty?
                     width = pattern_registry.keys.inject(0){|width, name| max(width, name.to_s.length)}

                     output_file.puts %[#{prefix}]
                     output_file.puts %[#{prefix}# ]
                     output_file.puts %[#{prefix}# Terminal patterns ]
                     output_file.puts %[#{prefix}]
                     
                     pattern_registry.keys.sort.each do |name|
                        output_file.puts %[#{prefix}@@#{name.to_s.ljust(width)} = Regexp.compile( #{quote_pattern(pattern_registry[name])} )]
                     end
                  end
                  
                  
               else
                  # do nothing
            end
         end
         
      end

      
      #
      # process_lexer_plan()
      #  - generates the body of a lexer routine, based on a LexerPlan
      
      def process_lexer_plan( name, plan, pattern_registry, fallback_registry, output_file, prefix, suffix, description = nil )
         out = lambda() do |string|
            output_file.puts( "#{prefix}#{string}#{suffix}")
         end
         
         out.call %[]
         out.call %[# ]
         if description.nil? then
            out.call %[# #{name}()]
         else
            description.split("\n").each do |line|
               out.call %[# #{line}]
            end
         end
         out.call %[]
         out.call %[def #{name}()]
         out.call %[   token = nil]
         out.call %[   while token.nil? and input_remaining?()]

         #
         # Generate an FSA for the literals in this plan.
      
         unless plan.literal_processor.nil?
            out.call %[      ]
            out.call %[      # ]
            out.call %[      # Try for a literal first.  We take the longest possible match.]
            out.call %[      ]
            process_lexer_state( plan.literal_processor, output_file, prefix + "      ", suffix )
         end
      
         #
         # After all literals are attempted, we move on to patterns (if any).
      
         unless plan.patterns.empty?
            out.call %[      ]
            out.call %[      # ]
            out.call %[      # If we didn't get a literal, try our patterns, in order. ]
            out.call %[      ]
            
            width = plan.patterns.values.inject(0){|width, name| max(width, name.to_s.length)}
            plan.patterns.each do |pattern, name|
               pattern_variable = "#{name}_pattern"
               pattern_registry[pattern_variable] = pattern unless pattern_registry.member?(pattern_variable)
               
               out.call %[      string = consume_match( @@#{pattern_variable.ljust(width + "_pattern".length)} ) and token = make_token( string, #{quote_symbol(name).ljust(width+1)} ) if token.nil?]
            end
         end
      
         #
         # After all patterns are attempted, we try the fallback lexer, if present.
         
         unless plan.fallback_plan.nil?
            out.call %[      ]
            out.call %[      # ]
            out.call %[      # If we still don't have a token, try the fallback lexer.]
            out.call %[      ]
            out.call %[      token = #{fallback_registry[plan.fallback_plan.object_id]}()]
         end

         #
         # Drop the token if it is in the ignore list.
         
         unless plan.ignore_list.empty?
            out.call %[      ]
            out.call %[      # ]
            out.call %[      # If we got a token, and it is on the discard list for this lexer, discard it.]
            out.call %[      ]
            if plan.ignore_list.length == 1 then
               out.call %[      token = nil if token.type == #{quote_symbol(plan.ignore_list[0])}]
            else
               out.call %[      token = nil if [#{plan.ignore_list.collect{|name| quote_symbol(name)}.join(", ")}].member?(token.type)]
            end
         end
         
         out.call %[   end]
         out.call %[   ]
         out.call %[   return token]
         out.call %[end]
         out.call %[]
         out.call %[]

      end
      
      
      #
      # process_lexer_state()
      #  - generates a fragment of the literal lexer, based on a LexerState
      
      def process_lexer_state( state, output_file, prefix, suffix, base_la = 1, else_case = nil )
         child_prefix = prefix + "   "
         out = lambda() do |string|
            output_file.puts( "#{prefix}#{string}#{suffix}")
         end
         
         #
         # state.accepted contains a hash of la() characters that we accept.  state.child_states contains a hash of la() 
         # characters we should direct to our children.  Any overlap is sent first to the child state.
         
         order = (state.child_states.keys + state.accepted.keys).uniq.sort
         unless order.empty?
            c = "c"
            c = c + base_la.to_s if base_la > 1
            
            out.call %[case #{c} = la(#{base_la})]
            order.each do |literal|
               out.call %[when #{quote_literal(literal)}]
               
               if state.child_states.member?(literal) then
                  process_lexer_state( state.child_states[literal], output_file, child_prefix, suffix, base_la + 1, state.accepted[literal] )
               else
                  out.call %[   token = make_token( consume(#{base_la}), #{quote_symbol(state.accepted[literal])} )]
               end
            end
            
            unless else_case.nil?
               out.call %[else]
               out.call %[   token = make_token( consume(#{base_la-1}), #{quote_symbol(else_case)} )]
            end
            
            out.call %[end]
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
                  before = $`
                  after  = $'
                  
                  case $1
                     when "MODULE_HEADER"
                        if @configuration.member?(:module_contexts) then
                           @configuration[:module_contexts].each do |module_context|
                              output_file.puts "#{before}module #{module_context}#{after}"
                           end
                        end
                        
                     when "MODULE_FOOTER"
                        if @configuration.member?(:module_contexts) then
                           @configuration[:module_contexts].reverse.each do |module_context|
                              output_file.puts "#{before}end   # module #{module_context}#{after}"
                           end
                        end

                     when "GRAMMAR_NAME"
                        output_file.puts "#{before}#{parser_plan.name}#{after}"
                        
                     when "GRAMMAR_CLASS_NAME"
                        output_file.puts "#{before}#{make_camel_case(parser_plan.name)}#{after}"
                        
                     when "GENERATION_DATE"
                        output_file.puts "#{before}#{Time.now.strftime("%Y-%m-%d at %H:%M")}#{after}"
                        
                     else
                        yield( output_file, $1, $`, $' )
                  end
               else
                  output_file.puts line
               end
            end
         end
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
         if symbol.is_a?(String) then
            return quote_literal( symbol )
         else
            return ":#{symbol.to_s}"
         end
      end
      
      
      #
      # make_camel_case()
      #  - given a name, produces a Ruby class name
      
      def make_camel_case( name )
         return name.gsub(/(?:\A|_)([a-z])/){|letter| letter.slice(-1..-1).upcase}
      end
      
      
   
      
   end # Generator
   
   
   
   
   

end  # module Ruby
end  # module CodeGeneration
end  # module Rethink
