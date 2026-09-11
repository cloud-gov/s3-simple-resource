#!/bin/sh

# Offline unit tests for the resource scripts.
#
# These run without AWS credentials or network access: a stub `aws` on PATH
# returns canned `s3api list-objects` output and no-ops `s3 sync`.
#
# The point of these tests is the Concourse version contract (see
# atc/db/resource_config_scope.go): every version emitted by check/in/out must
# be a non-empty JSON object whose values are strings, and check/in/out must all
# use the same key.
#
# usage: test/unit.sh

set -e

assets="$(cd "$(dirname "$0")/../assets" && pwd)"
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

failures=0
total=0

# ---------------------------------------------------------------- aws stub ---

mkdir -p "$workdir/bin"
cat > "$workdir/bin/aws" <<'STUB'
#!/bin/sh
# Stub aws CLI. `s3api list-objects` echoes $STUB_LIST_OBJECTS; everything
# else (s3 sync) is a logged no-op.
if [ "$1" = "s3api" ] && [ "$2" = "list-objects" ]; then
  printf '%s\n' "$STUB_LIST_OBJECTS"
  exit 0
fi
echo "stub aws: $*" >&2
exit 0
STUB
chmod +x "$workdir/bin/aws"
PATH="$workdir/bin:$PATH"
export PATH

# ------------------------------------------------------------------ helpers ---

fail() {
  echo "  FAIL: $1"
  failures=$((failures + 1))
}

# Asserts that $1 is a valid Concourse version object: a JSON object with at
# least one key, all values strings.
assert_valid_version() {
  version=$1
  label=$2

  if ! echo "$version" | jq -e . >/dev/null 2>&1; then
    fail "$label: not valid JSON: $version"
    return
  fi
  if [ "$(echo "$version" | jq -r 'type')" != "object" ]; then
    fail "$label: version is not an object: $version"
    return
  fi
  if [ "$(echo "$version" | jq -r 'length')" -lt 1 ]; then
    fail "$label: version is empty; Concourse requires >= 1 key-value pair"
    return
  fi
  if [ "$(echo "$version" | jq -r '[.[] | type] | unique | join(",")')" != "string" ]; then
    fail "$label: version values must all be strings: $version"
    return
  fi
}

assert_equals() {
  if [ "$1" != "$2" ]; then
    fail "$3: expected [$2], got [$1]"
  fi
}

start_test() {
  total=$((total + 1))
  echo "- $1"
}

two_objects='[{"LastModified": "2026-09-01T10:00:00+00:00"}, {"LastModified": "2026-09-10T12:34:56+00:00"}]'
newest='2026-09-10T12:34:56+00:00'

payload='{"source": {"bucket": "test-bucket", "path": "some/prefix"}}'

# -------------------------------------------------------------------- check ---

start_test "check emits the newest LastModified as a valid version"
STUB_LIST_OBJECTS="$two_objects" export STUB_LIST_OBJECTS
out="$(echo "$payload" | "$assets/check")"
assert_equals "$(echo "$out" | jq -r 'type')" "array" "check output type"
assert_equals "$(echo "$out" | jq -r 'length')" "1" "check output length"
assert_valid_version "$(echo "$out" | jq -c '.[0]')" "check"
assert_equals "$(echo "$out" | jq -r '.[0].LastModified')" "$newest" "check picks newest"

start_test "check emits an empty list when the prefix holds no objects"
STUB_LIST_OBJECTS="null" export STUB_LIST_OBJECTS
out="$(echo "$payload" | "$assets/check")"
assert_equals "$(echo "$out" | jq -c .)" "[]" "check on empty prefix"

start_test "check emits an empty list when list-objects returns []"
STUB_LIST_OBJECTS="[]" export STUB_LIST_OBJECTS
out="$(echo "$payload" | "$assets/check")"
assert_equals "$(echo "$out" | jq -c .)" "[]" "check on empty result set"

