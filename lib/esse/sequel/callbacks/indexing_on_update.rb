# frozen_string_literal: true

module Esse::Sequel
  module Callbacks
    class IndexingOnUpdate < Callback
      def call(model)
        record = block_result || model

        document = repo.serialize(record)
        return true unless document

        update_document(document)
        return true unless document.routing

        prev_document = previous_document(model)

        return true unless prev_document
        return true if [prev_document.id, prev_document.routing].include?(nil)
        return true if prev_document.routing == document.routing
        return true if prev_document.id != document.id

        begin
          repo.index.delete(prev_document, **options)
        rescue Esse::Transport::NotFoundError
        end

        true
      end

      protected

      def update_document(document)
        return if document.ignore_on_index?

        if @with == :update || (@with.nil? && repo.lazy_document_attributes.any?)
          begin
            repo.index.update(document, **options)
          rescue Esse::Transport::NotFoundError
            repo.index.index(document, **options)
          end
        else
          repo.index.index(document, **options)
        end
      end

      # Previous column values are only known when the model uses the Sequel dirty plugin
      def previous_document(model)
        return unless model.respond_to?(:previous_changes)

        changes = model.previous_changes
        return if changes.nil? || changes.empty?

        prev_values = model.values.merge(changes.transform_values(&:first))
        repo.serialize(model.class.call(prev_values).freeze)
      end
    end

    register_callback(:indexing, :update, IndexingOnUpdate)
  end
end
