# frozen_string_literal: true

require "spec_helper"

RSpec.describe Esse::Plugins::Sequel, ".collection" do # rubocop:disable RSpec/SpecFilePathFormat
  describe "index collection definition" do
    context "when the type is a model class" do
      it "define collection with only class name without raise an error" do
        expect {
          stub_esse_index(:animals) do
            plugin :sequel

            repository :animal do
              collection Animal
            end
          end
        }.not_to raise_error
        expect(AnimalsIndex.repo.instance_variable_get(:@collection_proc)).to be < Esse::Sequel::Collection
        expect(AnimalsIndex.repo.dataset).to be_a(::Sequel::Dataset)
      end

      it "define collection with name and class name without raise an error" do
        expect {
          stub_esse_index(:animals) do
            plugin :sequel

            repository :cat do
              collection Animal
            end
          end
        }.not_to raise_error
        expect(AnimalsIndex.repo(:cat).instance_variable_get(:@collection_proc)).to be < Esse::Sequel::Collection
        expect(AnimalsIndex.repo(:cat).dataset).to be_a(::Sequel::Dataset)
      end

      it "define collection with a model dataset" do
        expect {
          stub_esse_index(:animals) do
            plugin :sequel

            repository :animal do
              collection Animal.dataset
            end
          end
        }.not_to raise_error
        expect(AnimalsIndex.repo.instance_variable_get(:@collection_proc)).to be < Esse::Sequel::Collection
        expect(AnimalsIndex.repo.dataset).to be_a(::Sequel::Dataset)
      end

      it "define a collection with custom batch_size" do
        expect {
          stub_esse_index(:animals) do
            plugin :sequel

            repository :animal do
              collection(Animal, batch_size: 10)
            end
          end
        }.not_to raise_error
        expect(col = AnimalsIndex.repo.instance_variable_get(:@collection_proc)).to be < Esse::Sequel::Collection
        expect(col.batch_size).to eq(10)
      end

      it "define a collection with custom connect_with" do
        expect {
          stub_esse_index(:animals) do
            plugin :sequel

            repository :animal do
              collection(Animal, connect_with: {server: :read_only})
            end
          end
        }.not_to raise_error
        expect(col = AnimalsIndex.repo.instance_variable_get(:@collection_proc)).to be < Esse::Sequel::Collection
        expect(col.connect_with).to eq(server: :read_only)
      end

      it "evaluates the block in the Esse::Sequel::Collection" do
        expect {
          stub_esse_index(:animals) do
            plugin :sequel

            repository :animal do
              collection Animal do
                def self.foo
                  "bar"
                end
              end
            end
          end
        }.not_to raise_error
        expect(AnimalsIndex.repo.instance_variable_get(:@collection_proc).foo).to eq("bar")
      end
    end
  end
end
