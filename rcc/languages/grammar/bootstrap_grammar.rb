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
require "#{$RCCLIB}/scanner/artifacts/node.rb"
require "#{$RCCLIB}/scanner/artifacts/nodes/token.rb"

module RCC
module Languages
module Grammar

 
 #============================================================================================================================
 # class BootstrapGrammar
 #  - description

   class BootstrapGrammar
      
      
      #
      # ::ast()
      #  - returns the bootstrap grammar as an AST
      
      def self.ast()
         return @@ast
      end
      
      
      
    private
    
    
      #
      # ::build_ast()
      #  - builds the AST for the grammar grammar
       
      def self.build_ast()

         #
         # grammar RCC
         # 
         #    start_rule grammar_spec
         #    ignore     whitespace
         #    ignore     comment
         # 
         
         @@ast = grammar_spec( 'RCC',

            start_rule_option( "grammar" ),
            ignore_option( "whitespace"  ),
            ignore_option( "comment"     ),

         #
         #    characters
         #       any_character     => [\u0000-\uFFFF]
         #       digit             => [0-9]
         #       hex_digit         => [{digit}a-fA-F]
         #       word_first_char   => [a-zA-Z_]
         #       word_char         => [{word_first_char}{digit}]
         #       general_character => [{any_character}]-['\n\r\\]
         #    end
         #
         
            characters_spec(
               character_spec( 'any_character'    , cs_characters(cs_range(ust('0000'), ust('FFFF'))) ),
               character_spec( 'digit'            , cs_characters(cs_range('0'        , '9'        )) ),
               character_spec( 'hex_digit'        , cs_characters(cs_reference('digit'), cs_range('a', 'f'), cs_range('A', 'F')) ),
               character_spec( 'word_first_char'  , cs_characters(cs_range('a', 'z'), cs_range('A', 'Z'), '_')            ),
               character_spec( 'word_char'        , cs_characters(cs_reference('word_first_char'), cs_reference('digit')) ),
               character_spec( 'general_character',
                  cs_difference(
                     cs_characters( cs_reference('any_character') ),
                     cs_characters( "'", est('n'), est('r')       )
                  )
               )
            ),
            
         # 
         #    words
         #       unicode_sequence  => '\\' 'u' hex_digit hex_digit hex_digit hex_digit
         #       escape_sequence   => '\\' [a-z\\\-\[\]\']
         #       word              => word_first_char word_char*
         #       eol               => '\n'
         #       general_text      => general_character+
         #       whitespace        => [ \t\r]+
         #       comment           => '#' [{any_character}]-[\n]*
         #       property_text     => [{general_character}]-[}]+
         #    end
         # 

            words_spec(
               word_spec( 'unicode_sequence', est('\\'), 'u', sp_reference('hex_digit'), sp_reference('hex_digit'), sp_reference('hex_digit'), sp_reference('hex_digit') ),
               word_spec( 'escape_sequence' , est('\\'), cs_characters(cs_range('a', 'z'), est('\\'), est('-'), est('['), est(']'), est("'")) ),
               word_spec( 'word'            , sp_reference('word_first_char'), sp_repeated('*', sp_reference('word_char')) ),
               word_spec( 'eol'             , est('n')                                                 ),
               word_spec( 'general_text'    , sp_repeated('+', sp_reference('general_character'))      ),
               word_spec( 'whitespace'      , sp_repeated('+', cs_characters(' ', est('t'), est('r'))) ),
               word_spec( 'comment'         , '#', sp_repeated('*', cs_difference(cs_characters(cs_reference('any_character')), est('n'))) ),
               word_spec( 'property_text'   , sp_repeated('+', cs_difference(cs_characters(cs_reference('general_character')), cs_characters('}')))  )
            ),

         #
         #    macros
         #       eols              => eol:ignore*
         #       statement         => %% eols ;
         #       block( header )   => statement() [ statement() [$header] %% 'end' ]
         #    end
         # 
         
            macros_spec(
               simple_macro( 'eols'     , repeated_exp('*', reference_exp('eol', 'ignore'))         ),
               simple_macro( 'statement', transclusion(), reference_exp('eols'), recovery_commit()) ),
               parameterized_macro( 'block', ['header'],
                  macro_call('statement', []
                     macro_call( 'statement', [], variable_exp('header') ),
                     transclusion(),
                     string_exp('end')
                  )
               )
            ),
            
         # 
         #    section grammar
         #       grammar_spec => block('grammar' word:name) [ option* specification* ]
         # 

            section( 'grammar',
               rule_spec( 'grammar', 
                  block_macro(
                     expression('grammar', reference_exp('word', 'name')), 
                     repeated_exp('*', reference_exp('option'       )),
                     repeated_exp('*', reference_exp('specification'))
                  )
               ),
         
         #
         #       category option
         #          start_rule          => 'start_rule' word:rule_name
         #          ignore_switch       => 'ignore'     word:name
         #          backtracking_switch => 'enable_backtracking'
         #       end
         # 
         
               category_spec( 'option',
                  rule_spec( 'start_rule'   , string_exp('start_rule'), reference_exp('word', 'rule_name') ),
                  rule_spec( 'ignore_switch', string_exp('ignore'    ), reference_exp('word', 'name'     ) ),
                  rule_spec( 'backtracking_switch', string_exp('enable_backtracking') )       
               ),

         #       
         #       category specification
         #          macros_spec     => block('macros')             [ macro_spec*           ]
         #          characters_spec => block('characters')         [ character_spec*       ]
         #          words_spec      => block('words')              [ word_spec*            ]
         #          precedence_spec => block('precedence')         [ precedence_level*     ]
         #          section_spec    => block('section' word:name?) [ specification*        ]
         #          category_spec   => block('category' word:name) [ (rule_spec|category_spec|spec_reference):specification* ]
         #          
         #          rule_spec       => statement() [ word:name '=>' expression directive* ] transformation_spec*
         #       end
         #
         
               category_spec( 'specification',
                  rule_spec( 'macros_spec'    , block_macro('macros'    , repeated_reference('*', 'macro_spec'      )) ),
                  rule_spec( 'characters_spec', block_macro('characters', repeated_reference('*', 'character_spec'  )) ),
                  rule_spec( 'words_spec'     , block_macro('words'     , repeated_reference('*', 'word_spec'       )) ),
                  rule_spec( 'precedence_spec', block_macro('precedence', repeated_reference('*', 'precedence_level')) ),
                  
                  rule_spec( 'section_spec', 
                     block_macro( expression('section', repeated_reference('?', 'word', 'name')),
                        repeated_reference( '*', 'specification' )
                     )
                  ),
                  
                  rule_spec( 'category_spec', 
                     block_macro( expression('category', reference_exp('word', 'name')),
                        repeated_exp( '*', 
                           group_exp(
                              branch_exp( reference_exp('rule_spec'), reference_exp('category_spec'), reference_exp('spec_reference') ),
                              'specification'
                           )
                        )
                     )
                  ),
                  
                  rule_spec( 'rule_spec',
                     statement_macro( 
                        reference_exp( 'word', 'name' ), 
                        string_exp( '=>' ),
                        reference_exp( 'expression' ),
                        repeated_reference( '*', 'directive' )
                     ),
                     repeated_reference( '*', 'transformation_spec' )
                  )
               ),
               
         #       
         #       spec_reference   => statement() [ word:name ]
         #       precedence_level => statement() [ word:reference+ ]
         #
               rule_spec( 'spec_reference'  , statement_macro(reference_exp('word', 'name'))                ),
               rule_spec( 'precedence_level', statement_macro(repeated_reference('+', 'word', 'reference')) ),
         
         #       
         #    end
         #    
         
            ),
                        
         #
         #    section characters_spec
         #       character_spec => statement() [ word:name '=>' character_set ]
         # 
         #       category character_set
         #          cs_characters => '[' cs_element+ ']'
         #          cs_difference => character_set:lhs '-' character_set:rhs   @associativity=none
         #       end
         #       
         #       category cs_element
         #          cs_range      => character:from '-' character:to           @associativity=none
         #          cs_reference  => '{' word:name '}'              
         #          character                              
         #       end
         # 
         #       category character
         #          unicode_sequence
         #          escape_sequence
         #          general_character
         #       end
         #    end
         #
            
            section( 'characters_spec',
            
               rule_spec( 'character_spec', statement_macro(reference_exp('word', 'name'), '=>', reference_exp('character_set')) ),
               
               category_spec( 'character_set',
                  rule_spec( 'cs_characters', '[', repeated_reference('+', 'cs_element'), ']' ),
                  rule_spec( 'cs_difference', reference_exp('character_set', 'lhs'), '-', reference_exp('character_set', 'rhs'), assoc('none') )
               ),
               
               category_spec( 'cs_element' 
                  rule_spec( 'cs_range'    , reference_exp('character', 'from'), '-', reference_exp('character', 'to'), assoc('none') ),
                  rule_spec( 'cs_reference', '{', reference_exp('word', 'name'), '}' ),
                  spec_reference( 'character' )
               ),
               
               category_spec( 'character',
                  spec_reference( 'unicode_sequence'  ),
                  spec_reference( 'escape_sequence'   ),
                  spec_reference( 'general_character' )
               )
            ),
         
         #    
         #    section words_spec
         #       word_spec => statement() [ word:name '=>' string_pattern:definition ]
         # 
         #       category string_pattern
         #          sp_reference  => word:name
         #          sp_group      => '(' string_pattern ')'
         #          sp_branch     => string_pattern '|' string_pattern          @associativity=left
         #          sp_concat     => string_pattern string_pattern              @associativity=left
         #          sp_repeated   => string_pattern ('*'|'+'|'?'):repeat_count
         #          character_set
         #          string
         #       end
         # 
         #       string => '\'' (unicode_sequence|escape_sequence|general_text)+ '\''
         #    end
         #    
            
            section( 'words_spec',
               
               rule_spec( 'word_spec', statement_macro(reference_exp('word', 'name'), '=>', reference_exp('string_pattern', 'definition')) ),
               
               category_spec( 'string_pattern',
                  rule_spec( 'sp_reference', reference_exp('word', 'name')                                                         ),
                  rule_spec( 'sp_group'    , '(', reference_exp('string_pattern'), ')'                                             ),
                  rule_spec( 'sp_branch'   , reference_exp('string_pattern'), '|', reference_exp('string_pattern'), assoc('left')  ),
                  rule_spec( 'sp_concat'   , reference_exp('string_pattern'), reference_exp('string_pattern'),      assoc('left')  ),
                  rule_spec( 'sp_repeated' , reference_exp('string_pattern'), group_exp(branch_exp('*', '+', '?'), 'repeat_count') ),
                  
                  spec_reference( 'character_set' ),
                  spec_reference( 'string'        )
               ),
               
               rule_spec( 'string', 
                  est("'"), 
                  repeated_exp( '+', group_exp(branch_exp('unicode_sequence', 'escape_sequence', 'general_text')) ), 
                  est("'") 
               )
            ),
         
         #    
         #    section rule_spec
         #       macros
         #          labelled()          => %% (':' word:label)?
         #          attribute_set(name) => '@' $name '=' %%
         #       end
         #
         
            section( 'rule_spec',
               macros_spec(
                  parameterized_macro( 'labelled'     , []      , transclusion(), repeated_exp('?', group_exp(expression(':', reference_exp('word', 'label')))) ),
                  parameterized_macro( 'attribute_set', ['name'], '@', variable_exp('name'), '=', transclusion() )
               ),

         #       
         #       category expression
         #          reference_exp   => labelled() [ word:name          ]
         #          string_exp      => labelled() [ string             ]
         #          group_exp       => labelled() [ '(' expression ')' ]
         #          variable_exp    => labelled() [ '$' word:name      ]
         #          
         #          sequence_exp    => expression:tree expression:leaf            @associativity=left
         #          branch_exp      => expression:tree '|' expression:leaf        @associativity=left
         #          repeated_exp    => expression ('*'|'+'|'?'):repeat_count
         #          gateway_exp     => '!' !whitespace word
         #          recovery_commit => ';'
         #          transclusion    => '%%'
         #          macro_call      => word:macro_name !whitespace '(' parameters? ')' ('[' expression:body? ']')?
         #                          ** parameters => parameters{expression|parameter_tree/(@tree|@leaf)//}         
         #       end
         # 
            
               category_spec( 'expression',
                  rule_spec( 'reference_exp' , macro_call('labelled', [], reference_exp('word', 'name'))         ),
                  rule_spec( 'string_exp'    , macro_call('labelled', [], reference_exp('string'      ))         ),
                  rule_spec( 'group_exp'     , macro_call('labelled', [], '(', reference_exp('expression'), ')') ),
                  rule_spec( 'variable_exp'  , macro_call('labelled', [], '$', reference_exp('word', 'name'))    ),
                                             
                  rule_spec( 'sequence_exp'  , reference_exp('expression', 'tree'), reference_exp('expression', 'leaf'),      assoc('left') ),
                  rule_spec( 'branch_exp'    , reference_exp('expression', 'tree'), '|', reference_exp('expression', 'leaf'), assoc('left') ),
                  rule_spec( 'repeated_exp'  , reference_exp('expression'), group_exp(branch_exp('*', '+', '?'), 'repeat_count')          ),
                  
                  rule_spec( 'gateway_exp'     , '!', gateway_exp('whitespace'), reference_exp('word') ),
                  rule_spec( 'recovery_commit' , ';'  ),
                  rule_spec( 'transclusion'    , '%%' ),
                  
                  rule_spec( 'macro_call',
                     reference_exp('word', 'macro_name'), gateway_exp('whitespace'), '(', repeated_reference('?', 'parameters'), ')',
                     repeated_exp( '?', group_exp(expression('[', repeated_reference('?', 'expression', 'body'), ']')) ),
                     transformation_spec( 'parameters', 'parameters',  
                        tr_branch(
                           tr_type_reference('expression'),
                           tr_recursive_search(
                              tr_path(
                                 tr_type_reference('parameter_tree'),
                                 tr_group(
                                    tr_branch(
                                       tr_slot_reference('tree'), 
                                       tr_slot_reference('leaf')
                                    )
                                 )
                              )
                           )
                        )
                     )
                  )
               ),

         # 
         #       category parameters
         #          parameter_tree  => parameters:tree ',' parameters:leaf      @associativity=left
         #          expression
         #       end
         # 
         #       category directive
         #          associativity_directive => attribute_set('associativity') [ ('left'|'right'|'none'):direction ]
         #       end
         #       
         
               category_spec( 'parameters',
                  rule_spec( 'parameter_tree', reference_exp('parameters', 'tree'), ',', reference_exp('parameters', "leaf"), assoc('left') ),
                  spec_reference( 'expression' )
               ),
               
               category_spec( 'directive',
                  rule_spec( 'associativity_directive', 
                     macro_call( 'attribute_set', ['associativity'], 
                        group_exp(
                           branch_exp('left', 'right', 'none'),
                           'direction'
                        )
                     )
                  )
               ),
               
         #       
         #       precedence
         #          repeated_exp
         #          branch_exp
         #          sequence_exp
         #       end
         #
         
               precedence_spec(
                  precedence_level('repeated_exp'),
                  precedence_level('branch_exp'  ),
                  precedence_level('sequence_exp')
               )
         
         #
         #    end
         # 
               
            ),
            
         #    
         #    section transformations_spec
         #       transformation_spec => statement() ['**' word:destination '=>' word:source '{' transformation '}']
         # 
         #       category transformation
         #          tr_type_reference   => word:type_name
         #          tr_slot_reference   => '@' word:slot_name
         #          tr_recursive_search => transformation '//'
         #          tr_path             => transformation:tree '/' transformation:leaf   @associativity=left
         #          tr_branch           => transformation:tree '|' transformation:leaf   @associativity=left
         #          tr_sequence         => transformation:tree ',' transformation:leaf   @associativity=left
         #          tr_group            => '(' transformation ')'
         #       end
         # 
         #       precedence
         #          tr_path
         #          tr_branch
         #          tr_group
         #       end
         #    end
         #    
         
            section( 'transformations_spec',
               rule_spec( 'transformation_spec', 
                  statement_macro( '**', reference_exp('word', 'destination'), reference_exp('word', 'source'), '{', reference_exp('transformation'), '}' )
               ),
               
               category_spec( 'transformation',
                  rule_spec( 'tr_type_reference'  , reference_exp('word', 'type_name')      ),
                  rule_spec( 'tr_slot_reference'  , '@', reference_exp('word', 'slot_name') ),
                  rule_spec( 'tr_recursive_search', reference_exp('transformation'), '//'   ),
                  rule_spec( 'tr_path'            , reference_exp('transformation', 'tree'), '/', reference_exp('transformation', 'leaf'), assoc('left') ),
                  rule_spec( 'tr_branch'          , reference_exp('transformation', 'tree'), '|', reference_exp('transformation', 'leaf'), assoc('left') ),
                  rule_spec( 'tr_sequence'        , reference_exp('transformation', 'tree'), ',', reference_exp('transformation', 'leaf'), assoc('left') ),
                  rule_spec( 'tr_group'           , '(', reference_exp('transformation'), ')' )
               ),
               
               precedence_spec(
                  precedence_level( 'tr_path'   ),
                  precedence_level( 'tr_branch' ),
                  precedence_level( 'tr_group'  )
               )
            ),
         
         #
         #    section macros_spec
         #       category macro_spec
         #          simple_macro        => statement() [ word:name '=>' expression ]
         #          parameterized_macro => statement() [ word:name !whitespace '(' parameter_definitions? ')' '=>' expression ]
         #                              ** parameter_definitions => parameter_definitions{word|parameter_definition_tree/(@tree|@leaf)//}
         #       end
         #       
         #       category parameter_definitions
         #          parameter_definition_tree => parameter_definitions:tree ',' parameter_definitions:leaf   @associativity=left
         #          word
         #       end
         #    end
         #
         
            section( 'macros_spec',
               category_spec( 'macro_spec',
                  rule_spec( 'simple_macro', statement_macro(reference_exp('word', 'name'), '=>', reference_exp('expression')) ),
                  
                  rule_spec( 'parameterized_expression',
                     statement_macro(
                        reference_exp('word', 'name'), gateway_exp('whitespace'), 
                        '(', repeated_reference('?', 'parameter_definitions'), ')', 
                        '=>', reference_exp('expression') 
                     ),
                     transformation_spec( 'parameter_definitions', 'parameter_definitions',  
                        tr_branch(
                           tr_type_reference('word'),
                           tr_recursive_search(
                              tr_path(
                                 tr_type_reference('parameter_definition_tree'),
                                 tr_group(
                                    tr_branch(
                                       tr_slot_reference('tree'), 
                                       tr_slot_reference('leaf')
                                    )
                                 )
                              )
                           )
                        )
                     )
                  )
               )
               
               
               category_spec( 'parameter_definitions',
                  rule_spec( 'parameter_definition_tree', 
                     reference_exp( 'parameter_definitions', 'tree' ),
                     ',',
                     reference_exp( 'parameter_definitions', 'leaf' ),
                     assoc('left')
                  ),
                  
                  spec_reference('word')
               )
            ),
            
         #
         # end
         #
         
         )
         
      end
    
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Support
    #---------------------------------------------------------------------------------------------------------------------
    
      Node  = RCC::Scanner::Artifacts::Node
      Token = RCC::Scanner::Artifacts::Nodes::Token
      
    
      #
      # class ASN
      #  - a custom Node for our AST
      #  - represents an AST without reference to an RCC Model or Plan
      #  - doesn't include stuff that would be used for error recovery, as it will not be constructed by a parser
      
      class ASN < Node
         
         attr_reader :slots
         
         def initialize( type, slots )
            super( type )
            @slots = slots
         end
       
         def description() ; return "#{@ast_class_name} (#{@type})" ; end

         def follow_position() ; return nil   ; end
         def terminal?()       ; return false ; end      
         def first_token()     ; return nil   ; end
         def last_token()      ; return nil   ; end
         def token_count()     ; return 0     ; end
         
         def gather( *slots )
            values = []
            
            slots.each do |slot|
               values << @slots[slot] if slot_filled?(slot)
            end
            
            return values
         end
         
         
         def slot_defined?( slot )
            return @slots.member?(slot)
         end
         
         def slot_filled?( slot )
            return (@slots.member?(slot) and !@slots[slot].nil?)
         end
         
         def define_slot( slot, value )
            @slots[slot] = value
         end

      
         def method_missing( id, *args )
            name, set = id.to_s.split("=")
            slot      = name.intern
            
            assert( set == "" || set.nil?, "unknown method [#{id.to_s}]"        )
            assert( @slots.member?(slot) , "unknown property or slot [#{name}]" )
            
            if set == "" then
               assert( args.length == 1, "expected 1 value to set into slot [#{name}]")
               @slots[slot] = args[0]
            else
               assert( args.length == 0, "expected 0 values when getting from slot" )
               return @slots[slot]
            end
         end
         
         
         def display( stream, indent = "", inline_candidate = false )
            if @subtype.nil? or @subtype == @type then
               stream << indent << "#{@type} =>" << "\n"
            else
               stream << indent << "#{@type} (#{@subtype}) =>" << "\n"
            end

            indent1 = indent + "   "
            indent2 = indent1 + "   "
            @slots.each do |slot_name, value|
               stream << indent1 << slot_name << ":\n"
               self.class.display_node( value, stream, indent2, inline_candidate )
            end

            return inline_candidate
         end
         
         def self.display_node( node, stream, indent = "", inline_candidate = false )
            case node
            when NilClass
               stream << indent << "<nil>\n"
            when Array
               index = 0
               node.each do |child_node|
                  stream << indent << "[#{index}]:\n"
                  display_node( child_node, stream, indent + "   ", inline_candidate )
                  index += 1
               end
            when ASN
               node.display( stream, indent, inline_candidate )
            when Token
               node.display( stream, indent )
            else
               bug( "don't know how to display [#{node.class.name}]" )
            end
         end

      end
      
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Token Production
    #---------------------------------------------------------------------------------------------------------------------
    

      #
      # ::t()
      #  - produces a Token from a String (or Token)
      
      def self.t( text, type = nil )
         return text if text.is_a?(Node)
         return Token.new( text, 0, 0, 0, nil, type, false, nil )
      end

      #
      # ::w()
      #  - produces a :word Token
      
      def self.w( word )
         return t( word, :word )
      end

      #
      # ::ust()
      #  - produces a Token that represents a unicode escape sequence, per the grammar
      
      def self.ust( number )
         return number if number.is_a?(Node)
         return t( "\\u#{number}", :unicode_sequence )
      end
    
      #
      # ::est()
      #  - produces a Token that represents a general escape sequencer, per the grammar
      
      def self.est( code )
         return code if code.is_a?(Node)
         return t( "\\#{code}", :escape_sequence )
      end

      #
      # ::gct()
      #  - produces a Token that represents a general character, per the grammar
      
      def self.gct( letter )
         return letter if letter.is_a?(Node)
         return t( letter, :general_character)
      end

      #
      # ::gtt()
      #  - produces a Token that represents general text, per the grammar
      
      def self.gtt( text )
         return text if text.is_a?(Node)
         return t( text, :general_text )
      end      
            
      #
      # ::vt()
      #  - produces a Token that represents a variable, per the grammar
      
      def self.vt( variable )
         return variable if variable.is_a?(Node)
         return t( variable, :variable )
      end
      
      #
      # ::ptt()
      #  - produces a Token that represents property text, per the grammar
      
      def self.ptt( text )
         return text if text.is_a?(Node)
         return t( text, :property_text )
      end




    #---------------------------------------------------------------------------------------------------------------------
    # Node Production
    #---------------------------------------------------------------------------------------------------------------------
    
      #
      # node_has_type?( node, type )
      #  - returns true if the node can be viewed as having the specified type
      
      def node_has_type?( node, type )
         return true if node.type == type
         
         case type
            when :option
               return true if node.type == :start_rule
               return true if node.type == :ignore_switch
               return true if node.type == :backtracking_switch
            when :specification
               return true if node.type == :macros_spec
               return true if node.type == :section_spec
               return true if node.type == :characters_spec
               return true if node.type == :words_spec
               return true if node.type == :precedence_spec
               return true if node.type == :category_spec
               return true if node.type == :rule_spec
            when :character_set
               return true if node.type == :cs_characters 
               return true if node.type == :cs_difference
            when :cs_element
               return true if node.type == :cs_range
               return true if node.type == :cs_reference
               return true if node_has_type?(node, :character)
            when :character
               return true if node.type == :unicode_sequence
               return true if node.type == :escape_sequence
               return true if node.type == :general_character
            when :string_pattern
               return true if node.type == :sp_reference
               return true if node.type == :sp_group
               return true if node.type == :sp_branch
               return true if node.type == :sp_concat
               return true if node.type == :sp_repeated
               return true if node.type == :string
               return true if node_has_type?(node, :character_set)
            when :expression
               return true if node.type == :reference_exp   
               return true if node.type == :string_exp      
               return true if node.type == :group_exp       
               return true if node.type == :variable_exp    
               return true if node.type == :sequence_exp    
               return true if node.type == :branch_exp      
               return true if node.type == :repeated_exp    
               return true if node.type == :gateway_exp     
               return true if node.type == :recovery_commit 
               return true if node.type == :transclusion    
               return true if node.type == :macro_call      
            when :parameters
               return true if node.type == :parameter_tree   
               return true if node_has_type?(node, :expression)
            when :directive
               return true if node.type == :associativity_directive
            when :transformation
               return true if node.type == :tr_type_reference   
               return true if node.type == :tr_slot_reference   
               return true if node.type == :tr_recursive_search 
               return true if node.type == :tr_path             
               return true if node.type == :tr_branch           
               return true if node.type == :tr_sequence         
               return true if node.type == :tr_group            
            when :macro_spec
               return true if node.type == :simple_macro
               return true if node.type == :parameterized_macro
            when :parameter_definitions
               return true if node.type == :parameter_definition_tree
               return true if node.type == :word
         end
         
         return false
      end
    
    
      #
      # ::node()
      #  - returns a new FakeASN from parts
      
      def self.node( type, slots = {} )
         return ASN.new( type, slots )
      end
      
      
      #
      # ::grammar_spec()
   
      def self.grammar_spec( name, *clauses )
         options        = []
         specifications = []
         
         clauses.each do |clause|
            if node_has_type?(clause, :option) then
               options << clause
            else
               specifications << clause
            end
         end
         
         return node( :grammar_spec, :name => w(name), :options => options, :specifications => specifications )
      end
      
      
      #
      # ::start_rule()
      
      def self.start_rule( name )
         return node( :start_rule, :rule_name => name )
      end
      
      #
      # ::ignore_switch()
      
      def self.ignore_switch( name )
         return node( :ignore_switch, :name => name )
      end
      
      #
      # ::backtracking_switch()
      
      def self.backtracking_switch()
         return node( :backtracking_switch )
      end
      
      
      #
      # ::macros_spec()
      
      def self.macros_spec( *specs )
         return node( :macros_spec, :macro_specs => specs )
      end
            
      #
      # ::section_spec()
      
      def self.section_spec( name, *specs )
         return node( :section_spec, :name => w(name), :specifications => specs )
      end
      
      #
      # ::characters_spec()
      
      def self.characters_spec( *specs )
         return node( :characters_spec, :character_specs => specs )
      end
      
      #
      # ::words_spec()
      
      def self.words_spec( *specs )
         return node( :words_spec, :word_specs => specs )
      end
      
      #
      # ::precedence_spec()
      
      def self.precedence_spec( *levels )
         return node( :precedence_spec, :precedence_levels => levels )
      end
      
      #
      # ::category_spec()
      
      def self.category_spec( name, *specs )
         return node( :category_spec, :name => w(name), :specifications => specs )
      end
      
      #
      # ::rule_spec()
      
      def self.rule_spec( name, *clauses )
         expressions     = []
         directives      = []
         transformations = []
         
         clauses.each do |clause|
            if node_has_type?(clause, :directive) then
               directives << clause
            elsif node_has_type?(clause, :transformation) then
               transformations << clause
            else
               expressions << clause
            end
         end
         
         return node( :rule_spec, :name => w(name), :expression => expression(*expressions), :directives => directives, :transformation_specs => transformations )
      end
      
      
      #
      # ::spec_reference()
      
      def self.spec_reference( name )
         return node( :spec_reference, name => w(name) )
      end
      
      #
      # ::precedence_level()
      
      def self.precedence_level( *references )
         return node( :precedence_level, :references => references.collect{|r| w(r)} )
      end
      
      
      
      
      
      #
      # ::character_spec()
      
      def self.character_spec( name, character_set )
         return node( :character_spec, :name => w(name), :character_set => character_set )
      end
      
      
      #
      # ::cs_characters()
      
      def self.cs_characters( *cs_elements )
         return node( :cs_characters, :cs_elements => cs_elements.collect{|c| character(c)} )
      end
      
      
      #
      # ::cs_difference()
      
      def self.cs_difference( lhs, rhs )
         return node( :cs_difference, :lhs => lhs, :rhs => rhs )
      end


      #
      # ::cs_range()
      
      def self.cs_range( from, to )
         return node( :cs_range, :from => character(from), :to => character(to) )
      end
      
      
      #
      # ::cs_reference()
      
      def self.cs_reference( name )
         return node( :cs_reference, :name => w(name) )
      end
      
      
      #
      # ::character()
      #  - "character" is treated as a category, not a rule . . . 
   
      def self.character( token )
         return gct(token) unless token.is_a?(Node)
         return token
      end
      
      
      
      
      
      #
      # ::word_spec()
      #  - produces a :word_spec Node, given one or more :string_pattern
      #  - Strings are up-converted to :general_text Tokens
      #  - all terms are up-converted to string_patterns, as necessary
      #  - multiple terms are up-converted to a tree of sp_concat Nodes
      
      def self.word_definition( name, *terms )
         terms.unshift sp_concat( terms.shift, terms.shift ) until terms.length < 2
         return node( :word_spec, :name => w(name), :definition => string_pattern(terms[0]) )
      end
      
      
      #
      # ::string_pattern()
      #  - :string_pattern is a category, not a rule
      
      def self.string_pattern( term )
         if term.is_an?(ASN) then
            
            return term if node_has_type?(term, :string_pattern)
            return sp_characters(term) if node_has_type?(term, :character_set)
         end
         
         return string(term)
      end
      
      
      #
      # ::sp_reference()
      
      def self.sp_reference( name )
         return node( :sp_reference, :name => w(name) )
      end
      
      
      #
      # ::sp_group()
      
      def self.sp_group( string_pattern )
         return node( :sp_group, :string_pattern => string_pattern(string_pattern) )
      end
      
      
      #
      # ::sp_concat()
      
      def self.sp_concat( lhs, rhs )
         return node( :sp_concat, :lhs => string_pattern(lhs), :rhs => string_pattern(rhs) )
      end
      
      
      #
      # ::sp_repeated()
      
      def self.sp_repeated( count, string_pattern )
         return node( :sp_repeated, :repeat_count => t(count), :string_pattern => string_pattern(string_pattern) )
      end
      
      
      #
      # ::string()
      
      def self.string( *elements )
         return node( :string, :string_elements => elements.collect{|e| gtt(e)} )
      end
      



      
      #
      # ::expression()
   
      def self.expression( *elements )
         elements.unshift sequence_exp( elements.shift, elements.shift ) until elements.length < 2
         return elements[0]
      end

      
      #
      # ::reference_exp()
      
      def self.reference_exp( name, label = nil )
         return node( :reference_exp, :name => w(name), :label => label.nil? ? nil : w(label) )
      end
         
         
      #
      # ::string_exp()
      
      def self.string_exp( string, label = nil )
         return node( :string_exp, :string => string(string), :label => label.nil? ? nil : w(label) )
      end
      
      
      #
      # ::group_exp()
      
      def self.group_exp( expression, label = nil )
         return node( :group_exp, :expression => expression, :label => label.nil? ? nil : w(label) )
      end
      
      
      #
      # ::variable_exp()
      
      def self.variable_exp( name, label = nil )
         return node( :variable_exp, :name => w(name), :label => label.nil? ? nil : w(label) )
      end
      
      
      #
      # ::sequence_exp()
      
      def self.sequence_exp( tree, leaf )
         return node( :sequence_exp, :tree => tree, :leaf => leaf )
      end
      
      
      #
      # ::branch_exp()
      
      def self.branch_exp( tree, leaf, *more )
         if more.empty? then
            return node( :branch_exp, :tree => tree, :leaf => leaf )
         else
            return branch_exp( branch_exp(tree, leaf), *more )
         end
      end
      
      
      #
      # ::repeated_exp()
   
      def self.repeated_exp( count, expression )
         return node( :repeated_exp, :repeat_count => t(count), :expression => expression )
      end
      
      
      #
      # ::repeated_reference()
      
      def self.repeated_reference( count, name, label = nil )
         return repeated_exp( count, reference_exp(name, label) )
      end
      
      
      #
      # ::gateway_exp()
      
      def self.gateway_exp( word )
         return node( :gateway_exp, :word => w(word) )
      end
      
      
      #
      # ::recovery_commit()
      
      def self.recovery_commit()
         return node( :recovery_commit )
      end
      
      
      #
      # ::transclusion()
      
      def self.transclusion()
         return node( :fe_transclusion )
      end
      
      
      #
      # ::macro_call()
      
      def self.macro_call( name, parameters, *data )
         return node( :macro_call, 
            :macro_name => w(name), 
            :parameters => parameters.collect{|p| expression(p)},
            :body       => expression( *data )
         )
      end



      
      #
      # ::associativity_directive()
      
      def self.associativity_directive( direction )
         return node( :associativity_directive, :direction => direction )
      end
      
      
      
      
      #
      # ::transformation_spec()
      
      def self.transformation_spec( destination, source, transformation )
         return node( :transformation_spec, :destination => destination, :source => source, :transformation = transformation )
      end
      
      
      #
      # ::tr_type_reference()
      
      def self.tr_type_reference( type_name )
         return type_name if type_name.is_an?(ASN)
         return node( :tr_type_reference, :type_name => w(type_name) )
      end
      
      
      #
      # ::tr_slot_reference()
      
      def self.tr_slot_reference( slot_name )
         return node( :tr_slot_reference, :slot_name => w(slot_name) )
      end
      
      
      #
      # ::tr_recursive_search()
      
      def self.tr_recursive_search( transformation )
         return node( :tr_recursive_search, :transformation => transformation )
      end
      
      
      #
      # ::tr_path()
      
      def self.tr_path( tree, leaf, *more )
         if more.empty? then
            return node( :tr_path, :tree => tree, :leaf => leaf )
         else
            return tr_path( tr_path(tree, leaf), *more )
         end
      end
      
      
      #
      # ::tr_branch
      
      def self.tr_branch( tree, leaf, *more )
         if more.empty? then
            return node( :tr_branch, :tree => tree, :leaf => leaf )
         else
            return tr_branch( tr_branch(tree, leaf), *more )
         end
      end
         
      
      #
      # ::tr_sequence()
      
      def self.tr_sequence( tree, leaf, *more )
         if more.empty? then
            return node( :tr_sequence, :tree => tree, :leaf => leaf )
         else
            return tr_sequence( tr_sequence(tree, leaf), *more )
         end
      end

      
      #
      # ::tr_group()
      
      def self.tr_group( transformation )
         return node( :tr_group, :transformation => transformation )
      end




      
      #
      # ::simple_macro()
      
      def self.simple_macro( name, *terms )
         return node( :simple_macro, ::name => w(name), :expression => expression(*terms) )
      end
      
            
      #
      # ::parameterized_macro()
      
      def self.parameterized_macro( name, parameters, *terms )
         return node( :parameterized_macro, :name => w(name), :parameter_definitions => parameters.collect{|p| w(p)}, :expression => expression(*term) )
      end



      

      #
      # Finally, build the AST so it can be accessed.

      build_ast()

          
   end # BootstrapGrammar
   


end  # module Grammar
end  # module Languages
end  # module RCC
