#!/bin/bash
# STAGE 1: Argument parsing testing
# At this stage, the program should parse arguments and handle errors properly
# The program should either:
# 1. Exit with code 1 for errors AND/OR print error message
# 2. Exit with code 0 for success AND print something (not empty)

echo "======================================"
echo "STAGE 1: Argument Parsing"
echo "======================================"
echo ""

# Path to executable (one level up from tests/)
LOGSEARCH="../logsearch"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

run_test_expects_error() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Test: $test_name ... "
    
    output=$(eval "$command" 2>&1)
    result=$?
    
    # Success if: exit code is 1 OR output contains error/usage message
    if [ $result -ne 0 ] || echo "$output" | grep -qiE "(usage|error|invalid|help)"; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Command: $command"
        echo "  Expected: error exit code (!=0) OR error message in output"
        echo "  Got: exit code $result"
        echo "  Output: '$output'"
        ((FAILED++))
        return 1
    fi
}

run_test_expects_success() {
    local test_name="$1"
    local command="$2"
    
    echo -n "Test: $test_name ... "
    
    output=$(eval "$command" 2>&1)
    result=$?
    
    # Success if: exit code is 0 AND output is not empty
    if [ $result -eq 0 ] && [ -n "$output" ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Command: $command"
        echo "  Expected: exit code 0 AND non-empty output"
        echo "  Got: exit code $result"
        echo "  Output: '$output'"
        ((FAILED++))
        return 1
    fi
}

echo "Generating test log..."
./generate_logs.sh small > /dev/null 2>&1

echo ""
echo "--- Basic tests ---"
echo ""

run_test_expects_error "Without arguments (should show help)" \
    "$LOGSEARCH"

run_test_expects_success "Minimum arguments: -f file" \
    "$LOGSEARCH -f small.log"

run_test_expects_success "With workers: -w 2" \
    "$LOGSEARCH -f small.log -w 2"

echo ""
echo "--- Filter tests ---"
echo ""

run_test_expects_success "Filter by method: -p GET" \
    "$LOGSEARCH -f small.log -p GET"

run_test_expects_success "Filter by status: -s 404" \
    "$LOGSEARCH -f small.log -s 404"

run_test_expects_success "Multiple filters: -p POST -s 200" \
    "$LOGSEARCH -f small.log -p POST -s 200"

echo ""
echo "--- Error tests ---"
echo ""

run_test_expects_error "Non-existent file (should return error)" \
    "$LOGSEARCH -f nonexistent.log"

run_test_expects_error "Incorrect number of workers: -w 0" \
    "$LOGSEARCH -f small.log -w 0"

run_test_expects_error "Negative number of workers: -w -5" \
    "$LOGSEARCH -f small.log -w -5"

run_test_expects_error "Unknown argument" \
    "$LOGSEARCH -f small.log --unknown-flag"

echo ""
echo "======================================"
echo "Stage 1 Results:"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "======================================"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Stage 1 completed successfully!${NC}"
    echo "You can proceed to Stage 2 (single worker without fork)"
    exit 0
else
    echo -e "${YELLOW}⚠ There are failed tests${NC}"
    echo "Fix them before moving to the next stage"
    exit 1
fi

