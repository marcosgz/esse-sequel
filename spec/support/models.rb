# frozen_string_literal: true

db_path = "/tmp/esse-sequel.db"
File.delete(db_path) if File.exist?(db_path)

DB = Sequel.sqlite(db_path, servers: {read_only: {}})
DB.extension :server_block
DB.loggers << Logger.new($stdout) if ENV["VERBOSE"]

DB.create_table(:animals) do
  primary_key :id
  String :name
  Integer :age
  String :type
end

DB.create_table(:states) do
  primary_key :id
  String :name
  String :abbr_name
  String :iso_country
end

DB.create_table(:counties) do
  primary_key :id
  String :name
  String :iso_country
  Integer :state_id
end

class Animal < Sequel::Model
  plugin :single_table_inheritance, :type
end

class Dog < Animal
end

class Cat < Animal
end

class State < Sequel::Model
  plugin :dirty
  one_to_many :counties
end

class County < Sequel::Model
  plugin :dirty
  many_to_one :state
end

def create_record(klass, **attrs)
  @tables ||= []
  @tables |= [klass.table_name]
  klass.create(attrs)
end

def build_record(klass, **attrs)
  @tables ||= []
  @tables |= [klass.table_name]
  klass.new(attrs)
end

def clean_db
  (@tables || []).each do |table|
    DB[table].delete
  end
end
