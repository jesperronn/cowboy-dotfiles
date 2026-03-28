#!/usr/bin/env bash

# test_anonymize.sh - Comprehensive test suite for anonymize.sh
# This script tests all functionality of the anonymization script

set -euo pipefail

pushd "$(dirname "$0")" > /dev/null || exit 1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test directory
TEST_DIR="./test_anonymize_$$"
SCRIPT_PATH="./anonymize.sh"

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Setup test environment
setup_test_env() {
    log_info "Setting up test environment..."

    # Check if anonymize.sh exists
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log_fail "$SCRIPT_PATH not found in current directory"
        exit 1
    fi

    # Make script executable
    chmod +x "$SCRIPT_PATH"

    # Create test directory
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"

    # Copy script to test directory
    cp "../$SCRIPT_PATH" "./anonymize.sh"

    log_info "Test environment ready in $TEST_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    cd ..
    rm -rf "$TEST_DIR"
    log_info "Test environment cleaned up"
}

# Create test files
create_test_files() {
    log_test "Creating test files..."

    # Simple test file
    cat > "simple_test.txt" << 'EOF'
John Smith works at Acme Corporation.
His email is john.smith@example.com and phone is +1-555-123-4567.
The company website is https://www.acme-corp.com.
EOF

    # Multi-line test file
    cat > "multiline_test.txt" << 'EOF'
Contact Information:

Name: Sarah Johnson
Email: sarah.johnson@company.com
Company: TechFlow Solutions Inc.
Address: 123 Business Street
Suite 456
New York, NY 10001

Phone: +1-555-987-6543
Website: https://techflow.com
EOF

    # Complex test file with edge cases
    cat > "complex_test.txt" << 'EOF'
Dr. Emma Watson from DataSecure Ltd. reported the following:

IP Addresses: 192.168.1.100, 10.0.0.50
Emails: admin@company.com, support@company.com
Companies: Nordic Investments A/S, Jensen & Partners ApS

Multi-line company info:
Acme Corporation
123 Main Street
Suite 100
City, State 12345

Special characters: test@domain.co.uk, phone: +44-20-7946-0958
EOF

    # Test file with no patterns
    cat > "no_patterns.txt" << 'EOF'
This is a simple text file.
It contains no email addresses, phone numbers, or company names.
Just plain text for testing purposes.
EOF

    log_pass "Test files created successfully"
}

# Test help functionality
test_help() {
    log_test "Testing help functionality..."
    ((TESTS_RUN++))

    if ./anonymize.sh --help > /dev/null 2>&1; then
        log_pass "Help command works"
    else
        log_fail "Help command failed"
    fi
}

# Test config generation
test_config_generation() {
    log_test "Testing config generation..."
    ((TESTS_RUN++))

    if ./anonymize.sh -g simple_test.txt multiline_test.txt complex_test.txt > /dev/null 2>&1; then
        if [[ -f "anonymize.conf" ]]; then
            log_pass "Config file generated successfully"

            # Check if config contains expected patterns
            local config_checks=0
            if grep -q "EMAIL_" "anonymize.conf"; then ((config_checks++)); fi
            if grep -q "PHONE_" "anonymize.conf"; then ((config_checks++)); fi
            if grep -q "PERSON_" "anonymize.conf"; then ((config_checks++)); fi
            if grep -q "COMPANY_" "anonymize.conf"; then ((config_checks++)); fi

            ((TESTS_RUN++))
            if [[ $config_checks -ge 3 ]]; then
                log_pass "Config file contains expected pattern types"
            else
                log_fail "Config file missing expected pattern types"
            fi
        else
            log_fail "Config file not created"
        fi
    else
        log_fail "Config generation failed"
    fi
}

# Test dry run functionality
test_dry_run() {
    log_test "Testing dry run functionality..."
    ((TESTS_RUN++))

    # Count files before dry run
    local files_before=$(ls -1 | wc -l)

    if ./anonymize.sh --dry-run -a simple_test.txt > /dev/null 2>&1; then
        local files_after=$(ls -1 | wc -l)

        if [[ $files_before -eq $files_after ]]; then
            log_pass "Dry run doesn't create files"
        else
            log_fail "Dry run created files when it shouldn't"
        fi
    else
        log_fail "Dry run command failed"
    fi
}

