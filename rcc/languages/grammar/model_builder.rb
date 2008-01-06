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
         
         @names                     = {}    # name => some AST
         @referenceable_names       = {}    # name => top-level AST
         
         @character_definition_asts = {}    # name => :character_definition AST
         @word_definition_asts      = {}    # name => :word_definition      AST
         @pattern_definition_asts   = {}    # name => :pattern_definition   AST
         @form_definition_asts      = {}    # name => :form_definition      AST
         
         @character_definitions     = {}    # name => SparseRange result of processing a :character_definition 
         @word_definitions          = {}    # name => ??? result of processing a :word_definition
      end



      #
      # build_model()
      #  - given a AST of a grammar source file, returns a Model::Grammar or an error report
      
      def build_model( grammar_ast )
         assert( grammar_ast.type == :grammar, "Um, perhaps you meant to pass a grammar AST?" )
         
         #
         # Start by running a few validations, and flattening a few data structures.  Groups, for instance, are
         # syntactic sugar only -- they don't change the meaning of any of the rules -- so we can discard them here.
         # In fact, all of the sections have already served their purpose, by producing Nodes of the right type.
         # We can get rid of all of them.

         options     = []
         precedences = []
         work_queue = [grammar_ast]
         until work_queue.empty?
            container = work_queue.shift
            case container.type
               
               when :grammar
                  work_queue.concat container.gather(:preamble, :rules)
                  work_queue.concat(container.groups) if container.slot_filled?(:groups)
               when :group
                  work_queue.concat container.gather(:preamble, :rules)
               when :preamble
                  options.concat( container.options ) if container.slot_filled?(:options)
                  work_queue.concat container.gather(:characters_section, :words_section, :patterns_section)
               when :rules
                  precedences.concat container.gather(:precedence_section) 
                  work_queue.concat  container.gather(:forms_section     )
                  
               when :characters_section
                  register_names( container.character_definitions, @names, @referenceable_names, @character_definition_asts ) if container.slot_filled?(:character_definitions)
               when :words_section
                  register_names( container.word_definitions     , @names, @referenceable_names, @word_definition_asts      ) if container.slot_filled?(:word_definitions     )
               when :patterns_section
                  register_names( container.pattern_definitions  , @names, @referenceable_names, @pattern_definition_asts   ) if container.slot_filled?(:pattern_definitions  )
                  
               when :forms_section
                  if container.slot_filled?(:form_definitions) then
                     register_names( container.form_definitions, @names, @referenceable_names, @form_definition_asts )
                     
                     #
                     # The form definitions are always named.  Additionally, individual forms can also be named.
                     # Unfortunately, this is in the AST as a separate node, in a list.  So we have to go into the
                     # form directives list and find any names.  We'll copy the data up to the form node, for 
                     # convenient access, then register any named forms, to verify their unique names.
                     
                     named_forms = []
                     container.form_definitions.each do |form_definition|
                        if form_definition.slot_filled?(:forms) then
                           form_definition.forms.each do |form|
                              form.define_slot( :definition_name, form_definition.name )
                              if form.slot_filled?(:directives) then
                                 form.directives.each do |directive|
                                    if directive.subtype == :form_name then
                                       if form.slot_filled?(:name) then
                                          nyi( "error reporting for duplicate form name specification" )
                                       else
                                          form.define_slot( :name, directive.name )
                                          named_forms << form
                                       end
                                    end
                                 end
                              end
                           end
                        end
                     end
                     
                     register_names( named_forms, @names )
                  end
                  
               else
                  nyi( "work_queue support for type [#{container.type}]")
            end
         end
         
         
         #
         # Resolve character definitions into SparseRanges of character codes.
         
         @character_definition_asts.each do |name, definition_ast|
            @character_definitions[name] = process_character_data( definition_ast.character_set, [name] ) unless @character_definitions.member?(name)
         end
         
         if false then
            @character_definitions.each do |name, definition|
               puts "character_definition #{name}:"
               puts "   #{definition}"
               puts ""
            end
         end
         
         
         #
         # Resolve word definitions into ExpressionForms.
         
         @word_definition_asts.each do |name, definition_ast|
            @word_definitions[name] = process_word_data( definition_ast.definition, [name] ) unless @word_definitions.member?(name)
         end
         
         if false then
            @word_definitions.each do |name, definition|
               puts "word_definition #{name}:"
               definition.display( STDOUT, "   " )
               puts ""
            end
         end
         
         
         #
         # Resolve form definitions into an Array of ExpressionForms.
         
         @form_definition_asts.each do |name, definition_ast|
            forms = []
            definition_ast.forms.each do |form|
               forms << process_form_data( form )
            end
            
            @form_definitions[name] = forms
         end
         
         if true then
            @form_definitions.each do |name, definition|
               puts "form_definition #{name}:"
               puts ""
            end
         end
         
         
         #
         # Now we can start building the Model.
         
         @grammar = Model::Grammar.new( grammar_ast.name )
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

      @@escape_sequences = { '\n' => "\n"[0], '\r' => "\r"[0], '\t' => "\t"[0], "\\\\" => "\\"[0] }
    
      #
      # process_character_data()
      #  - processes the body of a :character_definition (or parts thereof) into a SparseRange
      
      def process_character_data( node, loop_detection = [] )
         result = nil
         
         case node.subtype
            when :cs_difference
               result = process_character_data( node.lhs, loop_detection ) - process_character_data( node.rhs, loop_detection )

            when :cs_characters
               result = Util::SparseRange.new()
               node.cs_elements.each do |element|
                  result += process_character_data( element, loop_detection )
               end

            when :cs_reference
               referenced_name = node.name.text
               unless @character_definitions.member?(referenced_name)
                  if loop_detection.member?(referenced_name) then
                     nyi( "error handling for detected reference loop [#{referenced_name}]" )
                  elsif @character_definition_asts.member?(referenced_name) then
                     referenced_ast = @character_definition_asts[referenced_name]
                     @character_definitions[referenced_name] = process_character_data( referenced_ast.character_set, loop_detection + [referenced_name] )
                  else
                     nyi( "error handling for missing character_definition referenced [#{referenced_name}]" )
                  end
               end
            
               result = @character_definitions[referenced_name]
               
            when :cs_character
               result = process_character_data( node.character, loop_detection )
               
            when :cs_range
               result = process_character_data(node.from, loop_detection)..process_character_data(node.to, loop_detection)
               
            when :general_character
               result = node.text[0]
               
            when :escape_sequence
               if @@escape_sequences.member?(node.text) then
                  result = @@escape_sequences[node.text]
               else
                  result = node.text[1]
               end
               
            when :unicode_sequence
               result = node.text.slice(2..-1).to_i(16)
               
            else
               bug( "unsupported node subtype [#{node.subtype}]" )
         end
         
         return result
      end
      
      
      #
      # process_word_data()
      #  - process the body of a :word_definition (or parts thereof) into an ExpressionForm
      
      def process_word_data( node, loop_detection = [] )
         result = nil
         
         case node.subtype
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
                  
               result = Util::ExpressionForms::Repeater.new( process_word_data(node.string_pattern, loop_detection), minimum, maximum )
               
            when :sp_concat
               result = Util::ExpressionForms::Sequence.new( process_word_data(node.lhs), process_word_data(node.rhs) )
               
            when :sp_reference
               referenced_name = node.name.text
               if @character_definitions.member?(referenced_name) or @character_definition_asts.member?(referenced_name) then
                  unless @character_definitions.member?(referenced_name)
                     if loop_detection.member?(referenced_name) then
                        nyi( "error handling for detected reference loop [#{referenced_name}]" )
                     elsif @character_definition_asts.member?(referenced_name) then
                        referenced_ast = @character_definition_asts[referenced_name]
                        @character_definitions[referenced_name] = process_character_data( referenced_ast.character_set, loop_detection + [referenced_name] )
                     end
                  end
                  result = Util::ExpressionForms::Sequence.new( @character_definitions[referenced_name] )
               elsif @word_definitions.member?(referenced_name) or @word_definition_asts.member?(referenced_name) then
                  unless @word_definitions.member?(referenced_name)
                     if loop_detection.member?(referenced_name) then
                        nyi( "error handling for detected reference loop [#{referenced_name}]" )
                     elsif @word_definition_asts.member?(referenced_name) then
                        referenced_ast = @word_definition_asts[referenced_name]
                        @word_definitions[referenced_name] = process_word_data( referenced_ast.definition, loop_detection + [referenced_name] )
                     end
                  end
                  result = @word_definitions[referenced_name]
               else
                  nyi( "error handling for missing character/word definition reference [#{referenced_name}]" )
               end
               
            when :sp_characters
               result = Util::ExpressionForms::Sequence.new( process_character_data(node.character_set) )

            when :sp_string
               result = process_word_data(node.string)
            
            when :string
               result = Util::ExpressionForms::Sequence.new()
               node.string_elements.each do |string_element|
                  result << process_word_data( string_element )
               end
               
            when :general_text
               result = Util::ExpressionForms::Sequence.new()
               node.text.each do |code|
                  result << Util::SparseRange.new( code[0] )
               end
               
            when :escape_sequence
               if @@escape_sequences.member?(node.text) then
                  result = Util::ExpressionForms::Sequence.new( Util::SparseRange.new(@@escape_sequences[node.text]) )
               else
                  result = Util::ExpressionForms::Sequence.new( Util::SparseRange.new(node.text[1]) )
               end
               
            when :unicode_sequence
               result = Util::ExpressionForms::Sequence.new( Util::SparseRange.new(node.text.slice(2..-1).to_i(16)) )
               
            else
               bug( "unsupported node subtype [#{node.subtype}]" )
         end
         
         return result
      end
      

      #
      # process_form_data()
      #  - process the body of a :form (or parts thereof) into an ExpressionForm
      
      def process_form_data( node, loop_detection = [] )
         result = nil
         
         case node.subtype
            when :form
               result = process_form_data( node.form_expression )
               
            when :fe_macro_call
               result = 
               
               
            else
               die( node )
               bug( "unsupported node subtype [#{node.subtype}]" )
         end
   
         return result
      end
      
      


    
    #---------------------------------------------------------------------------------------------------------------------
    # Debugging
    #---------------------------------------------------------------------------------------------------------------------

    protected
         
      #
      # die()
      #  - dumps the top level of any supplied AST and kills the system
                 
      def die( ast = nil )
         ast.display( STDOUT, "" ) unless ast.nil?
         exit
      end
      
      
      
      
      
      
      
   end # ModelBuilder
   


end  # module Grammar
end  # module Languages
end  # module RCC
