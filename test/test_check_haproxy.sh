#!/bin/bash

NUM_TESTS=$(find test/haproxy/ -type f -name '*.csv' |wc -l|awk '{print $1}')
echo "1..$(($NUM_TESTS + 3))" # this sucks, you have to add test count manually
I=1
for f in test/haproxy/*.csv; do
    OUTPUT_FILE=$(mktemp)
    DIFF_FILE=$(mktemp)
    ./check_haproxy.rb -u "$f" > "$OUTPUT_FILE"
    if diff -u "$f.expected" "$OUTPUT_FILE" > "$DIFF_FILE" 2>&1; then
        echo "ok $I - $f"
    else
        echo "not ok $I - $f"
        cat "$DIFF_FILE"
    fi
    I=$(($I + 1))
done

do_test () {
    NAME=$1
    CMD=$2
    OUTPUT_FILE=$(mktemp)
    if eval "$CMD"; then
        TEST_RESULT="ok"
    else
        echo $?
        TEST_RESULT="not ok"
        cat "$OUTPUT_FILE"
    fi
    echo "$TEST_RESULT $I - $NAME"
    I=$(($I + 1))
}

do_test 'warn limit' \
    "./check_haproxy.rb -u test/haproxy/fedoraproject_org.csv -w 2 -p fedmsg-raw-zmq-outbound-backend |grep 'WARN.*too many sessions' > /dev/null"

do_test 'crit limit' \
        "./check_haproxy.rb -u test/haproxy/fedoraproject_org.csv -w 1 -c2 -p fedmsg-raw-zmq-outbound-backend |grep 'CRIT.*too many sessions' > /dev/null"

do_test 'live url' \
        "./check_haproxy.rb -u 'http://demo.1wt.eu/' >/dev/null"
