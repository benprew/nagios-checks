# check_haproxy.rb CHANGELOG

## v3.2.0
* Add cookie argument to check_haproxy. Fixes #15
* Fix bug with checking header variable
* Enable openssl as needed.  fixes #9
* add --http-error-critical
* parameters for SSL and insecure certificate
* fix redirect for ruby 1.8 and change return codes
* try first redirect which is mainly to https
* allow https with invalid certificate on Ruby 1.8+
* Adding some error management
* check_haproxy: collect perfdata from frontends, backends and servers.
## v3.1.0
* Ignore backends without checks
* Better plugin output; added thresholds for number of sessions
* Add a little bit more output by default, but disable the "UP" spam unless you specify --debug (option was previously unused).
* print all down proxies on a single line for nagios status
## v3.0.0
* Fix bug when incorrectly reporting status 'UP 1/3' as warning
* add debug flag, update usage and make script work with ruby 1.8+
* always display output and list down proxies first
* Use method not hash key access
* add license details
## v1.0.0
* Initial version