# Test anonymization
test_anonymization() {
    log_test "Testing anonymization..."
    ((TESTS_RUN++))

    if ./anonymize.sh -a simple_test.txt > /dev/null 2>&1; then
        if [[ -f "simple_test.txt.anon" && -f "simple_test.txt.orig" ]]; then
            log_pass "Anonymization created expected files"

            # Test that content changed
            ((TESTS_RUN++))
            if ! diff -q simple_test.txt.orig simple_test.txt.anon > /dev/null 2>&1; then
                log_pass "Anonymized file differs from original"
            else
                log_fail "Anonymized file identical to original"
            fi
        else
            log_fail "Anonymization didn't create expected files"
        fi
    else
        log_fail "Anonymization command failed"
    fi
}

# Test de-anonymization
test_deanonymization() {
    log_test "Testing de-anonymization..."
    ((TESTS_RUN++))

    if ./anonymize.sh -d simple_test.txt.anon > /dev/null 2>&1; then
        if [[ -f "simple_test.txt.deanon" ]]; then
            log_pass "De-anonymization created expected file"

            # Test that de-anonymized file matches original
            ((TESTS_RUN++))
            if diff -q simple_test.txt.orig simple_test.txt.deanon > /dev/null 2>&1; then
                log_pass "De-anonymized file matches original"
            else
                log_fail "De-anonymized file doesn't match original"
            fi
        else
            log_fail "De-anonymization didn't create expected file"
        fi
    else
        log_fail "De-anonymization command failed"
    fi
}

# Test multi-line handling
test_multiline_handling() {
    log_test "Testing multi-line pattern handling..."
    ((TESTS_RUN++))

    # Create a custom config with multi-line patterns
    cat > "multiline.conf" << 'EOF'
COMPANY_1=TechFlow Solutions Inc.
ADDRESS_1=123 Business Street
Suite 456
New York, NY 10001
PERSON_1=Sarah Johnson
EOF

    if ./anonymize.sh -c multiline.conf -a multiline_test.txt > /dev/null 2>&1; then
        if [[ -f "multiline_test.txt.anon" ]]; then
            # Check if multi-line address was replaced
            if grep -q "ADDRESS_1" multiline_test.txt.anon; then
                log_pass "Multi-line patterns handled correctly"
            else
                log_fail "Multi-line patterns not replaced"
            fi
        else
            log_fail "Multi-line test file not created"
        fi
    else
        log_fail "Multi-line anonymization failed"
    fi
}

# Test edge cases
test_edge_cases() {
    log_test "Testing edge cases..."

    # Test with non-existent file
    ((TESTS_RUN++))
    if ! ./anonymize.sh -a non_existent_file.txt > /dev/null 2>&1; then
        log_pass "Correctly handles non-existent files"
    else
        log_fail "Should fail with non-existent files"
    fi

    # Test with file containing no patterns
    ((TESTS_RUN++))
    if ./anonymize.sh -a no_patterns.txt > /dev/null 2>&1; then
        if [[ -f "no_patterns.txt.anon" ]]; then
            log_pass "Handles files with no patterns"
        else
            log_fail "Failed to process file with no patterns"
        fi
    else
        log_fail "Command failed on file with no patterns"
    fi

    # Test with missing config file
    ((TESTS_RUN++))
    rm -f anonymize.conf
    if ! ./anonymize.sh -a simple_test.txt > /dev/null 2>&1; then
        log_pass "Correctly handles missing config file"
    else
        log_fail "Should fail with missing config file"
    fi
}

