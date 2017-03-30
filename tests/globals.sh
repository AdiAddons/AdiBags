#!/bin/bash

THERE="$(dirname $0)"

{
    failed=0
    for f in $(find "$THERE/.." -name "*.lua" | grep -v "/tests/"); do
        if ! $LUAC -l "$f" | $LUA "$THERE/globals.lua" "$f"; then
            failed=1
        fi
    done
    exit $failed
}
