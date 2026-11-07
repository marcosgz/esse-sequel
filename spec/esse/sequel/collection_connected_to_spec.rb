require "spec_helper"

RSpec.describe Esse::Sequel::Collection, ".connected_to" do
  let(:collection_class) do
    klass = Class.new(described_class)
    klass.base_scope = -> { State }
    klass.connected_to(server: :read_only)
    klass
  end

  after do
    State.dataset.delete
  end

  describe ".connected_to" do
    it "sets the connect_with" do
      expect(collection_class.connect_with).to eq(server: :read_only)
    end
  end

  describe "#dataset using custom server" do
    it "runs the dataset on the configured server" do
      expect(collection_class.new.dataset.opts[:server]).to eq(:read_only)
    end
  end

  describe "#each using custom server" do
    it "wraps the iteration with the database server block" do
      expect(DB).to receive(:with_server).with(:read_only).and_call_original
      il_state = State.create(name: "Illinois", abbr_name: "IL")

      instance = collection_class.new
      expect { |b| instance.each(&b) }.to yield_successive_args([il_state])
    end
  end

  describe "#each_batch_ids using custom server" do
    it "wraps the iteration with the database server block" do
      expect(DB).to receive(:with_server).with(:read_only).and_call_original
      il_state = State.create(name: "Illinois", abbr_name: "IL")

      instance = collection_class.new
      expect { |b| instance.each_batch_ids(&b) }.to yield_successive_args([il_state.id])
    end
  end

  describe "#count using custom server" do
    it "wraps the query with the database server block" do
      expect(DB).to receive(:with_server).with(:read_only).and_call_original
      State.create(name: "Illinois", abbr_name: "IL")

      instance = collection_class.new
      expect(instance.count).to eq(1)
    end
  end
end
