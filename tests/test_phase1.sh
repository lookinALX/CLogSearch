#!/bin/bash
# STAGE 1: Argument parsing testing
# At this stage, the program should simply parse the arguments and output what it understood
# No fork(), no shared memory, no semaphores

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

run_test() {
    local test_name="$1"
    local command="$2"
    local expected="$3"
    
    echo -n "Test: $test_name ... "
    
    output=$(eval "$command" 2>&1)
    result=$?
    
    if [ $result -eq $expected ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Command: $command"
        echo "  Expected exit code: $expected, received: $result"
        echo "  Output: $output"
        ((FAILED++))
        return 1
    fi
}

echo "Generating test log..."
./generate_logs.sh small > /dev/null 2>&1

echo ""
echo "--- Basic tests ---"
echo ""

run_test "Without arguments (should show help)" \
    "$LOGSEARCH" \
    1

run_test "Minimum arguments: -f file" \
    "$LOGSEARCH -f small.log" \
    0

run_test "With workers: -w 2" \
    "$LOGSEARCH -f small.log -w 2" \
    0

echo ""
echo "--- Filter tests ---"
echo ""

run_test "Filter by method: -p GET" \
    "$LOGSEARCH -f small.log -p GET" \
    0

run_test "Filter by status: -s 404" \
    "$LOGSEARCH -f small.log -s 404" \
    0

run_test "Multiple filters: -p POST -s 200" \
    "$LOGSEARCH -f small.log -p POST -s 200" \
    0

echo ""
echo "--- Error tests ---"
echo ""

run_test "Non-existent file (should return error)" \
    "$LOGSEARCH -f nonexistent.log" \
    1

run_test "Incorrect number of workers: -w 0" \
    "$LOGSEARCH -f small.log -w 0" \
    1

run_test "Negative number of workers: -w -5" \
    "$LOGSEARCH -f small.log -w -5" \
    1

run_test "Unknown argument" \
    "$LOGSEARCH -f small.log --unknown-flag" \
    1

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
