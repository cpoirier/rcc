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

require "#{File.expand_path(__FILE__).split("/system/")[0..-2].join("/system/")}/system/environment.rb"

require "#{RCC_LIBDIR}/model/grammar.rb"
require "#{RCC_LIBDIR}/model/system.rb"
require "#{RCC_LIBDIR}/model/elements/group.rb"
require "#{RCC_LIBDIR}/model/elements/rule.rb"
require "#{RCC_LIBDIR}/model/elements/slot.rb"
require "#{RCC_LIBDIR}/model/elements/character_range.rb"
require "#{RCC_LIBDIR}/model/elements/pattern.rb"
require "#{RCC_LIBDIR}/model/markers/reference.rb"
require "#{RCC_LIBDIR}/model/markers/local_commit.rb"
require "#{RCC_LIBDIR}/model/markers/gateway_marker.rb"
