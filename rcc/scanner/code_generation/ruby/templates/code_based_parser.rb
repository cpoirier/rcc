#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================
#
#  === DO NOT EDIT THIS FILE! ===
# 
#  It was GENERATED by rcc on %%GENERATION_DATE%%
#     from grammar "%%GRAMMAR_NAME%%"
#
#================================================================================================================================


require "#{File.dirname(File.expand_path(__FILE__))}/common.rb" 
require "#{File.dirname(File.expand_path(__FILE__))}/node.rb" 


%%MODULE_HEADER%%
 


 #============================================================================================================================
 # class Parser
 #  - not much I can say here . . . 

   class %%GRAMMAR_CLASS_NAME%%Parser
      include Common
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization and public interface
    #---------------------------------------------------------------------------------------------------------------------







    #---------------------------------------------------------------------------------------------------------------------
    # States
    #---------------------------------------------------------------------------------------------------------------------
    
    protected    
    
      %%STATES%%
    
    
       
    

    #---------------------------------------------------------------------------------------------------------------------
    # Productions
    #---------------------------------------------------------------------------------------------------------------------
    
    protected    
    
      %%PRODUCTIONS%%




    
    #---------------------------------------------------------------------------------------------------------------------
    # Support code
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
      
   end # %%GRAMMAR_CLASS_NAME%%Parser
   

%%MODULE_FOOTER%%
