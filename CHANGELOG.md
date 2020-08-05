## 1.0.1
* Allow `allow_partial_result` in configuration and while calling any of `ParallelWorkforce.perform_all`;By default false but can make true if partial result needed

## 0.2.0

* Add optional execution block to `ParallelWorkforce.perform_all` that is evaluated in calling thread after jobs enqueued,
  but before blocking for job responses.
* Add `production_environment` configuration that disables unnecessary serialization/deserialization when executing in
  serial mode. Uses Rails.env if available, otherwise defaults to true.

## 0.1.0

* Initial release.
