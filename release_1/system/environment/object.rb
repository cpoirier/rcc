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


class Object
   def each()
      yield( self ) 
   end
   
   def exists?()
      return true
   end
   
   alias set? exists?
   
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
