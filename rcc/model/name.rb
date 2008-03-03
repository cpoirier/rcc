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
module Model

 
 #============================================================================================================================
 # class Name
 #  - a qualified name that refers to something in the Model

   class Name < String
      
      #
      # ::create()
      
      def self.create( name, namespace = nil )
         name = new(name)
         name.namespace = namespace
         return name
      end
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_writer :namespace
      
      def namespace( default = nil )
         if @namespace.nil? then
            return default
         else
            return @namespace
         end
      end
      
      def has_namespace?()
         return @namespace.exists?
      end
      
      
      #
      # resolve()
      #  - resolves the name against a System or Grammar
      
      def resolve( context )
         case context
            when Grammar
               if @namespace.nil? or @namespace == context.name then
                  return context.strings[self] if context.strings.member?(self)
                  return context.rules[self]   if context.rules.member?(self)
                  return nil
               else
                  return resolve( context.system )
               end
            when System
               if @namespace.nil? then
                  return nil
               else
                  if context.grammars.member?(@namespace) then
                     return resolve( context.grammars[@namespace] )
                  else
                     return nil
                  end
               end
            else
               nyi( "support for #{context.class.name}", context )
         end
      end
      
   end # Name
   


end  # module Model
end  # module RCC
