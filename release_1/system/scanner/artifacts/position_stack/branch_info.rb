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

module RCC
module Scanner
module Artifacts
module PositionStack

 
 #============================================================================================================================
 # class BranchInfo
 #  - an adjunct to the Position marker that tracks information on a single branch point 
 #  - BranchInfo is carried forward through the parse until a Shift disambiguates the potential branches

   class BranchInfo
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :root_position
      attr_reader   :attempt_action
      attr_reader   :branch_index
      attr_accessor :end_position
      attr_reader   :previous_attempt
      
      def initialize( root_position, attempt_action, branch_index, previous_attempt = nil )
         @root_position     = root_position
         @previous_attempt  = previous_attempt
         @attempt_action    = attempt_action
         @branch_index      = branch_index
         @recovery_branches = nil
         @end_position      = nil
         @last_option       = (@branch_index + 1 == @attempt_action.actions.length)
         @committable_after = root_position.sequence_number
         
         position = @root_position
         attempt_action.attempt_span.times do
            if position then
               @committable_after = position.sequence_number
               position = position.context
            else
               break
            end
         end
      end
      
      
      def action()
         return @attempt_action.actions[@branch_index]
      end
      
      def started_with_shift?()
         return @attempt_action.actions[@branch_index].is_a?(Plan::Actions::Shift)
      end
      
      def last_option?()
         return @last_option
      end
      

      def committable?( current_top_position )
         if @last_option then
            current_top_position.each_position do |position|
               return false if position.sequence_number == @root_position.sequence_number
               break if position.sequence_number < @root_position.sequence_number
            end
         else
            current_top_position.each_position do |position|
               return false if position.sequence_number == @committable_after
               break if position.sequence_number < @committable_after
            end
         end
         
         return true
      end

      
      def at_validate_position?( position )
         return false unless started_with_shift?
         return false unless position.node.token?
         return position.context.object_id == @root_position.object_id
      end
      
      def id()
         local = "#{@root_position.sequence_number}:#{@branch_index + 1}/#{@attempt_action.actions.length}"
         if context_id = @root_position.branch_id then
            return context_id + " " + local
         else
            return local
         end
      end
      
      
      #
      # context_info()
      #  - this branch may lead off another, older branch; returns the context branch or nil
      
      def context_info()
         return @root_position.branch_info
      end
      
      
      #
      # context_info_and_root()
      
      def context_info_and_root()
         context_info  = context_info()
         root_position = context_info.nil? ? nil : context_info.root_position
         return context_info, root_position
      end
      
      
      #
      # add_recovery_branch()
      #  - even if a branch fails, we still need it around in case all branches fail and a recovery
      #    must be attempted; this routine adds a peer or downline BranchInfo to our recovery set
      
      def add_recovery_branch( branch_info )
         @recovery_branches = [] if @recovery_branches.nil?
         @recovery_branches << branch_info
      end
      
      
      #
      # add_recovery_branches_from()
      #  - adds all recovery_branches from another BranchInfo to this one (used for absorbing downline points)
      
      def add_recovery_branches_from( branch_info )
         branch_info.each_recovery_branch do |recovery_branch|
            add_recovery_branch( recovery_branch )
         end
      end
      
      
      #
      # each_recovery_branch()
      
      def each_recovery_branch()
         unless @recovery_branches.nil?
            @recovery_branches.each do |recovery_branch|
               yield( recovery_branch )
            end
         end
      end
      
      
      #
      # valid_production?()
      #  - returns true if the supplied production is a satisfactory way to resolve this branch
      
      def valid_production?( production )
         causal_action = @attempt_action.actions[@branch_index]
         if causal_action.is_a?(RCC::Plan::Actions::Shift) then
            return causal_action.valid_production?( production )
         else
            return true
         end
      end
      
      
      #
      # next_branch()
      #  - returns the next BranchInfo worth trying, either on this root_position or on a
      #    context one
      #  - if it returns nil, you are out of options
      
      def next_branch( end_position = nil )
         branch = nil
         
         @end_position = end_position
         if @branch_index + 1 < @attempt_action.actions.length then
            branch = BranchInfo.new( @root_position, @attempt_action, @branch_index + 1 )
         elsif context_branch = context_info() then
            branch = context_branch.next_branch()
         end
         
         if branch.exists? then
            branch.add_recovery_branches_from( self )
            branch.add_recovery_branch( self )
         end
         
         return branch
      end
      
      
   end # BranchInfo
   


end  # module PositionStack
end  # module Artifacts
end  # module Scanner
end  # module RCC


