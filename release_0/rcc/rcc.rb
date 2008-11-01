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
require "#{$RCCLIB}/languages/bootstrap_loader.rb"
require "#{$RCCLIB}/scanner/interpreter/factory.rb"


module RCC

 
 #============================================================================================================================
 # class class
 #  - description

   class RCC
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    

      #
      # initialize()
      #  - loads the system from disk and provides operational control facilities.
      
      def initialize()
         
         #
         # First thing, we must load the grammar grammar.  We use the bootstrap loader if there isn't a pre-compiled
         # version in the languages directory.
         
         begin
            require "#{$RCCLIB}/languages/grammar/Parser.rb"
            nyi( "compiled parser handling" )
         rescue LoadError
            path = "#{$RCCLIB}/languages/grammar_language.rcc"
            File.open(path) do |file|
               @grammar_parser_factory = Scanner::Interpreter::Factory.new( Languages::BootstrapLoader.new().load(file.read(), path), 3, nil )
            end
         end
      end


      #
      # load_grammar()
      #  - returns a ParserPlan for the specified grammar
      #  - raises an exception with error information if the grammar fails to load
      
      def compile_grammar( descriptor, file = nil )
         solution = @grammar_parser_factory.parse( descriptor, file )
         if solution.valid? then
            
         else
         end
      end
      
      



    #---------------------------------------------------------------------------------------------------------------------
    # RCC Grammar Grammar
    #---------------------------------------------------------------------------------------------------------------------
    #
    # Grammar files are arranged in four sections: configuration, terminals, rules, and a precedence table.  The latter three
    # can optionally be arranged inside multiple groups, if it helps clarify your grammar.
    #
    # Quick example:
    #    Grammar <name>
    #       StartRule string
    #    
    #       Group strings
    #          Terminals 
    #             escape_sequence => /\\./
    #             general_text    => /[^"\\{]+/
    #          end
    #       
    #          Rules
    #             string          => '"' string_body '"'
    #             
    #             string_body     => string_element
    #                             => string_body string_element
    #                             
    #             string_element  => escape_sequence
    #                             => general_text
    #                             => '{' expression '}'
    #          end
    #       end
    #    end
    #
    #
    # Grammar
    # -------
    # The Grammar section wraps the whole grammar and gives it a name.  At the top of the Grammar, you can specify configuration
    # settings that control how rcc does its work.  These settings are defaults, and can be overridden on the command line
    # (generally). 
    #
    # Example:
    #    Grammar <name>
    #       StartRule <rule name>
    #       
    #       Terminals
    #       end
    #   
    #       Rules
    #       end
    #  
    #       Precedence
    #       end
    #    end
    #
    # Current configuration directives:
    #    StartRule <rule name>          -- provides name of the rule that starts the grammar
    #    IgnoreTerminal <terminal name> -- specifies the name of a Terminal that should be discarded by the lexer
    #                                   -- useful for getting rid of whitespace and comments, for instance
    #                                   -- include as many IgnoreTerminal directives as necessary
    #
    #
    # Group
    # -----
    # The Group section can be used if you'd like to divide your grammar up into multiple sets of Terminals/Rules/Precedence 
    # sections.  Groups are for documentation purposes only, and do not affect how your grammar works.  If you don't use a Group,
    # you can use only one each of the Terminals/Rules/Precedence declaration sections.
    #
    # Example:
    #    Grammar <name>
    #       Group code
    #          Terminals
    #          end
    #         
    #          Rules
    #          end
    #       
    #          Precedence
    #          end
    #       end
    #
    #       Group strings
    #          Terminals
    #          end
    #         
    #          Rules
    #          end
    #       
    #          Precedence
    #          end
    #       end
    #    end
    #    
    #
    # Terminals
    # ---------
    # Simple terminals (literal symbols that appear in the text of your program) can be defined directly in the rules.  However,
    # for more complicated things (identifiers, numbers, etc.), you'll need to specify them here.  You can use regular 
    # expressions or literal strings, and the name you assign them will be used as the generated Token type.
    #
    # As a rule, the lexer will search for literal strings first, then try your patterns, in the declaration order.  However,
    # the parser will automatically prioritize those literals and patterns it expects to find on the lookahead for the current
    # state, so you can have, for instance, two or more overlapping regular expressions, and the parser will choose the 
    # appropriate one for the context (where possible).
    #
    # Example:
    #    Terminals
    #       id  => /[a-zA-Z]\w+/
    #       eos => "\n"
    #    end
    #
    #
    # Rules
    # -----
    # The rules section contains the actual grammar definition.  Individual rules can have multiple forms.  With rcc, you don't
    # include semantic actions in the rules; instead, the generated parser calls methods on itself (or your subclass), named
    # for the rule.  You can specify a form-specific label as a property after the form, and that label will be used instead of 
    # the rule name when calling the handler routine.  It also identifies the form for use in precedence lists.  Note that such 
    # labels share the same namespace as rule names and must be unique.
    #
    # Properties are defined at the end of the same line as the rule form, marked with curly braces.  As just mentioned, the
    # default property is a form label, but you can supply other data as name=value pairs (each in their own pair of braces).  
    # 
    # Supported properties:
    #    label - the label to apply to the form for purpose of identification in Precedence rules
    #          - label is the default property, so you don't need to use "label="
    #    assoc - the associativity for binary forms (left, right, or none; defaults to none; further discussion below)
    #
    # Example:
    #    Rules
    #       statement => expression eos:ignore
    #    
    #       expression 
    #          => expression:lhs '+' eos:ignore? expression:rhs     {addition_expression}       {assoc=left}
    #          => expression '-' eos? expression                    {subtraction_expression}    {assoc=left}
    #          => expression '*' eos? expression                    {multiplication_expression} {assoc=left} 
    #          => expression '/' eos? expression                    {division_expression}       {assoc=left}
    #          => '-' expression                                    {negation_expression}
    #          => relation                                          {relation_expression}
    #          => predicate                                         {predicate_expression}
    #          => id
    #    end
    #
    # Rules contain a mix of names and simple terminals.  Names not defined as Terminals in the Terminals section are Rule names.  
    # Simple terminals can be written directly in rules using single or double quotes.
    #
    # The rcc system supports some syntactic sugar for grammars.  The first is the ability to use alternate literals within a 
    # single rule.  The second is the ability to mark a symbol as optional.  
    #
    # Example rule:
    #   intersection => relation ('intersect'|'∩') eos? relation
    #
    # In this example, the user can type the symbol or name for the "interesect" operator, and either will be accepted.  Use 
    # parentheses to group the options and the pipe symbol (|) to separate them.  Note also that you can only use this form with 
    # literals.  For anything more complicated, make additional rules.
    # 
    # Also in this example, the "eos" terminal has been marked as optional.  This means that it can be included immediately 
    # after the operator without terminating the statement, but will not generate an error if it is missing.  You can mark any 
    # rule element as optional.  In an rcc-produced AST, any missing slots will be nil.
    #
    #
    # AST Construction and Term Labels
    # --------------------------------
    # In the above example, you will notice that some of the Rule terms include a : label.  This label is used when assigning the
    # data to a slot in the AST.  For instance, in the first "expression" form above, the first expression will be available in
    # slot "lhs" and the second in slot "rhs" on AST class "addition_expression".
    #
    # If you don't specify labels for any of your terms, rcc will assign labels for you.  Generally speaking, these labels will
    # be based on the terms themselves.  For instance, in the second "expression" form above, the first expression will be 
    # available in slot "expression1" and the second in slot "expression2" on AST class "subtraction_expression".  For the 
    # "negation_expression", the expression term will be available in slot "expression", as there is no contention for the name
    # in that form.  
    #
    # rcc automatically assigns labels to any unlabeled non-terminals in your rules.  It does not automatically supply labels 
    # for literals, as they are assumed to be uninteresting in the AST.  You can override this behaviour by supplying an explicit
    # label of your own.  The "ignore" label is special, and has the opposite effect: any term labelled "ignore" will not get
    # a slot in the AST class.
    #
    #
    # Conflicts and Associativity
    # ---------------------------
    # rcc generates LALR(k) parsers.  Basically, what this means is that the parser reads tokens onto a stack until it recognizes 
    # something at the top of the stack that matches a Rule.  It then pops the relevant tokens off the top of the stack, applies
    # the Rule, then pushes the Rule result back onto the stack for use in future matches.
    #
    # Because the parser is working this way, it has the choice to defer or prioritize reductions, should it make sense to do so.  
    # One place this comes into play is associativity.  Consider this basic math expression:
    #    1 + 2 - 3
    #
    # This expression can be grouped in one of two ways: (1 + 2) - 3  OR  1 + (2 - 3).  Now, in basic math, the two options just
    # happen to have the same meaning, but it shows the concept of associativity: the first parse is "left" associative; the 
    # second is "right" associative. 
    # 
    # By default, LR parsers treat all rules as right-associative: shifts are prioritized over reduces, given an option.  But
    # this is not always ideal.  While it doesn't matter in our simple example, in real life, basic math is defined as left-
    # associative.  If, say, those terms were function calls instead of numbers, you would want the evaluation to proceed from 
    # left to right, to ensure that any side-effects from those functions occur the in order your user is expecting.  
    #
    # rcc supports three associativities: left, right, and none.  For left associativity, the left-most match will be reduced 
    # first.  For right associativity, the right-most match will be reduced first.  For non-associativity, no repeating of
    # a form is allowed.  This last option is useful if you want to force associativity to be explicitly chosen by the user:
    # ie. "1 + 2 + 3" would have to be written either as "(1 + 2) + 3" or "1 + (2 + 3)", in order to be accepted by the parser.  
    #
    # You specify associativity as a property on the rule form (see above).
    #
    #
    # Conflicts and Precedence
    # ------------------------
    # In the previous section, we discussed how the associativity of rules can control when to shift and when to reduce.  This
    # implies that the parser had a choice: that, in fact, it was in a state where it could (and therefore had to) choose between
    # a shift and a reduce.  
    #
    # Real grammars often have many such conflicts between rules.  Associativity can help solve some of those conflicts, but
    # other tools can be useful, too.
    # 
    # Consider the following grammar:
    #   expression => number
    #              => expression '*' expression   {assoc=left} {multiplication_expression}
    #              => expression '/' expression   {assoc=left} {division_expression}
    #              => expression '+' expression   {assoc=left} {addition_expression}
    #              => expression '-' expression   {assoc=left} {subtraction_expression}
    #
    # This grammar expresses basic math on numbers, in that it has the four basic operators and marks them all as left-
    # associative.  But there's a wrinkle: in real math, multiplication and division must be done BEFORE addition and subtraction.  
    # That's a significant complication, and associativity alone is not enough to solve it.  We could find a way to rewrite the 
    # grammar, to express those relationship, but that would probably make our grammar less readable, not more so.
    #
    # What we really need is to be able to express a precedence relationship between these forms.  This is done using a 
    # Precedence section.
    # 
    # Example:
    #    Precedence
    #      multiplication_expression division_expression
    #      addition_expression       subtraction_expression
    #    end
    #
    # Within a Precedence section, each line indicates rules or forms (by name or label) that should be treated as having equal
    # precedence.  Lines earlier in the section indicate higher precedence than lines later in the section.
    #
    # You can have multiple Precedence sections, each of which indicates a closed set of relationships.  When resolving 
    # shift/reduce conflicts between rules that appear in the same section, precedence will be used.  When resolving shift/reduce
    # conflicts between rules that do not appear in the same Precedence section, precedence will not be used.
    #
    #
    # Conflicts and Backtracking
    # --------------------------
    # Coming soon.
    #
    #
    # Error recovery
    # --------------
    # Coming soon.
    #---------------------------------------------------------------------------------------------------------------------
    
    protected

      def self.t( text, type = nil )
         return Scanner::Artifacts::Nodes::Token.new( text, type, 0, 0, 0, nil )
      end
      
      def self.i( text )
         return t( text, :identifier )
      end
      
      def self.n( root_symbol, *symbols )
         return Scanner::Artifacts::Nodes::CSN.new( root_symbol, symbols )
      end
      
      
      @@rcc_grammar = n( :grammar,
         t('Grammar'), i("RCC"),
         n( :options, n(:option, t('StartRule'), i('grammar')) ),
         n( :body, 
            
         ),
         t('end'),
         t("\n", :eol)
      )
      

      #
      # generate_grammar_grammar()
      #  - produces a Model::Grammar for the grammar grammar, in case there isn't a compile processor available

      def generate_grammar_grammar()
         
         grammar = Model::Grammar.new( "RCC" )
         
         #
         # Set the configuration.
         
         grammar.start_rule_name = make_token( "grammar" )
         grammar.ignore_terminals << make_token( "whitespace" )
         grammar.ignore_terminals << make_token( "eol"        )
         
         
         #
         # Define the terminals.
         
         grammar.add_terminal_definition( Model::TerminalDefinitions::Simple.new(make_token("escape_sequence"), name ))
         grammar.add_terminal_definition( Model::TerminalDefinitions::Pattern.new(, make_token("<escape_sequence>"), make_token("escape_sequence")))


         #                   escape_sequence => /\\./        
         #                   general_text    => /[^'\\]+/    
         #                   pattern         => /\/[^\/]\//    
         
         
         
         

         #
         # load_rules()
         #  - parses the rules section and builds the model

         def load_rules()
            process_block( "Rules" ) do
               until at_end_of_block()
                  name = consume( :WORD, "expected Rule name" )
                  rule = @grammar.create_rule( name )

                  while skip_eos() and la_type() == :ARROW
                     consume( :ARROW )
                     root_element = load_rule_elements( :ARROW, '{' )

                     #
                     # Process any properties

                     form_name  = nil
                     properties = {}

                     while la() == '{'
                        consume( '{' ) 

                        if la(2) == '=' then
                           name  = consume( :WORD )
                                   consume( "="   )
                           value = consume( :WORD )

                           if name == "label" then
                              form_name = value
                           elsif key = Model::Form.validate_property_name(name) then
                              if value = Model::Form.validate_property_value(@grammar, rule, name, value) then
                                 properties[key] = value
                              else
                                 nyi "error handling for bad value for property #{name}: #{Model::Form::PROPERTY_ERRORS[key]}"
                              end
                           else
                              nyi "error handling for bad property name #{name}"
                           end
                        else
                           form_name = consume( :WORD )
                        end

                        consume( '}' )
                     end

                     #
                     # Add the general form to the rule.

                     rule.create_form( root_element, form_name, properties )
                  end
               end
            end
         end


         #
         # load_rule_elements()
         #  - parses a series of elements from a rule form and returns the model

         def load_rule_elements( *stop_types )
            root  = Model::FormElements::SeriesElement.new()
            empty = true

            while (type = la_type()) != :EOS and !stop_types.member?(type) 
               root.add_element( load_rule_element() )
               empty = false
            end

            nyi "error handling for empty series" if empty

            return root
         end


         #
         # load_rule_element()
         #  - parses an element of a rule and returns the model

         def load_rule_element()
            element = nil

            case la_type()
               when '('
                  element = load_fork_element()
               when :LITERAL
                  element = Model::FormElements::RawTerminal.new( consume() )
                  element.label = consume() if la_type() == :SPECIAL
               when :WORD
                  if @grammar.definitions.member?(la()) then
                     element = Model::FormElements::NamedTerminal.new( consume() )
                  else
                     element = Model::FormElements::NonTerminal.new( consume() )
                  end
                  element.label = consume() if la_type() == :SPECIAL
               else
                  nyi "error handling for bad parse for rule element [#{la()} #{la_type()}]"
            end

            if la() == "?" then
               consume()
               element = Model::FormElements::OptionalElement.new( element )
            end

            return element
         end


         #
         # load_fork_element()
         #  - parses a single fork structure and builds the model

         def load_fork_element()
            element = Model::FormElements::ForkElement.new()

            consume( '(' )
            while true
               element.add_choice load_rule_elements( '|', ')' )

               if la() == '|' then
                  consume('|')
               else
                  break
               end
            end

            consume( ')' ) 

            return element
         end



         #
         # load_precedence_table()
         #  - parses a single precedence table and builds the model

         def load_precedence_table()
            process_block( "Precedence" ) do
               precedence_table = @grammar.precedence_table
               current_row      = precedence_table.create_row()

               until at_end_of_block()
                  if la_type() == :WORD then
                     search_name = consume( :WORD, "expected rule or form name" )
                     if @grammar.labels.member?(search_name) then
                        current_row << @grammar.labels[search_name]
                     else
                        nyi( "error handling for missing precedence reference [#{search_name}]" )
                     end
                  end

                  if la_type() == :EOS then
                     current_row = precedence_table.create_row()
                  end
               end
            end
         end

         

         
         
         
         
         


         # Grammar RCC
         #             StartRule grammar
         # 
         # 
         #             Group literals
         #                Terminals 
         #                   escape_sequence => /\\./        
         #                   general_text    => /[^'\\]+/    
         #                   pattern         => /\/[^\/]\//    
         #                end
         # 
         #                Rules
         #                   literal  => pattern:pattern
         #                            => string:string
         # 
         #                   string          => '\'' string_elements '\''
         #                   string_elements => string_elements? string_element
         #                   string_element  => escape_sequence
         #                                   => general_text
         # 
         # 
         #                end
         #             end
         # 
         # 
         #             Group options
         #                Rules
         #                   options  => 'StartRule'          identifier:rule_name
         #                            => 'IgnoreTerminal'     identifier:terminal_name
         #                            => 'LocalCommit'     identifier:non_terminal_name
         #                            => 'EnableBacktracking'
         #                end
         #             end
         # 
         # 
         #             Group general
         #                Terminals
         #                   identifier => /[a-zA-Z]\w*/  
         #                   eol        => /\n+/          '\n'
         #                end
         # 
         #                Rules
         #                   eols     => eols? eol
         # 
         #                   grammar  => 'Grammar' identifier:name options body 'end' eols
         # 
         #                   body     => groups
         #                            => mainline
         # 
         #                   groups   => groups? group_section
         #                   mainline => terminal_section? rules_section precedence_section?
         # 
         #                   group_section      => 'Group' identifier:group_name mainline 'end' eols
         #                   terminal_section   => 'Terminals'  terminal_definitions      'end' eols
         #                   rules_section      => 'Rules'      rule_definitions          'end' eols
         #                   precedence_section => 'Precedence' rule_names                'end' eols
         # 
         #                   terminal_definitions => terminal_definitions? terminal_definition
         #                   terminal_definition  => identifier:name '=>' literal string:exemplar? eols
         #                   rule_names           => rule_names?           identifier:rule_name
         #                end
         #             end
         # 
         # 
         #             Group rules
         #                Rules
         #                   rule_definitions => rule_definitions? rule_definition
         #                   rule_definition  => terms directives eols
         # 
         #                   terms        => terms?      marked_term
         #                   directives   => directives? directive
         # 
         #                   directive    => '{' content '}'
         #                   content      => identifier
         #                                => identifier '=' identifier
         # 
         #                   symbol       => identifier:symbol
         #                                => string:literal
         # 
         #                   term         => named_term '?':optionality_marker?
         #                   named_term   => unnamed_term (':' identifier:label)?
         #                   unnamed_term => symbol
         #                                => '(' clauses ')'
         # 
         #                   clauses      => terms
         #                                => clauses '|' terms
         #                end
         #             end
         # 
         #          end
         # 
         # 
         #          
         
      end
      
      
      
      
   end # RCC
   


end  # module RCC


if $0 == __FILE__ then
   system = RCC::RCC.new()
   puts "hi"
end