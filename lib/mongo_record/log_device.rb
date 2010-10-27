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

module MongoRecord

  # A destination for Ruby's built-in Logger class. It writes log messages
  # to a Mongo database collection. Each item in the collection consists of
  # two fields (besides the _id): +time+ and +msg+. +time+ is automatically
  # generated when +write+ is called.
  #
  # If we are running outside of the cloud, all log messages are echoed to
  # $stderr.
  #
  # The collection is capped, which means after the limit is reached old
  # records are deleted when new ones are inserted. See the new method and
  # the Mongo documentation for details.
  #
  # Example:
  #
  #   logger = Logger.new(MongoRecord::LogDevice('my_log_name'))
  #
  # The database connection defaults to the global $db. You can set the
  # connection using MongoRecord::LogDevice.connection= and read it with
  # MongoRecord::LogDevice.connection.
  #
  #   # Set the connection to something besides $db
  #   MongoRecord::LogDevice.connection = connect('my-database')
  class LogDevice

    DEFAULT_CAP_SIZE = (10 * 1024 * 1024)

    @@connection = nil

    class << self # Class methods

      # Return the database connection. The default value is
      # <code>$db</code>.
      def connection
        conn = @@connection || $db
        raise "connection not defined" unless conn
        conn
      end

      # Set the database connection. If the connection is set to +nil+, then
      # <code>$db</code> will be used.
      def connection=(val)
        @@connection = val
      end

    end

    # +name+ is the name of the Mongo database collection that will hold all
    # log messages. +options+ is a hash that may have the following entries:
    #
    # <code>:size</code> - Optional. The max size of the collection, in
    # bytes. If it is nil or negative then +DEFAULT_CAP_SIZE+ is used.
    #
    # <code>:max</code> - Optional. Specifies the maximum number of log
    # records, after which the oldest items are deleted as new ones are
    # inserted.
    #
    # <code>:stderr</code> - Optional. If not +nil+ then all log messages will
    # be copied to $stderr.
    #
    # Note: a non-nil :max requires a :size value. The collection will never
    # grow above :size. If you leave :size nil then it will be
    # +DEFAULT_CAP_SIZE+.
    #
    # Note: once a capped collection has been created, you can't redefine
    # the size or max falues for that collection. To do so, you must drop
    # and recreate (or let a LogDevice object recreate) the collection.
    def initialize(name, options = {})
      @collection_name = name
      options[:capped] = true
      options[:size] ||= DEFAULT_CAP_SIZE
      options[:size] = DEFAULT_CAP_SIZE if options[:size] <= 0

      # It's OK to call createCollection if the collection already exists.
      # Size and max won't change, though.
      #
      # Note we can't use the name "create_collection" because a DB JSObject
      # does not have normal keys and returns collection objects as the
      # value of all unknown names.
      self.class.connection.create_collection(@collection_name, options)

      @console = options[:stderr]
    end

    # Write a log message to the database. We save the message and a timestamp.
    def write(str)
      $stderr.puts str if @console
      self.class.connection.collection(@collection_name).insert({:time => Time.now, :msg => str})
    end

    # Close the log. This method is a sham. Nothing happens. You may
    # continue to use this LogDevice.
    def close
    end
  end
end
