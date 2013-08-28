nagios-checks
=============

Various Nagios check scripts.

check_haproxy
-------------

Checks haproxy stats and reports errors if any of the servers for a proxy are down.

    Usage: check_haproxy.rb [options]
    
    Specific options:
        -u, --url URL                    Statistics URL to check (e.g. http://demo.1wt.eu/)
        -p, --proxies [PROXIES]          Only check these proxies (eg proxy1,proxy2,proxylive)
        -U, --user [USER]                Basic auth user to login as
        -P, --password [PASSWORD]        Basic auth password
        -w, --warning [WARNING]          Threshold for number of sessions as a percentage of the limit
        -c, --critical [CRITICAL]        Threshold for number of sessions as a percentage of the limit

Example: check_haproxy.rb -u "http://demo.1wt.eu/;csv" -w 80 -c 95

License
-------

GPL https://www.gnu.org/licenses/gpl.html
