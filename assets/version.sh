#!/bin/sh

# Prints the current version of the bucket/prefix as a compact, single-key
# JSON object, e.g.:
#
#   {"LastModified":"2026-09-11T18:22:04+00:00"}
#
# Prints nothing (exit 0) when no objects exist under the prefix.
#
# Concourse requires every version emitted by check/in/out to be a non-empty
# map of string keys to string values, and requires the same key across all
# three scripts so that version history and `passed:` constraints work.
# See atc/db/resource_config_scope.go:saveResourceVersion.

set -e

bucket=$1
prefix=$2

if [ -z "$bucket" ]; then
  echo "usage: $0 <bucket> [prefix]" >&2
  exit 1
fi

# Consider the most recent LastModified timestamp the current version.
aws s3api list-objects \
  --bucket "$bucket" \
  --prefix "$prefix" \
  --query 'Contents[].{LastModified: LastModified}' \
  | jq -c 'if . == null or length == 0 then empty else max_by(.LastModified) end'
