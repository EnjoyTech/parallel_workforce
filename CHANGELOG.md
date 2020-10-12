## 2.0.0

* Ruby version tested is 2.6.6.

## 1.0.0

* RubyGems version 1.

## 0.2.0

* Add optional execution block to `ParallelWorkforce.perform_all` that is evaluated in calling thread after jobs enqueued,
  but before blocking for job responses.
* Add `production_environment` configuration that disables unnecessary serialization/deserialization when executing in
  serial mode. Uses Rails.env if available, otherwise defaults to true.

## 0.1.0

* Initial release.
