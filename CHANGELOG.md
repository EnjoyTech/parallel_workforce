## 1.1.0

* Add Json, Yajl serializer
* Make Yajl as default serializer
* Fixed https://github.com/EnjoyTech/parallel_workforce/issues/1
 
## 0.2.0

* Add optional execution block to `ParallelWorkforce.perform_all` that is evaluated in calling thread after jobs enqueued,
  but before blocking for job responses.
* Add `production_environment` configuration that disables unnecessary serialization/deserialization when executing in
  serial mode. Uses Rails.env if available, otherwise defaults to true.

## 0.1.0

* Initial release.
