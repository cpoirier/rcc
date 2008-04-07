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

module RCC
module Languages
module Grammar

 
 #============================================================================================================================
 # class NamingContext
 #  - manages naming of Slots in a Rule for the GrammarBuilder

   class NamingContext
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :explicit_names
      attr_reader :implicit_names

      def initialize( grammar_builder )
         @grammar_builder   = grammar_builder
         @explicit_names    = {}
         @implicit_names    = {}
         @applied_labels    = []
         @label_is_explicit = false
      end
      
      def explicit_label_pending?()
         return @label_is_explicit
      end
      
      
      #
      # apply_label()
      #  - applies the specified label_token to all naming events that occur during the passed block
      #  - an implicit label overrides supplied names
      #  - an explicit label overrides any implicit labels and supplied names
      #  - it is an error to nest explicit labels
      #  - you can pass a nil label and your block will still be called without any effect on naming
      
      def apply_label( label, is_explicit = false )
         if label.nil? or (@label_is_explicit and !is_explicit) then
            yield()
         else
            if is_explicit then
               nyi( "error reporting for nested explicit label"      ) if @label_is_explicit
               nyi( "error reporting for duplicate explicit label"   ) if @explicit_names.member?(label.to_s)
               nyi( "error reporting for explicit/implicit conflict" ) if @implicit_names.member?(label.to_s)
               @explicit_names[label.to_s] = [] unless label.to_s == "ignore"
            else
               nyi( "error reporting for explicit/implicit conflict" ) if @explicit_names.member?(label.to_s)
               @implicit_names[label.to_s] = [] unless @implicit_names.member?(label.to_s) or label.to_s == "ignore"
            end

            begin
               @applied_labels.push label.to_s 
               @label_is_explicit = is_explicit
               yield()
            ensure
               @applied_labels.pop
               @label_is_explicit = false
            end
         end
      end


      #
      # name()
      #  - associates a name with a symbol
      #  - any applied label overrides the name you supply here, unless you mark it explicit
      
      def name( symbol, name, name_is_explicit = false )
         apply_label( name_is_explicit ? name : nil ) do
            if @applied_labels.empty? then
               name = name.to_s
               nyi( "error reporting for explicit/implicit conflict" ) if @explicit_names.member?(name)
               @implicit_names[name] = [] unless @implicit_names.member?(name)
               @implicit_names[name] << symbol
            else
               label = @applied_labels[-1]
               if label == "ignore" then
                  # no op
               elsif @label_is_explicit then
                  @explicit_names[label] << symbol
               else
                  @implicit_names[label] << symbol
               end
            end
         end
      end
      
      
      
      #
      # import_pluralization()
      #  - imports names from a Namer for a Pluralization
      #  - the other Namer MUST ALREADY HAVE BEEN APPLIED to the other Rule
      
      def import_pluralization( pluralization_reference, namer )
         namer.explicit_names.each do |name, pluralized_symbols|
            next if pluralized_symbols.empty?
            assert( pluralized_symbols[0].context_rule.exists?, "you must apply naming to the imported Namer's rule BEFORE importing it" )
            
            plural_name = @grammar_builder.pluralize(name)
            nyi( "error reporting for explicit/implicit conflict" ) if (@explicit_names.member?(plural_name) or @implicit_names.member?(plural_name))
            
            pluralized_symbols.each do |symbol|
               explicit_names[plural_name] = [] unless explicit_names.member?(plural_name)
               explicit_names[plural_name] << [pluralization_reference, symbol]
            end
         end
         
         namer.implicit_names.each do |name, pluralized_symbols|
            next if pluralized_symbols.empty?
            assert( pluralized_symbols[0].context_rule.exists?, "you must apply naming to the imported Namer's rule BEFORE importing it" )
            
            plural_name = @grammar_builder.pluralize(name)
            nyi( "error reporting for explicit/implicit conflict" ) if @explicit_names.member?(plural_name)
            
            pluralized_symbols.each do |symbol|
               implicit_names[plural_name] = [] unless implicit_names.member?(plural_name)
               implicit_names[plural_name] << [pluralization_reference, symbol]
            end
         end
      end
      
      
      
      #
      # commit()
      #  - applies the Namer to a Rule
      #  - all implicit names are resolved at this stage
      #  - you shouldn't change this Namer again after calling this
      
      def commit( rule )
         explicit = true
         [@explicit_names, @implicit_names].each do |symbol_set|
            symbol_set.each do |name, symbols|
               number = 1
               symbols.each do |symbol|
                  effective_name = (explicit or symbols.length == 1) ? name : name + "_#{number}"

                  if symbol.is_an?(Array) then
                     rule.register_plural_import( effective_name, symbol[0], symbol[1].slot_name )
                  else
                     symbol.set_slot_name( rule, effective_name )
                  end
                  
                  number +=1
               end
            end
            
            explicit = false
         end
      end
      
      


   end # NamingContext
   


end  # module Grammar
end  # module Languages
end  # module RCC
