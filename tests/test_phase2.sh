#!/bin/bash
# STAGE 2: File reading and filtering (single process)
# The program must read the file, apply filters, and output results
# Still without fork(), shared memory, semaphores - just one process

echo "======================================"
echo "STAGE 2: Reading and Filtering (1 process)"
echo "======================================"
echo ""

# Path to executable (one level up from tests/)
LOGSEARCH="../logsearch"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

check_output() {
    local test_name="$1"
    local command="$2"
    local expected_count="$3"
    
    echo -n "Test: $test_name ... "
    
    output=$(eval "$command" 2>&1)
    actual_count=$(echo "$output" | grep -E "192\.168|10\.0\.0|172\.16" | wc -l)
    
    if [ "$actual_count" -eq "$expected_count" ]; then
        echo -e "${GREEN}PASS${NC} (found $actual_count lines)"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Command: $command"
        echo "  Expected: $expected_count lines, got: $actual_count"
        echo "  Program output:"
        echo "$output" | head -20
        ((FAILED++))
        return 1
    fi
}

check_stats() {
    local test_name="$1"
    local command="$2"
    local expected_pattern="$3"
    
    echo -n "Test: $test_name ... "
    
    output=$(eval "$command" 2>&1)
    
    if echo "$output" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Command: $command"
        echo "  Pattern not found: $expected_pattern"
        echo "  Output:"
        echo "$output"
        ((FAILED++))
        return 1
    fi
}

echo "Generating test logs..."
./generate_logs.sh small > /dev/null 2>&1

echo ""
echo "--- File reading tests ---"
echo ""

# In small.log we have:
# 6 GET requests
# 2 POST requests
# 1 DELETE request
# 1 status 403
# 2 status 404
# 1 status 500
# 5 lines with 200

check_output "All lines" \
    "$LOGSEARCH -f small.log" \
    10

check_output "Only GET requests" \
    "$LOGSEARCH -f small.log -p GET" \
    7

check_output "Only POST requests" \
    "$LOGSEARCH -f small.log -p POST" \
    2

check_output "Only status 404" \
    "$LOGSEARCH -f small.log -s 404" \
    2

check_output "Only status 200" \
    "$LOGSEARCH -f small.log -s 200" \
    5

echo ""
echo "--- Combined filter tests ---"
echo ""

check_output "GET requests with 200 status" \
    "$LOGSEARCH -f small.log -p GET -s 200" \
    4

check_output "POST requests with 200 status" \
    "$LOGSEARCH -f small.log -p POST -s 200" \
    1

# Test IP filter (if implemented)
if $LOGSEARCH --help 2>&1 | grep -q "\-\-ip"; then
    check_output "IP filter: 192.168.1.1" \
        "$LOGSEARCH -f small.log --ip 192.168.1.1" \7        4
fi

echo ""
echo "--- Statistics tests (if implemented) ---"
echo ""

# Test count mode
if $LOGSEARCH --help 2>&1 | grep -q "\-\-count"; then
    check_stats "Count mode --count" \
        "$LOGSEARCH -f small.log -p GET --count" \
        "6"
fi

check_output "Entire file is read (all 10 lines)" \
    "$LOGSEARCH -f small.log" \
    10

echo ""
echo "--- medium.log tests ---"
echo ""

echo "Generating medium.log (1000 lines)..."
./generate_logs.sh medium > /dev/null 2>&1

output=$($LOGSEARCH -f medium.log 2>&1)
count=$(echo "$output" | grep -c "192.168\|10.0.0\|172.16" || echo 0)
echo -n "Test: Read 1000 lines ... "
if [ $count -eq 1000 ]; then
    echo -e "${GREEN}PASS${NC} (read $count lines)"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC} (read $count lines instead of 1000)"
    ((FAILED++))
fi

echo ""
echo "======================================"
echo "Stage 2 Results:"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "======================================"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Stage 2 completed successfully!${NC}"
    echo "Now you can add shared memory (Stage 3)"
    exit 0
else
    echo -e "${YELLOW}⚠ There are failed tests${NC}"
    echo "Fix them before moving to the next stage"
    exit 1
fi

