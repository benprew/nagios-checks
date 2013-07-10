nagios-checks
=============

Various Nagios check scripts

check_haproxy.rb checks haproxy stats and reports errors if any of the servers for a proxy are down

Usage: check_haproxy.rb [options]

Specific options:
    -u, --url URL                    URL to check
    -p, --proxies [PROXIES]          Only check these proxies (eg proxy1,proxy2,proxylive)
    -U, --user [USER]                basic auth USER to login as
    -P, --password [PASSWORD]        basic auth PASSWORD
