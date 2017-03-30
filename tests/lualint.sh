#!/bin/bash
echo "Lua lint:"
$LUAC -p $(find .. -name "*.lua") || exit 1
echo "OK"
