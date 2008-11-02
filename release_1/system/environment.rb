#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright 2007-2008 Chris Poirier (cpoirier@gmail.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the 
# License.  You may obtain a copy of the License at
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" 
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language 
# governing permissions and limitations under the License.
#================================================================================================================================


   RCC_LIBDIR = File.expand_path(File.dirname(File.expand_path(__FILE__)))
   RCC_INDEV  = true   # Clear this when building a distribution!
   
   
   #
   # Bootstrap the environment.
   
   Dir["#{RCC_LIBDIR}/environment/*.rb"].each {|path| require path}
   ContextStream.hijack_std()


   #
   # Set up some useful constants.
   
   RCC_RELEASE   = 1
   RCC_VERSION   = (RCC_INDEV && `which svnversion`.strip.length > 0) ? `svnversion -n "#{RCC_LIBDIR}"`.split(":").pop : "$Revision$".to_i
   RCC_STRING    = "RCC #{RCC_RELEASE} Version #{RCC_VERSION}"
   RCC_COPYRIGHT = "Copyright (C) 2007-2008 Chris Poirier"
   RCC_WELCOME   = RCC_STRING + " -- " + RCC_COPYRIGHT + "\nThis program comes with ABSOLUTELY NO WARRANTY.  See license for details."



