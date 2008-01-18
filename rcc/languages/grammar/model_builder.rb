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
require "#{$RCCLIB}/util/sparse_range.rb"
require "#{$RCCLIB}/util/expression_forms/expression_form.rb"
require "#{$RCCLIB}/model/symbol.rb"


module RCC
module Languages
module Grammar

 
 #============================================================================================================================
 # class ModelBuilder
 #  - builds an RCC::Model::Grammar from a CST parsed from a grammar source file

   class ModelBuilder
      
      #
      # ::build()
      #  - given a CST of a grammar source file, returns a Model::Grammar or an error report
      
      def self.build( cst )
         builder = new()
         return builder.build_model( cst )
      end
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
         @grammar = nil
         
         @specs           = Util::OrderedHash.new()    # name => ASN, by declared name
         @character_specs = Util::OrderedHash.new()    # name => :character_spec ASN
         @word_specs      = Util::OrderedHash.new()    # name => :word_spec      ASN
         @macro_specs     = Util::OrderedHash.new()    # name => :macro_spec     ASN
         @category_specs  = Util::OrderedHash.new()    # name => :category_spec  ASN
         @rule_specs      = Util::OrderedHash.new()    # name => :rule_spec      ASN
         
         
         @character_defs   = Util::OrderedHash.new()   # name => SparseRange result of processing a :character_spc
         @word_defs        = Util::OrderedHash.new()   # name => ExpressionForm result of processing a :word_spec
         @category_defs    = Util::OrderedHash.new()   # name => list of rule names in the category
         @rule_defs        = Util::OrderedHash.new()   # name => 
         
      end



      #
      # build_model()
      #  - given a AST of a grammar source file, returns a Model::Grammar or an error report
      
      def build_model( grammar_spec )
         stream = STDOUT.indent_stream
         assert( grammar_spec.type == :grammar_spec, "Um, perhaps you meant to pass a grammar_spec AST?" )
         
         #
         # Start by running a few validations, and flattening a few data structures.  Groups, for instance, are
         # syntactic sugar only -- they don't change the meaning of any of the rules -- so we can discard them here.
         # In fact, all of the sections have already served their purpose, by producing Nodes of the right type.
         # We can get rid of all of them.

         options     = []
         precedences = []
         work_queue = [grammar_spec]
         until work_queue.empty?
            container = work_queue.shift
            case container.type
               
               when :grammar_spec, :section_spec
                  work_queue.concat container.specifications
                  
               when :characters_spec
                  register_names( container.character_specs, @specs, @character_specs ) if container.slot_filled?(:character_specs)
               when :words_spec
                  register_names( container.word_specs     , @specs, @word_specs      ) if container.slot_filled?(:word_specs     )
               when :macros_spec
                  register_names( container.macro_specs    , @specs, @macro_specs     ) if container.slot_filled?(:macro_specs    )
                  STDERR.puts "macro_specs are not being validated, currently"
                  
               when :rule_spec
                  register_names( [container], @specs, @rule_specs )
                  container.categories.each do |category|
                     @category_defs[category.text] << container.name.text unless @category_defs[category.text].member?(container.name.text)
                  end
                     
               when :category_spec
                  register_names( [container], @specs, @category_specs )
                  @category_defs[container.name.text] = [ container.name.text ]

                  work_queue.concat container.specifications
                  
               when :precedence_spec
                  STDERR.puts "skipping :precedence_spec in build_model(): what should this do?"
                   
               when :spec_reference
                  container.categories.each do |category|
                     @category_defs[category.text] << container.name.text unless @category_defs[category.text].member?(container.name.text)
                  end
                  
               else
                  nyi( "work_queue support for type [#{container.type}]")
            end
         end
         
         
         #
         # Resolve character specs into SparseRanges of character codes.
         
         @character_specs.each do |name, spec|
            @character_defs[name] = process_character_data( spec.character_set, [name] ) unless @character_defs.member?(name)
         end
         
         if false then
            @character_defs.each do |name, definition|
               puts "character_def #{name}:"
               puts "   #{definition}"
               puts ""
            end
         end
         
         
         #
         # Resolve word specs into ExpressionForms.
         
         @word_specs.each do |name, spec|
            @word_defs[name] = process_word_data( spec.definition, [name] ) unless @word_defs.member?(name)
         end
         
         if false then
            @word_defs.each do |name, definition|
               stream.puts "word_def #{name}:"
               definition.display( stream.indent )
               stream.puts ""
            end
         end


         #
         # Resolve rule specs into ExpressionForms.
         
         @rule_specs.each do |name, spec|
            naming_context = []
            @rule_defs[name] = process_rule_expression( spec.expression, naming_context ) unless @rule_defs.member?(name)
            STDERR.puts "skipping transformation on rule #{name}" if spec.slot_filled?(:transformation_specs)
         end
         
         if true then
            @rule_defs.each do |name, definition|
               stream.puts "rule_def #{name}:"
               definition.display( stream.indent )
               stream.puts ""
            end
         end
         
         
         #
         # Now we can start building the Model.
         
         @grammar = Model::Grammar.new( grammar_spec.name )
         puts "DONE"
         exit

      end


      def register_names( definitions, *containers )
         definitions.each do |definition|
            name = definition.name.text
            containers.each do |container|
               if container.member?(name) then
                  nyi( "error reporting for duplicate name [#{name}]" )
                  break
               else
                  container[name] = definition
               end
            end
         end
      end
      
      

    #---------------------------------------------------------------------------------------------------------------------
    # Model Building
    #---------------------------------------------------------------------------------------------------------------------
          
    protected

      @@escape_sequences = { '\n' => "\n", '\r' => "\r", '\t' => "\t", "\\\\" => "\\" }
    
      #
      # process_character_data()
      #  - processes the body of a :character_definition (or parts thereof) into a SparseRange
      
      def process_character_data( node, loop_detection = [] )
         result = nil
         
         case node.type
            when :cs_difference
               result = process_character_data( node.lhs, loop_detection ) - process_character_data( node.rhs, loop_detection )
            
            when :cs_characters
               result = Util::SparseRange.new()
               node.cs_elements.each do |element|
                  result += process_character_data( element, loop_detection )
               end
               
            when :cs_range
               result = Util::SparseRange.new( process_character_data(node.from, loop_detection)..process_character_data(node.to, loop_detection) )
               
            when :cs_reference
               referenced_name = node.name.text
               if resolution = resolve_character_reference(referenced_name, loop_detection) then
                  result = resolution
               else
                  nyi( "error handling for missing character_definition referenced [#{referenced_name}]" )
               end

            when :general_character
               result = node.text[0]
               
            when :escape_sequence
               if @@escape_sequences.member?(node.text) then
                  result = @@escape_sequences[node.text][0]
               else
                  result = node.text[1]
               end
               
            when :unicode_sequence
               result = node.text.slice(2..-1).to_i(16)
              
            else
               die( node )
               bug( "unsupported node subtype [#{node.type}]" )
         end
         
         return result
      end
      
      
      #
      # process_word_data()
      #  - process the body of a :word_definition (or parts thereof) into an ExpressionForm
      
      def process_word_data( node, loop_detection = [] )
         result = nil
         
         case node.type
            when :sp_concat
               result = create_sequence( process_word_data(node.lhs), process_word_data(node.rhs) )
               
            when :sp_reference
               referenced_name = node.name.text
               if resolution = resolve_character_reference(referenced_name, loop_detection) then
                  result = create_sequence( resolution )
               elsif resolution = resolve_word_reference(referenced_name, loop_detection) then
                  result = resolution
               else
                  nyi( "error handling for missing character/word definition reference [#{referenced_name}]" )
               end

            when :sp_repeated
               minimum = 0
               maximum = nil
               
               case node.repeat_count.text
                  when "?"
                     minimum = 0
                     maximum = 1
                  when "*"
                     minimum = 0
                     maximum = nil
                  when "+"
                     minimum = 1
                     maximum = nil
                  else
                     bug( "unsupported repeat_count [#{node.repeat_count}]")
               end
                  
               result = create_repeater( process_word_data(node.string_pattern, loop_detection), minimum, maximum )
            
            when :cs_characters, :cs_difference
               result = create_sequence( process_character_data(node) )
         
            when :string
               result = create_sequence()
               node.string_elements.each do |string_element|
                  result << process_word_data( string_element )
               end
               
            when :general_text
               result = create_sequence()
               node.text.each do |character|
                  result << Util::SparseRange.new( character[0] )
               end
               
            when :escape_sequence
               if @@escape_sequences.member?(node.text) then
                  result = create_sequence( Util::SparseRange.new(@@escape_sequences[node.text][0]) )
               else
                  result = create_sequence( Util::SparseRange.new(node.text[1]) )
               end
               
            when :unicode_sequence
               result = create_sequence( Util::SparseRange.new(node.text.slice(2..-1).to_i(16)) )
               
            else
               bug( "unsupported node subtype [#{node.subtype}]" )
         end
         
         return result
      end
      
      
      #
      # process_rule_expression()
      #  - process the body of a :rule :expression (or parts thereof) into an ExpressionForm
      
      def process_rule_expression( node, naming_context, slot_name = nil )
         result = nil
         
         case node.type
            when :macro_call
               result = process_rule_expression( do_macro_call(node), naming_context, slot_name )

            when :sequence_exp
               result = create_sequence( 
                  process_rule_expression( node.tree, naming_context, slot_name ), 
                  process_rule_expression( node.leaf, naming_context, slot_name ) 
               )

            when :repeated_exp
               minimum = 0
               maximum = nil
               
               case node.repeat_count.text
                  when "?"
                     minimum = 0
                     maximum = 1
                  when "*"
                     minimum = 0
                     maximum = nil
                  when "+"
                     minimum = 1
                     maximum = nil
                  else
                     bug( "unsupported repeat_count [#{node.repeat_count}]")
               end
                  
               result = create_repeater( 
                  process_rule_expression(node.expression, naming_context, slot_name), minimum, maximum 
               )
               
            when :branch_exp
               result = create_branch_point(
                  process_rule_expression( node.tree, naming_context, slot_name ),
                  process_rule_expression( node.leaf, naming_context, slot_name )
               )
               
            when :gateway_exp
               STDERR.puts "skipping gateway_exp, because I've no clue what to do with it"
               result = create_sequence()
               
            when :recovery_commit
               STDERR.puts "skipping recovery_commit, because I've no clue what to do with it"
               result = create_sequence()
            
            when :string_exp
               word_name = anonymous_word( process_word_data(node.string) )
               symbol = Model::Symbol.new( word_name, true )
               
               do_slot_registration( symbol, slot_name, node.label, naming_context, false )
               result = create_sequence( symbol )
            
            when :reference_exp
               referenced_name = node.name.text
               if @macro_specs.member?(referenced_name) then
                  nyi("error handling for overlapping labels at reference level") if slot_name.exists? and node.label.exists?
                  result = process_rule_expression( do_macro_call(node), naming_context, slot_name.nil? ? node.label : slot_name )
                  
               else
                  symbol = nil
                  
                  #
                  # If a reference to an existing Word definition, use it.
               
                  if @word_defs.member?(referenced_name) then
                     symbol = Model::Symbol.new( referenced_name, true )
                  
                  #
                  # If a reference to an existing Character definition, create an anonymous Word def from it
                  # and use it.
               
                  elsif @character_defs.member?(referenced_name) then
                     word_name = anonymous_word( create_sequence(@character_defs[referenced_name]) )
                     symbol = Model::Symbol.new( referenced_name, true )
                  
                  #
                  # If a reference to another rule, then use it.
               
                  elsif @rule_defs.member?(referenced_name) || @rule_specs.member?(referenced_name) || @category_specs.member?(referenced_name) then
                     symbol = Model::Symbol.new( referenced_name, false )
                  
                  #
                  # Otherwise, we have a problem.
               
                  else
                     nyi( "error handling for missing referenced name [#{referenced_name}]" )
                  end


                  #
                  # Deal with any label.  We always mark a slot if a name is specified.  In addition, for a referenced
                  # name, unless it resolves to a constant string, we should mark a slot for later assignment.
               
                  unless symbol.nil?
                     do_slot_registration( symbol, slot_name, node.label, naming_context, true )
                     result = create_sequence( symbol )
                  end
               end
            
            when :group_exp
               nyi("error handling for overlapping labels at group level") if slot_name.exists? and node.label.exists?
               result = process_rule_expression( node.expression, naming_context, node.label.exists? ? node.label : slot_name )
               
            when :variable_exp
               nyi( "error handling for variable in regular rule" )
               
            when :transclusion
               nyi( "error handling for transclusion in regular rule" )
               
            else
               die( node, "unsupported node type [#{node.type}]" )
               bug( "unsupported node type [#{node.type}]" )
         end
   
         return result
      end
      
      
      #
      # do_macro_call()
      #  - processes a macro_call spec or a reference to a zero-parameter macro
      #  - returns a list of :expression elements for further processing 
      
      def do_macro_call( call_exp )
         parameters = []
         body       = nil
         macro_name = nil
         
         case call_exp.type
            when :reference_exp
               macro_name = call_exp.name.text        # NB: the label is being handled elsewhere!
            when :macro_call
               macro_name = call_exp.macro_name.text
               parameters = call_exp.parameters 
               body       = call_exp.body if call_exp.slot_filled?(:body)
            else
               bug( "why are you passing me a [#{call_exp.type}]?" )
         end
         
         nyi( "error handling for undefined macro call [#{macro_name}]" ) unless @macro_specs.member?(macro_name)
         macro_spec = @macro_specs[macro_name]
         
         #
         # Validate the parameter counts and then assign them to slots.
         
         if parameters.length != macro_spec.parameter_definitions.length then
            nyi( "error handling for macro call parameter count mismatch (found #{parameters.length}; expected #{macro_spec.parameter_definitions.length})" )
         end
         
         parameter_lookup = {}
         parameters.length.times do |i|
            parameter_lookup[macro_spec.parameter_definitions[i].text] = parameters[i]
         end
         
         #
         # Process the macro body by creating a copy with all variable and transclusion
         # nodes replaced appropriately.
         
         return macro_spec.expression.duplicate do |node|
            case node.type
               when :transclusion
                  nyi( "error handling for missing macro_call body" ) if body.nil?
                  body
               
               when :variable_exp
                  nyi( "error handling for non-existent macro parameter definition [#{node.name.text}] in [#{parameter_lookup.keys.join(", ")}]" ) unless parameter_lookup.member?(node.name.text)
                  if node.label.nil? then
                     parameter_lookup[node.name.text]
                  else
                     BootstrapGrammar.group_exp( parameter_lookup[node.name.text], node.label )
                  end

               else
                  node
            end
         end
      end
      
      
      # def expand_macro_body( node, parameter_lookup, transclusion_data )
      #    case node.type
      #       when :macro_call
      #          return BootstrapGrammar.macro_call( )
      #          expand_macro_body
      #          die( )
      #       when nil
      #       else
      #    end
      # end
      # 
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Reference support
    #---------------------------------------------------------------------------------------------------------------------

    protected

      #
      # resolve_character_reference()
      
      def resolve_character_reference( referenced_name, loop_detection = [] )
         resolution = nil
         
         if @character_specs.member?(referenced_name) or @character_defs.member?(referenced_name) then
            unless @character_defs.member?(referenced_name)
               if loop_detection.member?(referenced_name) then
                  nyi( "error handling for detected reference loop [#{referenced_name}]" )
               elsif @character_specs.member?(referenced_name) then
                  referenced_spec = @character_specs[referenced_name]
                  @character_defs[referenced_name] = process_character_data( referenced_spec.character_set, loop_detection + [referenced_name] )
               end
            end

            resolution = @character_defs[referenced_name]
         end

         return resolution
      end


      #
      # resolve_word_reference()
      
      def resolve_word_reference( name, loop_detection = [] )
         resolution = nil
         
         if @word_definitions.member?(referenced_name) or @word_definition_asts.member?(referenced_name) then
            unless @word_definitions.member?(referenced_name)
               if loop_detection.member?(referenced_name) then
                  nyi( "error handling for detected reference loop [#{referenced_name}]" )
               elsif @word_definition_asts.member?(referenced_name) then
                  referenced_ast = @word_definition_asts[referenced_name]
                  @word_definitions[referenced_name] = process_word_data( referenced_ast.definition, loop_detection + [referenced_name] )
               end
            end
            
            resolution = @word_definitions[referenced_name]
         end
         
         return resolution
      end


      #
      # anonymous_word()
      #  - given a word definition (ExpressionForm of SparseRanges), looks up/registers it under an
      #    anonymous name and returns the name
      
      def anonymous_word( word_def )
         STDERR.puts "skipping anonymous_word"
         return "_blah"
      end
      


    #---------------------------------------------------------------------------------------------------------------------
    # General support
    #---------------------------------------------------------------------------------------------------------------------

    protected
    
      
      #
      # create_sequence()
      #  - returns an ExpressionForms::Sequence of its parameters
      
      def create_sequence( *elements )
         return Util::ExpressionForms::Sequence.new( *elements )
      end
      
      
      #
      # create_branch_point()
      #  - returns an ExpressionForms::BranchPoint of its parameters
      
      def create_branch_point( *elements )
         return Util::ExpressionForms::BranchPoint.new( *elements )
      end
      
      
      #
      # create_repeater()
      #  - returns an ExpressionForms::Repeater
      
      def create_repeater( element, min = 1, max = nil )
         return Util::ExpressionForms::Repeater.new( element, min, max )
      end
      

      #
      # do_slot_registration()
      #  - given all the necessary information, decides how/if to register a slot or raise an error
      
      def do_slot_registration( symbol, inherited_name, specified_name, naming_context, assign_nil = false )
         name = nil
         
         if inherited_name.exists? and specified_name.exists? then
            nyi( "error handling for overlapping labels ([#{inherited_name.text}] vs [#{specified_name.text}])" ) 
         elsif inherited_name.exists? then
            name = inherited_name
         elsif specified_name.exists? then
            name = specified_name
         elsif !assign_nil then
            set = false
         end
         
         if name then
            naming_context.each do |symbol|
               nyi( "error handling for duplicate labels within rule" ) if symbol.slot_name == name.text
            end
         end
         
         if name or assign_nil then
            symbol.register_slot( name )
         end
      end
         

      
      
      
    
    #---------------------------------------------------------------------------------------------------------------------
    # Debugging
    #---------------------------------------------------------------------------------------------------------------------

    protected
         
      #
      # die()
      #  - dumps the top level of any supplied AST and kills the system
                 
      def die( ast = nil, message = nil )
         STDOUT.puts( "ERROR: #{message}" ) unless message.nil?
         ast.display( STDOUT.indent_stream ) unless ast.nil?
         exit
      end
      
      
      
      
      
      
      
   end # ModelBuilder
   


end  # module Grammar
end  # module Languages
end  # module RCC
