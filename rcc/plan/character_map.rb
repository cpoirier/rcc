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
require "#{$RCCLIB}/util/sparse_range.rb"


module RCC
module Plan

 
 #============================================================================================================================
 # class CharacterMap
 #  - sort of an array version of CharacterRange, with data held on the ranges 

   class CharacterMap
      
      attr_accessor :next

      def initialize( keep_data_unique = false )
         @next = nil
         @mapping_class = (keep_data_unique ? UniqueMapping : Mapping)
      end
      
      def empty?
         return @next.nil?
      end
      
      def each() 
         current = @next
         until current.nil?
            yield( current.character_range, current.data )
            current = current.next
         end
      end 
      
      def []=( coordinates, value )
         replace_data( value, coordinates )
      end
      
      def []( coordinates )
         find( coordinates )
      end
      

      #
      # merge_data()
      #  - merges data into the map across the specified character codes
      
      def merge_data( value, *coordinates )
         stratify_over( coordinates ) do |mapping|
            mapping.merge_data( value )
         end
      end


      #
      # replace_data()
      #  - replaces data into the map across the specified character codes
      
      def replace_data( value, *coordinates )
         stratify_over( coordinates ) do |mapping|
            mapping.replace_data( value )
         end
      end
      
      
      #
      # find()
      #  - returns the data at the specified coordinates
      
      def find( coordinates )
         case coordinates
         when Numeric
            each() do |character_range, data|
               return data if character_range.member?(coordinates)
            end
         else
            nyi( "support for #{coordinates.class.name} coordinates", coordinates )
         end
         
         return nil
      end


      def display( stream = $stdout )
         stream.puts "CharacterMap:"
         stream.indent do 
            current = @next
            until current.nil?
               current.display( stream )
               current = current.next
            end
         end
      end




    #---------------------------------------------------------------------------------------------------------------------
    # Internal processing
    #---------------------------------------------------------------------------------------------------------------------

    protected
    
    
      #
      # with_coordinates()
      #  - given a Range, SparseRange, or a pair of integers, calls your block with each pair
      
      def with_coordinates( coords )
         if coords.length == 2 then
            yield( coords[0], coords[1] )
         else
            coords = coords[0] if coords.is_an?(Array)
            case coords
            when Range
               yield( coords.first, coords.last )
            when Util::SparseRange
               coords.each_range do |range|
                  yield( range.first, range.last )
               end
            else
               nyi( "support for [#{coords.class.name}]" )
            end
         end
      end
      
      
      #
      # stratify_over()
      #  - calls stratify() for your coordinates, returning an array of unique Mappings it covers
      #  - calls your block once for each mapping instead, if supplied
      
      def stratify_over( coords )
         in_scope = {}
         with_coordinates( coords ) do |from, to|
            stratify( from, to ) do |mapping|
               in_scope[mapping.object_id] = mapping
            end
         end
         
         unique_mappings = in_scope.values
         if block_given? then
            unique_mappings.each do |mapping|
               yield( mapping )
            end
         end

         return unique_mappings
      end
    
    
      #
      # stratify()
      #  - slices up the map so you can directly address the specified range
      #  - calls your block once for each matching slice
      
      def stratify( from, to )
         current  = @next
         previous = self

         if @next.nil? then
            @next = @mapping_class.new( from, to )
            yield( @next )
         else
            while (from <= to and current.exists?)
               if to < current.first then
                  mapping = @mapping_class.new(from, to).move_after( previous )
                  yield( mapping )
                  from = to + 1
               elsif from > current.last then
                  if current.next.nil? then
                     mapping = @mapping_class.new(from, to).move_after( current )
                     yield( mapping )
                     from = to + 1
                  else
                     previous = current
                     current  = current.next
                  end
               else
                  from, to = current.stratify( from, to ) {|mapping| yield(mapping) }
               end
            end
         end
      end


      class Mapping
         attr_reader :first, :last, :data, :next
         attr_writer :next

         def initialize( first, last, data = [] )
            @first = first
            @last  = last
            @data  = data
            @next  = nil
         end
         
         def character_range()
            return CharacterRange.new( @first..@last ) 
         end

         def member?( key )
            return (key >= @first and key <= @last)
         end

         def merge_data( value )
            @data << value
         end

         def replace_data( value )
            @data = [value]
         end

         def stratify( from, to )
            in_scope = []

            if from < @first then
               created = make_copy( @first, @last ).move_after(self)
               @last  = @first - 1
               @first = from
               arrange_data( created, :forward )

               in_scope << self
               in_scope << created
            elsif from == @first then
               in_scope << self
            else
               created = split(from)
               in_scope << created
            end

            if to >= @last then
               from = @last + 1
            else
               previous_mapping = in_scope[-1]
               previous_mapping.split( to + 1 )
               from = to + 1
            end

            in_scope.each do |mapping|
               yield( mapping )
            end

            return from, to
         end

         def make_copy( first, last )
            return self.class.new( first, last, [] + self.data )
         end

         def split( first_of_second, placement = :both )
            copy = make_copy( first_of_second, @last ).move_after(self)
            @last = first_of_second - 1
            arrange_data( copy, placement )
            return copy
         end
         
         def arrange_data( forward_copy, placement = :both )
            case placement
            when :forward
               @data.clear()
            when :back
               forward_copy.instance_eval { @data.clear() }
            else
               # no op
            end
            
            return forward_copy
         end

         def move_after( previous )
            self.next = previous.next
            previous.next = self
            return self
         end
         
         def display( stream = $stdout )
            stream.puts "#{@first}..#{@last}:"
            stream.indent do
               @data.each do |datum|
                  datum.display( stream )
               end
            end
         end
      end


      class UniqueMapping < Mapping
         def initialize( first, last, data = [] )
            super( first, last )
            @data = {}
            data.each do |datum|
               @data[datum] = true
            end
         end
         
         def merge_data( value )
            @data[value] = true
         end

         def replace_data( value )
            @data.clear()
            @data[value] = true
         end
         
         def data()
            return @data.keys
         end
      end

      
      
      
   end # CharacterMap
   



end  # module Plan
end  # module RCC