# ----------------------------------------------------------------------- in ---

start_test "in echoes back the requested version"
STUB_LIST_OBJECTS="$two_objects" export STUB_LIST_OBJECTS
requested='{"LastModified": "2026-09-01T10:00:00+00:00"}'
in_payload="$(jq -nc --argjson v "$requested" \
  '{source: {bucket: "test-bucket", path: "some/prefix"}, version: $v}')"
out="$(echo "$in_payload" | "$assets/in" "$workdir/dest" 2>/dev/null)"
assert_valid_version "$(echo "$out" | jq -c '.version')" "in"
assert_equals "$(echo "$out" | jq -r '.version.LastModified')" \
  "2026-09-01T10:00:00+00:00" "in echoes requested version"

start_test "in falls back to the current version when none is requested"
out="$(echo "$payload" | "$assets/in" "$workdir/dest" 2>/dev/null)"
assert_valid_version "$(echo "$out" | jq -c '.version')" "in (no version)"
assert_equals "$(echo "$out" | jq -r '.version.LastModified')" "$newest" \
  "in falls back to newest"

start_test "in emits a synthetic version when the prefix is empty"
STUB_LIST_OBJECTS="null" export STUB_LIST_OBJECTS
out="$(echo "$payload" | "$assets/in" "$workdir/dest" 2>/dev/null)"
assert_valid_version "$(echo "$out" | jq -c '.version')" "in (empty prefix)"

# ---------------------------------------------------------------------- out ---

mkdir -p "$workdir/src"
echo hello > "$workdir/src/hello.txt"

start_test "out emits the newest LastModified as a valid version"
STUB_LIST_OBJECTS="$two_objects" export STUB_LIST_OBJECTS
out="$(echo "$payload" | "$assets/out" "$workdir/src" 2>/dev/null)"
assert_valid_version "$(echo "$out" | jq -c '.version')" "out"
assert_equals "$(echo "$out" | jq -r '.version.LastModified')" "$newest" \
  "out picks newest"

start_test "out emits a synthetic version when nothing was uploaded"
STUB_LIST_OBJECTS="null" export STUB_LIST_OBJECTS
out="$(echo "$payload" | "$assets/out" "$workdir/src" 2>/dev/null)"
assert_valid_version "$(echo "$out" | jq -c '.version')" "out (nothing uploaded)"

start_test "out does not leak credentials into its trace output"
STUB_LIST_OBJECTS="$two_objects" export STUB_LIST_OBJECTS
secret_payload='{"source": {"bucket": "test-bucket", "path": "p", "access_key_id": "AKIAEXAMPLE", "secret_access_key": "s3cr3t-do-not-log"}}'
stderr="$(echo "$secret_payload" | "$assets/out" "$workdir/src" 2>&1 >/dev/null)"
if echo "$stderr" | grep -q 's3cr3t-do-not-log'; then
  fail "out leaked secret_access_key to stderr"
fi

# -------------------------------------------------------- version agreement ---

start_test "check, in and out agree on the version key"
STUB_LIST_OBJECTS="$two_objects" export STUB_LIST_OBJECTS
check_keys="$(echo "$payload" | "$assets/check" | jq -r '.[0] | keys | join(",")')"
in_keys="$(echo "$payload" | "$assets/in" "$workdir/dest" 2>/dev/null | jq -r '.version | keys | join(",")')"
out_keys="$(echo "$payload" | "$assets/out" "$workdir/src" 2>/dev/null | jq -r '.version | keys | join(",")')"
assert_equals "$in_keys" "$check_keys" "in vs check version keys"
assert_equals "$out_keys" "$check_keys" "out vs check version keys"

# ------------------------------------------------------------------ summary ---

echo
if [ "$failures" -eq 0 ]; then
  echo "ok: $total test groups passed"
else
  echo "FAILED: $failures assertion(s) across $total test groups"
  exit 1
fi
