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
         # Grammar RCC
         # 
         #    StartRule grammar
         #    Ignore    whitespace
         #    Ignore    comment
         # 
         
         @@ast = grammar( 'RCC',

            option( "StartRule", "grammar"    ),
            option( "Ignore"   , "whitespace" ),
            option( "Ignore"   , "comment"    ),

         #
         #    Characters
         #       any_character     => [\u0000-\uFFFF]
         #       digit             => [0-9]
         #       hex_digit         => [{digit}a-fA-F]
         #       word_first_char   => [a-zA-Z_]
         #       word_char         => [{word_first_char}{digit}]
         #       general_character => [{any_character}]-['\n\r\\]
         #    end
         #
         
            characters_section(
               character_definition( 'any_character'    , cs_characters(cs_range(ust('0000'), ust('FFFF'))) ),
               character_definition( 'digit'            , cs_characters(cs_range('0'        , '9'        )) ),
               character_definition( 'hex_digit'        , cs_characters(cs_reference('digit'), cs_range('a', 'f'), cs_range('A', 'F')) ),
               character_definition( 'word_first_char'  , cs_characters(cs_range('a', 'z'), cs_range('A', 'Z'), '_')            ),
               character_definition( 'word_char'        , cs_characters(cs_reference('word_first_char'), cs_reference('digit')) ),
               character_definition( 'general_character',
                  cs_difference(
                     cs_characters( cs_reference('any_character') ),
                     cs_characters( "'", est('n'), est('r')       )
                  )
               )
            ),
            
         # 
         #    Words
         #       unicode_sequence  => '\\' 'u' hex_digit hex_digit hex_digit hex_digit
         #       escape_sequence   => '\\' [a-z\\\-\[\]\']
         #       word              => word_first_char word_char*
         #       eol               => '\n'
         #       general_text      => general_character+
         #       whitespace        => [ \t\r]+
         #       comment           => '#' [{any_character}]-[\n]*
         #       property_text     => [{general_character}]-[}]+
         #       variable          => '$' word
         #    end
         # 

            words_section(
               word_definition( 'unicode_sequence', est('\\'), 'u', sp_reference('hex_digit'), sp_reference('hex_digit'), sp_reference('hex_digit'), sp_reference('hex_digit') ),
               word_definition( 'escape_sequence' , est('\\'), cs_characters(cs_range('a', 'z'), est('\\'), est('-'), est('['), est(']'), est("'")) ),
               word_definition( 'word'            , sp_reference('word_first_char'), sp_repeated('*', sp_reference('word_char')) ),
               word_definition( 'eol'             , est('n')                                                 ),
               word_definition( 'general_text'    , sp_repeated('+', sp_reference('general_character'))      ),
               word_definition( 'whitespace'      , sp_repeated('+', cs_characters(' ', est('t'), est('r'))) ),
               word_definition( 'comment'         , '#', sp_repeated('*', cs_difference(cs_characters(cs_reference('any_character')), est('n'))) ),
               word_definition( 'property_text'   , sp_repeated('+', cs_difference(cs_characters(cs_reference('general_character')), cs_characters('}')))  ),
               word_definition( 'variable'        , '$', sp_reference('word')                                )
            ),

         #
         #    Patterns
         #       eols              => eol:ignore*
         #       statement         => %% eols ;
         #       block( header )   => statement() [ statement() [$header] %% 'end' ]
         # 
         
            patterns_section(
               pattern_definition( 'eols'     , pattern(fe_repeated('*', fe_reference('eol', 'ignore')))               ),
               pattern_definition( 'statement', pattern(fe_transclusion(), fe_reference('eols'), fe_recovery_commit()) ),
               pattern_definition( 'block', parameter_definition('header'),
                  pattern(
                     fe_macro_call('statement', 
                        fe_macro_call( 'statement', fe_variable('header') ),
                        fe_transclusion(),
                        fe_string('end')
                     )
                  )
               ),

         #
         #       character         => unicode_sequence
         #                         => escape_sequence
         #                         => general_character
         # 
         
               pattern_definition( 'character',
                  pattern( fe_reference('unicode_sequence' ) ),
                  pattern( fe_reference('escape_sequence'  ) ),
                  pattern( fe_reference('general_character') )
               ),

         #
         #       string_element    => unicode_sequence
         #                         => escape_sequence
         #                         => general_text
         #
         
               pattern_definition( 'string_element',
                  pattern( fe_reference('unicode_sequence' ) ),
                  pattern( fe_reference('escape_sequence'  ) ),
                  pattern( fe_reference('general_text'     ) )
               )               
         #
         #    end
         #
            ),
            
         # 
         #    Group grammar
         #       Forms
         #          grammar  => block('Grammar' word:name) [ preamble? rules|group+ ]
         # 

            group( 'grammar',
               forms_section(
                  form_definition( 'grammar',
                     form(
                        fe_macro_call('block', parameter(fe_string('Grammar'), fe_reference('word', 'name')),
                           fe_repeated( '?', fe_reference('preamble') ),
                           fe_branch( 
                              fe_reference( 'rules' ),
                              fe_repeated( '+', fe_reference('groups') )
                           )
                        )
                     )
                  ),
         
         #
         #          preamble => option* characters_section? words_section? patterns_section?
         #          rules    => forms_section precedence_section?
         #          group    => block('Group' word:name?) [ preamble? rules ]
         # 
         
                  form_definition( 'preamble',
                     form( 
                        fe_repeated( '*', fe_reference('option'            ) ),
                        fe_repeated( '?', fe_reference('characters_section') ),
                        fe_repeated( '?', fe_reference('words_section'     ) ),
                        fe_repeated( '?', fe_reference('patterns_section'  ) )
                     )
                  ),
                  
                  form_definition( 'rules',
                     form( fe_reference('forms_section'), fe_repeated('?', fe_reference('precedence_section')) )
                  ),
                  
                  form_definition( 'group',
                     form(
                        fe_macro_call('block', parameter(fe_string('Group'), fe_repeated('?', fe_reference('word', 'name'))),
                           fe_repeated( '?', fe_reference('preamble') ),
                           fe_reference('rules', 'body')
                        )
                        
                     )
                  ),

         #
         #          option   => 'StartRule':type          word:rule_name
         #                   => 'Ignore':type             word:name
         #                   => 'EnableBacktracking':type
         #
         
                  form_definition( 'option',
                     form( fe_string('StartRule', 'type'), fe_reference('word', 'rule_name') ),
                     form( fe_string('Ignore'   , 'type'), fe_reference('word', 'name'     ) ),
                     form( fe_string('EnableBacktracking', 'type')                           )
                  )
                  
         #
         #       end
         #    end
         # 

               )
            ),
         
         #
         #    Group characters
         #       Forms
         #          characters_section   => block('Characters') [ character_definition* ]
         #          character_definition => statement() [ word:name '=>' character_set ]
         # 
         #          character_set        => '[' cs_element+ ']'                           {cs_characters}
         #                               => character_set:lhs '-' character_set:rhs       {cs_difference}          {assoc=none}
         # 
         #          cs_element           => character:from '-' character:to               {cs_range}
         #                               => character                                     {cs_character}
         #                               => '{' word:name '}'                             {cs_reference}
         #       end
         #    end
         # 
         
            group( 'characters',
               forms_section(
                  form_definition( 'characters_section',
                     form(
                        fe_macro_call( 'block', parameter(fe_string('Characters')), fe_repeated('*', fe_reference('character_definition')) )
                     )
                  ),

                  form_definition( 'character_definition',
                     form(
                        fe_macro_call( 'statement', fe_reference('word', 'name'), fe_string('=>'), fe_reference('character_set') )
                     )
                  ),

                  form_definition( 'character_set',
                     form( 'cs_characters', fe_string('['), fe_repeated('+', fe_reference('set_body', 'element')), fe_string(']')                                     ),
                     form( 'cs_difference', fe_reference('character_set', 'lhs'), fe_string('-'), fe_reference('character_set', 'rhs'), property_set('assoc', 'left') )
                  ),

                  form_definition( 'cs_element',
                     form( 'cs_range',     fe_reference('character', 'from'), fe_string('-'), fe_reference('character', 'to') ),
                     form( 'cs_character', fe_reference('character')                                                          ),
                     form( 'cs_reference', fe_string('{'), fe_reference('word', 'name'), fe_string('}')                       )
                  )
               )
            ),
            
         #
         #    Group words
         #       Forms
         #          words_section        => block('Words') [ word_definition* ]
         #          word_definiton       => statement() [ word:name '=>' string_pattern:definition ]
         # 
         #          string_pattern       => string                                        {sp_string}
         #                               => word:name                                     {sp_reference}
         #                               => character_set                                 {sp_characters}
         #                               => '(' string_pattern ')'                        {sp_group}
         #                               => string_pattern '|' string_pattern             {sp_branch}
         #                               => string_pattern string_pattern                 {sp_concat}              {assoc=left}
         #                               => string_pattern ('*'|'+'|'?'):repeat_count     {sp_repeated}            {assoc=left}
         # 
         #          string               => '\'' string_element+ '\''
         #       end
         #    end
         # 

            group( 'words',
               forms_section(
                  form_definition( 'words_section',
                     form(
                        fe_macro_call( 'block', parameter(fe_string('Words')), fe_repeated('*', fe_reference('word_definition')) )
                     )
                  ),

                  form_definition( 'word_definition',
                     form(
                        fe_macro_call( 'statement', fe_reference('word', 'name'), fe_string('=>'), fe_reference('string_pattern', 'definition') )
                     )
                  ),

                  form_definition( 'string_pattern',
                     form( 'sp_string'    , fe_reference('string'       ) ),
                     form( 'sp_reference' , fe_reference('word', 'name' ) ),
                     form( 'sp_characters', fe_reference('character_set') ),
                     form( 'sp_group'     , fe_string('('), fe_reference('string_pattern'), fe_string(')') ),
                     form( 'sp_branch'    , fe_reference('string_pattern'), fe_string('|'), fe_reference('string_pattern') ),
                     form( 'sp_concat'    , fe_reference('string_pattern', 'lhs'), fe_reference('string_pattern', 'rhs'), property_set('assoc', 'left') ),
                     form( 'sp_repeated'  , fe_reference('string_pattern'), fe_group(fe_branch(fe_string('*'), fe_string('+'), fe_string('?')), 'repeat_count'), property_set('assoc', 'left') )
                  ),

                  form_definition( 'string',
                     form( fe_string(est("'")), fe_repeated('+', fe_reference('string_element')), fe_string(est("'")) )
                  )
               )
            ),

         #
         #    Group forms
         #       Forms
         #          forms_section        => block('Forms') [ form_definition* ]
         #          form_definition      => word:name eols? form+
         #          form                 => statement() [ '=>' form_expression directive* ]
         # 

            group( 'forms',
               forms_section(
                  form_definition( 'forms_section',
                     form(
                        fe_macro_call( 'block', parameter(fe_string('Forms')), fe_repeated('*', fe_reference('form_definition')) )
                     )
                  ),

                  form_definition( 'form_definition',
                     form( fe_reference('word', 'name'), fe_repeated('?', fe_reference('eols')), fe_repeated('+', fe_reference('form')) )
                  ),

                  form_definition( 'form',
                     form(
                        fe_macro_call( 'statement', fe_string('=>'), fe_reference('form_pattern'), fe_repeated('*', fe_reference('directive')) )
                     )
                  ),
                  
         #
         #          form_expression      => string term_label?                            {fe_string}
         #                               => word:name   term_label?                       {fe_reference}
         #                               => '(' form_expression ')' term_label?           {fe_group}
         #                               => form_expression form_expression               {fe_sequence}         {assoc=left}
         #                               => form_expression '|' form_expression           {fe_branch}           {assoc=left}
         #                               => form_expression ('*'|'+'|'?'):repeat_count    {fe_repeated}
         #                               => '!' word                                      {fe_unignore}
         #                               => ';'                                           {fe_recovery_commit}
         #                               => '%%'                                          {fe_transclusion}
         #                               => word:macro_name !whitespace '(' parameters? ')' ('[' form_expression:body? ']')?  {fe_macro_call}
         # 

                  form_definition( 'form_expression',
                     form( 'fe_string'         , fe_reference('string'), fe_repeated('?', fe_reference('term_label')) ),
                     form( 'fe_reference'      , fe_reference('word', 'name'), fe_repeated('?', fe_reference('term_label')) ),
                     form( 'fe_group'          , fe_string('('), fe_reference('form_expression'), fe_string(')'), fe_repeated('?', fe_reference('term_label'))        ),
                     form( 'fe_sequence'       , fe_reference('form_expression'), fe_reference('form_expression'),                 property_set('assoc', 'left')      ),
                     form( 'fe_branch'         , fe_reference('form_expression'), fe_string('|'), fe_reference('form_expression'), property_set('assoc', 'left')      ),
                     form( 'fe_repeated'       , 
                        fe_reference('form_expression'), 
                        fe_group( fe_branch(fe_string('*'), fe_string('+'), fe_string('?'), fe_reference('variable')), 'repeat_count') 
                     ),
                     form( 'fe_unignore'       , fe_string('!'), fe_reference('word') ),
                     form( 'fe_recovery_commit', fe_string(';')                       ),
                     form( 'fe_transclusion'   , fe_string('%%')                      ),
                     form( 'fe_macro_call'     ,
                        fe_reference('word', 'macro_name'),
                        fe_unignore('whitespace'),
                        fe_string('('),
                        fe_repeated('?', fe_reference('parameters')),
                        fe_string(')'),
                        fe_repeated('?',
                           fe_group(
                              form_expression(
                                 fe_string('['),
                                 fe_reference('form_expression', 'body'),
                                 fe_string(']')
                              )
                           )
                        )
                     )
                  ),
                  
         #
         #          term_label           => ':' word:label
         # 
         #          directive            => '{' word:name '}'                                {form_name}
         #                               => '{' word:name '=' property_text:value '}'        {property_set}
         # 
         #          parameters           => form_expression                                  {parameter}
         #                               => parameters ',' parameters                        {parameter_tree}      {assoc=left}
         # 
         #          precedence_section   => block('Precedence') [ precedence_level* ]
         #          precedence_level     => statement() [ word:reference+ ]
         #       end
         # 

                  form_definition( 'term_label',
                     form( fe_string(':'), fe_reference('word', 'label') )
                  ),

                  form_definition( 'directive',
                     form( 'form_name'   , fe_string('{'), fe_reference('word', 'name'), fe_string('}') ),
                     form( 'property_set', fe_string('{'), fe_reference('word', 'name'), fe_string('='), fe_reference('property_text', 'value'), fe_string('}') )
                  ),

                  form_definition( 'parameters',
                     form( 'parameter'     , fe_reference('form_expression') ),
                     form( 'parameter_tree', fe_reference('parameters'), fe_string(','), fe_reference('parameters'), property_set('assoc', 'left') )
                  ),

                  form_definition( 'precedence_section',
                     form(
                        fe_macro_call( 'block', parameter(fe_string('Precedence')), fe_repeated('*', fe_reference('precedence_level')) )
                     )
                  ),

                  form_definition( 'precedence_level',
                     form(
                        fe_macro_call( 'statement', fe_repeated('+', fe_reference('word')) )
                     )
                  )
               ),
               
         #
         #       Precedence
         #          fe_repeat
         #          fe_branch
         #          fe_sequence
         #       end
         #

               precedence_section(
                  precedence_level( 'fe_repeat'   ),
                  precedence_level( 'fe_branch'   ),
                  precedence_level( 'fe_sequence' )
               )
               
         #
         #    end
         #
         
            ),
            
         # 
         #    Group patterns
         #       Forms
         #          patterns_section      => block('Patterns') [ pattern_definition* ]
         #          pattern_definition    => word:name !whitespace '(' parameter_definitions? ')' eols? pattern+   {parameterized_pattern}
         #                                => word:name eols? pattern+                                              {simple_pattern}
         #          pattern               => statement() [ '=>' form_expression ]
         # 
         #          parameter_definitions => word:name                                        {parameter_definition}
         #                                => parameter_list:tree ',' parameter_list:leaf      {parameter_definition_tree}     {assoc=left}
         #       end
         #    end
         #
         
            group( 'patterns',
               forms_section(
                  form_definition( 'patterns_section',
                     form(
                        fe_macro_call( 'block', parameter(fe_string('Patterns')), fe_repeated('*', fe_reference('pattern_definition')) )
                     )
                  ),

                  form_definition( 'pattern_definition',
                     form( 'parameterized_pattern',
                        fe_reference('word', 'name'),
                        fe_unignore('whitespace'),
                        fe_string('('),
                        fe_repeated('?', fe_reference('parameter_definitions')),
                        fe_string(')'),
                        fe_repeated('?', fe_reference('eols')),
                        fe_repeated('+', fe_reference('pattern'))
                     ),
                     form( 'simple_pattern',
                        fe_reference('word', 'name'),
                        fe_repeated('?', fe_reference('eols')),
                        fe_repeated('+', fe_reference('pattern'))
                     )
                  ),
                  
                  form_definition( 'pattern',
                     form(
                        fe_macro_call( 'statement', fe_string('=>'), fe_reference('form_expression') )
                     )
                  ),
                  
                  form_definition( 'parameter_definitions',
                     form( 'parameter_definition'     , fe_reference('word', 'name') ),
                     form( 'parameter_definition_tree', fe_reference('parameter_definition', 'tree'), fe_string(','), fe_reference('parameter_definition', 'leaf'), property_set('assoc', 'left') )
                  )
               )
            )
            
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
         attr_reader :subtype
         attr_reader :ast_class_name
         
         def initialize( type, subtype, slots )
            super( type )
            @slots          = slots
            @subtype        = subtype.nil? ? type : subtype
            @ast_class_name = nil 
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
      # ::node()
      #  - returns a new FakeASN from parts
      
      def self.node( type, subtype, slots = {} )
         return ASN.new( type, subtype, slots )
      end
      
      
      #
      # ::grammar()
   
      def self.grammar( name, *clauses )
         preamble = []
         groups   = []
         rules    = []
         
         clauses.each do |clause|
            case clause.type
            when :option, :characters_section, :words_section, :patterns_section
               preamble << clause
            when :forms_section, :precedence_section
               rules << clause
            when :group
               groups << clause
            else
               bug( "wtf?" )
            end
         end
         
         assert( groups.empty? || rules.empty?, "you can't supply both" )
         
         if groups.empty? then
            return node( :grammar, nil, :name => w(name), :preamble => preamble(*preamble), :rules  => rules(*rules) )
         else
            return node( :grammar, nil, :name => w(name), :preamble => preamble(*preamble), :groups => groups )
         end
      end
      
      
      #
      # ::option()
      #  - builds an option node from bare strings
      
      def self.option( *data )
         case data[0]
         when "StartRule"
            return node( :option, nil, :type => t(data[0]), :rule_name => w(data[1]) )
         when "Ignore"
            return node( :option, nil, :type => t(data[0]), :name      => w(data[1]) )
         when "EnableBacktracking"
            return node( :option, nil, :type => t(data[0]) )
         else
            bug( "unknown option [#{data[0]}]" )
         end
      end
      
      
      #
      # ::group()
      
      def self.group( name, *sections )
         preamble = []
         rules    = []
         
         sections.each do |section|
            case section.type
            when :option, :characters_section, :words_section, :patterns_section
               preamble << section
            when :forms_section, :precedence_section
               rules << section
            else
               bug( "wtf?" )
            end
         end
         
         return node( :group, nil, :name => w(name), :preamble => preamble(*preamble), :rules => rules(*rules) )
      end
      
      
      #
      # ::preamble()
      
      def self.preamble( *sections )
         options            = []
         characters_section = nil
         words_section      = nil
         patterns_section   = nil
         
         sections.each do |section|
            case section.type
            when :option
               options << section
            when :characters_section
               characters_section = section
            when :words_section
               words_section = section
            when :patterns_section
               patterns_section = section
            else
               bug( "wtf?" )
            end
         end
         
         return node( :preamble, nil, :options => options, :characters_section => characters_section, :words_section => words_section, :patterns_section => patterns_section )
      end
      
      
      #
      # ::rules()
      
      def self.rules( *sections ) 
         forms_section = precedence_section = nil
         
         sections.each do |section|
            case section.type
            when :forms_section
               forms_section = section
            when :precedence_section
               precedence_section = section
            else
               bug( "wtf?" )
            end
         end
         
         return node( :rules, nil, :forms_section => forms_section, :precedence_section => precedence_section )
      end
      

      #
      # ::characters_section()

      def self.characters_section( *definitions )
         return node( :characters_section, nil, :character_definitions => definitions )
      end
         

      #
      # ::character_definition()
      
      def self.character_definition( name, definition )
         return node( :character_definition, nil, :name => w(name), :character_set => definition )
      end
      
      
      #
      # ::cs_characters()
      
      def self.cs_characters( *elements )
         return node( :character_set, :cs_characters, :cs_elements => elements.collect{|e| cs_character(e)} )
      end
      
      
      #
      # ::cs_difference()
      
      def self.cs_difference( lhs, rhs )
         return node( :character_set, :cs_difference, :lhs => lhs, :rhs => rhs )
      end


      #
      # ::cs_range()
      
      def self.cs_range( from, to )
         return node( :cs_element, :cs_range, :from => character(from), :to => character(to) )
      end
      
      
      #
      # ::cs_character()
      
      def self.cs_character( character )
         return character if character.is_an?(ASN)
         return node( :cs_element, :cs_character, :character => character(character) )
      end
      
      
      #
      # ::cs_reference()
      
      def self.cs_reference( name )
         return node( :cs_element, :cs_reference, :name => w(name) )
      end
      
      
      #
      # ::character()
      #  - "character" is treated as a token class, not a rule, so this is a no-op
   
      def self.character( token )
         return gct(token) unless token.is_a?(Node)
         return token
      end
      
      
      #
      # ::words_section()
      
      def self.words_section( *definitions )
         return node( :words_section, nil, :word_definitions => definitions )
      end
      
      
      #
      # ::word_definition()
      #  - produces a :word_definition Node, given one or more :string_pattern
      #  - Strings are up-converted to :general_text Tokens
      #  - all terms are up-converted to string_patterns, as necessary
      #  - multiple terms are up-converted to a tree of sp_concat Nodes
      
      def self.word_definition( name, *terms )
         terms.unshift sp_concat( terms.shift, terms.shift ) until terms.length < 2
         return node( :word_definition, nil, :name => w(name), :definition => string_pattern(terms[0]) )
      end
      
      
      #
      # ::string_pattern()
      
      def self.string_pattern( term )
         if term.is_an?(ASN) then
            return term if term.type == :string_pattern
            return sp_characters(term) if term.type == :character_set
         end
         
         return sp_string(term)
      end
      
      
      #
      # ::sp_string()
      
      def self.sp_string( string )
         return string if string.is_an?(ASN) and term.type == :string_pattern
         return node( :string_pattern, :sp_string, :string => string(string) )
      end
      
      
      #
      # ::sp_reference()
      
      def self.sp_reference( name )
         return node( :string_pattern, :sp_reference, :name => w(name) )
      end
      
      
      #
      # ::sp_characters()
      
      def self.sp_characters( character_set )
         assert( character_set.is_an?(ASN) && character_set.type == :character_set, "expected :character_set" )
         return node( :string_pattern, :sp_characters, :character_set => character_set )
      end
      
      
      #
      # ::sp_group()
      
      def self.sp_group( string_pattern )
         return node( :string_pattern, :sp_group, :string_pattern => string_pattern(string_pattern) )
      end
      
      
      #
      # ::sp_concat()
      
      def self.sp_concat( lhs, rhs )
         return node( :string_pattern, :sp_concat, :lhs => string_pattern(lhs), :rhs => string_pattern(rhs) )
      end
      
      
      #
      # ::sp_repeated()
      
      def self.sp_repeated( count, string_pattern )
         return node( :string_pattern, :sp_repeated, :repeat_count => t(count), :string_pattern => string_pattern(string_pattern) )
      end
      
      
      #
      # ::string()
      
      def self.string( *elements )
         return node( :string, nil, :string_elements => elements.collect{|e| gtt(e)} )
      end
      
      
      #
      # ::forms_section()
      
      def self.forms_section( *definitions )
         return node( :forms_section, nil, :form_definitions => definitions )
      end
      
      
      #
      # ::forms_definition()
      
      def self.form_definition( name, *forms )
         return node( :form_definition, nil, :name => w(name), :forms => forms )
      end
      
      
      #
      # ::form()
      #  - first parameter can be a String that names the form
      #  - everything else must be :form_expression or :directive Nodes
      
      def self.form( *elements )
         
         #
         # Filter out any :directives
         
         directives = []
         if elements[0].is_a?(String) then
            directives << form_name(elements.shift)
         end
         
         directives.concat( elements.remove_if{|e| e.type == :directive} )

         
         #
         # Convert the remaining elements to a tree and return the Node.
         
         return node( :form, nil, :form_expression => form_expression(*elements), :directives => directives )
      end

      
      #
      # ::form_expression()
   
      def self.form_expression( *elements )
         elements.unshift fe_sequence( elements.shift, elements.shift ) until elements.length < 2
         return elements[0]
      end

      
      #
      # ::fe_string()
      
      def self.fe_string( string, label = nil )
         return node( :form_expression, :fe_string, :string => string(string), :term_label => term_label(label) )
      end
      
      
      #
      # ::fe_reference()
      
      def self.fe_reference( name, label = nil )
         return node( :form_expression, :fe_reference, :name => w(name), :term_label => term_label(label) )
      end
         
         
      #
      # ::fe_variable()
      
      def self.fe_variable( variable, label = nil )
         return node( :form_expression, :fe_variable, :variable => vt(variable), :term_label => term_label(label) )
      end
      
      
      #
      # ::fe_group()
      
      def self.fe_group( form_expression, label = nil )
         return node( :form_expression, :fe_group, :form_expression => form_expression, :term_label => term_label(label) )
      end
      
      
      #
      # ::fe_sequence()
      
      def self.fe_sequence( lhs, rhs )
         return node( :form_expression, :fe_sequence, :form_expression_1 => lhs, :form_expression_2 => rhs )
      end
      
      
      #
      # ::fe_branch()
      
      def self.fe_branch( lhs, rhs, *more )
         if more.empty? then
            return node( :form_expression, :fe_branch, :form_expression_1 => lhs, :form_expression_2 => rhs )
         else
            return fe_branch( fe_branch(lhs, rhs), *more )
         end
      end
      
      
      #
      # ::fe_repeated()
   
      def self.fe_repeated( count, expression )
         return node( :form_expression, :fe_branch, :repeat_count => t(count), :form_expression => expression )
      end
      
      
      #
      # ::fe_unignore()
      
      def self.fe_unignore( word )
         return node( :form_expression, :fe_unignore, :word => w(word) )
      end
      
      
      #
      # ::fe_recovery_commit()
      
      def self.fe_recovery_commit()
         return node( :form_expression, :fe_recovery_commit )
      end
      
      
      #
      # ::fe_transclusion()
      
      def self.fe_transclusion()
         return node( :form_expression, :fe_transclusion )
      end
      
      
      #
      # ::fe_macro_call()
      #  - pass the macro name, followed by any parameters, followed by any form_expressions to pass for transclusion
      
      def self.fe_macro_call( name, *data )
         parameters = data.remove_if{|e| e.is_an?(ASN) && e.type == :parameters}
         
         return node( :form_expression, :fe_macro_call, 
            :macro_name => w(name), 
            :parameters => parameters(parameters),
            :body       => form_expression( *data )
         )
      end
      
      
      #
      # ::term_label()
      
      def self.term_label( label )
         return nil if label.nil?
         return node( :term_label, nil, :label => w(label) )
      end
      
      
      #
      # ::form_name()
      
      def self.form_name( name )
         return node( :directive, :form_name, :name => w(name) )
      end
      
      
      #
      # ::property_set
      
      def self.property_set( name, value )
         return node( :directive, :property_set, :name => w(name), :value => ptt(value) )
      end
      
      
      #
      # ::parameters()
      
      def self.parameters( *parameters )
         return nil if parameters.empty?
         parameters.unshift parameter_tree( parameters.shift, parameters.shift ) until parameters.length < 2
         return parameters[0]
      end
      
      
      #
      # ::parameter()
   
      def self.parameter( *elements )
         return node( :parameters, :parameter, :form_expression => form_expression(*elements) )
      end
      
      
      #
      # ::parameter_tree()
      
      def self.parameter_tree( lhs, rhs )
         return node( :parameters, :parameter_tree, :parameters_1 => lhs, :parameters_2 => rhs )
      end
      
      
      #
      # ::precedence_section()
      
      def self.precedence_section( *levels )
         return node( :precedence_section, nil, :precedence_levels => levels )
      end
      
      
      #
      # ::precedence_level()
      
      def self.precedence_level( *references )
         return node( :precedence_level, nil, :references => references.collect{|r| w(r)} )
      end
      
      
      #
      # ::patterns_section()
      
      def self.patterns_section( *definitions )
         return node( :patterns_section, nil, :pattern_definitions => definitions )
      end
      
      
      #
      # ::pattern_definition()
      
      def self.pattern_definition( name, *data )
         parameters = data.remove_if{|e| e.is_an?(ASN) && e.type == :parameter_list}
         if parameters.empty? then
            return simple_pattern( name, *data )
         else
            return parameterized_pattern( name, parameter_definitions(parameters), *data )
         end
      end

      
      #
      # ::simple_pattern()
      
      def self.simple_pattern( name, *patterns )
         return node( :pattern_definition, :simple_pattern, :name => w(name), :patterns => patterns )
      end
      
      
      #
      # :parameterized_pattern()
      
      def self.parameterized_pattern( name, parameter_definitions, *patterns )
         return node( :pattern_definition, :parameterized_pattern, 
            :name                  => name, 
            :parameter_definitions => parameter_definitions(parameter_definitions),
            :patterns              => patterns 
         )
      end
      
      
      #
      # ::pattern()
      
      def self.pattern( *elements )
         return node( :pattern, nil, :form_expression => form_expression(*elements) )
      end
      
      
      #
      # ::parameter_definitions()
      
      def self.parameter_definitions( *names )
         return nil if names.empty?
         parameters = names.collect{|name| parameter_definition(name)}
         parameters.unshift parameter_definition_tree( parameters.shift, parameters.shift ) until parameters.length < 2
         return parameters[0]
      end


      #
      # ::parameter_definition()
      
      def self.parameter_definition( name )
         return node(:parameter_definitions, :parameter_definition, :name => w(name) )
      end
      
      
      #
      # ::parameter_definition_tree()
      
      def self.parameter_definition_tree( tree, leaf )
         return node( :parameter_definitions, :parameter_definition_tree, :tree => tree, :leaf => leaf )
      end
      
      

      #
      # Finally, build the AST so it can be accessed.

      build_ast()

          
   end # BootstrapGrammar
   


end  # module Grammar
end  # module Languages
end  # module RCC
