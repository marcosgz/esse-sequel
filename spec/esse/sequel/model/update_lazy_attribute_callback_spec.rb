require "spec_helper"

RSpec.describe Esse::Sequel::Model, ".update_lazy_attribute_callback" do
  let(:model_class) do
    Class.new(State) do
      include Esse::Sequel::Model
    end
  end

  before do
    clear_sequel_hooks
    @__hooks_models = Esse::Sequel::Hooks.models.dup
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
    Esse::Sequel::Hooks.instance_variable_set(:@models, @__hooks_models) # rubocop:disable RSpec/InstanceVariable
    clean_db
  end

  it "register the callback with multiple events" do
    model_class.update_lazy_attribute_callback("states:state", :field, custom: "value") { :ok }
    expect(model_class.esse_callbacks).to a_hash_including(
      "states:state" => a_hash_including(
        create_update_lazy_attribute_field: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field, custom: "value"}, an_instance_of(Proc)),
        update_update_lazy_attribute_field: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field, custom: "value"}, an_instance_of(Proc)),
        destroy_update_lazy_attribute_field: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field, custom: "value"}, an_instance_of(Proc))
      )
    )
  end

  it "registers multiple callbacks to different attributes" do
    model_class.update_lazy_attribute_callback("states:state", :field1, custom: "value1") { :ok }
    model_class.update_lazy_attribute_callback("states:state", :field2, custom: "value2") { :ok }
    expect(model_class.esse_callbacks).to a_hash_including(
      "states:state" => a_hash_including(
        create_update_lazy_attribute_field1: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field1, custom: "value1"}, an_instance_of(Proc)),
        update_update_lazy_attribute_field1: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field1, custom: "value1"}, an_instance_of(Proc)),
        destroy_update_lazy_attribute_field1: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field1, custom: "value1"}, an_instance_of(Proc)),
        create_update_lazy_attribute_field2: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field2, custom: "value2"}, an_instance_of(Proc)),
        update_update_lazy_attribute_field2: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field2, custom: "value2"}, an_instance_of(Proc)),
        destroy_update_lazy_attribute_field2: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field2, custom: "value2"}, an_instance_of(Proc))
      )
    )
  end

  context "when on :create" do
    it "register the model class into Esse::Sequel::Hooks.models" do
      model_class.update_lazy_attribute_callback "states:state", :field, on: %i[create]
      expect(Esse::Sequel::Hooks.models).to include(model_class)
    end

    it "register the callback with block definition and custom options" do
      model_class.update_lazy_attribute_callback("states:state", :field, on: %i[create], custom: "value") { :ok }
      expect(model_class.esse_callbacks).to a_hash_including(
        "states:state" => a_hash_including(
          create_update_lazy_attribute_field: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field, custom: "value"}, an_instance_of(Proc))
        )
      )
    end
  end

  context "when on :update" do
    it "register the model class into Esse::Sequel::Hooks.models" do
      model_class.update_lazy_attribute_callback("states:state", :field, on: %i[update])
      expect(Esse::Sequel::Hooks.models).to include(model_class)
    end

    it "register the callback with block definition and custom options" do
      model_class.update_lazy_attribute_callback("states:state", :field, on: %i[update], custom: "value") { :ok }
      expect(model_class.esse_callbacks).to a_hash_including(
        "states:state" => a_hash_including(
          update_update_lazy_attribute_field: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field, custom: "value"}, an_instance_of(Proc))
        )
      )
    end
  end

  context "when on :destroy" do
    it "register the model class into Esse::Sequel::Hooks.models" do
      model_class.update_lazy_attribute_callback("states:state", :field, on: %i[destroy])
      expect(Esse::Sequel::Hooks.models).to include(model_class)
    end

    it "register the callback with block definition and custom options" do
      model_class.update_lazy_attribute_callback("states:state", :field, on: %i[destroy], custom: "value") { :ok }
      expect(model_class.esse_callbacks).to a_hash_including(
        "states:state" => a_hash_including(
          destroy_update_lazy_attribute_field: contain_exactly(Esse::Sequel::Callbacks::UpdateLazyAttribute, {attribute_name: :field, custom: "value"}, an_instance_of(Proc))
        )
      )
    end
  end
end
