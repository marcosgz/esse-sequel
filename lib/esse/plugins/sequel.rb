# frozen_string_literal: true

require "sequel"

module Esse
  module Plugins
    module Sequel
      module RepositoryClassMethods
        # @param [Class, Sequel::Dataset] model_class The Sequel model class or model dataset
        # @param [Hash] options The options
        # @option options [Integer] :batch_size The batch size for the collection
        # @option options [Hash] :connect_with The database server to run the collection queries on. Ex: `{ server: :read_only }`
        def collection(*args, &block)
          unless model_or_dataset?(args.first)
            return super
          end
          kwargs = args.last.is_a?(Hash) ? args.pop.dup : {}
          model_class = args.shift

          repo = Class.new(Esse::Sequel::Collection)
          repo.base_scope = -> { model_class }
          repo.batch_size = kwargs.delete(:batch_size) if kwargs.key?(:batch_size)
          repo.connect_with = kwargs.delete(:connect_with) if kwargs.key?(:connect_with)
          repo.class_eval(&block) if block

          super(repo, *args, **kwargs)
        end
        # Sequel models and datasets respond to #to_hash, so a **kwargs signature would make
        # Ruby 2.7 implicitly convert the model argument into keyword arguments.
        ruby2_keywords(:collection) if respond_to?(:ruby2_keywords, true)

        def dataset(**params)
          if @collection_proc.nil?
            raise NotImplementedError, "Can't call `dataset' on a repository without a collection defined"
          elsif @collection_proc.is_a?(Class) && @collection_proc < Esse::Sequel::Collection
            @collection_proc.new(**params).dataset
          elsif defined? super
            super
          else
            raise NoMethodError, "undefined method `dataset' for #{self}"
          end
        end

        private

        def model_or_dataset?(klass)
          return true if klass.is_a?(Class) && klass < ::Sequel::Model
          return true if klass.is_a?(::Sequel::Dataset) && klass.respond_to?(:model)

          false
        end
      end
    end
  end
end
