#!/bin/bash

echo "Mixed indentation:"
grep -n -E '^	* 	' $(find .. -name "*.lua" -o -name "*.toc" -o -name "*.xml") && exit 1
echo "OK"

echo "Trailing whitespaces:"
grep -n -E '[ 	]+$' $(find .. -name "*.lua" -o -name "*.toc" -o -name "*.xml") && exit 1
echo "OK"
