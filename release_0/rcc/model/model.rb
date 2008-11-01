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

require "#{$RCCLIB}/model/grammar.rb"
require "#{$RCCLIB}/model/system.rb"
require "#{$RCCLIB}/model/elements/group.rb"
require "#{$RCCLIB}/model/elements/rule.rb"
require "#{$RCCLIB}/model/elements/slot.rb"
require "#{$RCCLIB}/model/elements/character_range.rb"
require "#{$RCCLIB}/model/elements/pattern.rb"
require "#{$RCCLIB}/model/markers/reference.rb"
require "#{$RCCLIB}/model/markers/local_commit.rb"
require "#{$RCCLIB}/model/markers/gateway_marker.rb"
