# frozen_string_literal: true

module Esse
  module Sequel
    class Collection
      include Enumerable

      class << self
        # The model class or the dataset to be used as the scope
        # @return [Proc]
        attr_accessor :base_scope

        # The number of records to be returned in each batch
        # @return [Integer]
        attr_accessor :batch_size

        # Hash with the custom scopes defined on the collection
        # @return [Hash]
        attr_accessor :scopes

        # The hash with the contexts as key and the transformer proc as value
        # @return [Hash]
        attr_accessor :batch_contexts

        # The database server (shard) options for the collection query. Ex: `{ server: :read_only }`
        # @return [Hash, nil]
        attr_accessor :connect_with

        def inspect
          return super unless self < Esse::Sequel::Collection
          return super unless base_scope

          format("#<Esse::Sequel::Collection__%s>", model)
        end

        def model
          raise(NotImplementedError, "No model defined for #{self}") unless base_scope

          scope = base_scope.call
          scope.is_a?(::Sequel::Dataset) ? scope.model : scope
        end

        def inherited(subclass)
          super

          subclass.base_scope = base_scope
          subclass.batch_size = batch_size
          subclass.scopes = scopes.dup
          subclass.batch_contexts = batch_contexts.dup
          subclass.connect_with = connect_with&.dup
        end

        def scope(name, proc = nil, override: false, &block)
          proc = proc&.to_proc || block
          raise ArgumentError, "proc or block required" unless proc
          raise ArgumentError, "scope `#{name}' already defined" if !override && scopes.key?(name.to_sym)

          scopes[name.to_sym] = proc
        end

        def batch_context(name, proc = nil, override: false, &block)
          proc = proc&.to_proc || block
          raise ArgumentError, "proc or block required" unless proc
          raise ArgumentError, "batch_context `#{name}' already defined" if !override && batch_contexts.key?(name.to_sym)

          batch_contexts[name.to_sym] = proc
        end

        # Runs the collection queries on the given database server (shard)
        # @param [Symbol] server The server name as configured in the Sequel database :servers option
        def connected_to(server:)
          self.connect_with = {server: server}
        end
      end

      self.scopes = {}
      self.batch_contexts = {}

      attr_reader :start, :finish, :batch_size, :params

      # @param [Integer] start Specifies the primary key value to start from, inclusive of the value.
      # @param [Integer] finish  Specifies the primary key value to end at, inclusive of the value.
      # @param [Integer] batch_size The number of records to be returned in each batch. Defaults to 1000.
      # @param [Hash] params The query criteria
      # @return [Esse::Sequel::Collection]
      def initialize(start: nil, finish: nil, batch_size: nil, **params)
        @start = start
        @finish = finish
        @batch_size = batch_size || self.class.batch_size || 1000
        @params = params
      end

      def each
        with_connection do
          find_in_batches(dataset) do |rows|
            kwargs = params.dup
            self.class.batch_contexts.each do |name, proc|
              kwargs[name] = proc.call(rows, **params)
            end
            yield(rows, **kwargs)
          end
        end
      end

      def each_batch_ids
        with_connection do
          find_in_batches(dataset, ids_only: true) do |ids|
            yield(ids)
          end
        end
      end

      def count
        with_connection do
          dataset.unordered.unlimited.ungrouped.count
        end
      end
      alias_method :size, :count

      def dataset(**kwargs)
        query = self.class.base_scope&.call || raise(NotImplementedError, "No scope defined for #{self.class}")
        query = query.dataset unless query.is_a?(::Sequel::Dataset)
        query = query.unordered.unlimited
        query = query.server(server) if server
        params.merge(kwargs).each do |key, value|
          if self.class.scopes.key?(key)
            scope_proc = self.class.scopes[key]
            query = if scope_proc.arity == 0
              query.instance_exec(&scope_proc)
            else
              query.instance_exec(value, &scope_proc)
            end
          elsif query.model.columns.include?(key.to_sym)
            query = query.where(::Sequel[query.model.table_name][key.to_sym] => value)
          else
            raise ArgumentError, "Unknown scope `#{key}'"
          end
        end

        query
      end

      def inspect
        return super unless self.class < Esse::Sequel::Collection
        return super unless self.class.base_scope

        vars = instance_variables.map do |n|
          "#{n}=#{instance_variable_get(n).inspect}"
        end
        format("#<Esse::Sequel::Collection__%s:0x%x %s>", self.class.model, object_id, vars.join(", "))
      end

      protected

      def server
        self.class.connect_with&.fetch(:server, nil)
      end

      # Wraps the block with Database#with_server when the server_block extension is loaded,
      # so queries made by batch contexts also run on the configured server.
      def with_connection(&block)
        db = server && self.class.model.db
        if db.respond_to?(:with_server)
          db.with_server(server, &block)
        else
          yield
        end
      end

      # Keyset pagination over the primary key, inclusive of start and finish values.
      def find_in_batches(query, ids_only: false)
        pk = ::Sequel[query.model.table_name][query.model.primary_key]
        query = query.where(pk >= start) if start
        query = query.where(pk <= finish) if finish
        query = query.order(pk).limit(batch_size)

        last_id = nil
        loop do
          page = last_id.nil? ? query : query.where(pk > last_id)
          rows = ids_only ? page.select_map(pk) : page.all
          break if rows.empty?

          yield rows
          break if rows.size < batch_size

          last_id = ids_only ? rows.last : rows.last.pk
        end
      end
    end
  end
end
