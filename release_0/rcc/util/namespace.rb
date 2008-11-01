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
require "#{$RCCLIB}/util/ordered_hash.rb"


module RCC
module Util

 
 #============================================================================================================================
 # class Namespace
 #  - a generic structure namespace (like you might expect for managing scoped variables in a program)

   class Namespace
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_accessor :allow_override
      attr_reader   :parent_namespace
      attr_reader   :top_namespace

      def initialize( parent = nil )
         @names  = Util::OrderedHash.new()
         @parent_namespace = parent
         @top_namespace    = parent.nil? ? self : parent.top_namespace
         @allow_override   = true 
      end
      
      
      #
      # define()
      #  - returns true if the name was defined in this Namespace, or false if it was already taken
      #  - you can pass a block that returns the value, and it will only be called if the name is available

      def define( name, value = nil, false_value = nil )
         if @names.member?(name) or (!@allow_override and resolve(name)) then
            return false_value
         else
            value = yield() if block_given? 
            @names[name] = value
            return value
         end
      end
      
      
      #
      # defined?()
      #  - returns true if the name is defined
      #  - follows the same interface as resolve()
      
      def defined?( path, limit_scope = false )
         value = resolve( path, limit_scope )
         return value.exists?
      end
      
      
      #
      # resolve()
      #  - returns the value for the specified name, in this or any parent Namespace
      #  - you can pass an array of names for a scoped name, if you have define()d the Namespaces in 
      #    a hierarchy of names -- pass namespaces first in the array
      #  - if you set limit_scope, the search will begin in this Namespace, and will not move to 
      #    any parent (this is mostly for internal use)
      
      def resolve( path, limit_scope = false )
         if path.is_an?(Array) then
            assert( !path.empty?, "why did you pass an empty path for resolution?" )
            resolved = resolve( path[0], limit_scope )
            if path.length == 1 then
               return resolved
            elsif resolved.is_a?(Namespace) then
               namespace = resolved
               return namespace.resolve( path.rest, true )
            else
               return nil
            end
         else
            name = path
            if @names.member?(name) then
               return @names[name]
            elsif !limit_scope and @parent_namespace.exists? then
               return @parent_namespace.resolve( path, limit_scope )
            end
         end
      
         return nil
      end
      
      
      #
      # name_of()
      #  - returns the name of the specified object within this namespace
      
      def name_of( object )
         @names.each do |name, member|
            return name if object == member
         end
         
         return @parent.name_of(object) if @parent.exists?
         return nil
      end
      
   end # Namespace
   


end  # module Util
end  # module RCC
