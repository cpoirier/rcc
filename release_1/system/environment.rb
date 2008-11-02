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


   RCC_LIBDIR = File.expand_path(File.dirname(File.expand_path(__FILE__)))
   
   RCC_RELEASE   = 1
   RCC_BUILD     = "$Revision$".gsub(/[^0-9]/, "").to_i     # Note, to force this to update, change this line and commit/update: 1
   RCC_STRING    = "RCC #{RCC_RELEASE} Build #{RCC_BUILD}"
   RCC_COPYRIGHT = "Copyright (C) 2007-2008 Chris Poirier"
   RCC_WELCOME   = RCC_STRING + " -- " + RCC_COPYRIGHT + "\nThis program comes with ABSOLUTELY NO WARRANTY.  See license for details."


   #
   # Bootstrap the environment.
   
   Dir["#{RCC_LIBDIR}/environment/*.rb"].each {|path| require path}
   ContextStream.hijack_std()

