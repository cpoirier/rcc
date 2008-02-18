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


require "#{$RCCLIB}/model/group.rb"
require "#{$RCCLIB}/model/rule.rb"
require "#{$RCCLIB}/model/slot.rb"
require "#{$RCCLIB}/model/pluralization.rb"
require "#{$RCCLIB}/model/string_reference.rb"
require "#{$RCCLIB}/model/rule_reference.rb"
require "#{$RCCLIB}/model/group_reference.rb"
require "#{$RCCLIB}/model/pluralization_reference.rb"
