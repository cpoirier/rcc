This is my "ruby compiler compiler" project. Unfortunately, it doesn't currently work, and development stopped several years ago. Ultimately, I got too smart for myself -- I ended up designing something I wasn't smart enough to build.

In the current repository, the +release_1+ is where the action was last happening (judging from the commit log).



# Feature list of Release 0, from the old website

RCC is a LALR(1) compiler compiler, written in Ruby, and supporting (theoretically) any output language. 

Declarative grammar:

* grammar is purely declarative and is therefore output-language-independent
* parser is generated as a class, and action code is added by subclassing and defining "event handler" methods

Generated components include:

* lexer
* parser
* AST classes
* AST construction code
* error recovery system
* grammar help system

Additional features:

* optional backtracking support, for dynamic resolution of ambiguous grammars
* error recovery system in generated parser that engages when a syntax error is detected:
  * allows parsing to continue beyond the first error
  * provides user with higher-quality error messages, that are more likely to identify the *cause* of an error, and not just its *effect*
  * error report includes suggested repairs for the error

Debugging tools:

* a grammar interpreter that explains how your grammar actually works on a particular source file, including clear descriptions of *why* it is making the choices it is making




# From Release 1, the grammar of the RCC grammar description language (discussion follows)

  
    grammar RCC 
       priority ascending
    
       start_rule system_spec
       discard    whitespace
       discard    comment
    
       section misc
          whitespace        := [ \t\r]+
          eol               := [\n]
          any_character     := [\u0000-\uffff]
          line_character    := [{any_character}]-[\n]
          general_character := [{line_character}]-['\\\{\}\[\]]
          digit             := [0-9]
          hex_digit         := [{digit}a-fA-F]
          
          unicode_sequence  := [\\] [u] [{hex_digit}] [{hex_digit}] [{hex_digit}] [{hex_digit}]
          escape_sequence   := [\\] [a-z\\\-\[\]\']
          
          word              := [a-zA-Z] [a-zA-Z0-9_]*
          property_text     := [{general_character}]-[}]+
          general_text      := [{general_character}]+
          
          comment           := [#] [{line_character}]*
       end
    
    
       macros
          statement         := %% eol:ignore+ ;
          block( header )   := statement() [ statement() [$header] %% 'end' ]
       end
    
    
       section grammar
          system_spec  := grammar_spec+ addendum?
          grammar_spec := block('grammar' word:name) [ priority option* specification* transformations? ]
          addendum     := statement() [ 'stop' ] 
    
    
          priority := statement() [ 'priority' ('ascending'|'descending'):direction ]
    
          group option
             start_rule          := statement() [ 'start_rule' word:rule_name        ]
             discard_switch      := statement() [ 'discard'    word:name             ]
             pluralization_guide := statement() [ 'pluralize'  word:name word:plural ]
          end
    
    
          
          group specification
             macros_spec     := block('macros')              [ macro_spec*           ]
             reorder_spec    := block('reorder')             [ reorder_level*        ]
             section_spec    := block('section' word:name)   [ no_discard? discard_switch:option* specification* ]
             group_spec      := block('group' word:name)     [ (rule_spec|group_spec|spec_reference):specification* ]
             rule_spec       := statement() [ word:name ':=' expression directive* ] transformation_spec*
          end
    
          
          no_discard     := statement() [ 'no' 'discard' ]
          spec_reference := statement() [ word:name ]
          reorder_level  := statement() [ word:reference+ ]
    
          
       end
       
       
       section rule_spec
          macros
             labelled()          := %% (':' word:label)?
             attribute_set(name) := '@' $name '=' %%
          end
    
          
          group expression
             local_commit := ';'
             transclusion := '%%'
             gateway_exp  := '!' !whitespace word
    
             group general_exp
                group repeatable_exp
                   reference_exp := labelled() [ word:name            ]
                   string_exp    := labelled() [ string               ]
                   sp_exp        := labelled() [ string_pattern       ]
                   variable_exp  := labelled() [ '$' word:name        ]
                   group_exp     := labelled() [ '(' general_exp:expression ')'   ]
    
                   macro_call    := word:macro_name !whitespace '(' parameters? ')' ('[' expression:body? ']')?
                   sequence_exp  := expression:tree expression:leaf              {left associative}
                   branch_exp    := general_exp:tree '|' general_exp:leaf        {left associative}
                end
    
                repeated_exp := repeatable_exp:expression ('*'|'+'|'?'):repeat_count
             end
          end
    
    
          group parameters
             expression
             parameter_tree  := parameters:tree ',' parameters:leaf      {left associative}
          end
    
          group directive
             associativity_directive := '{' 'associativity'? ('left'|'right'|'non'):direction ('assoc'|'associative')? '}'
          end
    
    
          group string_pattern
             character_set
             sp_group      := '(' string_pattern ')'
             sp_sequence   := string_pattern:tree string_pattern:leaf               {left associative}
             sp_branch     := string_pattern:tree '|' string_patttern:leaf          {left associative}
             sp_repeated   := string_pattern ('*'|'+'|'?'):repeat_count
          end
    
          group character_set
             cs_characters
             cs_difference := character_set:lhs '-' character_set:rhs   @associativity=none
          end
    
    
    
       section strings
          no discard
    
          string := '\'' (unicode_sequence|escape_sequence|general_text):element+ '\''
          cs_characters := '[' cs_element+ ']'
    
          group cs_element
             character                              
             cs_reference  := '{' word:name '}'              
             cs_range      := character:from '-' character:to           @associativity=none
          end
    
          group character
             general_character
             unicode_sequence
             escape_sequence
          end
       end
       
       
       section transformations
          transformations         := block('transformations') [ transformation_set* ]
          transformation_set      := word:rule_name eol:ignore* transformation_spec+
    
          group transformation_spec
             assignment_transform := statement() ['**' npath:destination '='  npath:source ]
             append_transform     := statement() ['**' npath:destination '+=' npath:source ]
          end
    
          group npath
             npath_self_exp       := '.'
             npath_slot_exp       := '@' word:slot_name
             npath_tclose_exp     := '{' npath '}'
             npath_branch_exp     := npath:tree '|' npath:leaf   {left associative}
             npath_reverse_exp    := '-' npath 
             npath_predicate_exp  := npath '[' npred ']'         {left associative}
             npath_path_exp       := npath:tree '/' npath:leaf   {left associative}
             npath_group_exp      := '(' npath ')'
          end
    
          group npred
             npred_type_exp       := word:type_name
             npath
             npred_or_exp         := npred:tree '|' npred:leaf   {left associative}
             npred_and_exp        := npred:tree '&' npred:leaf   {left associative}
             npred_negation_exp   := '!' npred
          end
    
          reorder
             npred_type_exp
             npath_slot_exp
          end
       end
       
    
       section macros_spec
          macro_spec := statement() [ word:name (!whitespace '(' parameter_defs? ')')? ':=' expression ]
          
          group parameter_defs
             parameter_def_tree := parameter_defs:tree ',' parameter_defs:leaf   {left associative}
             word
          end
       end
    
    
       transformations
          macro_call      ** @parameters = @parameters/{@tree|@leaf}[expression]
          npred_or_exp    ** @elements = @tree[npred_or_exp]/@elements  | @tree[!npred_or_exp]  | @leaf
          npred_and_exp   ** @elements = @tree[npred_and_exp]/@elements | @tree[!npred_and_exp] | @leaf
          npath_group_exp ** . = @npath
          macro_spec      ** @parameter_defs = @parameter_defs/{@tree|@leaf}[word]
       end
    
    end
  




# From the old website, a discussion of (I think) Release 1 grammars


When building an RCC grammar, you will be focussing on two primary things: 

* describing lexical elements (keywords, operators, names, etc.)
* describing grammatical structures (rules about how lexical elements combine to create meaning)

In addition to these basic elements, RCC also needs you to describe the Abstract Syntax Tree that will be built when a source file is processed by your grammar.  Most of this is done by implication -- there will be one class for each rule, with fields named for each of the non-constant terms.  However, you can override the default naming behaviour -- and even some of the structural composition -- by providing field labels to terms in your rules; and, for special needs, you can include an XPath-style description of how to restructure the AST after it has been constructed, for times when a simple tree isn't what you'd like to work with after processing is complete.

For the sake of this discussion, I'm going break down the RCC grammar itself.  It makes use of most of the language, so it will be a good example to work from.


## Basic Organization

There's a fair amount of flexibility in how you organize your grammar, but, in general, there will be three major chunks:

* options
* string definitions
* grammar rules


### Options

Options allow you to enable backtracking support in the grammar, specify which lexical symbols should be ignored by the parser (whitespace, for instance), and specify which of the grammar rules to start from.


## String Definitions

In general, RCC tries to let you work in a way that's natural for you.  For things like keywords and operators, you can specify them right in the grammar rules, where they make sense.  In fact, if you do this, such constant strings won't even be written into your AST, which is usually what you want (you can override this behaviour by specifying a label).

However, for strings that are recognized by pattern -- numbers, identifiers, strings, etc. -- you'll need to define them before using them.  You will then reference the pattern by name:

    strings
       any_character     => [\u0000-\uFFFF]
       digit             => [0-9]
       hex_digit         => [{digit}a-fA-F]
    
       unicode_sequence  => '\\' 'u' hex_digit hex_digit hex_digit hex_digit
       escape_sequence   => '\\' [a-z\\\-\[\]\']
       general_character => [{any_character}]-['\n\r\\]
       general_text      => general_character+
       property_text     => [{general_character}]-[}]+
    
       word_first_char   => [a-zA-Z_]
       word_char         => [{word_first_char}{digit}]
       word              => word_first_char word_char*
    
       eol               => '\n'
       whitespace        => [ \t\r]+
       comment           => '#' [{any_character}]-[\n]*
    end

Within the strings section, you can specify patterns in terms of character ranges (`[0-9]`), escape sequences (`\n`), and strings (`'abc'`) -- or any sequence thereof.  Individual elements can be repeated with `?`, `*`, or `+` markers, which indicate 0 or 1 occurrences, 0 or more occurrences, or 1 or more occurrences, respectively.  Additionally, you can subtract one character range from another to take a subset of its characters (`[abc]-[b]`); within a character range, you can refer to other character ranges by name (`[{any_character}]`).

RCC will use these definitions -- and any constant strings you specify in the rules -- to create your lexer.  Strings defined earlier in the grammar generally take precedence over ones defined later, if there is an conflict.  *However*, RCC will automatically prioritize strings appropriately for the parsing context, so you don't have to worry about defining very general strings (like `general_text`, above).  They will only get used when they are relevant.

Reread that last paragraph.  It's important.



## Rule Definitions

Rules are where you the structure of your grammar.  RCC allows you a good degree of freedom in how to specify them.  You can specify alternate paths through a rule (`x a|b|c y`), make elements optional or repeated (with `?`, `*`, or `+`), and group sets of elements into complex structures (`x (a b)|(c d) y`).  

Of course, with great freedom comes great responsibility, and these features are best used in moderation.  In most cases, if you have two different forms to parse, you should use two separate rules to do so.  But the power is there, when you need it.


### A Simple Rule

    system_spec => grammar_spec+

Here's a very simple rule that defines every `system_spec` parse as made up of one or more `grammar_spec` parses.  

Let's take a moment to discuss the AST produced by this rule.  I'll use Ruby examples, but RCC is perfectly capable of producing similar structures in other languages, and will even attempt to follow the naming conventions of those other languages.

In this case, on return from the parse of this rule, you will receive an object of class `SystemSpec`.  This object will have one property: `grammar_specs`, which will contain a list of `GrammarSpec` objects.  

Unless labelled, AST property names are taken directly from the corresponding terms within a rule.  Had the rule been `system_spec => grammar_spec`, for instance, the property would have been `grammar_spec` and would have held exactly one `GrammarSpec` object.  In the case of repeated elements, however, RCC pluralizes the term and stores in it a list of the parsed objects.  

Internally, plural elements are processed using a rule of the form `grammar_specs => grammar_specs? grammar_spec`, producing a lopsided binary tree of grammar_spec objects.  RCC then uses the AST rewriting system to unpack this tree and convert it to a list instead.  When you use `*` or `+` markers on your rule terms, you get all of this work for free.



### Macros

Before getting to the next example, I'd better tell you about macros.

When defining a grammar, you will often come across structures that get regular use.  For instance, when defining rules that make up the "statements" of your language, you may find that many of them end with the same statement terminator.  Other "statements" might have a block structure that involves something more complex, but still regular.  

In some cases, you will deal with this by building a rule that captures that structure and symbolically references all of the instances that use it.  This may even be the best way to do it, in some grammars.  However, in other grammars, it will unnecessarily complicate things.  Continuing the "statement" example, a high-level rule that captures the statement terminator would prevent you from having statements that can occur only in specific situations, as all terminated statements would have to be referenced by the one name.  And, at the other end of things, the produced AST would have an additional layer that may have no useful meaning. 

To solve this problem, RCC allows you to define macros that can be called to wrap structure around the unique elements of your rule.

    macros
       statement         => %% eol+ ;
       block( header )   => statement() [ statement() [$header] %% 'end' ]
    end

The first macro is used to append the terms `eol+` `;` to whatever is passed as the macro's body.  The second macro is used to construct a block statement from a header and the macro's body.  Both of the statements in each of the following sets has the same meaning:

    simple_statement  => statement() [ x y z ]
    complex_statement => x y z eol+ ;

    simple_block      => block( 'grammar' word:name ) [ option* specification* ]
    complex_block     => 'grammar' word:name eol+ ; option* specification* 'end' eol+ ;

Macros can help keep your code from getting cluttered with terms that are lexically important, but that have no additional meaning.  RCC will take care of "flattening" things out for processing.


### Groups

    grammar_spec => block('grammar' word:name) [ option* specification* ]

    group option
       start_rule          => statement() [ 'start_rule' word:rule_name        ]
       ignore_switch       => statement() [ 'ignore'     word:name             ]
       backtracking_switch => statement() [ 'enable'     'backtracking'        ]
       pluralization_guide => statement() [ 'pluralize'  word:name word:plural ]
    end

    group specification
       macros_spec     => block('macros')              [ macro_spec*           ]
       strings_spec    => block('strings')             [ string_spec*          ]
       precedence_spec => block('precedence')          [ precedence_level*     ]
       section_spec    => block('section' word:name)   [ specification*        ]
       group_spec      => block('group' word:name)     [ (rule_spec|group_spec|spec_reference):specification* ]
       rule_spec       => statement() [ word:name '=>' expression directive* ] transformation_spec*
    end

    spec_reference   => statement() [ word:name ]
    precedence_level => statement() [ word:reference+ ]

Often times, you will find yourself wanting to refer to a group of rules by the same name.  In the example above, the `grammar_spec` is made up of 0 or more `option`s followed by 0 or more `specification`s.  However, there are a number of different options available in RCC, and a number of different types of specifications.  This is where the group comes in.  It allows you to apply a single name to one or more rules, so you can reference them *en masse*.

For the sake of convenience, you can define rules directly in groups, as has been done in this example.  However, there is no requirement that you do so.  You can define all your rules outside of any group, and then just list the rule names within the appropriate groups, later on, to indicate membership.  And a rule can be in any number of groups.  You can even nest groups and/or use group names inside of other groups.  Finally, groups can also contain string names -- not just rule names.

When it comes to your AST, properties names are drawn (as always) from the term in the rule.  As such, if you use a group name in a rule, the property will be named for the group, not for its individual elements.  If this is not what you want, you can get around it by specifying the group members inline using a branch structure (`(a|b|c)` instead of `group_abc`).


### Term Labels

Something else you'll notice in the above example is that some terms have been labelled.  For instance:

    start_rule => statement() [ 'start_rule' word:rule_name ]

In this example, the label `rule_name` has been applied to the `word` term, which means the `word` parsed by that term will be stored in an AST property called `rule_name` instead.

By default, constant strings within a rule are not copied into the AST -- under the assumption that if they are constant, you don't need them.  However, if you to want them copied, you can simply give the string a label, and it will be stored.  Also by default, if two terms reference the same rule, RCC will ensure unique property names by appending a number to the default name (`expression_1`, `expression_2`).  You can override this behaviour with a label.


### Error Recovery Hints

RCC organizes its error recovery system around rules.  When an error is encountered in a source file, the generated parser will focus its efforts on finding a rule boundary at which to modify things to repair the error, and will not consider the error repaired until a rule completes.  Unfortunately, this is not always the best choice.  If a rule may cover a lot of the source text (a higher-level rule like a function or a class definition), then the recovery may be complete long before the error recovery system notices, and that can lead to a lot of churn.  You can tell the error recovery system to treat an error as recovered *before* reaching the end of a rule by using the recovery commit marker (`;`) within your rule.  Used carefully, recovery commit markers should produce better error recovery behaviour.




### Context-sensitive lexing

*RCC-generated lexers are context-sensitive.*

Specifically, RCC generates a whole set of lexers for you, one for each parser state.

Why should you care?  Well, because it means that RCC can handle declaratively what you might have had to do with custom code in the past; things like: 

* escape sequences inside strings
* expressions nested inside strings
* regular expressions literals
* etc.

In other words, RCC makes it easy to embed sub-languages in your grammar.  As long as you don't expect the same string of characters to be lexed in two ways in the same position within your grammar, RCC will ensure that it is lexed in the way that is appropriate for the context.  (And you can get past that other restriction by enabling backtracking within the generated parser.)

Consider this Ruby-like expression: 

    puts "Confirmed guests: {confirmed_guests.join(", ")}."

An RCC grammar like this could process it:

    group expression
       addition_expression    => expression '+' expression  @associativity=left
       subtraction_expression => expression '-' expression  @associativity=left
   
       # . . . additional expression rules left as an exercise for the reader . . . 
   
       string_expression
    end

    section strings
       strings      
          escape_sequence => '\\' [rtn\\"{]
          general_text    => [\u0000-\uffff]-["\\{]+
       end
   
       string_expression => '"' (escape_sequence|general_text|nested_expression):element* '"'
       nested_expression => '{' expression '}'
    end

It is safe to define a string like `general_text` (which would match just about any text in a source file), because it will only ever be used inside a string_expression (in this grammar, anyway).  And because the opening `{` of a nested expression is excluded from `general_text`, any such `{` inside a `string_expression` will trigger a shift into `nested_expression`.

Finally, because RCC generates an LR parser, you can still use `}` and even `string_expression`s inside `expression` without causing a problem, because the parser only considers reductions at the top of the stack.  In other words, a `}` will not cause a reduce of the `nested_expression` until the top of the stack matches `'{' expression '}'` in a state where `nested_expression` is expected.

