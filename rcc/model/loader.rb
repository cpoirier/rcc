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
require "rcc/model/form_elements/element.rb"
require "rcc/model/terminal_definitions/definition.rb"

module RCC
module Model
   
 
 #============================================================================================================================
 # class Loader
 #  - loads a Grammar from a description on disk
 #----------------------------------------------------------------------------------------------------------------------------
 # Grammar files are arranged in four sections: configuration, terminals, rules, and a precedence table.  All four sections 
 # follow the same general form.
 #
 #
 # Configuration
 # -------------
 # The configuration section includes directives that control how the code is generated.  These settings are defaults, and 
 # can be overridden on the command line.  
 #
 # Example:
 #    Configuration
 #       Mode AST
 #    end
 #
 #
 # Terminals
 # ---------
 # Simple terminals (literal symbols that appear in the text of your program) can be defined directly in the rules.  However,
 # for more complicated things (identifiers, numbers, etc.), you'll need to specify them here.  You can use regular 
 # expressions, strings, or Ruby-style symbol declarations that reference built-in patterns.
 #
 # Built-in patterns:
 #    :identifier - the standard C-style identifier
 #    :number     - the standard C-style floating-point number
 #    :integer    - the standard C-style integer
 #
 # Example:
 #    Terminals
 #       id  => :identifier
 #       id2 => /[a-zA-Z]\w+/
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
 #    assoc - the associativity for binary forms (left, right, or none; defaults to none; further discussion below)
 #    prec  - the name of a rule/form to match for precedence (further discussion below)
 #
 # Example:
 #    Rules
 #       statement => expression eos
 #    
 #       expression 
 #          => expression '+' eos? expression     {addition_expression}       {assoc=left}
 #          => expression '-' eos? expression     {subtraction_expression}    {assoc=left} {prec=addition_expression}
 #          => expression '*' eos? expression     {multiplication_expression} {assoc=left} 
 #          => expression '/' eos? expression     {division_expression}       {assoc=left} {prec=multiplication_expression}
 #          => '-' expression                     {negation_expression}
 #          => relation                           {relation_expression}
 #          => predicate                          {predicate_expression}
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
 # Associativity and Precedence
 # ----------------------------
 # rcc generates LALR(k) parsers.  Basically, what this means is that the parser reads tokens onto a stack until it recognizes 
 # something at the top of the stack that matches a Rule.  It then pops the relevant tokens off the top of the stack, applies
 # the Rule, then pushes the Rule result back onto the stack for use in future matches.
 #
 # Because the parser is working this way, it has the choice to defer reductions, should it make sense to do so.  This turns 
 # out to be really useful.  Consider basic math: multiplication and division must be done before addition and subtraction, 
 # but, other than those rules, operation proceeds from left to right.  This means that all four operators are "left" 
 # associative, but that multiplication and division have a higher precedence than addition and subtraction.  What this means 
 # for the parser is that if it can reduce an addition expression from the top of the stack, but the next token on lookahead 
 # is a multiplication sign, it should shift instead, and defer the reduction of the addition rule until after the 
 # multiplication rule has been reduced.  The result is that the proper order of operations is respected.
 #
 # rcc supports three associativities: left, right, and none.  For left associativity, the left-most match will be reduced 
 # first.  For right associativity, the right-most match will be reduced first.  For non-associativity, no pairing of operands
 # is done.  These associativities are primarily useful for binary and greater expressions (ie. exp => exp '+' exp).  You
 # specify associativity as a property on the rule form (see above).
 #
 # By default, rules defined earlier in the grammar have lower precedence than rules defined later in the grammar.  This
 # is not always ideal.  For instance, in our basic math example, addition and subtraction need to have the same precedence,
 # and it needs to be lower than multiplication and division.  You can change the precedence of a rule or form by
 # specifying another rule/form it should be equal to, using a property on the form (see above).

   class Loader
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Public interface
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :grammar            # The Grammar we are loading

      def initialize( grammar )
         @grammar = grammar
         @source  = nil
         @source_location     = nil
         @current_line_number = 1
         @lookahead           = []
      end
      
    
      #
      # load()
      #  - loads the grammar from a descriptor
      #  - optionally accepts a location name/description which will be included in error messages
      
      def load( source, location = nil )
         @source               = source
         @source_location      = location
         @current_line_number  = 1
         @lookahead            = []
         
         skip_eos()
         load_configuration()

         skip_eos()
         load_terminals() if la() == "Terminals"

         skip_eos()
         load_rules() 

         skip_eos()
         nyi "error handling for trailing tokens" if la() != nil
      end






    #---------------------------------------------------------------------------------------------------------------------
    # Section Processing
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
      
      #
      # load_configuration()
      #  - parses the configuration section and builds the model
      
      def load_configuration()
         process_block( "Configuration" ) do 
            until at_end_of_block() 
               name  = consume()
               value = consume()
               consume( :EOS )
            
               @grammar.configuration[name] = value
            end
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
                  when :SPECIAL
                     @grammar.add_terminal_definition( Model::TerminalDefinitions::Special.new(value, name) )
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
                        
                        if key = Model::Form.validate_property_name(name) then
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
            when :WORD
               if @grammar.definitions.member?(la()) then
                  element = Model::FormElements::NamedTerminal.new( consume() )
               else
                  element = Model::FormElements::NonTerminal.new( consume() )
               end
            else
               nyi "error handling for bad parse for rule element"
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
      
      def process_block( name )
         consume( name )
         consume( :EOS )
         skip_eos()
         
         yield()
         
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
                  
               when /^\s/
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
                  if @source =~/^:[a-zA-Z]+/ then
                     raw     = $&
                     @source = $'

                     token = Token.new( raw )
                     token.locate( @current_line_number, nil, @source_location, :SPECIAL )
                  else
                     nyi "exception handling for a bad symbol"
                  end
                  
               else
                  if @source =~ /^[a-zA-Z]\w*/ then
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