# Test custom config file
test_custom_config() {
    log_test "Testing custom config file..."
    ((TESTS_RUN++))

    cat > "custom.conf" << 'EOF'
CUSTOM_EMAIL=john.smith@example.com
CUSTOM_COMPANY=Acme Corporation
CUSTOM_PERSON=John Smith
EOF

    if ./anonymize.sh -c custom.conf -a simple_test.txt > /dev/null 2>&1; then
        if [[ -f "simple_test.txt.anon" ]]; then
            if grep -q "CUSTOM_EMAIL\|CUSTOM_COMPANY\|CUSTOM_PERSON" simple_test.txt.anon; then
                log_pass "Custom config file works correctly"
            else
                log_fail "Custom config patterns not applied"
            fi
        else
            log_fail "Custom config test file not created"
        fi
    else
        log_fail "Custom config command failed"
    fi
}

# Test special characters and escaping
test_special_characters() {
    log_test "Testing special characters and escaping..."
    ((TESTS_RUN++))

    cat > "special_chars.txt" << 'EOF'
Email with dots: test.user@domain.co.uk
Phone with parentheses: (555) 123-4567
Company with special chars: AT&T Inc.
URL with parameters: https://example.com/path?param=value&other=123
EOF

    cat > "special.conf" << 'EOF'
SPECIAL_EMAIL=test.user@domain.co.uk
SPECIAL_PHONE=(555) 123-4567
SPECIAL_COMPANY=AT&T Inc.
SPECIAL_URL=https://example.com/path?param=value&other=123
EOF

    if ./anonymize.sh -c special.conf -a special_chars.txt > /dev/null 2>&1; then
        if [[ -f "special_chars.txt.anon" ]]; then
            local special_checks=0
            if grep -q "SPECIAL_EMAIL" special_chars.txt.anon; then ((special_checks++)); fi
            if grep -q "SPECIAL_PHONE" special_chars.txt.anon; then ((special_checks++)); fi
            if grep -q "SPECIAL_COMPANY" special_chars.txt.anon; then ((special_checks++)); fi
            if grep -q "SPECIAL_URL" special_chars.txt.anon; then ((special_checks++)); fi

            if [[ $special_checks -eq 4 ]]; then
                log_pass "Special characters handled correctly"
            else
                log_fail "Some special characters not handled correctly ($special_checks/4)"
            fi
        else
            log_fail "Special characters test file not created"
        fi
    else
        log_fail "Special characters test failed"
    fi
}

# Test batch processing
test_batch_processing() {
    log_test "Testing batch processing..."
    ((TESTS_RUN++))

    # Regenerate config for clean test
    ./anonymize.sh -g simple_test.txt multiline_test.txt complex_test.txt > /dev/null 2>&1

    if ./anonymize.sh -a simple_test.txt multiline_test.txt complex_test.txt > /dev/null 2>&1; then
        local batch_files=0
        if [[ -f "simple_test.txt.anon" ]]; then ((batch_files++)); fi
        if [[ -f "multiline_test.txt.anon" ]]; then ((batch_files++)); fi
        if [[ -f "complex_test.txt.anon" ]]; then ((batch_files++)); fi

        if [[ $batch_files -eq 3 ]]; then
            log_pass "Batch processing works correctly"
        else
            log_fail "Batch processing incomplete ($batch_files/3 files)"
        fi
    else
        log_fail "Batch processing command failed"
    fi
}

# Run all tests
run_all_tests() {
    log_info "Starting comprehensive test suite for anonymize.sh"
    echo

    create_test_files
    echo

    test_help
    test_config_generation
    echo

    test_dry_run
    test_anonymization
    test_deanonymization
    echo

    test_multiline_handling
    test_edge_cases
    echo

    test_custom_config
    test_special_characters
    test_batch_processing
    echo

    # Summary
    echo "=================================="
    echo "TEST SUMMARY"
    echo "=================================="
    echo "Tests run: $TESTS_RUN"
    echo "Tests passed: $TESTS_PASSED"
    echo "Tests failed: $TESTS_FAILED"
    echo

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_info "All tests passed! ✅"
        return 0
    else
        log_info "Some tests failed! ❌"
        return 1
    fi
}

# Trap to ensure cleanup
trap cleanup_test_env EXIT

# Main execution
main() {
    setup_test_env
    set -x
    run_all_tests
    local exit_code=$?
    cleanup_test_env
    exit $exit_code
}

# Check if script is being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
