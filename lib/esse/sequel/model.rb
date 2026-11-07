# frozen_string_literal: true

module Esse
  module Sequel
    module Model
      def self.included(base)
        base.extend(ClassMethods)
      end

      def after_create
        super
        esse_after_commit(:create)
      end

      def after_update
        super
        esse_after_commit(:update)
      end

      def after_destroy
        super
        esse_after_commit(:destroy)
      end

      private

      def esse_after_commit(event)
        hooks = self.class.esse_commit_hooks.fetch(event, [])
        return if hooks.empty?

        db.after_commit do
          hooks.each { |hook| instance_exec(&hook) }
        end
      end

      module ClassMethods
        extend Esse::Deprecations::Deprecate

        def esse_callbacks
          @esse_callbacks ||= {}.freeze
        end

        def esse_commit_hooks
          @esse_commit_hooks ||= {}.freeze
        end

        def esse_callback(index_repo_name, operation_name, on: %i[create update destroy], identifier_suffix: nil, **options, &block)
          @esse_callbacks = esse_callbacks.dup
          @esse_commit_hooks = esse_commit_hooks.dup
          cb_if = options.delete(:if)
          cb_unless = options.delete(:unless)
          if_enabled = -> {
            (cb_if.nil? || (cb_if.respond_to?(:call) ? instance_exec(&cb_if) : send(cb_if))) &&
              (cb_unless.nil? || (cb_unless.respond_to?(:call) ? !instance_exec(&cb_unless) : !send(cb_unless))) &&
              Esse::Sequel::Hooks.enabled?(index_repo_name) &&
              Esse::Sequel::Hooks.enabled_for_model?(self.class, index_repo_name)
          }

          Array(on).each do |event|
            identifier, klass = Esse::Sequel::Callbacks.fetch!(operation_name, event)
            if identifier_suffix
              identifier = :"#{identifier}_#{identifier_suffix}"
            end

            if @esse_callbacks.dig(index_repo_name, identifier)
              raise ArgumentError, format("index repository %<name>p already registered %<op>s operation", name: index_repo_name, op: operation_name)
            end

            @esse_callbacks[index_repo_name] = @esse_callbacks[index_repo_name]&.dup || {}
            @esse_callbacks[index_repo_name][identifier] = [klass, options, block]

            hook = -> {
              next unless instance_exec(&if_enabled)

              klass, options, block = self.class.esse_callbacks.fetch(index_repo_name).fetch(identifier)
              repo = Esse::Sequel::Hooks.resolve_index_repository(index_repo_name)
              block_result = instance_exec(&block) if block.respond_to?(:call)
              klass.new(**options, repo: repo, block_result: block_result).call(self)
            }
            @esse_commit_hooks[event] = [*@esse_commit_hooks[event], hook].freeze
          end

          Esse::Sequel::Hooks.register_model(self)
        ensure
          @esse_callbacks&.each_value { |v| v.freeze }&.freeze
          @esse_commit_hooks&.freeze
        end

        # Define callback for create/update/delete elasticsearch index document after model commit.
        #
        # @param [String] index_repo_name The path of index and repository name.
        #   For example a index with a single repository named `users` is `users`. And a index with
        #   multiple repositories named `animals` and `dog` as the repository name is `animals/dog`.
        #   For namespace, use `/` as the separator.
        # @raise [ArgumentError] when the repo and events are already registered
        # @raise [ArgumentError] when the specified index have multiple repos
        def index_callback(index_repo_name, on: %i[create update destroy], with: nil, **options, &block)
          if with
            Array(on).each do |event|
              if event == :update
                esse_callback(index_repo_name, :indexing, on: event, with: with, **options, &block)
              else
                esse_callback(index_repo_name, :indexing, on: event, **options, &block)
              end
            end
          else
            esse_callback(index_repo_name, :indexing, on: on, **options, &block)
          end
        end

        def update_lazy_attribute_callback(index_repo_name, attribute_name, on: %i[create update destroy], **options, &block)
          options[:attribute_name] = attribute_name
          esse_callback(index_repo_name, :update_lazy_attribute, identifier_suffix: attribute_name.to_sym, on: on, **options, &block)
        end

        # Disable indexing for the block execution on model level
        # Example:
        #  User.without_indexing { }
        #  User.without_indexing(UsersIndex, AccountsIndex::User) { }
        def without_indexing(*repos)
          Esse::Sequel::Hooks.without_indexing_for_model(self, *repos) do
            yield
          end
        end

        def index_callbacks(*args, **options, &block)
          index_callback(*args, **options, &block)
        end
        deprecate :index_callbacks, :index_callback, 2024, 12

        def esse_index_repos
          esse_callbacks
        end
        deprecate :esse_index_repos, :esse_callbacks, 2024, 12
      end
    end
  end
end
