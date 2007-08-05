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
require "rcc/model/token.rb"
require "rcc/model/rule.rb"
require "rcc/model/precedence_table.rb"
require "rcc/model/form_elements/element.rb"
require "rcc/model/terminal_definitions/definition.rb"

module RCC
module Model
   
 
 #============================================================================================================================
 # class Loader
 #  - loads a Grammar from a description on disk
 #----------------------------------------------------------------------------------------------------------------------------
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
 #

   class Loader
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Public interface
    #---------------------------------------------------------------------------------------------------------------------
    
      def initialize()
         @grammar             = nil
         @source              = nil
         @source_location     = nil
         @current_line_number = 1
         @lookahead           = []
      end
      
    
      #
      # load()
      #  - loads the Grammar from a descriptor and returns it
      #  - optionally accepts a location name/description which will be included in error messages
      
      def load( source, location = nil )
         @source               = source
         @source_location      = location
         @current_line_number  = 1
         @lookahead            = []
         
         skip_eos()
         process_block( "Grammar", true ) do |name|
            @grammar = Grammar.new( name )

            skip_eos()
            load_configuration()

            skip_eos()
            if la() == "Group" then
               while la() == "Group" 
                  load_group()
                  skip_eos()
               end
            else
               load_terminals() if la() == "Terminals"

               skip_eos()
               load_rules() 

               skip_eos()
               load_precedence_table() if la() == "Precedence"

               skip_eos()
            end
         end

         skip_eos()
         nyi "error handling for trailing tokens #{la_type()}" if la() != nil
         
         return @grammar
      end







    #---------------------------------------------------------------------------------------------------------------------
    # Section Processing
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
      @@configuration_done_at = [ "Group", "Terminals", "Rules", "Precedence" ]
      
      
      #
      # load_configuration()
      #  - parses the configuration section and builds the model
      
      def load_configuration()
         until @@configuration_done_at.member?(token = la())
            case token
               when "StartRule"
                  consume()
                  start_rule_name = consume(:WORD)
                  @grammar.start_rule_name = start_rule_name if @grammar.start_rule_name.nil?

               when "IgnoreTerminal"
                  consume()
                  ignore_terminal = consume(:WORD)
                  @grammar.ignore_terminals << ignore_terminal unless @grammar.ignore_terminals.member?(la())
            
               else
                  nyi "error handling for unrecognized configuration parameter #{token}"
            end
         
            consume( :EOS )
            skip_eos()
         end
      end
      
            
      #
      # load_group()
      #  - parse a Group section
      
      def load_group()
         process_block( "Group", nil ) do |name|
            load_terminals() if la() == "Terminals"
            
            skip_eos()
            load_rules()
            
            skip_eos()
            load_precedence_table() if la() == "Precedence"
         end
      end
      
            
      #
      # load_terminals()
      #  - parses the terminals section and builds the model
      
      def load_terminals()
         process_block( "Terminals" ) do
            until at_end_of_block()
               name  = consume( :WORD, "expected Terminal name" )
                       consume( :ARROW )
               value = consume()
                       consume( :EOS   )
               
               case value.type
                  when :LITERAL
                     @grammar.add_terminal_definition( Model::TerminalDefinitions::Simple.new(value, name) )
                  when :REGEX
                     @grammar.add_terminal_definition( Model::TerminalDefinitions::Pattern.new(value, name) )
                  else 
                     nyi "exception handling for bad Terminal descriptor"
               end
            end
         end
      end
      
      
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
      
      
      




    #---------------------------------------------------------------------------------------------------------------------
    # High-level token management
    #---------------------------------------------------------------------------------------------------------------------
      
      #
      # skip_eos()
      #  - consumes() any eos markers immediately on lookahead
      
      def skip_eos()
         consume() while la_type() == :EOS
         return true
      end
      
      
      #
      # process_block( name )
      #  - eats the named block header and footer, calling your block between
      
      def process_block( name, expect_name = false )
         consume( name )
         
         name = nil
         if expect_name.nil? then
            name = consume( :WORD ) if la_type() != :EOS
         elsif expect_name then
            name = consume( :WORD )
         end

         consume( :EOS )
         skip_eos()
         
         yield( name )
         
         skip_eos()
         consume( "end" )
         consume( :EOS  )
      end
      
      
      #
      # at_end_of_block()
      #  - returns false until the next token is "end"
      
      def at_end_of_block()
         skip_eos()
         return la() == "end"
      end
         
         


    #---------------------------------------------------------------------------------------------------------------------
    # Low-level token management
    #---------------------------------------------------------------------------------------------------------------------

      #
      # la()
      #  - returns the count-th next token (counted from 1)
      
      def la( count = 1 )
         while @lookahead.length < count
            if token = next_token() then
               @lookahead << token
            else
               break
            end
         end
         
         return @lookahead[count - 1]
      end
      
      #
      # la_type()
      #  - returns the type of the count-th next token (counted from 1)
      
      def la_type( count = 1 )
         if token = la(count) then
            return token.type
         else
            return nil
         end
      end
      
      
      #
      # consume()
      #  - returns the count-th next token and moves the pointer so it is no longer on lookahead
      
      def consume( type = nil, message = nil )
         return nil if la(1).nil?

         if type.nil? or la(1).type == type or la(1) == type then
            return @lookahead.shift
         else
            nyi "exception handling for bad consume() (#{message.nil? ? type : message})"
         end
      end
      
      
      #
      # next_token()
      #  - lexes one token from the source
      #  - call this via la() and consume()
      
      def next_token()
         return nil if @source.nil? or @source.empty?

         token = nil
         while token.nil? and not @source.empty?
            case (c = @source.slice(0..0))
               when "(", ")", "|", "?", '{', '}'
                  c = @source.slice!(0..0)
                  token = Token.new( c )
                  token.locate( @current_line_number, nil, @source_location )
                  
               when "="
                  if @source.slice(0, 2) == "=>" then
                     op = @source.slice!(0, 2)
                     token = Token.new( c )
                     token.locate( @current_line_number, nil, @source_location, :ARROW )
                  else
                     token = Token.new( @source.slice!(0, 1) )
                     token.locate( @current_line_number, nil, @source_location )
                  end
                  
               when "\n"
                  c = @source.slice!(0..0)
                  token = Token.new( c )
                  token.locate( @current_line_number, nil, @source_location, :EOS )
                  @current_line_number += 1
                  
               when /\A\s/
                  c = @source.slice!(0..0)
                  
               when "#"
                  eol = @source.index("\n")
                  if eol then
                     @source.slice!(0..(eol-1))
                  else
                     @source = ""
                  end
                  
               when "'", "\""
                  delimiter   = c
                  offset      = 1
                  close_quote = 1
                  while true
                     close_quote  = @source.index(delimiter, offset)
                     next_newline = @source.index("\n"     , offset)
                     
                     #
                     # The close_quote must be before the end of the line.
                     
                     if close_quote.nil? or (next_newline and close_quote > next_newline) then
                        nyi "error reporting for missing close quote"
                        
                     #
                     # If it is followed by another quote, it's actually an escaped quote, and we keep on looking.
                     
                     elsif @source.slice(close_quote + 1, 1) == delimiter then
                        offset = close_quote + 2
                        
                     # 
                     # Otherwise, we're done.
                     
                     else
                        break
                     end
                  end
                  
                  raw = @source.slice!( 0..close_quote )
                  literal = raw.slice( 1..-2 ).gsub( delimiter + delimiter, delimiter ).gsub( /\\(.)/ ) do 
                     case $1
                        when "n"
                           "\n"
                        when "t"
                           "\t"
                        else
                           $1
                     end
                  end
                  
                  token = Token.new( literal )
                  token.locate( @current_line_number, nil, @source_location, :LITERAL, raw )
                  
               when '/'
                  offset       = 1
                  close_marker = 1
                  while true
                     close_marker = @source.index('/' , offset)
                     next_newline = @source.index("\n", offset)
                     
                     #
                     # The close_marker must be before the end of the line.
                     
                     if close_marker.nil? or (next_newline and close_marker > next_newline) then
                        nyi "error reporting for missing end-of-pattern"
                     
                     #
                     # If it is preceded by an odd number of backslashes, it's escaped, and we keep on looking.
                     # Otherwise, we're done.
                     
                     else
                        backslashes = 0
                        (close_marker-1).downto(offset) do |index|
                           if @source.slice(index, 1) == "\\" then
                              backslashes += 1
                           else
                              break
                           end
                        end
                        
                        if backslashes % 2 == 1 then
                           offset = close_marker + 1
                        else
                           break
                        end
                     end
                  end

                  pattern = @source.slice!( 0..close_marker )
                  token   = Token.new( pattern )
                  token.locate( @current_line_number, nil, @source_location, :REGEX )
                  
               when ':'
                  if @source =~/\A:([a-zA-Z]+)/ then
                     raw     = $&
                     value   = $1
                     @source = $'

                     token = Token.new( value )
                     token.locate( @current_line_number, nil, @source_location, :SPECIAL, raw
                      )
                  else
                     nyi "exception handling for a bad symbol"
                  end
                  
               else
                  if @source =~ /\A[a-zA-Z]\w*/ then
                     word    = $&
                     @source = $'
                     
                     token = Token.new( word )
                     token.locate( @current_line_number, nil, @source_location, :WORD )
                  else
                     nyi "exception handling for bad input #{@source.slice(0, 10)}"
                  end
            end
         end
         
         return token
      end
      
      
      
      
    
    
    
    
    
   end # Loader
   


end  # module Model
end  # module Rethink
