# Delayed Job Redis Backend

Redis-based backend for DelayedJob queues. 

### Examples

    FIXME (code sample of usage)

### Notes

* The redis backend does not support fine-grained priority. Instead, it will pull jobs from 

### Install

* Add "gem 'delayed_job_redis'" to your Gemfile.
* Optional drivers for redis-rb will be detected and used if present (see: hiredis)

### Author

Matt Griffin (matt@griffinonline.org)
Viximo, Inc.

### Acknowledgements

Obviously, this implementation is highly influenced by Github's Resque project and portions may have
been copied wholesale.
hcvbn
