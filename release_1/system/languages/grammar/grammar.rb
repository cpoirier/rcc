#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright 2007-2008 Chris Poirier (cpoirier@gmail.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the 
# License.  You may obtain a copy of the License at
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" 
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language 
# governing permissions and limitations under the License.
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/system/")[0..-2].join("/system/")}/system/environment.rb"
require "#{RCC_LIBDIR}/scanner/artifacts/name.rb"
require "#{RCC_LIBDIR}/scanner/artifacts/node.rb"
require "#{RCC_LIBDIR}/scanner/artifacts/nodes/token.rb"

module RCC
module Languages
module Grammar

   @@ast     = nil
   @@factory = nil
   
   
   #
   # ::factory()
   #  - returns a factory for grammar parsers -- the fastest one available
   
   def self.factory()
      if @@factory.nil? then
         if File.exists?("#{RCC_LIBDIR}/languages/grammar/parser/parser.rb") then
            nyi( "support for pre-build parser" )
         else
            require "#{RCC_LIBDIR}/languages/grammar/model_builder.rb"
            require "#{RCC_LIBDIR}/scanner/interpreter/factory.rb"
            
            duration = Time.measure do
               system_model = ModelBuilder.build( ast() )
               master_plan  = system_model.compile_master_plan()
               parser_plan  = master_plan.compile_parser_plan( system_model.start_rule )
               
               @@factory = RCC::Scanner::Interpreter::Factory.new( parser_plan )
            end
            
            puts "It took #{duration}s to build the RCC grammar"
         end
      end
      
      return @@factory
   end
   
   
   #
   # ::ast()
   #  - returns the bootstrap grammar as an AST
   
   def self.ast()
      build_ast() if @@ast.nil?
      return @@ast
   end   

   
   
   
 private
 
 
   #
   # ::build_ast()
   #  - builds the AST for the grammar grammar
    
   def self.build_ast()

      #
      # grammar RCC 
      #    priority ascending
      # 
      #    start_rule system_spec
      #    discard    whitespace
      #    discard    comment
      
      @@ast = system_spec( 
      grammar_spec( 'RCC',
         priority( "ascending" ),
         discard_switch( "whitespace" ),
         discard_switch( "comment"    ),
         start_rule( "system_spec" ),
         

      #
      #    section misc
      #       whitespace        := [ \t\r]+
      #       eol               := [\n]
      #       any_character     := [\u0000-\uffff]
      #       line_character    := [{any_character}]-[\n]
      #       general_character := [{line_character}]-['\\\{\}\[\]]
      #       digit             := [0-9]
      #       hex_digit         := [{digit}a-fA-F]
      #       
      #       unicode_sequence  := [\\] [u] [{hex_digit}] [{hex_digit}] [{hex_digit}] [{hex_digit}]
      #       escape_sequence   := [\\] [a-z\\\-\[\]\']
      #       
      #       word              := [a-zA-Z] [a-zA-Z0-9_]*
      #       property_text     := [{general_character}]-[}]+
      #       general_text      := [{general_character}]+
      #       
      #       comment           := [#] [{line_character}]*
      #    end
      #
      
         section_spec( 'misc',

            rule_spec( 'whitespace'       , sp_exp(sp_repeated("+", cs_characters(' ', est('t'), est('r')))) ),
            rule_spec( 'eol'              , sp_exp(cs_characters(est('n')))                           ),
            rule_spec( 'any_character'    , sp_exp(cs_characters(cs_range(ust('0000'), ust('FFFF')))) ),
            rule_spec( 'line_character'   , sp_exp(cs_difference(cs_characters(cs_reference('any_character')), cs_characters(est('n')))) ),
            rule_spec( 'general_character', sp_exp(cs_difference(cs_characters(cs_reference('line_character')), cs_characters("'", est('n'), est('r'), est("\\") ))) ),
            # rule_spec( 'general_character', sp_exp(cs_difference(cs_characters(cs_reference('line_character')), cs_characters("'", est('n'), est('r'), est("\\"), est("\{"), est("\}"), est("\["), est("\]") ))) ),
            rule_spec( 'digit'            , sp_exp(cs_characters(cs_range('0', '9'))) ),
            rule_spec( 'hex_digit'        , sp_exp(cs_characters(cs_reference('digit'), cs_range('a', 'f'), cs_range('A', 'F'))) ),
                                            
            rule_spec( 'unicode_sequence' , sp_exp(sp_sequence(est('\\'), 'u', cs_reference('hex_digit'), cs_reference('hex_digit'), cs_reference('hex_digit'), cs_reference('hex_digit'))) ),
            rule_spec( 'escape_sequence'  , sp_exp(sp_sequence(est('\\'), cs_characters(cs_range('a', 'z'), est('\\'), est('-'), est('['), est(']'), est("'")))) ),
                                            
            rule_spec( 'word'             , sp_exp(sp_sequence(cs_characters(cs_range('a', 'z'), cs_range('A', 'Z')), sp_repeated('*', cs_characters(cs_range('a', 'z'), cs_range('A', 'Z'), cs_range('0', '9'), '_')))) ),
            rule_spec( 'property_text'    , sp_exp(sp_repeated('+', cs_difference(cs_characters(cs_reference('general_character')), cs_characters('}')))) ),
            rule_spec( 'general_text'     , sp_exp(sp_repeated('+', cs_characters(cs_reference('general_character')))) ),
         
            rule_spec( 'comment'          , sp_exp(sp_sequence('#', sp_repeated('*', cs_characters(cs_reference('line_character'))))) )
            
         ),
         
      #
      #    macros
      #       statement         := %% eol:ignore+ ;
      #       block( header )   := statement() [ statement() [$header] %% 'end' ]
      #    end
      # 
      
         macros_spec(
            simple_macro( 'statement', transclusion(), repeated_reference('+', 'eol', 'ignore'), local_commit() ),
            parameterized_macro( 'block', ['header'],
               macro_call('statement', [],
                  macro_call( 'statement', [], variable_exp('header') ),
                  transclusion(),
                  string_exp('end')
               )
            )
         ),
         
      # 
      #    section grammar
      #       system_spec  := grammar_spec+ addendum?
      #       grammar_spec := block('grammar' word:name) [ priority option* specification* transformations? ]
      #       addendum     := statement() [ 'stop' ] 
      # 
      
         section_spec( 'grammar',
            rule_spec( 'system_spec', repeated_reference('*', 'eol', 'ignore'), repeated_reference('+', 'grammar_spec'), repeated_reference('?', 'addendum') ),
            rule_spec( 'grammar_spec', 
               block_macro_call(
                  expression('grammar', reference_exp('word', 'name')), 
                  reference_exp('priority'),
                  repeated_exp('*', reference_exp('option'         )),
                  repeated_exp('*', reference_exp('specification'  )),
                  repeated_exp('?', reference_exp('transformations'))
               )
            ),
            rule_spec( 'addendum',
               statement_macro_call('stop') # , repeated_reference('?', 'any_text')
            ),
      
      #
      #       priority := statement() [ 'priority' ('ascending'|'descending'):direction ]
      #
      #       group option
      #          start_rule          := statement() [ 'start_rule' word:rule_name        ]
      #          discard_switch      := statement() [ 'discard'    word:name             ]
      #          pluralization_guide := statement() [ 'pluralize'  word:name word:plural ]
      #       end
      #
      # 
            rule_spec( 'priority', statement_macro_call(string_exp('priority'), group_exp(branch_exp(string_exp('ascending'), string_exp('descending')), 'direction')) ),
            
            group_spec( 'option',
               rule_spec( 'start_rule'         , statement_macro_call(string_exp('start_rule'), reference_exp('word', 'rule_name')) ),
               rule_spec( 'discard_switch'     , statement_macro_call(string_exp('discard'   ), reference_exp('word', 'name'))      ),
               rule_spec( 'pluralization_guide', statement_macro_call(string_exp('pluralize' ), reference_exp('word', 'name'), reference_exp('word', 'plural')) )
            ),

      #       
      #       group specification
      #          macros_spec     := block('macros')              [ macro_spec*           ]
      #          reorder_spec    := block('reorder')             [ reorder_level*        ]
      #          section_spec    := block('section' word:name)   [ no_discard? discard_switch:option* specification* ]
      #          group_spec      := block('group' word:name)     [ (rule_spec|group_spec|spec_reference):specification* ]
      #          rule_spec       := statement() [ word:name ':=' expression directive* ] transformation_spec*
      #       end
      #
      
            group_spec( 'specification',
               rule_spec( 'macros_spec' , block_macro_call('macros' , repeated_reference('*', 'macro_spec'   )) ),
               rule_spec( 'reorder_spec', block_macro_call('reorder', repeated_reference('*', 'reorder_level')) ),
               
               rule_spec( 'section_spec', 
                  block_macro_call( expression('section', reference_exp('word', 'name')),
                     repeated_reference( '?', 'no_discard' ),
                     repeated_reference( '*', 'discard_switch', "option" ),
                     repeated_reference( '*', 'specification'  )
                  )
               ),
               
               rule_spec( 'group_spec', 
                  block_macro_call( expression('group', reference_exp('word', 'name')),
                     repeated_exp( '*', 
                        group_exp(
                           branch_exp( reference_exp('rule_spec'), reference_exp('group_spec'), reference_exp('spec_reference') ), 
                           'specification'
                        )
                     )
                  )
               ),
               
               rule_spec( 'rule_spec',
                  statement_macro_call( 
                     reference_exp( 'word', 'name' ), 
                     string_exp( ':=' ),
                     reference_exp( 'expression' ),
                     repeated_reference( '*', 'directive' )
                  ),
                  repeated_reference( '*', 'transformation_spec' )
               )
            ),
            
      #       
      #       no_discard     := statement() [ 'no' 'discard' ]
      #       spec_reference := statement() [ word:name ]
      #       reorder_level  := statement() [ word:reference+ ]
      #
            rule_spec( 'no_discard'    , statement_macro_call(string_exp('no'), string_exp('discard'))   ),
            rule_spec( 'spec_reference', statement_macro_call(reference_exp('word', 'name'))                ),
            rule_spec( 'reorder_level' , statement_macro_call(repeated_reference('+', 'word', 'reference')) )
      
      #       
      #    end
      #    
      
         ),
                     
      #    
      #    section rule_spec
      #       macros
      #          labelled()          := %% (':' word:label)?
      #          attribute_set(name) := '@' $name '=' %%
      #       end
      #
      
         section_spec( 'rule_spec',
            macros_spec(
               parameterized_macro( 'labelled', [], transclusion(), repeated_exp('?', group_exp(expression(':', reference_exp('word', 'label')))) ),
               parameterized_macro( 'attribute_set', ['name'], '@', variable_exp('name'), '=', transclusion() )
            ),

      #       
      #       group expression
      #          local_commit := ';'
      #          transclusion := '%%'
      #          gateway_exp  := '!' !whitespace word
      #
      #          group general_exp
      #             group repeatable_exp
      #                reference_exp := labelled() [ word:name            ]
      #                string_exp    := labelled() [ string               ]
      #                sp_exp        := labelled() [ string_pattern       ]
      #                variable_exp  := labelled() [ '$' word:name        ]
      #                group_exp     := labelled() [ '(' general_exp:expression ')'   ]
      #
      #                macro_call    := word:macro_name !whitespace '(' parameters? ')' ('[' expression:body? ']')?
      #                sequence_exp  := expression:tree expression:leaf              {left associative}
      #                branch_exp    := general_exp:tree '|' general_exp:leaf        {left associative}
      #             end
      #
      #             repeated_exp := repeatable_exp:expression ('*'|'+'|'?'):repeat_count
      #          end
      #       end
      # 
         
            group_spec( 'expression',
               rule_spec( 'local_commit', ';'  ),
               rule_spec( 'transclusion', '%%' ),
               rule_spec( 'gateway_exp' , '!', gateway_exp('whitespace'), reference_exp('word') ),
               
               group_spec( 'general_exp',
                  group_spec( 'repeatable_exp',
                     rule_spec( 'reference_exp' , macro_call('labelled', [], reference_exp('word', 'name'  ))       ),
                     rule_spec( 'string_exp'    , macro_call('labelled', [], reference_exp('string'        ))       ),
                     rule_spec( 'sp_exp'        , macro_call('labelled', [], reference_exp('string_pattern'))       ),
                     rule_spec( 'variable_exp'  , macro_call('labelled', [], '$', reference_exp('word', 'name'))    ),
                     rule_spec( 'group_exp'     , macro_call('labelled', [], '(', reference_exp('expression'), ')') ),
                     
                     rule_spec( 'macro_call',
                        reference_exp('word', 'macro_name'), gateway_exp('whitespace'), '(', repeated_reference('?', 'parameters'), ')',
                        repeated_exp( '?', group_exp(expression('[', repeated_reference('?', 'expression', 'body'), ']')) )
                     ),
                     
                     rule_spec( 'branch_exp'    , reference_exp('general_exp', 'tree'), '|', reference_exp('general_exp', 'leaf'), assoc('left') ),
                     rule_spec( 'sequence_exp'  , reference_exp('expression', 'tree')      , reference_exp('expression', 'leaf'),  assoc('left') )                        
                  ),
                  
                  rule_spec( 'repeated_exp'  , reference_exp('repeatable_exp', 'expression'), group_exp(branch_exp('*', '+', '?'), 'repeat_count') )
               )               
            ),
            
      # 
      #       group parameters
      #          expression
      #          parameter_tree  := parameters:tree ',' parameters:leaf      {left associative}
      #       end
      # 
      #       group directive
      #          associativity_directive := '{' 'associativity'? ('left'|'right'|'non'):direction ('assoc'|'associative')? '}'
      #       end
      #
      
            group_spec( 'parameters',
               rule_spec( 'parameter_tree', reference_exp('parameters', 'tree'), ',', reference_exp('parameters', "leaf"), assoc('left') ),
               spec_reference( 'expression' )
            ),
            
            group_spec( 'directive',
               rule_spec( 'associativity_directive', 
                  '{', 
                  repeated_exp('?', string_exp('associativity')),
                  group_exp(
                     branch_exp('left', 'right', 'none'),
                     'direction'
                  ),
                  repeated_exp('?',
                     group_exp(
                         branch_exp('assoc', 'associative')
                     )
                  ),
                  '}'
               )
            ),

      # 
      #       group string_pattern
      #          character_set
      #          sp_group      := '(' string_pattern ')'
      #          sp_sequence   := string_pattern:tree string_pattern:leaf               {left associative}
      #          sp_branch     := string_pattern:tree '|' string_patttern:leaf          {left associative}
      #          sp_repeated   := string_pattern ('*'|'+'|'?'):repeat_count
      #       end
      #
      #       group character_set
      #          cs_characters
      #          cs_difference := character_set:lhs '-' character_set:rhs   @associativity=none
      #       end
      #
      # 
         
            group_spec( 'string_pattern',
               spec_reference( 'character_set' ),
            
               rule_spec( 'sp_group'    , '(', reference_exp('string_pattern'), ')' ),
               rule_spec( 'sp_sequence' , reference_exp('string_pattern', "tree"), reference_exp('string_pattern', "leaf"),      assoc('left')  ),
               rule_spec( 'sp_branch'   , reference_exp('string_pattern', "tree"), '|', reference_exp('string_pattern', "leaf"), assoc('left')  ),
               rule_spec( 'sp_repeated' , reference_exp('string_pattern'), group_exp(branch_exp('*', '+', '?'), 'repeat_count') )
            ),
            
            group_spec( 'character_set',
               spec_reference( 'cs_characters' ),
               rule_spec( 'cs_difference', reference_exp('character_set', 'lhs'), '-', reference_exp('character_set', 'rhs'), assoc('none') )
            )
         ),
         
         
      #
      #    section strings
      #       no discard
      #
      #       string := '\'' (unicode_sequence|escape_sequence|general_text):element+ '\''
      #       cs_characters := '[' cs_element+ ']'
      #
      #       group cs_element
      #          character                              
      #          cs_reference  := '{' word:name '}'              
      #          cs_range      := character:from '-' character:to           @associativity=none
      #       end
      # 
      #       group character
      #          general_character
      #          unicode_sequence
      #          escape_sequence
      #       end
      #    end
      #    
      
         section_spec( 'strings',
            no_discard(),
         
            rule_spec( 'string', 
               est("'"), 
               repeated_exp( '+', group_exp(branch_exp(reference_exp('unicode_sequence'), reference_exp('escape_sequence'), reference_exp('general_text')), 'element') ), 
               est("'") 
            ),

            rule_spec( 'cs_characters', '[', repeated_reference('+', 'cs_element'), ']' ),
         
            group_spec( 'cs_element',
               spec_reference( 'character' ),
               rule_spec( 'cs_reference', '{', reference_exp('word', 'name'), '}' ),
               rule_spec( 'cs_range'    , reference_exp('character', 'from'), '-', reference_exp('character', 'to'), assoc('none') )
            ),
         
            group_spec( 'character',
               spec_reference( 'general_character' ),
               spec_reference( 'unicode_sequence'  ),
               spec_reference( 'escape_sequence'   )
            )

         ),
      
      
         
      #    
      #    section transformations
      #       transformations         := block('transformations') [ transformation_set* ]
      #       transformation_set      := word:rule_name eol:ignore* transformation_spec+
      #
      #       group transformation_spec
      #          assignment_transform := statement() ['**' npath:destination '='  npath:source ]
      #          append_transform     := statement() ['**' npath:destination '+=' npath:source ]
      #       end
      #
      #       group npath
      #          npath_self_exp       := '.'
      #          npath_slot_exp       := '@' word:slot_name
      #          npath_tclose_exp     := '{' npath '}'
      #          npath_branch_exp     := npath:tree '|' npath:leaf   {left associative}
      #          npath_reverse_exp    := '-' npath 
      #          npath_predicate_exp  := npath '[' npred ']'         {left associative}
      #          npath_path_exp       := npath:tree '/' npath:leaf   {left associative}
      #          npath_group_exp      := '(' npath ')'
      #       end
      #
      #       group npred
      #          npred_type_exp       := word:type_name
      #          npath
      #          npred_or_exp         := npred:tree '|' npred:leaf   {left associative}
      #          npred_and_exp        := npred:tree '&' npred:leaf   {left associative}
      #          npred_negation_exp   := '!' npred
      #       end
      #
      #       reorder
      #          npred_type_exp
      #          npath_slot_exp
      #       end
      #    end
      #    
      
         section_spec( 'transformations',
            rule_spec( 'transformations'   , block_macro_call(expression('transformations'), repeated_reference('*', 'transformation_set')) ),
            rule_spec( 'transformation_set', 
               reference_exp('word', 'rule_name'), 
               repeated_reference('*', 'eol', 'ignore'), 
               repeated_reference('+', 'transformation_spec') 
            ),
         
            group_spec( 'transformation_spec',
               rule_spec( 'assignment_transform', statement_macro_call('**', reference_exp('npath', 'destination'), '=' , reference_exp('npath', 'source')) ),
               rule_spec( 'append_transform'    , statement_macro_call('**', reference_exp('npath', 'destination'), '+=', reference_exp('npath', 'source')) )
            ),
            
            group_spec( 'npath',
               rule_spec( 'npath_self_exp'     , '.'                                                                                ),
               rule_spec( 'npath_slot_exp'     , '@', reference_exp('word', 'slot_name')                                            ),
               rule_spec( 'npath_tclose_exp'   , '{', reference_exp('npath'), '}'                                                   ),
               rule_spec( 'npath_branch_exp'   , reference_exp('npath', 'tree'), '|', reference_exp('npath', 'leaf'), assoc('left') ),
               rule_spec( 'npath_reverse_exp'  , '-', reference_exp('npath')                                                        ),
               rule_spec( 'npath_predicate_exp', reference_exp('npath'), '[', reference_exp('npred'), ']'                           ),
               rule_spec( 'npath_path_exp'     , reference_exp('npath', 'tree'), '/', reference_exp('npath', 'leaf'), assoc('left') ),
               rule_spec( 'npath_group_exp'    , '(', reference_exp('npath'), ')'                                                   )
            ),

            group_spec( 'npred',
               rule_spec( 'npred_type_exp'    , reference_exp('word', 'type_name')                                  ),
               spec_reference( 'npath' ),
               rule_spec( 'npred_or_exp'      , reference_exp('npred', 'tree'), '|', reference_exp('npred', 'leaf') ),
               rule_spec( 'npred_and_exp'     , reference_exp('npred', 'tree'), '&', reference_exp('npred', 'leaf') ),
               rule_spec( 'npred_negation_exp', '!', reference_exp('npred')                                         )
            ),
            
            reorder_spec(
               reorder_level('npred_type_exp'),
               reorder_level('npath_slot_exp')
            )
            
         ),
      
      #
      #    section macros_spec
      #       macro_spec := statement() [ word:name (!whitespace '(' parameter_defs? ')')? ':=' expression ]
      #       
      #       group parameter_defs
      #          parameter_def_tree := parameter_defs:tree ',' parameter_defs:leaf   {left associative}
      #          word
      #       end
      #    end
      #
      
         section_spec( 'macros_spec',
            rule_spec( 'macro_spec',
               statement_macro_call(
                  reference_exp('word', 'name'), 
                  repeated_exp( '?',
                     group_exp(
                        expression(
                           gateway_exp('whitespace'), '(', repeated_reference('?', 'parameter_defs'), ')' 
                        )
                     )
                  ),
                  ':=', 
                  reference_exp('expression') 
               )
            ),
            
            
            group_spec( 'parameter_defs',
               rule_spec( 'parameter_def_tree', 
                  reference_exp( 'parameter_defs', 'tree' ),
                  ',',
                  reference_exp( 'parameter_defs', 'leaf' ),
                  assoc('left')
               ),
               
               spec_reference('word')
            )
         ),
         
      #
      #    transformations
      #       macro_call      ** @parameters = @parameters/{@tree|@leaf}[expression]
      #       npred_or_exp    ** @elements = @tree[npred_or_exp]/@elements  | @tree[!npred_or_exp]  | @leaf
      #       npred_and_exp   ** @elements = @tree[npred_and_exp]/@elements | @tree[!npred_and_exp] | @leaf
      #       npath_group_exp ** . = @npath
      #       macro_spec      ** @parameter_defs = @parameter_defs/{@tree|@leaf}[word]
      #    end
      
         transformations(
            transformation_set( "macro_call",
               assignment_transform(
                  npath_slot_exp( "parameters" ),
                  npath_predicate_exp(
                     npath_path_exp( npath_slot_exp("parameters"), npath_tclose_exp(npath_branch_exp(npath_slot_exp("tree"),npath_slot_exp("leaf"))) ),
                     npred_type_exp("expression")
                  )
               )
            ),
         
            transformation_set( "npred_or_exp",
               assignment_transform(
                  npath_slot_exp( "elements" ),
                  npath_branch_exp(
                     npath_path_exp( npath_predicate_exp(npath_slot_exp("tree"), npred_type_exp("npred_or_exp")), npath_slot_exp("elements") ),
                     npath_predicate_exp( npath_slot_exp("tree"), npred_negation_exp(npred_type_exp("npred_or_exp")) ),
                     npath_slot_exp("leaf")
                  )
               )
            ),
         
            transformation_set( "npred_and_exp",
               assignment_transform(
                  npath_slot_exp( "elements" ),
                  npath_branch_exp(
                     npath_path_exp( npath_predicate_exp(npath_slot_exp("tree"), npred_type_exp("npred_and_exp")), npath_slot_exp("elements") ),
                     npath_predicate_exp( npath_slot_exp("tree"), npred_negation_exp(npred_type_exp("npred_and_exp")) ),
                     npath_slot_exp("leaf")
                  )
               )
            ),
         
            transformation_set( "npath_group_exp",
               assignment_transform(
                  npath_self_exp(),
                  npath_slot_exp( "npath" )
               )
            ),
         
            transformation_set( "macro_spec",
               assignment_transform(
                  npath_slot_exp( "parameter_defs" ),
                  npath_predicate_exp(
                     npath_path_exp( npath_slot_exp("parameter_defs"), npath_tclose_exp(npath_branch_exp(npath_slot_exp("tree"), npath_slot_exp("leaf"))) ),
                     npred_type_exp("word")
                  )
               )
            )
         
         )
      
      #
      # end
      #
      
      ))
      
   end
 
   
   
   
 #---------------------------------------------------------------------------------------------------------------------
 # Support
 #---------------------------------------------------------------------------------------------------------------------

   Name  = RCC::Scanner::Artifacts::Name
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
      
      def []( name )
         return @slots[name]
      end
      
      def []=( name, value )
         @slots[name] = value
      end
      
    
      def description() ; return "#{@ast_class_name} (#{@type})" ; end

      def follow_position() ; return nil   ; end
      def token?()          ; return false ; end      
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
      
      
      def duplicate()
         copied_slots = @slots.class.new()
         @slots.each do |name, value|
            case value
               when Array
                  if block_given? then
                     copied_slots[name] = value.collect{|v| v.duplicate{|c| yield(c)} }
                  else
                     copied_slots[name] = value.collect{|v| v.duplicate()}
                  end
               when Node
                  if block_given? then
                     copied_slots[name] = yield(value.duplicate(){|c| yield(c)})
                  else
                     copied_slots[name] = value.duplicate()
                  end
               else
                  copied_slots[name] = value
            end
         end
         
         copy = self.class.new( @type, copied_slots )
         if block_given? then
            return yield(copy)
         else
            return copy
         end
      end
      
      
      def slot_defined?( slot )
         return @slots.member?(slot)
      end
      
      def slot_filled?( slot )
         return false unless @slots.member?(slot)
         return !@slots[slot].empty? if @slots[slot].is_an?(Array)
         return !@slots[slot].nil?
      end
      
      def define_slot( slot, value )
         @slots[slot] = value
      end
      
      def undefine_slot( slot )
         @slots.delete( slot )
      end

   
      def method_missing( id, *args )
         name, set = id.to_s.split("=")
         slot      = name
         
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
      
      
      def display( stream = $stdout )
         stream.puts @type
         stream.indent do
            @slots.each do |slot_name, value|
               stream << slot_name << ":\n"
               stream.indent do
                  self.class.display_node( value, stream )
               end
            end
         end
      end
      
      def self.display_node( node, stream = $stdout )
         case node
         when NilClass
            stream << "<nil>\n"
         when Array
            index = 0
            node.each do |child_node|
               stream << "[#{index}]:\n"
               stream.indent do 
                  display_node( child_node, stream )
               end
               index += 1
            end
         when ASN
            node.display( stream )
         when Token
            node.display( stream )
         when String
            stream.puts( node )
         else
            stream.puts( node.class.name )
         end
      end

   end
   
   
   


 #---------------------------------------------------------------------------------------------------------------------
 # Token Production
 #---------------------------------------------------------------------------------------------------------------------
 
   # 
   # ::type_name()
   #  - produces a Name
   
   def self.type_name( name, grammar = "RCC" )
      return name if name.is_a?(Name)
      return Name.new( name, grammar )
   end
   
   #
   # ::rcc()
   #  - produe
 

   #
   # ::t()
   #  - produces a Token from a String (or Token)
   
   def self.t( text, type = nil )
      return text if text.is_a?(Node)
      return Token.new( text, type, 0, 0, 0, nil )
   end

   #
   # ::w()
   #  - produces a :word Token
   
   def self.w( word )
      return t( word, type_name("word") )
   end

   #
   # ::ust()
   #  - produces a Token that represents a unicode escape sequence, per the grammar
   
   def self.ust( number )
      return number if number.is_a?(Node)
      return t( "\\u#{number}", type_name("unicode_sequence") )
   end
 
   #
   # ::est()
   #  - produces a Token that represents a general escape sequencer, per the grammar
   
   def self.est( code )
      return code if code.is_a?(Node)
      return t( "\\#{code}", type_name("escape_sequence") )
   end

   #
   # ::gct()
   #  - produces a Token that represents a general character, per the grammar
   
   def self.gct( letter )
      return letter if letter.is_a?(Node)
      return t( letter, type_name("general_character") )
   end

   #
   # ::gtt()
   #  - produces a Token that represents general text, per the grammar
   
   def self.gtt( text )
      return text if text.is_a?(Node)
      return t( text, type_name("general_text") )
   end      
         
   #
   # ::vt()
   #  - produces a Token that represents a variable, per the grammar
   
   def self.vt( variable )
      return variable if variable.is_a?(Node)
      return t( variable, type_name("variable") )
   end
   
   #
   # ::ptt()
   #  - produces a Token that represents property text, per the grammar
   
   def self.ptt( text )
      return text if text.is_a?(Node)
      return t( text, type_name("property_text") )
   end




 #---------------------------------------------------------------------------------------------------------------------
 # Node Production
 #---------------------------------------------------------------------------------------------------------------------
 
   #
   # node_has_type?( node, type )
   #  - returns true if the node can be viewed as having the specified type
   
   def self.node_has_type?( node, type )
      return false unless node.is_a?(Node)
      return true if node.type == type
      
      case type
         when "option"
            return true if node.type == "start_rule"
            return true if node.type == "discard_switch"
            return true if node.type == "no_discard"
         when "specification"
            return true if node.type == "macros_spec"
            return true if node.type == "section_spec"
            return true if node.type == "characters_spec"
            return true if node.type == "words_spec"
            return true if node.type == "reorder_spec"
            return true if node.type == "group_spec"
            return true if node.type == "rule_spec"
         when "character_set"
            return true if node.type == "cs_characters"
            return true if node.type == "cs_difference"
         when "cs_element"
            return true if node.type == "cs_range"
            return true if node.type == "cs_reference"
            return true if node_has_type?(node, "character")
         when "character"
            return true if node.type == "unicode_sequence"
            return true if node.type == "escape_sequence"
            return true if node.type == "general_character"
         when "string_pattern"
            return true if node.type == "sp_group"
            return true if node.type == "sp_branch"
            return true if node.type == "sp_sequence"
            return true if node.type == "sp_repeated"
            return true if node_has_type?(node, "character_set")
         when "expression"
            return true if node.type == "reference_exp"
            return true if node.type == "string_exp"
            return true if node.type == "sp_exp"
            return true if node.type == "group_exp"
            return true if node.type == "variable_exp"
            return true if node.type == "sequence_exp"
            return true if node.type == "branch_exp"   
            return true if node.type == "repeated_exp"
            return true if node.type == "gateway_exp"   
            return true if node.type == "local_commit"
            return true if node.type == "transclusion"
            return true if node.type == "macro_call"   
         when "parameters"
            return true if node.type == "parameter_tree"
            return true if node_has_type?(node, "expression")
         when "directive"
            return true if node.type == "associativity_directive"
         when "transformation_spec"
            return true if node.type == "assignment_transform"
            return true if node.type == "append_transform"
         when "npath"
            return true if node.type == "npath_self_exp"
            return true if node.type == "npath_slot_exp"
            return true if node.type == "npath_group_exp"
            return true if node.type == "npath_tclose_exp"
            return true if node.type == "npath_branch_exp"
            return true if node.type == "npath_predicate_exp"
            return true if node.type == "npath_path_exp"
         when "npred"
            return true if node.type == "npred_type_exp"
            return true if node.type == "npred_slot_exp"
            return true if node.type == "npred_or_exp"
            return true if node.type == "npred_and_exp"
            return true if node.type == "npred_negation_exp"
         when "macro_spec"
            return true if node.type == "simple_macro"
            return true if node.type == "parameterized_macro"
         when "parameter_definitions"
            return true if node.type == "parameter_definition_tree"
            return true if node.type == "word"
      end
      
      return false
   end
 
 
   #
   # ::node()
   #  - returns a new FakeASN from parts
   
   def self.node( type, slots = {} )
      return ASN.new( type_name(type), slots )
   end
   
   
   #
   # ::system_spec()
   
   def self.system_spec( *clauses )
      return node( "system_spec", "grammar_specs" => clauses )
   end
   
   
   #
   # ::grammar_spec()

   def self.grammar_spec( name, *clauses )
      priority        = nil
      options         = []
      specifications  = []
      transformations = nil
      
      clauses.each do |clause|
         if node_has_type?(clause, "option") then
            options << clause
         elsif clause.type.name == "priority" then
            priority = clause
         elsif clause.type.name == "transformations" then
            transformations = clause
         else
            specifications << clause
         end
      end
      
      return node( "grammar_spec", "name" => w(name), "priority" => priority, "options" => options, "specifications" => specifications, "transformations" => transformations )
   end
   

   #
   # ::priority()
   
   def self.priority( direction )
      return node( "priority", "direction" => t(direction) )
   end
   
   #
   # ::start_rule()
   
   def self.start_rule( name )
      return node( "start_rule", "rule_name" => w(name) )
   end
   
   #
   # ::discard_switch()
   
   def self.discard_switch( name )
      return node( "discard_switch", "name" => w(name) )
   end

   #
   # ::no_discard()
   
   def self.no_discard()
      return node( "no_discard" )
   end
   
   
   #
   # ::macros_spec()
   
   def self.macros_spec( *specs )
      return node( "macros_spec", "macro_specs" => specs )
   end
         
   #
   # ::section_spec()
   
   def self.section_spec( name, *clauses )
      options        = []
      specifications = []
      
      clauses.each do |clause|
         if node_has_type?(clause, "option") then
            options << clause
         else
            specifications << clause
         end
      end
      
      return node( "section_spec", "name" => w(name), "options" => options, "specifications" => specifications )
   end
   
   #
   # ::reorder_spec()
   
   def self.reorder_spec( *levels )
      return node( "reorder_spec", "reorder_levels" => levels )
   end
   
   #
   # ::group_spec()
   
   def self.group_spec( name, *specs )
      return node( "group_spec", "name" => w(name), "specifications" => specs )
   end
   
   #
   # ::rule_spec()
   
   def self.rule_spec( name, *clauses )
      expressions     = []
      directives      = []
      transformations = []
      
      clauses.each do |clause|
         if node_has_type?(clause, "directive") then
            directives << clause
         elsif node_has_type?(clause, "transformation_spec") then
            transformations << clause
         else
            expressions << clause
         end
      end
      
      return node( "rule_spec", "name" => w(name), "expression" => expression(*expressions), "directives" => directives, "transformation_specs" => transformations )
   end
   
   
   #
   # ::spec_reference()
   
   def self.spec_reference( name )
      return node( "spec_reference", "name" => w(name) )
   end
   
   #
   # ::reorder_level()
   
   def self.reorder_level( *references )
      return node( "reorder_level", "references" => references.collect{|r| w(r)} )
   end
   
   
   
   
   #
   # ::cs_characters()
   
   def self.cs_characters( *cs_elements )
      return node( "cs_characters", "cs_elements" => cs_elements.collect{|c| character(c)} )
   end
   
   
   #
   # ::cs_difference()
   
   def self.cs_difference( lhs, rhs )
      return node( "cs_difference", "lhs" => lhs, "rhs" => rhs )
   end


   #
   # ::cs_range()
   
   def self.cs_range( from, to )
      return node( "cs_range", "from" => character(from), "to" => character(to) )
   end
   
   
   #
   # ::cs_reference()
   
   def self.cs_reference( name )
      return node( "cs_reference", "name" => w(name) )
   end
   
   
   #
   # ::character()
   #  - "character" is treated as a group, not a rule . . . 

   def self.character( token )
      return gct(token) unless token.is_a?(Node)
      return token
   end
   
   
   
   
   
   #
   # ::string_pattern()
   #  - :string_pattern is a group, not a rule
   
   def self.string_pattern( term )
      return term if (term.is_an?(ASN) and node_has_type?(term, "string_pattern"))
      return cs_characters(term)
   end
   
   
   #
   # ::sp_group()
   
   def self.sp_group( string_pattern )
      return node( "sp_group", "string_pattern" => string_pattern(string_pattern) )
   end
   
   
   #
   # ::sp_sequence()
   
   def self.sp_sequence( tree, leaf, *more )
      if more.empty? then
         return node( "sp_sequence", "tree" => string_pattern(tree), "leaf" => string_pattern(leaf) )
      else
         return sp_sequence( sp_sequence(tree, leaf), *more )
      end
   end
   
   
   #
   # ::sp_branch()
   
   def self.sp_branch( tree, leaf )
      return node( "sp_branch", "tree" => string_pattern(tree), "leaf" => string_pattern(leaf) )
   end
   
   
   #
   # ::sp_repeated()
   
   def self.sp_repeated( count, string_pattern )
      return node( "sp_repeated", "repeat_count" => t(count), "string_pattern" => string_pattern(string_pattern) )
   end
   
   
   #
   # ::string()
   
   def self.string( *elements )
      return node( "string", "elements" => elements.collect{|e| gtt(e)} )
   end
   



   
   #
   # ::expression()

   def self.expression( *elements )
      elements.unshift sequence_exp( elements.shift, elements.shift ) until elements.length < 2
      return string_exp(elements[0])
   end

   
   #
   # ::reference_exp()
   
   def self.reference_exp( name, label = nil )
      return node( "reference_exp", "name" => w(name), "label" => label.nil? ? nil : w(label) )
   end
      
      
   #
   # ::string_exp()
   
   def self.string_exp( string, label = nil )
      return string if node_has_type?(string, "expression")
      return node( "string_exp", "string" => string(string), "label" => label.nil? ? nil : w(label) )
   end
   
   #
   # ::sp_exp()
   
   def self.sp_exp( string_pattern, label = nil )
      return node( "sp_exp", "string_pattern" => string_pattern, "label" => label.nil? ? nil : w(label) )
   end
   
   
   #
   # ::group_exp()
   
   def self.group_exp( expression, label = nil )
      return node( "group_exp", "expression" => expression, "label" => label.nil? ? nil : w(label) )
   end
   
   
   #
   # ::variable_exp()
   
   def self.variable_exp( name, label = nil )
      return node( "variable_exp", "name" => w(name), "label" => label.nil? ? nil : w(label) )
   end
   
   
   #
   # ::sequence_exp()
   
   def self.sequence_exp( tree, leaf )
      return node( "sequence_exp", "tree" => string_exp(tree), "leaf" => string_exp(leaf) )
   end
   
   
   #
   # ::branch_exp()
   
   def self.branch_exp( tree, leaf, *more )
      if more.empty? then
         return node( "branch_exp", "tree" => expression(tree), "leaf" => expression(leaf) )
      else
         return branch_exp( branch_exp(tree, leaf), *more )
      end
   end
   
   
   #
   # ::repeated_exp()

   def self.repeated_exp( count, expression )
      return node( "repeated_exp", "repeat_count" => t(count), "expression" => expression )
   end
   
   
   #
   # ::repeated_reference()
   
   def self.repeated_reference( count, name, label = nil )
      return repeated_exp( count, reference_exp(name, label) )
   end
   
   
   #
   # ::gateway_exp()
   
   def self.gateway_exp( word )
      return node( "gateway_exp", "word" => w(word) )
   end
   
   
   #
   # ::local_commit()
   
   def self.local_commit()
      return node( "local_commit" )
   end
   
   
   #
   # ::transclusion()
   
   def self.transclusion()
      return node( "transclusion" )
   end
   
   
   #
   # ::macro_call()
   
   def self.macro_call( name, parameters, *data )
      return node( "macro_call", 
         "macro_name" => w(name), 
         "parameters" => parameters.collect{|p| expression(p)},
         "body"       => expression( *data )
      )
   end


   #
   # ::block_macro_call()
   #  - a premade builder for a call to the "block()" macro from the grammar
   
   def self.block_macro_call( header, *body )
      return macro_call( "block", [header], *body )
   end
   
   
   #
   # ::statement_macro_call()
   #  - a premade builder for a call to the "statement()" macro from the grammar
   
   def self.statement_macro_call( *body )
      return macro_call( "statement", [], *body )
   end


   




   
   #
   # ::associativity_directive()
   
   def self.associativity_directive( direction )
      return node( "associativity_directive", "direction" => w(direction) )
   end
   
   def self.assoc( direction )
      return associativity_directive( direction )
   end
   
   
   
   
   #
   # ::transformations()

   def self.transformations( *sets )
      return node( "transformations", "transformation_sets" => sets )
   end
   
   
   #
   # ::transformation_set()
   
   def self.transformation_set( rule_name, *specs )
      return node( "transformation_set", "rule_name" => w(rule_name), "transformation_specs" => specs )
   end
   
   
   #
   # ::assignment_transform()
   
   def self.assignment_transform( destination, source )
      return node( "assignment_transform", "destination" => destination, "source" => source )
   end
   
   
   #
   # ::append_transform()
   
   def self.append_transform( destination, source )
      return node( "append_transform", "destination" => destination, "source" => source )
   end
   
   
   #
   # ::unset_transform()
   
   def self.unset_transform( destination )
      return node( "unset_transform", "destination" => destination )
   end
   
   
   #
   # ::npred_type_exp()
   
   def self.npred_type_exp( type_name )
      return type_name if type_name.is_an?(ASN)
      return node( "npred_type_exp", "type_name" => w(type_name) )
   end
   
   
   #
   # ::npred_slot_exp()
   
   def self.npred_slot_exp( slot_name )
      return node( "npred_slot_exp", "slot_name" => w(slot_name) )
   end
   
   
   #
   # ::npred_or_exp()
   
   def self.npred_or_exp( tree, leaf, *more )
      if more.empty? then
         return node( "npred_or_exp", "tree" => tree, "leaf" => leaf )
      else
         return npred_or_exp( npred_or_exp(tree, leaf), *more )
      end
   end
   
   
   #
   # ::npred_and_exp()
   
   def self.npred_and_exp( tree, leaf, *more )
      if more.empty? then
         return node( "npred_and_exp", "tree" => tree, "leaf" => leaf )
      else
         return npred_and_exp( npred_and_exp(tree, leaf), *more )
      end
   end
   
   
   #
   # ::npred_negation_exp()
   
   def self.npred_negation_exp( npred )
      return node( "npred_negation_exp", "npred" => npred )
   end
   
   
   
   #
   # ::npath_self_exp()
   
   def self.npath_self_exp()
      return node( "npath_self_exp" )
   end
   
   
   #
   # ::npath_slot_exp()
   
   def self.npath_slot_exp( slot_name )
      return node( "npath_slot_exp", "slot_name" => w(slot_name) )
   end
   
   
   #
   # ::npath_path_exp()
   
   def self.npath_path_exp( tree, leaf, *more )
      if more.empty? then
         return node( "npath_path_exp", "tree" => tree, "leaf" => leaf )
      else
         return npath_path_exp( npath_path_exp(tree, leaf), *more )
      end
   end
   
   
   #
   # ::npath_branch_exp
   
   def self.npath_branch_exp( tree, leaf, *more )
      if more.empty? then
         return node( "npath_branch_exp", "tree" => tree, "leaf" => leaf )
      else
         return npath_branch_exp( npath_branch_exp(tree, leaf), *more )
      end
   end
      
   
   #
   # ::npath_group_exp()
   
   def self.npath_group_exp( npath )
      return npath
   end


   #
   # ::npath_tclose_exp()
   
   def self.npath_tclose_exp( npath )
      return node( "npath_tclose_exp", "npath" => npath )
   end
   
   
   #
   # ::npath_predicate_exp()
   
   def self.npath_predicate_exp( npath, predicate )
      return node( "npath_predicate_exp", "npath" => npath, "npred" => predicate )
   end
   


   
   #
   # ::simple_macro()
   
   def self.simple_macro( name, *terms )
      return node( "macro_spec", "name" => w(name), "parameter_definitions" => [], "expression" => expression(*terms) )
   end
   
         
   #
   # ::parameterized_macro()
   
   def self.parameterized_macro( name, parameters, *terms )
      return node( "macro_spec", "name" => w(name), "parameter_definitions" => parameters.collect{|p| w(p)}, "expression" => expression(*terms) )
   end







end  # module Grammar
end  # module Languages
end  # module RCC
