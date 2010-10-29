# Copyright 2009-2010 10gen, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rubygems'
require 'mongo_record/core_ext'
require 'mongo_record/sql'

module MongoRecord

  class PKFactory
    def create_pk(row)
      return row if row[:_id]
      row.delete(:_id)          # in case it is nil
      row['_id'] ||= BSON::ObjectId
.new
      row
    end
  end

  class MongoError < StandardError #:nodoc:
  end
  class PreparedStatementInvalid < MongoError #:nodoc:
  end
  class RecordNotFound < MongoError #:nodoc:
  end
  class RecordNotSaved < MongoError #:nodoc:
  end

  # A superclass for database collection instances. The API is very similar
  # to ActiveRecord. See #find for examples.
  #
  # If you override initialize, make sure to call the superclass version,
  # passing it the database row or hash that it was given.
  #
  # Example:
  #
  #    class MP3Track < MongoRecord::Base
  #      collection_name :mp3_track
  #      fields :artist, :album, :song, :track
  #      def to_s
  #        "artist: #{self.artist}, album: #{self.album}, song: #{self.song}, track: #{track}"
  #      end
  #    end
  #
  #    track = MP3Track.find_by_song('She Blinded Me With Science')
  #    puts track.to_s
  #
  # The database connection defaults to the global $db. You can set the
  # connection using MongoRecord::Base.connection= and read it with
  # MongoRecord::Base.connection.
  #
  #   # Set the connection to something besides $db
  #   MongoRecord::Base.connection = connect('my-database')
  class Base

    @@connection = nil

    class << self # Class methods

      # Return the database connection. The default value is # <code>$db</code>.
      def connection
        conn = @@connection || $db
        raise "connection not defined" unless conn
        conn
      end

      # Set the database connection. If the connection is set to +nil+, then
      # <code>$db</code> will be used.
      def connection=(val)
        @@connection = val
        @@connection.pk_factory = PKFactory.new unless @@connection.pk_factory
      end

      # This method only exists so that MongoRecord::Base and
      # ActiveRecord::Base can live side by side.
      def instantiate(row={})
        new(row)
      end

      # Get ready to save information about +subclass+.
      def inherited(subclass)
        subclass.instance_variable_set("@coll_name", class_name_to_field_name(subclass.name)) # default name
        subclass.instance_variable_set("@field_names", []) # array of scalars names (symbols)
        subclass.instance_variable_set("@subobjects", {}) # key = name (symbol), value = class
        subclass.instance_variable_set("@arrays", {})     # key = name (symbol), value = class
        subclass.field(:_id, :_ns)
      end

      # Call this method to set the Mongo collection name for this class.
      # The default value is the class name turned into
      # lower_case_with_underscores.
      def collection_name(coll_name)
        @coll_name = coll_name
      end

      # Creates one or more collection fields. Each field will be saved to
      # and loaded from the database. The fields named "_id" and "_ns" are
      # automatically saved and loaded.
      #
      # The method "field" is also called "fields"; you can use either one.
      def field(*fields)
        fields.each { |field|
          field = field.to_sym
          unless @field_names.include?(field)
            ivar_name = "@" + field.to_s
            # this is better than lambda because it's only eval'ed once
            define_method(field, lambda { instance_variable_get(ivar_name) })
            define_method("#{field}=".to_sym, lambda { |val| instance_variable_set(ivar_name, val) })
            define_method("#{field}?".to_sym, lambda {
                            val = instance_variable_get(ivar_name)
                            val != nil && (!val.kind_of?(String) || val != '')
                          })
            @field_names << field
          end
        }
      end
      alias_method :fields, :field

      # Return the field names.
      def field_names; @field_names; end

      # Creates an index for this collection.
      # +fields+ should be either a single field name (:title)
      # or an array of fields ([:title, :author, :date])
      # or an array of a field name and direction ([:title, :asc] or [:title, :desc])
      # or an array of field names and directions ([[:title, :asc], [:author, :desc]])
      # +options+ Same as options for create index in the ruby driver
      def index(fields, options={})
        fields = Array(fields)

        if fields.length == 2 &&
          ( fields[1].to_s == 'asc' || fields[1].to_s == 'desc' ||
            fields[1] == Mongo::ASCENDING || fields[1] == Mongo::DESCENDING )
          fields = [fields]
        end

        fields = fields.map do |field|
          field = field.is_a?(Array) ? field : [field, :asc]
          field[1] = (field[1] == :desc) ? Mongo::DESCENDING : Mongo::ASCENDING
          field
        end

        collection.create_index(fields, options)
      end

      # Returns list of indexes for model, unless fields are passed.
      # In that case, creates an index.
      def indexes(*fields)
        if fields.empty?
          collection.index_information
        else
          index(*fields)
        end
      end

      # Return the names of all instance variables that hold objects
      # declared using has_one. The names do not start with '@'.
      #
      # These are not necessarily MongoRecord::Subobject subclasses.
      def subobjects; @subobjects; end

      # Return the names of all instance variables that hold objects
      # declared using has_many. The names do not start with '@'.
      def arrays; @arrays; end

      # Return the names of all fields, subobjects, and arrays.
      def mongo_ivar_names; @field_names + @subobjects.keys + @arrays.keys; end

      # Tell Mongo about a subobject (which can be either a
      # MongoRecord::Subobject or MongoRecord::Base instance).
      #
      # Options:
      # <code>:class_name<code> - Name of the class of the subobject.
      def has_one(name, options={})
        name = name.to_sym
        unless @subobjects[name]
          ivar_name = "@" + name.to_s
          define_method(name, lambda { instance_variable_get(ivar_name) })
          define_method("#{name}=".to_sym, lambda { |val| instance_variable_set(ivar_name, val) })
          define_method("#{name}?".to_sym, lambda {
                          val = instance_variable_get(ivar_name)
                          val != nil && (!val.kind_of?(String) || val != '')
                        })
          klass_name = options[:class_name] || field_name_to_class_name(name)
          @subobjects[name] = eval(klass_name)
        end
      end

      # Tells Mongo about an array of subobjects (which can be either a
      # MongoRecord::Subobject or MongoRecord::Base instance).
      #
      # Options:
      # <code>:class_name</code> - Name of the class of the subobject.
      def has_many(name, options={})
        name = name.to_sym
        unless @arrays[name]
          ivar_name = "@" + name.to_s
          define_method(name, lambda { instance_variable_get(ivar_name) })
          define_method("#{name}=".to_sym, lambda { |val| instance_variable_set(ivar_name, val) })
          define_method("#{name}?".to_sym, lambda { !instance_variable_get(ivar_name).empty? })
          klass_name = options[:class_name] || field_name_to_class_name(name)
          @arrays[name] = eval(klass_name)
        end
      end

      # Tells Mongo that this object has and many belongs to another object.
      # A no-op.
      def has_and_belongs_to_many(name, options={})
      end

      # Tells Mongo that this object belongs to another. A no-op.
      def belongs_to(name, options={})
      end

      # The collection object for this class, which will be different for
      # every subclass of MongoRecord::Base.
      def collection
        connection.collection(@coll_name.to_s)
      end

      # Find one or more database objects.
      #
      # * Find by id (a single id or an array of ids) returns one record or a Cursor.
      #
      # * Find :first returns the first record that matches the options used
      #   or nil if not found.
      #
      # * Find :all records; returns a Cursor that can iterate over raw
      #   records.
      #
      # Options:
      #
      # <code>:conditions</code> - Hash where key is field name and value is
      # field value. Value may be a simple value like a string, number, or
      # regular expression.
      #
      # <code>:select</code> - Single field name or list of field names. If
      # not specified, all fields are returned. Names may be symbols or
      # strings. The database always returns _id and _ns fields.
      #
      # <code>:order</code> - If a symbol, orders by that field in ascending
      # order. If a string like "field1 asc, field2 desc, field3", then
      # sorts those fields in the specified order (default is ascending). If
      # an array, each element is either a field name or symbol (which will
      # be sorted in ascending order) or a hash where key =isfield and value
      # is 'asc' or 'desc' (case-insensitive), 1 or -1, or if any other value
      # then true == 1 and false/nil == -1.
      #
      # <code>:limit</code> - Maximum number of records to return.
      #
      # <code>:offset</code> - Number of records to skip.
      #
      # <code>:where</code> - A string containing a JavaScript expression.
      # This expression is run by the database server against each record
      # found after the :conditions are run.
      #
      # This expression is run by the database server against each record
      # found after the :conditions are run.
      #
      # <code>:criteria</code> - A hash field to pass in MongoDB conditional operators
      # in a hash format.  [$gt, $lt, $gte, $lte, $in, ect.]
      #
      # Examples for find by id:
      #   Person.find("48e5307114f4abdf00dfeb86")     # returns the object for this ID
      #   Person.find(["a_hex_id", "another_hex_id"]) # returns a Cursor over these two objects
      #   Person.find(["a_hex_id"])                   # returns a Cursor over the object with this ID
      #   Person.find("a_hex_id", :conditions => "admin = 1", :order => "created_on DESC")
      #
      # Examples for find first:
      #   Person.find(:first) # returns the first object in the collection
      #   Person.find(:first, :conditions => ["user_name = ?", user_name])
      #   Person.find(:first, :order => "created_on DESC", :offset => 5)
      #   Person.find(:first, :order => {:created_on => -1}, :offset => 5) # same as previous example
      #
      # Examples for find all:
      #   Person.find(:all) # returns a Cursor over all objects in the collection
      #   Person.find(:all, :conditions => ["category = ?, category], :limit => 50)
      #   Person.find(:all, :offset => 10, :limit => 10)
      #   Person.find(:all, :select => :name) # Only returns name (and _id) fields
      #
      # Find_by_*
      #   Person.find_by_name_and_age("Spongebob", 42)
      #   Person.find_all_by_name("Fred")
      #
      # Mongo-specific example:
      #   Person.find(:all, :where => "this.address.city == 'New York' || this.age = 42")
      #   Person.find(:all, :criteria => {"followers_count"=>{"$gte"=>410}})
      #
      # As a side note, the :order, :limit, and :offset options are passed
      # on to the Cursor (after the :order option is rewritten to be a
      # hash). So
      #   Person.find(:all, :offset => 10, :limit => 10, :order => :created_on)
      # is the same as
      #   Person.find(:all).skip(10).limit(10).sort({:created_on => 1})
      def find(*args)
        options = extract_options_from_args!(args)
        options.symbolize_keys!
        case args.first
        when :first
          find_initial(options)
        when :all
          find_every(options)
        when :last
          find_last(options)
        else
          find_from_ids(args, options)
        end
      end

      # Yields each record that was found by the find +options+. The find is
      # performed by find.
      #
      # Example:
      #
      #   Person.find_each(:conditions => "age > 21") do |person|
      #     person.party_all_night!
      #   end

      def find_each(*args)
        options = extract_options_from_args!(args)
        options.symbolize_keys!
        find_every(options).each do |record|
          yield record
        end
        self
      end

      def all(*args)
        options = extract_options_from_args!(args)
        find_every(options)
      end

      def first(*args)
