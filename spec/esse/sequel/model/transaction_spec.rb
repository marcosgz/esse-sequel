# frozen_string_literal: true

require "spec_helper"

RSpec.describe Esse::Sequel::Model, ".index_callback within transactions" do # rubocop:disable RSpec/SpecFilePathFormat
  let(:index_ok_response) { {"result" => "indexed"} }
  let(:model_class) do
    Class.new(State) do
      include Esse::Sequel::Model
      index_callback "states_index", on: %i[create]
    end
  end

  before do
    clear_sequel_hooks
    @models_value_backup = Esse::Sequel::Hooks.models.dup
    Esse::Sequel::Hooks.models.clear
    stub_cluster_info

    stub_esse_index(:states) do
      repository :state, const: true do
        document do |state, **|
          {
            _id: state.id,
            name: state.name
          }
        end
      end
    end
  end

  after do
    Esse::Sequel::Hooks.instance_variable_set(:@models, @models_value_backup) # rubocop:disable RSpec/InstanceVariable
    clean_db
  end

  it "indexes the document only after the outer transaction commits" do
    indexed_within_transaction = nil
    allow(StatesIndex).to receive(:index) do
      indexed_within_transaction = DB.in_transaction?
      index_ok_response
    end

    DB.transaction do
      create_record(model_class, name: "Illinois")
      expect(indexed_within_transaction).to be_nil
    end
    expect(indexed_within_transaction).to be(false)
  end

  it "does not index the document when the transaction is rolled back" do
    expect(StatesIndex).not_to receive(:index)

    DB.transaction(rollback: :always) do
      create_record(model_class, name: "Illinois")
    end
  end
end
