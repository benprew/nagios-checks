#!/bin/bash

set -e

echo -n "testing nothing smokes..."
for f in test/haproxy/*; do
    ./check_haproxy.rb -u "$f" |head -n1
done > /tmp/output.txt

cat <<EOF > /tmp/expected.txt
HAPROXY CRIT: www www DOWN active 	sess=0/20(0%) smax=14; git www DOWN active 	sess=0/2(0%) smax=2
HAPROXY OK: 58 proxies found
HAPROXY CRIT: osbs-backend osbs-master01 DOWN active 	sess=0/-1(0%) smax=0; osbs-backend BACKEND DOWN 	sess=0/500(0%) smax=0
HAPROXY OK: 13 proxies found
HAPROXY CRIT: ubuntuusers-tt srv10 DOWN active 	sess=0/512(0%) smax=0; ubuntuusers-tt BACKEND DOWN 	sess=0/820(0%) smax=1; ubuntuusers-static kanu DOWN active 	sess=0/512(0%) smax=0; ubuntuusers-media kanu DOWN active 	sess=0/512(0%) smax=0; ubuntuusers-tour kanu DOWN active 	sess=0/512(0%) smax=0; ubuntuusers-legacy kanu DOWN active 	sess=0/512(0%) smax=0
EOF

diff -u /tmp/output.txt /tmp/expected.txt
echo "OK"

echo -n "testing warn limit..."
./check_haproxy.rb -u "test/haproxy/fedoraproject_org.csv;" -w 2 -p fedmsg-raw-zmq-outbound-backend |grep 'WARN.*too many sessions' > /dev/null
echo "OK"

echo -n "testing crit limit..."
./check_haproxy.rb -u "test/haproxy/fedoraproject_org.csv;" -w 1 -c2 -p fedmsg-raw-zmq-outbound-backend |grep 'CRIT.*too many sessions' > /dev/null
echo "OK"

echo "SUCCESS! ALL TESTS PASSED"
