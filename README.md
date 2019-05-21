# ParallelWorkforce

Easily parallelize functionality by partitioning work in either a Sidekiq (preferred) or ActiveJob worker pool.

See more info at the EnjoyTech blog.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'parallel_workforce'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install parallel_workforce

## Usage

Parallel execution requires two things:

* Creating one or more actor classes that has a keyword arguments `initializer` and a no-args `perform` method.
* Invoking `ParallelWorkforce.perform_all` with an array of `actor_classes` and an equally sized array for `actor_args_array`
  with initializer arguments for the actor classes.

  Optional arguments for `execute_serially` and `job_class` can be used with `perform_all` to override configuration settings.

  An optional `serial_execution_indexes` can also be used to execute specific indexes serially. This is useful to easily
  perform "fast" actors in the current thread and only sending "slow" actors to be executed in workers. The specified serial
  actors are performed after enqueuing the remaining actors and waiting for them to complete.

  Additionally, a block can be passed to `perform_all` that allows arbitrary
  execution in the current thread after the jobs have been enqueued and before checking for job responses.

## Example

Create cryptographic hashes of passwords in parallel in workers using BCrypt. Then verify the generated hashes against the passwords.

### Create a class that performs the work.

```ruby
require 'bcrypt'

class PasswordHashGenerator
  attr_reader :password

  def initialize(password:)
    @password = password
  end

  def perform
    BCrypt::Password.create(password, cost: 15).to_s
  end
end
```

### Invoke the workers and verify the results.

```ruby
require 'bcrypt'

passwords = ['password 1', 'password 2', 'password 3']

password_hashes = ParallelWorkforce.perform_all(
  actor_classes: Array.new(passwords.size) { PasswordHashGenerator },
  actor_args_array: passwords.map { |password| { password: password } },
)

# check that password hashes match
passwords.zip(password_hashes).each do |password, password_hash|
  raise "Password does not match hash" if BCrypt::Password.new(password_hash) != password
end
```

## Configuration

Execute `ParallelWorkforce.configure` before executing `ParallelWorkforce.perform_all` to configure. In a Rails application, add a file `parallel_workforce_config.rb` in your `config/initializers` directory.

```ruby
ParallelWorkforce.configure do |configuration|
  configuration.job_class = MyJobClass
  # etc
end
```

* `job_class` - The class to use to respond to enqueued jobs. See classes under the `ParallelWorkforce::Job` namespace. Defaults to `ParallelWorkforce::Job::ActiveJob`.
* `logger` - Defaults to `Rails.logger` if `Rails` is loaded.
* `revision_builder` - Used to determine if the calling thread and worker have a different revision of code. Defaults to a class that builds a hash from the contents of all `.rb` files contained within the current working directory.
* `serial_mode_checker` - An object with an `execute_serially?` method that allows forcing Actors to execute in calling thread instead of in workers. This can be used to turn off parallel execution globally. Default is `nil`.
* `serializer` - An object with a `serialize(object)` method that returns a `String` and `deserialize(string)` method that returns an `Object`. Default imlementation uses `Marshal.dump` and `Marshal.load`.
* `redis_connector` - An object with a `with` method that yields a Redis connection. Defaults to `ParallelWorkforce::RedisConnector::RedisPool`. If using Sidekiq, it's best to use `ParallelWorkforce::RedisConnector::SidekiqRedisPool`.
* `job_timeout` - Time allowed to execte a job before timing out. Default is `10` seconds.
* `job_key_expiration` - Time allowed for result key in Redis to remain before it expires. This should be larger than `job_timeout`. Default is `20` seconds.
* `production_environment` - Removes serialization/deserialization when executing serially that helps locate problems with objects that fail to serialize. When `Rails` is loaded, uses `Rails.env.production?`, otherwise `true`.
* `allow_nested_parallelization` - By default, executing `ParallelWorkforce.perform_all` within a ParallelWorkforce `Actor` will execute serially. This can be enabled to allow nesting worker invocations, but ensure that the worker pool is large enough to handle blocked workers waiting for a response. Too small of a pool will lead to timeouts as no workers will be available.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/EnjoyTech/parallel_workforce.
