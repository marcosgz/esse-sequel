# frozen_string_literal: true

require "spec_helper"

RSpec.describe Esse::Sequel::Model, ".index_callbacks" do
  specify do
    Gem::Deprecate.skip_during do
      model_class = Class.new(State) do
        include Esse::Sequel::Model
        index_callbacks "states_index", on: %i[create]
      end
      expect(Esse::Sequel::Hooks.models).to include(model_class)
    end
  end
end