#        args = ([:first]<<args).flatten
        options = extract_options_from_args!(args)
        find_initial(options)
      end

      def last(*args)
        options = extract_options_from_args!(args)
        find_last(options)
      end

      # Returns all records matching mql. Not yet implemented.
      def find_by_mql(mql)    # :nodoc:
        raise "not implemented"
      end
      alias_method :find_by_sql, :find_by_mql

      # Returns the number of matching records.
      def count(options={})
        criteria = criteria_from(options[:conditions],options[:criteria]).merge!(where_func(options[:where]))
        begin
          collection.find(criteria).count()
        rescue => ex
          if ex.to_s =~ /Error with count command.*ns missing/
            # Return 0 because we will graciously assume that we are being
            # called from a subclass that has been initialized properly, and
            # is therefore mentioned in the schema.
            0
          else
            raise ex
          end
        end
      end

      def sum(column)
        x = all(:select => column)
        x.map {|p1| p1[column.to_sym]}.compact.inject(0) { |s,v| s += v }
      end

      # Deletes the record with the given id from the collection.
      def delete(id)
        collection.remove({:_id => id})
      end
      alias_method :remove, :delete

      # Load the object with +id+ and delete it.
      def destroy(id)
        id.is_a?(Array) ? id.each { |oid| destroy(oid) } : find(id).destroy
      end

      # This updates all records matching the specified criteria.  It leverages the
      # db.update call from the Mongo core API to guarantee atomicity.  You can
      # specify either a hash for simplicity, or full Mongo API operators to the
      # update part of the method call:
      #
      # Person.update_all({:name => 'Bob'}, {:name => 'Fred'})
      # Person.update_all({'$set' => {:name => 'Bob'}, '$inc' => {:age => 1}}, {:name => 'Fred'})
      def update_all(updates, conditions = nil, options = {})
        all(:conditions => conditions).each do |row|
          collection.update(criteria_from(conditions).merge(:_id => row.id.to_oid), update_fields_from(updates), options)
        end
      end

      # Destroy all objects that match +conditions+. Warning: if
      # +conditions+ is +nil+, all records in the collection will be
      # destroyed.
      def destroy_all(conditions = nil)
        all(:conditions => conditions).each { |object| object.destroy }
      end

      # Deletes all records that match +condition+, which can be a
      # Mongo-style hash or an ActiveRecord-like hash. Examples:
      #   Person.destroy_all "name like '%fred%'   # SQL WHERE clause
      #   Person.destroy_all ["name = ?", 'Fred']  # Rails condition
      #   Person.destroy_all {:name => 'Fred'}     # Mongo hash
      def delete_all(conditions=nil)
        collection.remove(criteria_from(conditions))
      end

      # Creates, saves, and returns a new database object.
      def create(values_hash)
        object = self.new(values_hash)
        object.save
        object
      end

      # Finds the record from the passed +id+, instantly saves it with the passed +attributes+ (if the validation permits it),
      # and returns it. If the save fails under validations, the unsaved object is still returned.
      #
      # The arguments may also be given as arrays in which case the update method is called for each pair of +id+ and
      # +attributes+ and an array of objects is returned.
      # =>
      # Example of updating one record:
      #   Person.update(15, {:user_name => 'Samuel', :group => 'expert'})
      #
      # Example of updating multiple records:
      #   people = { 1 => { "first_name" => "David" }, 2 => { "first_name" => "Jeremy"} }
      #   Person.update(people.keys, people.values)
      def update(id, attrib)
        if id.is_a?(Array)
          i = -1
          id.collect { |id| i += 1; update(id, attrib[i]) }
        else
          object = find(id)
          object.update_attributes(attrib)
          object
        end
      end

      # Handles find_* methods such as find_by_name, find_all_by_shoe_size,
      # and find_or_create_by_name.
      def method_missing(sym, *args)
        if match = /^find_(all_by|by)_([_a-zA-Z]\w*)$/.match(sym.to_s)
          find_how_many = ($1 == 'all_by') ? :all : :first
          field_names = $2.split(/_and_/)
          super unless all_fields_exist?(field_names)
          search = search_from_names_and_values(field_names, args)
          self.find(find_how_many, {:conditions => search}, *args[field_names.length..-1])
        elsif match = /^find_or_(initialize|create)_by_([_a-zA-Z]\w*)$/.match(sym.to_s)
          create = $1 == 'create'
          field_names = $2.split(/_and_/)
          super unless all_fields_exist?(field_names)
          search = search_from_names_and_values(field_names, args)
          row = self.find(:first, {:conditions => search})
          return self.new(row) if row # found
          obj = self.new(search.merge(args[field_names.length] || {})) # new object using search and remainder of args
          obj.save if create
          obj
        else
          super
        end
      end

      private

      def extract_options_from_args!(args)
        args.last.is_a?(Hash) ? args.pop : {}
      end

      # def find_initial(options)
      #   criteria = criteria_from(options[:conditions]).merge!(where_func(options[:where]))
      #   fields = fields_from(options[:select])
      #   row = collection.find_one(criteria, :fields => fields)
      #   (row.nil? || row['_id'] == nil) ? nil : self.new(row)
      # end

      def find_initial(options)
        options[:limit] = 1
        options[:order] = 'created_at asc'
        find_one(options)
      end

      def find_last(options)
        options[:limit] = 1
        options[:order] = 'created_at desc'
        find_one(options)
      end

      def find_one(options)
        one = nil
        cursor = find_every(options)
        one = cursor.detect {|c| c}
        cursor.close
        one.nil? ? nil : new(one)
      end

      def find_every(options)
        options.symbolize_keys!
        criteria = criteria_from(options[:conditions], options[:criteria]).merge!(where_func(options[:where]))

        find_options = {}
        find_options[:fields] = fields_from(options[:select]) if options[:select]
        find_options[:limit]  = options[:limit].to_i if options[:limit]
        find_options[:offset] = options[:offset].to_i if options[:offset]
        find_options[:hint]   = options[:hint] if options[:hint]
        find_options[:sort]   = sort_by_from(options[:order]) if options[:order]

        cursor = collection.find(criteria, find_options)

        # Override cursor.next_object so it returns a new instance of this class
        eval "def cursor.next_document; doc_hash=super(); doc_hash && #{self.name}.new(doc_hash); end"
        cursor
      end

      def find_from_ids(ids, options)
        ids = ids.to_a.flatten.compact.uniq
        raise RecordNotFound, "Couldn't find #{name} without an ID" unless ids.length > 0

        criteria = criteria_from(options[:conditions], options[:criteria]).merge!(where_func(options[:where]))
        criteria.merge!(options[:criteria]) unless options[:criteria].nil?
        criteria[:_id] = ids_clause(ids)
        fields = fields_from(options[:select])

        if ids.length == 1
          row = collection.find_one(criteria, :fields => fields)
          raise RecordNotFound, "Couldn't find #{name} with ID=#{ids[0]} #{criteria.inspect}" if row == nil || row.empty?
          self.new(row)
        else
          find_options = {}
          find_options[:fields] = fields if fields
          find_options[:sort] = sort_by_from(options[:order]) if options[:order]
          find_options[:limit] = options[:limit].to_i if options[:limit]
          find_options[:offset] = options[:offset].to_i if options[:offset]

          cursor = collection.find(criteria, find_options)

          # Override cursor.next_object so it returns a new instance of this class
          eval "def cursor.next_object; doc_hash=super(); doc_hash && #{self.name}.new(doc_hash); end"
          cursor
        end
      end

      def ids_clause(ids)
        #ids.length == 1 ? ids[0].to_oid : {'$in' => ids.collect{|id| id.to_oid}}

        if ids.length == 1
          ids[0].is_a?(String) ? ids[0].to_oid : ids[0]
        else
          {'$in' => ids.collect{|id| id.is_a?(String) ? id.to_oid : id}}
        end
      end

      # Returns true if all field_names are in @field_names.
      def all_fields_exist?(field_names)
        field_names.collect! {|f| f == 'id' ? '_id' : f}
        (field_names - @field_names.collect{|f| f.to_s}).empty?
      end

      # Returns a db search hash, given field_names and values.
      def search_from_names_and_values(field_names, values)
        h = {}
        field_names.each_with_index { |iv, i| h[iv.to_s] = values[i] }
        h
      end

      # Given a "SymbolOrStringLikeThis", return the string "symbol_or_string_like_this".
      def class_name_to_field_name(name)
        name.gsub(/([A-Z])/, '_\1').downcase.sub(/^_/, '')
      end

      # Given a "symbol_or_string_like_this", return the string "SymbolOrStringLikeThis".
      def field_name_to_class_name(name)
        name = name.to_s.dup.gsub(/_([a-z])/) {$1.upcase}
        name[0,1] = name[0,1].upcase
        name
      end

      protected

      # Turns array, string, or hash conditions into something useable by Mongo.
      #   ["name='%s' and group_id='%s'", "foo'bar", 4]  returns  {:name => 'foo''bar', :group_id => 4}
      #   "name='foo''bar' and group_id='4'" returns {:name => 'foo''bar', :group_id => 4}
      #   { :name => "foo'bar", :group_id => 4 }  returns the hash, modified for Mongo
      def criteria_from(condition, criteria={}) # :nodoc:
        case condition
        when Array
          opts = criteria_from_array(condition)
        when String
          opts = criteria_from_string(condition)
        when Hash
          opts = criteria_from_hash(condition)
        else
          opts = {}
        end
        opts ||= {}
        criteria ||= {}
        opts.merge!(criteria)
      end

      # Substitutes values at the end of an array into the string at its
      # start, sanitizing strings in the values. Then passes the string on
      # to criteria_from_string.
      def criteria_from_array(condition) # :nodoc:
        str, *values = condition
        sql = if values.first.kind_of?(Hash) and str =~ /:\w+/
                replace_named_bind_variables(str, values.first)
              elsif str.include?('?')
                replace_bind_variables(str, values)
              else
                str % values.collect {|value| quote(value) }
              end
        criteria_from_string(sql)
      end

      # Turns a string into a Mongo search condition hash.
      def criteria_from_string(sql) # :nodoc:
        MongoRecord::SQL::Parser.parse_where(sql)
      end

      # Turns a hash that ActiveRecord would expect into one for Mongo.
      def criteria_from_hash(condition) # :nodoc:
        h = {}
        condition.each { |k,v|
          h[k] = case v
                 when Array
                   {'$in' => v}
                 when Range
                   {'$gte' => v.first, '$lte' => v.last}
                 else
                   v
                 end
        }
        h
      end

      # Returns a hash useable by Mongo for applying +func+ on the db server.
      # +func+ must be +nil+ or a JavaScript expression or function in a
      # string.
      def where_func(func)    # :nodoc:
        func ? {'$where' => BSON::Code.new(func)} : {}
      end

      def replace_named_bind_variables(str, h) # :nodoc:
        str.gsub(/:(\w+)/) do
          match = $1.to_sym
          if h.include?(match)
            quoted_bind_var(h[match])
          else
            raise PreparedStatementInvalid, "missing value for :#{match} in #{str}" # TODO this gets swallowed in find()
          end
        end
      end

      def replace_bind_variables(str, values) # :nodoc:
        raise "parameter count does not match value count" unless str.count('?') == values.length
        bound = values.dup
        str.gsub('?') { quoted_bind_var(bound.shift) }
      end

      def quoted_bind_var(val) # :nodoc:
        case val
        when Array
          val.collect{|v| quote(v)}.join(',')
        else
          quote(val)
        end
      end

      # Returns value quoted if appropriate (if it's a string).
      def quote(val) # :nodoc:
        return val unless val.is_a?(String)
        return "'#{val.gsub(/\'/, "\\\\'")}'" # " <= for Emacs font-lock
      end

      def fields_from(a)
        return nil unless a
        a = [a] unless a.kind_of?(Array)
        a += ['_id']            # always return _id
        a.uniq.collect { |k| k.to_s }
      end

      def sort_by_from(option) # :nodoc:
        return nil unless option
        sort_by = []
        case option
        when Symbol           # Single value
          sort_by << [option.to_s, 1]
        when String
          fields = option.split(',')
          fields.each {|f|
            name, order = f.split
            order ||= 'asc'
            sort_by << [name.to_s, sort_value_from_arg(order)]
          }
        when Array            # Array of field names; assume ascending sort
          # TODO order these by building an array of hashes
          sort_by = option.collect {|o| [o.to_s, 1]}
        else                  # Hash (order of sorts is not guaranteed)
          sort_by = option.collect {|k, v| [k.to_s, sort_value_from_arg(v)]}
        end
        return nil unless sort_by.length > 0
        sort_by
      end

      # Turns "asc" into 1, "desc" into -1, and other values into 1 or -1.
      def sort_value_from_arg(arg) # :nodoc:
        case arg
        when /^asc/i
          arg = 1
        when /^desc/i
          arg = -1
        when Number
          arg.to_i >= 0 ? 1 : -1
        else
          arg ? 1 : -1
        end
      end

      # Turns {:key => 'Value'} in update_all into the appropriate '$set' operator
      def update_fields_from(arg)
        raise "Update spec for #{self.name}.update_all must be a hash" unless arg.is_a?(Hash)
        updates = {}
        arg.each do |key,val|
          case val
          when Hash
            # Assume something like $inc => {:num => 1}
            updates[key] = val
          when Array, Range
            raise "Array/range not supported in value of update spec"
          else
            # Assume a simple value, so change to $set
            updates['$set'] ||= {}
            updates['$set'][key] = val
          end
        end
        updates
      end

      # Overwrite the default class equality method to provide support for association proxies.
      def ===(object)
        object.is_a?(self)
      end

    end                       # End of class methods

    public

    # Initialize a new object with either a hash of values or a row returned
    # from the database.
    def initialize(row={})

      case row
      when Hash
        row.each { |k, val|
          k = '_id' if k == 'id' # Rails helper
          init_ivar("@#{k}", val)
        }
      else
        row.instance_variables.each { |iv|
          init_ivar(iv, row.instance_variable_get(iv))
        }
      end
      # Default values for remaining fields
      (self.class.field_names + self.class.subobjects.keys).each { |iv|
        iv = "@#{iv}"
        instance_variable_set(iv, nil) unless instance_variable_defined?(iv)
      }
      self.class.arrays.keys.each { |iv|
        iv = "@#{iv}"
        instance_variable_set(iv, []) unless instance_variable_defined?(iv)
      }

      # Create accessors for any per-row dynamic fields we got from our schemaless store
      self.instance_values.keys.each do |key|
        next if respond_to?(key.to_sym)  # exists
        define_instance_accessors(key)
      end
      
      yield self if block_given?
    end

    def attributes
      self.instance_values.inject({}){|h,iv| h[iv.first] = iv.last; h}
    end

    # Set the id of this object. Normally not called by user code.
    def id=(val); @_id = (val == '' ? nil : val); end

    # Return this object's id.
    def id; @_id ? @_id.to_s : nil; end

    # Return true if the +comparison_object+ is the same object, or is of
    # the same type and has the same id.
    def ==(comparison_object)
      comparison_object.equal?(self) ||
        (comparison_object.instance_of?(self.class) &&
         comparison_object.id == id &&
         !comparison_object.new_record?)
    end

    # Delegate to ==
    def eql?(comparison_object)
      self == (comparison_object)
    end

    # Delegate to id in order to allow two records of the same type and id to work with something like:
    #   [ Person.find(1), Person.find(2), Person.find(3) ] & [ Person.find(1), Person.find(4) ] # => [ Person.find(1) ]
    def hash
      id.hash
    end

    # Rails convenience method. Return this object's id as a string.
    def to_param
      @_id.to_s
    end

    # Save self and returns true if the save was successful, false if not.
    def save
      create_or_update
    end

    # Save self and returns true if the save was successful and raises
    # RecordNotSaved if not.
    def save!
      create_or_update || raise(RecordNotSaved)
    end

    # Return true if this object is new---that is, does not yet have an id.
    def new_record?
      @_id.nil? || self.class.collection.find_one("_id" => @_id).nil?
    end

    # Convert this object to a Mongo value suitable for saving to the
    # database.
    def to_mongo_value
      h = {}
      key_names = self.instance_values.keys
      key_names.each {|key|
        value = instance_variable_get("@#{key}").to_mongo_value
        if value.instance_of? Hash and value["_ns"]
          value = BSON::DBRef.new(value["_ns"], value["_id"])
        elsif value.instance_of? Array
          value = value.map {|v|
            if v.instance_of? Hash and v["_ns"]
              BSON::DBRef.new(v["_ns"], v["_id"])
            else
              v
            end
          }
        end
        h[key] = value
      }
      h
    end

    # Save self to the database and set the id.
    def create
      create_date = self.instance_variable_defined?("@created_at") ? self.created_at : nil
      set_create_times(create_date)
      @_ns = self.class.collection.name
      value = to_mongo_value
      @_id = self.class.collection.insert(value)
      value.merge(:_id => @_id)
    end

    # Save self to the database. Return +false+ if there was an error,
    # +self+ if all is well.
    def update
      set_update_times
      self.class.collection.update({:_id => @_id}, to_mongo_value)
      if self.class.collection.db.error?
        return false
      end
      self
    end

    # Remove self from the database and set @_id to nil. If self has no
    # @_id, does nothing.
    def delete
      if @_id
        self.class.collection.remove({:_id => self._id})
        @_id = nil
      end
    end
    alias_method :remove, :delete

    # Delete and freeze self.
    def destroy
      delete
      freeze
    end

    def [](attr_name)
      self.send(attr_name)
    end

    def []=(attr_name, value)
      define_instance_accessors(attr_name)
      self.send(attr_name.to_s + '=', value)
    end

    def method_missing(sym, *args)
      if self.instance_variables.include?("@#{sym}")
        define_instance_accessors(sym)
        return self.send(sym)
      else
        super
      end
    end

    #--
    # ================================================================
    # These methods exist so we can plug in ActiveRecord validation, etc.
    # ================================================================
    #++

    # Updates a single attribute and saves the record. This is especially
    # useful for boolean flags on existing records. Note: This method is
    # overwritten by the Validation module that'll make sure that updates
    # made with this method doesn't get subjected to validation checks.
    # Hence, attributes can be updated even if the full object isn't valid.
    def update_attribute(name, value)
      self[name] = value
      save
    end

    # Updates all the attributes from the passed-in Hash and saves the
    # record. If the object is invalid, the saving will fail and false will
    # be returned.
    def update_attributes(attributes)
      attributes.each do |name, value|
        update_attribute(name, value)
      end
    end

    # Updates an object just like Base.update_attributes but calls save!
    # instead of save so an exception is raised if the record is invalid.
    def update_attributes!(attributes)
      self.attributes = attributes
      save!
    end

    def valid?; true; end
    alias_method :respond_to_without_attributes?, :respond_to?
    
    # Does nothing.
    def attributes_from_column_definition; end

    # ================================================================

    def set_create_times(t=nil)
      t ||= Time.now
      t = Time.parse(t) if t.is_a?(String)
      self["created_at"] = t
      self["created_on"] = Time.local(t.year, t.month, t.day)
      self.class.subobjects.keys.each { |iv|
        val = instance_variable_get("@#{iv}")
        val.send(:set_create_times, t) if val
      }
    end

    #--
    # ================================================================
    # "Dirty" attribute tracking, adapted from ActiveRecord. This is
    # a big performance boost, plus it avoids issues if two people
    # are updating a record concurrently.
    # ================================================================
    #++


    private

    def create_or_update
      result = new_record? ? create : update
      result != false
    end

    # Initialize ivar. +name+ must include the leading '@'.
    def init_ivar(ivar_name, val)
      sym = ivar_name[1..-1].to_sym
      value = nil

      if self.class.subobjects.keys.include?(sym)
        if val.instance_of? BSON::DBRef
          val = self.class.collection.db.dereference(val)
        end
        value =  self.class.subobjects[sym].new(val)
        #instance_variable_set(ivar_name, self.class.subobjects[sym].new(val))

      elsif self.class.arrays.keys.include?(sym)
        klazz = self.class.arrays[sym]
        val = [val] unless val.kind_of?(Array)

        value = val.collect do |v|
          if v.instance_of? BSON::DBRef
            v = self.class.collection.db.dereference(v)
          end
          v.kind_of?(MongoRecord::Base) ? v : klazz.new(v)
        end
      else

        value =  val
      end

      if self.class.field_names.include?(sym)
        __send__(sym.to_s + '=', value)

      else
        instance_variable_set(ivar_name, value)
      end
    end

    def set_update_times(t=nil)
      t ||= Time.now
      self["updated_at"] = t
      self["updated_on"] = Time.local(t.year, t.month, t.day)
      self.class.subobjects.keys.each { |iv|
        val = instance_variable_get("@#{iv}")
        val.send(:set_update_times, t) if val
      }
    end

    # Per-object accessors, since row-to-row attributes can change
    # Use instance_eval so that they don't bleed over to other objects that lack the fields
    def define_instance_accessors(*fields)
      fields = Array(fields)
      fields.each do |field|
        ivar_name = "@" + field.to_s
        instance_eval <<-EndAccessors
          def #{field}
            instance_variable_get('#{ivar_name}')
          end
          def #{field}=(val)
            old = instance_variable_get('#{ivar_name}')
            instance_variable_set('#{ivar_name}', val)
            instance_variable_set('#{ivar_name}', val)
          end
          def #{field}?
            val = instance_variable_get('#{ivar_name}')
            val != nil && (!val.kind_of?(String) || val != '')
          end
        EndAccessors
      end
    end
  end

end
