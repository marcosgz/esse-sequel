# frozen_string_literal: true

module Esse
  module Sequel
    module Hooks
      STORE_STATE_KEY = :esse_sequel_hooks

      include Esse::Hooks[store_key: STORE_STATE_KEY]
    end
  end
end
