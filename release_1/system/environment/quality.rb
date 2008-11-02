#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright (C) 2007-2008 Chris Poirier (cpoirier@gmail.com)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation 
# files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
# modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
# is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE 
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR 
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#================================================================================================================================



 #----------------------------------------------------------------------------------------------------------------------------
 # Exception classes for bugs.
 #----------------------------------------------------------------------------------------------------------------------------
   
   class Bug < Exception
      attr_reader :data
      
      def initialize( message, data = nil )
         super( message )
         @data = data
      end
   end
   
   class NYI              < Bug; end
   class AssertionFailure < Bug; end
   class TypeCheckFailure < Bug; end


   
   
 #----------------------------------------------------------------------------------------------------------------------------
 # Convenience routines for maintaining software quality.
 #----------------------------------------------------------------------------------------------------------------------------
 
 
   #
   # assert()
   #  - raises an AssertionFailure if the condition is false

   def assert( condition, message, *data )
      unless condition
         data = yield() if block_given?
         raise AssertionFailure.new(message, data)
      end
   end


   #
   # bug()
   #  - raises a Bug exception, indicating that something happened that shouldn't have
   
   def bug( description, *data )
      raise Bug.new( "BUG: " + description, data )
   end
   
   
   #
   # nyi()
   #  - raises an NYI exception, indicating that something it Not Yet Implemented (but will be, one day)
   
   def nyi( description = nil, *data )
      if description.nil? then
         begin
            raise "tmp"
         rescue Exception => e
            description = e.backtrace[1]
         end
      end
      
      raise NYI.new( "NYI: " + description, data )
   end
   
   
   #
   # warn_nyi()
   #  - dumps an NYI warning to $stderr, once per message
   
   def warn_nyi( description )
      unless $nyi_warnings_already_given.member?(description)
         $stderr.puts "NYI: " + description
         $nyi_warnings_already_given[description] = true
      end
   end

   $nyi_warnings_already_given = {}   


   #
   # warn_bug()
   #  - dumps an NYI warning to $stderr, once per message
   
   def warn_bug( description )
      unless $nyi_warnings_already_given.member?(description)
         $stderr.puts "BUG: " + description
         $nyi_warnings_already_given[description] = true
      end
   end


   #
   # ignore_errors()
   #  - catches any exceptions raised in your block, and returns error_return instead
   #  - returns your block return otherwise
   
   def ignore_errors( error_return = nil )
      begin
         return yield()
      rescue
         return error_return
      end
   end


   #
   # type_check()
   #  - verifies that object is of the specified type
   #  - if type is an array, verifies that object is one of the specified types
   #  - unless allow_nil is true, object cannot be nil

   def type_check( object, type, allow_nil = false )

      typeMessage = ""
      error = true

      if object.nil? then
         error = false if allow_nil

      elsif type.kind_of?( Array ) then

         type.each do |t|
            if t.is_a?(String) then 
               error = !(object.class.name == t)
            elsif object.kind_of?(t) then
               error = false
               break
            end
         end

         if error then
            names = type.collect {|t| t.name}
            typeMessage = "expected one of [ " + names.join( ", " ) + " ]"
         end

      else
         if type.is_a?(String) then
            error = !(object.class.name == type)
         elsif object.kind_of?(type) then
            error = false
         else
            typeMessage = "expected " + type.name
         end

      end

      if error then
         actual = object.class.name
         message = "BUG: wrong argument type " + actual + " (" + typeMessage + ")"
         raise TypeCheckFailure.new( message )
      end

      return object
   end


