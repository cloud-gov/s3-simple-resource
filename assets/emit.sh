#!/bin/sh

set -e

# give back a(n empty) version, so that the check passes when using `in`/`out`
echo '{
  "version": {}
}'
