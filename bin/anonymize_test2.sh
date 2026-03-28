#!/usr/bin/env bash

# Simple unit tests for anonymize.sh
# Usage: ./test_anonymize.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/anonymize.sh"

TEST_DIR="/tmp/anonymize_test_$$"
CONFIG_FILE="$TEST_DIR/test.conf"
SAMPLE_FILE="$TEST_DIR/sample.txt"

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Source the script (functions only)
set +e
source "$SCRIPT"
set -e

# Helpers
fail() { echo "not ok - $1"; exit 1; }
pass() { echo "ok - $1"; }
assert_file_contains() { grep -q "$2" "$1" || fail "$1 does not contain $2"; }
assert_file_not_contains() { ! grep -q "$2" "$1" || fail "$1 should not contain $2"; }
assert_file_exists() { [[ -f "$1" ]] || fail "$1 does not exist"; }
assert_success() { "$@" || fail "$*"; }

# Test data
cat > "$SAMPLE_FILE" <<EOF
John Smith works at Acme Corporation.
Contact: john.smith@example.com or +1 555-123-4567.
Visit https://acme.com for more info.
EOF

cat > "$CONFIG_FILE" <<EOF
PERSON_1=John Smith
COMPANY_1=Acme Corporation
EMAIL_1=john.smith@example.com
PHONE_1=+1 555-123-4567
URL_1=https://acme.com
EOF

# Test functions
test_generate_config() {
    rm -f "$TEST_DIR/gen.conf"
    generate_config "$SAMPLE_FILE"
    assert_file_exists "$CONFIG_FILE"
    pass "generate_config"
}

test_load_config() {
    load_config
    [[ "${ANONYMIZE_MAP[John Smith]}" == "PERSON_1" ]] || fail "load_config mapping"
    pass "load_config"
}

test_anonymize_text() {
    anonymize_text "$SAMPLE_FILE"
    assert_file_exists "$SAMPLE_FILE.anon"
    assert_file_contains "$SAMPLE_FILE.anon" "PERSON_1"
    assert_file_not_contains "$SAMPLE_FILE.anon" "John Smith"
    assert_file_exists "$SAMPLE_FILE.orig"
    pass "anonymize_text"
}

test_deanonymize_text() {
    deanonymize_text "$SAMPLE_FILE.anon"
    assert_file_exists "$SAMPLE_FILE.deanon"
    assert_file_contains "$SAMPLE_FILE.deanon" "John Smith"
    assert_file_contains "$SAMPLE_FILE.deanon" "Acme Corporation"
    pass "deanonymize_text"
}

test_anonymize_text_dry_run() {
    DRY_RUN=true
    anonymize_text "$SAMPLE_FILE"
    DRY_RUN=false
    pass "anonymize_text DRY_RUN"
}

test_deanonymize_text_dry_run() {
    DRY_RUN=true
    deanonymize_text "$SAMPLE_FILE.anon"
    DRY_RUN=false
    pass "deanonymize_text DRY_RUN"
}

test_parse_args_all_options() {
    WORK_FILES=()
    MODE="anonymize"
    CONFIG_FILE="$CONFIG_FILE"
    GENERATE_CONFIG=false
    DRY_RUN=false
    parse_args -a -c "$CONFIG_FILE" "$SAMPLE_FILE"
    [[ "$MODE" == "anonymize" ]] || fail "parse_args -a"
    [[ "${WORK_FILES[0]}" == "$SAMPLE_FILE" ]] || fail "parse_args file"
    pass "parse_args -a -c"
}

test_parse_args_deanonymize() {
    WORK_FILES=()
    MODE="deanonymize"
    parse_args -d "$SAMPLE_FILE.anon"
    [[ "$MODE" == "deanonymize" ]] || fail "parse_args -d"
    pass "parse_args -d"
}

test_parse_args_generate() {
    WORK_FILES=()
    GENERATE_CONFIG=false
    parse_args -g "$SAMPLE_FILE"
    [[ "$GENERATE_CONFIG" == true ]] || fail "parse_args -g"
    pass "parse_args -g"
}

test_parse_args_dry_run() {
    WORK_FILES=()
    DRY_RUN=false
    parse_args --dry-run "$SAMPLE_FILE"
    [[ "$DRY_RUN" == true ]] || fail "parse_args --dry-run"
    pass "parse_args --dry-run"
}

test_show_help() {
    show_help | grep -q "Text Anonymization Script" || fail "show_help"
    pass "show_help"
}

main() {

# Run all tests
echo "1..12"
test_show_help
test_generate_config
test_load_config
test_anonymize_text
test_deanonymize_text
test_anonymize_text_dry_run
test_deanonymize_text_dry_run
test_parse_args_all_options
test_parse_args_deanonymize
test_parse_args_generate
test_parse_args_dry_run

echo "All tests passed!"

# Cleanup
rm -rf "$TEST_DIR"
}

# Run main function with all arguments
# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
