# Esse Sequel Plugin

This gem is a [esse](https://github.com/marcosgz/esse) plugin for the Sequel ORM. It provides a set of methods to simplify implementation of Sequel models as datasource of esse indexes.

## Documentation

Full guides, usage examples, and API reference are published at **[gems.marcosz.com.br/esse-sequel](https://gems.marcosz.com.br/esse-sequel/)** — part of the [marcosgz Ruby gem catalogue](https://gems.marcosz.com.br).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'esse-sequel'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install esse-sequel

## Usage

Add the `:sequel` plugin and configure the `collection` with the Sequel model you want to use.

```ruby
class UsersIndex < Esse::Index
  plugin :sequel

  repository :user do
    collection ::User
    document # ...
  end
end
```

Using multiple repositories is also possible:

```ruby
class UsersIndex < Esse::Index
  plugin :sequel

  repository :account do
    collection ::Account
    document # ...
  end

  repository :admin do
    collection ::User.where(admin: true)
    document # ...
  end
end
```

### Collection Scope
It's also possible to specify custom scopes to the repository collection to be used to import data to the index:

```ruby
class UsersIndex < Esse::Index
  plugin :sequel

  repository :user do
    collection ::User do
      scope :active, -> { where(active: true) }
      scope :role, ->(role) { where(role: role) }
    end
    document # ...
  end
end

# Import data using the scopes
#   > UsersIndex.import(context: { active: true, role: 'admin' })
#
# Streaming data using the scopes
#   > UsersIndex.documents(active: true, role: 'admin').first
```

## Collection Batch Context

Assume that you have a collection of orders and you want to also include the customer data that lives in a external system. To avoid making a request for each order, you can use the `batch_context` to fetch the data in batches and make it available in the document context.

```ruby
class OrdersIndex < Esse::Index
  plugin :sequel

  repository :order do
    collection ::Order do
      batch_context :customers do |orders, **_existing_context|
        # The return value will be available in the document context
        # { customers: <value returned from this block> }
        ExternalSystem::Customer.find_all_by_ids(orders.map(&:customer_id)).index_by(&:id) # => { 1 => <Customer>, 2 => <Customer> }
      end
    end
    document do |order, customers: {}, **_|
      customer = customers[order.customer_id]
      {
        id: order.id,
        customer: {
          id: customer&.id,
          name: customer&.name
        }
      }
    end
  end
end
```

For Sequel associations, you can define the repository collection by eager loading the associations as usual:

```ruby

class OrdersIndex < Esse::Index
  plugin :sequel

  repository :order do
    collection ::Order.eager(:customer)
    document do |order, **_|
      {
        id: order.id,
        customer: {
          id: order.customer&.id,
          name: order.customer&.name
        }
      }
    end
  end
end
```

### Data Streaming Options

By default the collection supports 3 streaming options:
* `batch_size`: the number of documents to be streamed in each batch. Default is 1000;
* `start`: the primary key value to start from, inclusive of the value;
* `finish`: the primary key value to end at, inclusive of the value;

This is useful when you want to import simultaneous data. You can make one process import all records between 1 and 10,000, and another from 10,000 and beyond

```ruby
UsersIndex.import(context: { start: 1, finish: 10000, batch_size: 500 })
```

The default value of `batch_size` can be also defined in the `collection` configuration:

```ruby
class UsersIndex < Esse::Index
  plugin :sequel

  repository :user do
    collection ::User, batch_size: 500
    document # ...
  end
end
```

### Database Server (Sharding)

If the Sequel database is configured with multiple servers, the collection queries can be routed to one of them using the `connect_with` option or the `connected_to` method:

```ruby
DB = Sequel.connect(ENV["DATABASE_URL"], servers: { read_only: { host: "replica" } })

class UsersIndex < Esse::Index
  plugin :sequel

  repository :user do
    collection ::User, connect_with: { server: :read_only }
    # or
    collection ::User do
      connected_to server: :read_only
    end
    document # ...
  end
end
```

The collection dataset runs on the given server. When the [server_block](https://sequel.jeremyevans.net/rdoc-plugins/files/lib/sequel/extensions/server_block_rb.html) extension is loaded (`DB.extension :server_block`), the whole batch iteration, including `batch_context` queries, runs inside `DB.with_server`.

### Indexing Callbacks

The `index_callback` callback can be used to automatically index or delete documents after commit on create/update/destroy events. Include the `Esse::Sequel::Model` module in the model to enable it.

```ruby
class UsersIndex < Esse::Index
  plugin :sequel

  repository :user, const: true do
    collection ::User
    document # ...
  end
end

class User < Sequel::Model
  include Esse::Sequel::Model
  many_to_one :organization

  # Using a index and repository as argument. Note that the index name is used instead of the
  # of the constant name. it's so because index and model depends on each other should result in
  # circular dependencies issues.
  index_callback 'users_index:user'
  # Using a block to direct a different object to be indexed
  index_callback('organizations') { organization } # The `_index` suffix and repo name is optional on the index name
end
```

Callbacks run in the `after_create`, `after_update` and `after_destroy` model hooks and are deferred with `DB.after_commit`, so documents are only indexed after the transaction commits, and are not indexed at all when it is rolled back. Models that override these hooks must call `super`.

When a document uses a routing key, the update callback also deletes the document from its previous routing when the routing value changes. This requires the previous column values, so load the [dirty](https://sequel.jeremyevans.net/rdoc-plugins/classes/Sequel/Plugins/Dirty.html) plugin in those models:

```ruby
class City < Sequel::Model
  plugin :dirty
  include Esse::Sequel::Model

  index_callback 'geos_index:city'
end
```

Callbacks can also be disabled/enabled globally:

```ruby
Esse::Sequel::Hooks.disable!
Esse::Sequel::Hooks.enable!
Esse::Sequel::Hooks.without_indexing do
  10.times { User.create! }
end
```

or by some specific list of index or index's repository

```ruby
Esse::Sequel::Hooks.disable!(UsersIndex.repo)
Esse::Sequel::Hooks.enable!(UsersIndex.repo)
Esse::Sequel::Hooks.without_indexing(AccountsIndex, UsersIndex.repo) do
  10.times { User.create! }
end
```

or by the model that the callback is configured

```ruby
User.without_indexing do
  10.times { User.create! }
end
User.without_indexing(AccountsIndex) do
  10.times { User.create! }
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/marcosgz/esse-sequel.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
