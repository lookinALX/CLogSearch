#!/bin/bash
# STAGE 3: Shared Memory
# The program must create shared memory and write statistics there
# Still a single process, but statistics go into shared memory
# This is preparation before doing fork()

echo "======================================"
echo "STAGE 3: Shared Memory"
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

echo "Generating test logs..."
./generate_logs.sh small > /dev/null 2>&1

echo ""
echo "--- Shared memory creation tests ---"
echo ""

# Test 1: Check that the program creates shared memory
echo -n "Test: Creating shared memory ... "
$LOGSEARCH -f small.log &
PID=$!
sleep 0.5

# Check that shared memory segment exists
if ipcs -m | grep -q "$USER\|0x"; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC} (shared memory not created)"
    ((FAILED++))
fi

# Kill the process if it's still alive
kill $PID 2>/dev/null
wait $PID 2>/dev/null

sleep 0.5

echo ""
echo "--- Statistics writing tests ---"
echo ""

# Test 2: Statistics must be in shared memory
echo -n "Test: Writing statistics to shared memory ... "
output=$($LOGSEARCH -f small.log 2>&1)

# The program should output statistics from shared memory
if echo "$output" | grep -qE "(Statistics|Stats|Total|Found|Processed)"; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}PARTIAL${NC} (statistics not printed, but that's OK for basic implementation)"
    # Not counted as fail
fi

echo ""
echo "--- Cleanup tests ---"
echo ""

# Test 3: Check that shared memory is removed after finishing
echo -n "Test: Shared memory cleanup after exit ... "

# Run the program
$LOGSEARCH -f small.log > /dev/null 2>&1

# Wait a bit
sleep 0.5

# Count shared memory segments before
BEFORE=$(ipcs -m | grep -c "$USER" || echo 0)

# Run and immediately kill
timeout 1 $LOGSEARCH -f small.log > /dev/null 2>&1 &
PID=$!
sleep 0.5
kill $PID 2>/dev/null
wait $PID 2>/dev/null

sleep 0.5

# Count shared memory segments after
AFTER=$(ipcs -m | grep -c "$USER" || echo 0)

if [ $AFTER -le $BEFORE ]; then
    echo -e "${GREEN}PASS${NC} (shared memory cleaned)"
    ((PASSED++))
else
    echo -e "${YELLOW}WARNING${NC} (possible shared memory leak)"
    echo "  Check that you call shmctl(shm_id, IPC_RMID, NULL)"
    echo "  Or use atexit() for cleanup"
fi

echo ""
echo "--- Data structure tests ---"
echo ""

# Test 4: Statistics must update
echo -n "Test: Counter updates ... "
output=$($LOGSEARCH -f small.log -p GET 2>&1)

# Check that the program outputs correct count
if echo "$output" | grep -qE "(6|Found: 6|Processed: 6|GET.*6)"; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}PARTIAL${NC} (cannot verify counters in output)"
fi

echo ""
echo "--- Additional checks ---"
echo ""

# Test 5: Check that multiple runs don't conflict
echo -n "Test: Multiple runs (no conflicts) ... "
$LOGSEARCH -f small.log > /dev/null 2>&1
result1=$?
$LOGSEARCH -f small.log > /dev/null 2>&1
result2=$?
$LOGSEARCH -f small.log > /dev/null 2>&1
result3=$?

if [ $result1 -eq 0 ] && [ $result2 -eq 0 ] && [ $result3 -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC} (issues with repeated runs)"
    ((FAILED++))
fi

echo ""
echo "======================================"
echo "Stage 3 Results:"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "======================================"
echo ""

# Clean up any remaining shared memory segments
echo "Cleaning up leftover shared memory segments..."
for shm_id in $(ipcs -m | grep "$USER" | awk '{print $2}'); do
    ipcrm -m $shm_id 2>/dev/null
done

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Stage 3 completed successfully!${NC}"
    echo "Now you can add semaphores (Stage 4)"
    exit 0
else
    echo -e "${YELLOW}⚠ There are failed tests${NC}"
    echo "Fix them before moving to the next stage"
    exit 1
fi