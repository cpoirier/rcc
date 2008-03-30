#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

   $RCCLIB = File.expand_path(File.dirname(File.expand_path(__FILE__)))
   require "#{$RCCLIB}/util/quality.rb"
   
   def max( a, b )
      a > b ? a : b
   end
   
   def min( a, b )
      a < b ? a : b
   end
   
   
   def ignore_errors( *error_classes )
      begin
         yield()
      rescue Exception => e
         raise e unless error_classes.empty? or error_classes.member?(e.class)
         return false
      end
      
      return true
   end
   
   
   def with_context_variables( pairs = {} )
      old = pairs.keys.each{ |name| Thread.current[name] }
      begin
         pairs.each{ |name, value| Thread.current[name] = value }
         yield( )
      ensure
         old.each{ |name, value| Thread.current[name] = value }
      end      
   end
   
   
   def context_variable( name )
      return Thread.current[name]
   end
   
   
   def collect_from( container, method = :each, *parameters )
      collection = []
      container.send( method, *parameters ) do |element|
         if block_given? then
            collection << yield(element)
         else 
            collection << element
         end
      end
      
      return collection
   end
   
   def select_from( container, method = :each, *parameters )
      collection = []
      container.send( method, *parameters ) do |element|
         collection << element if yield(element)
      end
      
      return collection
   end
   
   
   class String
      
      attr_accessor :source
      
      
      #
      # Converts the string to a plural form.  It's simple
      # stupid concatenation...

      def pluralize( count = 2, plural_form = nil )
         if count == 1 then
            return self
         else
            if plural_form.nil? then
               if self[-1..-1] == "y" then
                  return self[0..-2] + "ies"
               else
                  return self + "s"
               end
            else
               return plural_form
            end
         end
      end
   

      #
      # each_index_of()
      #  - calls your block with each position of the search string
      
      def each_index_of( search, pos = 0 )
         while next_pos = ruby_index( search, pos )
            yield( next_pos )
            pos = next_index + 1
         end
      end


      #
      # escape()
      #  - returns a string with newline etc. escaped
      
      def escape()
         self.inspect.slice(1..-2).gsub("\\\"", "\"").gsub("\\'", "'")
      end
      
      
      #
      # <<
      #  - adds unicode character code support to the standard << 

      alias ruby_append <<
      
      def <<( data )
         if data.is_a?(Numeric) then
            self << [data].pack("U*")
         else
            ruby_append( data )
         end
      end

   end
   
   
            

   class Array
      
      #
      # inject()
      #  - calls the block for each element, passing in the last value generated to each next item
      #  - returns the final value

      def inject( seed ) 
         each() do |element|
            result = yield( seed, element )
            next if result.nil?
            seed = result
         end
         return seed
      end
      
      
      #
      # select()
      #  - returns an array containing only those elements for which your block returns true
      
      def select()
         selected = []
         
         each() do |element|
            selected << element if yield(element)
         end
         
         return selected
      end
      
           
      #
      # remove_if()
      #  - just like delete_if(), except it returns an array of the deleted elements
      
      def remove_if()
         removed = []
         
         delete_if() do |element|
            if yield(element) then
               removed << element
               true
            else
               false
            end
         end
         
         return removed
      end
      
      
      #
      # subsets()
      #  - treating this list as a set, returns all possible subsets
      #  - by way of definitions, sets have no intended order and no duplicate elements
      
      def subsets( pretty = true )
         set     = self.uniq
         subsets = [ [] ]
         until set.empty?
            work_point = [set.shift]
            work_queue = subsets.dup
            until work_queue.empty?
               subsets.unshift work_queue.shift + work_point
            end
            
         end
         
         subsets.sort!{|lhs, rhs| rhs.length == lhs.length ? lhs <=> rhs : rhs.length <=> lhs.length } if pretty

         return subsets
      end
      
      
      #
      # to_hash( )
      #  - converts the elements of this array to keys in a hash and returns it
      #  - the item itself will be used as value if the value you specify is :value_is_element
      #  - if you supply a block, it will be used to obtain keys from the element
      
      def to_hash( value = nil )
         hash = {}
         
         self.each do |element|
            key = block_given? ? yield( element ) : element
            if value == :value_is_element then
               hash[key] = element
            else
               hash[key] = value
            end
         end
         
         return hash
      end
      
      
      #
      # rest()
      #  - returns all but the first element
      
      def rest()
         return self[1..-1]
      end


      #
      # to_a()
      
      def to_a()
         return self
      end
      
   end
   
   
   class Object
      def each()
         yield( self )
      end
      
      def exists?()
         return !nil?()
      end
      
      alias is_an? is_a?

      
      #
      # specialize_method_name( name )
      #  - returns a specialized Symbol version of the supplied name, based on this object's class name
      #  - example: <object:SomeClass>.specialize("process") => :process_some_class
      
      def specialize_method_name( name )
         return "#{name}#{self.class.name.split("::")[-1].gsub(/[A-Z]/){|s| "_#{s.downcase}"}}".intern
      end
      
      
      def to_a()
         return [self]
      end
   end
   
   
   
   class NilClass
      def each()
      end
      
      def to_a()
         return []
      end
   end
   
   
   class Time
      
      #
      # Time.measure()
      #  - returns the duration of the supplied block in seconds (floating point)

      def Time.measure()
         start = Time.now
         yield()
         return Time.now - start
      end
      
   end
   
   
   
   #
   # class ContextStream
   #  - a wrapper for STDOUT/STDERR that provides a bit of context-sensitivity for output processing.
   
   class ContextStream
      attr_reader :stream
      attr_reader :indent
      
      def initialize( stream, indent = "" )
         @stream     = stream
         @indent     = indent
         @pending    = true
         @properties = {}
      end
      
      
      #
      # ::indent_with()
      
      def self.indent_with( stream, additional = "   " )
         if stream then
            stream.indent(additional) { yield(stream) }
         else
            yield(stream)
         end
      end
      
      
      #
      # indent()
      #  - any output during your block will be indented from the context
      
      def indent( additional = "   " )
         old_indent = @indent
         begin
            additional = "   " * additional if additional.is_a?(Numeric)
            @indent += additional
            return yield( self )
         ensure
            @indent = old_indent
         end
      end
      

      #
      # with()
      #  - applies a set of name => value properties for the length of your block
      #  - properties can be retrieved with property()
      
      def with( pairs )
         old = pairs.keys.each{ |name| @properties[name] }
         begin
            pairs.each{ |name, value| @properties[name] = value }
            yield( )
         ensure
            old.each{ |name, value| @properties[name] = value }
         end      
      end
      
      
      #
      # []
      #  - returns the named property's current value, or nil
      
      def []( name )
         return @properties[name]
      end
      
      
      #
      # []=
      #  - sets a named property (without any scope management)
      
      def []=( name, value )
         @properties[name] = value
      end
      
      
      def <<( text )
         write( text )
         self
      end


      def puts( text = "" )
         write( text )
         write( "\n" )
      end
      
      def write( string )
         string = string.to_s
         
         if @pending then
            @stream.write( @indent )
            @pending = false
         end
         
         if string[-1..-1] == "\n" then
            @pending = true
            @stream.write( string.slice(0..-2).gsub("\n", "\n#{@indent}") )
            @stream.write( "\n" )
         else
            @stream.write( string.gsub("\n", "\n#{@indent}") )
         end
      end
      
      def end_line()
         write( "\n" ) unless @pending
      end
      
      def blank_lines( count = 2 )
         end_line()
         count.times { puts }
      end
      
      def method_missing( name, *args )
         @stream.send( name, *args )
      end
      
      
   end # ContextStream


   $stdout = ContextStream.new( $stdout ) unless $stdout.is_a?(ContextStream)
   $stderr = ContextStream.new( $stderr ) unless $stderr.is_a?(ContextStream)
   
