#!/bin/sh
# Checks that xara-varanny holds SIGTERM during an open link and not otherwise.
cd "$(dirname "$0")/.." || exit 1
export XARA="$PWD/tests/fake-xara" XARA_ARGS=""
fail=0

run_case() { # name, FAKE_LINK, min seconds, max seconds
	out=$(mktemp)
	FAKE_LINK=$2 ./xara-varanny /dev/null > "$out" 2>&1 &
	pid=$!
	sleep 1
	start=$(date +%s)
	kill -TERM $pid
	wait $pid
	took=$(($(date +%s) - start))
	if [ $took -ge "$3" ] && [ $took -le "$4" ] && grep -q "got TERM" "$out"; then
		echo "ok   $1 (${took}s)"
	else
		echo "FAIL $1 (${took}s)"; cat "$out"; fail=1
	fi
	rm -f "$out"
}

run_case "idle stops at once" 0 0 1
run_case "open link waits for DISCONNECTED" 1 2 4
export XARA_STOP_TIMEOUT=1
run_case "timeout caps the wait" 1 0 2
exit $fail
