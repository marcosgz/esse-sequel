# frozen_string_literal: true

require "spec_helper"

RSpec.describe Esse::Sequel::Model, ".esse_index_repos" do
  specify do
    Gem::Deprecate.skip_during do
      model_class = Class.new(State) do
        include Esse::Sequel::Model

        index_callback "states_index"
      end
      expect(model_class.esse_index_repos.keys).to include("states_index")
    end
  end
end
