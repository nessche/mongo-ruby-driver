# Copyright (C) 2009-2014 MongoDB, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mongo
  class Collection
    class View

      # Provides behaviour around an aggregation pipeline on a collection view.
      #
      # @since 2.0.0
      class Aggregation
        extend Forwardable
        include Enumerable
        include Immutable
        include Explainable

        # @return [ View ] view The collection view.
        attr_reader :view
        # @return [ Array<Hash> ] pipeline The aggregation pipeline.
        attr_reader :pipeline

        # Delegate necessary operations to the view.
        def_delegators :view, :collection, :read, :cluster

        # Delegate necessary operations to the collection.
        def_delegators :collection, :database

        # Set to true if disk usage is allowed during the aggregation.
        #
        # @example Set disk usage flag.
        #   aggregation.allow_disk_use(true)
        #
        # @param [ true, false ] value The flag value.
        #
        # @return [ true, false, Aggregation ] The aggregation if a value was
        #   set or the value if used as a getter.
        #
        # @since 2.0.0
        def allow_disk_use(value = nil)
          configure(:allowDiskUse, value)
        end

        # Iterator over the results of the aggregation.
        #
        # @example Iterate over the results.
        #   aggregation.each do |doc|
        #     p doc
        #   end
        #
        # @yieldparam [ BSON::Document ] Each returned document.
        #
        # @return [ Enumerator ] The enumerator.
        #
        # @since 2.0.0
        def each
          server = read.select_servers(cluster.servers).first
          cursor = Cursor.new(view, send_initial_query(server), server).to_enum
          if block_given?
            cursor.each{ |document| yield document }
          end
          cursor
        end

        # Initialize the aggregation for the provided collection view, pipeline
        # and options.
        #
        # @param [ Collection::View ] view The collection view.
        # @param [ Array<Hash> ] pipeline The pipeline of operations.
        # @param [ Hash ] options The aggregation options.
        #
        # @since 2.0.0
        def initialize(view, pipeline, options = {})
          @view = view
          @pipeline = pipeline.dup
          @options = options.dup
        end

        private

        def aggregate_spec
          { :selector => {
              :aggregate => collection.name,
              :pipeline => pipeline,
              :cursor => view.batch_size ? { :batchSize => view.batch_size } : {}
            }.merge!(options),
            :db_name => database.name,
            :options => view.options }
        end

        def explain_options
          { :explain => true }
        end

        def new(options)
          Aggregation.new(view, pipeline, options)
        end

        def initial_query_op
          Operation::Aggregate.new(aggregate_spec)
        end

        def send_initial_query(server)
          initial_query_op.execute(server.context)
        end
      end
    end
  end
end
