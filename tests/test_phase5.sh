#!/bin/bash
# STAGE 5: Multiple Workers (fork)
# The program uses fork() to create multiple worker processes
# Each worker processes its own portion of the file
# All use shared memory and semaphores for synchronization

echo "======================================"
echo "STAGE 5: Multiple Workers (fork)"
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
./generate_logs.sh medium > /dev/null 2>&1
./generate_logs.sh large > /dev/null 2>&1

echo ""
echo "--- Worker creation tests ---"
echo ""

# Test 1: Launch with 2 workers
echo -n "Test: Launch with 2 workers ... "
timeout 10 $LOGSEARCH -f medium.log -w 2 > /dev/null 2>&1
result=$?

if [ $result -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC} (exit code: $result)"
    ((FAILED++))
fi

# Test 2: Launch with 4 workers
echo -n "Test: Launch with 4 workers ... "
timeout 10 $LOGSEARCH -f medium.log -w 4 > /dev/null 2>&1
result=$?

if [ $result -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC} (exit code: $result)"
    ((FAILED++))
fi

# Test 3: Launch with 8 workers
echo -n "Test: Launch with 8 workers ... "
timeout 10 $LOGSEARCH -f medium.log -w 8 > /dev/null 2>&1
result=$?

if [ $result -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC} (exit code: $result)"
    ((FAILED++))
fi

echo ""
echo "--- Result correctness tests ---"
echo ""

# Test 4: Results with 1 worker == results with 4 workers
echo -n "Test: Correctness with multiple workers ... "

output1=$($LOGSEARCH -f medium.log -w 1 -p GET 2>&1 | grep -c "GET" || echo 0)
output4=$($LOGSEARCH -f medium.log -w 4 -p GET 2>&1 | grep -c "GET" || echo 0)

if [ "$output1" -eq "$output4" ] && [ "$output1" -gt 0 ]; then
    echo -e "${GREEN}PASS${NC} (found $output1 lines)"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    echo "  With 1 worker: $output1 lines"
    echo "  With 4 workers: $output4 lines"
    ((FAILED++))
fi

# Test 5: Check that all workers are active
echo -n "Test: All workers active (check via ps) ... "

$LOGSEARCH -f large.log -w 4 > /dev/null 2>&1 &
PARENT_PID=$!
sleep 1

# Count processes
PROCESS_COUNT=$(pgrep -P $PARENT_PID | wc -l)

if [ $PROCESS_COUNT -ge 4 ]; then
    echo -e "${GREEN}PASS${NC} (found $PROCESS_COUNT child processes)"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC} (found only $PROCESS_COUNT processes instead of 4)"
    ((FAILED++))
fi

# Kill processes
kill $PARENT_PID 2>/dev/null
pkill -P $PARENT_PID 2>/dev/null
wait $PARENT_PID 2>/dev/null

echo ""
echo "--- Synchronization tests ---"
echo ""

# Test 6: No race conditions in statistics
echo -n "Test: Counter synchronization (no race conditions) ... "

# Run multiple times and check that result is stable
results=()
for i in {1..5}; do
    output=$(timeout 10 $LOGSEARCH -f medium.log -w 4 -p GET --count 2>&1)
    count=$(echo "$output" | grep -oE "[0-9]+" | head -1)
    results+=("$count")
done

# Check that all results are identical
first="${results[0]}"
all_same=true
for result in "${results[@]}"; do
    if [ "$result" != "$first" ]; then
        all_same=false
        break
    fi
done

if [ "$all_same" = true ] && [ -n "$first" ]; then
    echo -e "${GREEN}PASS${NC} (all 5 runs produced: $first)"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC} (results are unstable)"
    echo "  Results: ${results[*]}"
    echo "  Possible race condition in shared memory!"
    ((FAILED++))
fi

echo ""
echo "--- Performance tests ---"
echo ""

# Test 7: Speed 1 vs 4 workers
echo "Test: Performance comparison ..."

echo -n "  1 worker ... "
time1_start=$(date +%s%N)
timeout 30 $LOGSEARCH -f large.log -w 1 > /dev/null 2>&1
time1_end=$(date +%s%N)
time1=$(( (time1_end - time1_start) / 1000000 ))
echo "${time1}ms"

echo -n "  4 workers ... "
time4_start=$(date +%s%N)
timeout 30 $LOGSEARCH -f large.log -w 4 > /dev/null 2>&1
time4_end=$(date +%s%N)
time4=$(( (time4_end - time4_start) / 1000000 ))
echo "${time4}ms"

if [ $time4 -lt $time1 ]; then
    speedup=$(echo "scale=2; $time1 / $time4" | bc)
    echo -e "  ${GREEN}PASS${NC} (speedup ${speedup}x)"
    ((PASSED++))
else
    echo -e "  ${YELLOW}INFO${NC} (4 workers not faster, but this can be OK for small files)"
    # Not counted as fail
fi

echo ""
echo "--- Graceful shutdown tests ---"
echo ""

# Test 8: All workers exit cleanly
echo -n "Test: Graceful shutdown of all workers ... "

$LOGSEARCH -f large.log -w 4 > /dev/null 2>&1 &
PARENT_PID=$!
sleep 1

# Send SIGTERM
kill -TERM $PARENT_PID 2>/dev/null
sleep 2

# Check for zombie and hanging processes
ZOMBIE_COUNT=$(ps aux | grep logsearch | grep -c "Z" || echo 0)
RUNNING_COUNT=$(pgrep logsearch | wc -l)

if [ $ZOMBIE_COUNT -eq 0 ] && [ $RUNNING_COUNT -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    echo "  Zombie processes: $ZOMBIE_COUNT"
    echo "  Hanging processes: $RUNNING_COUNT"
    ((FAILED++))
    # Cleanup
    pkill -9 logsearch 2>/dev/null
fi

echo ""
echo "--- Stress tests ---"
echo ""

# Test 9: Many workers
echo -n "Test: 16 workers on a large file ... "
timeout 30 $LOGSEARCH -f large.log -w 16 > /dev/null 2>&1
result=$?

if [ $result -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
elif [ $result -eq 124 ]; then
    echo -e "${RED}FAIL${NC} (timeout)"
    ((FAILED++))
else
    echo -e "${YELLOW}PARTIAL${NC} (exit code: $result)"
fi

echo ""
echo "======================================"
echo "Stage 5 Results:"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "======================================"
echo ""

# Cleanup
echo "Cleaning up IPC resources..."
pkill -9 logsearch 2>/dev/null
sleep 1
for shm_id in $(ipcs -m | grep "$USER" | awk '{print $2}'); do
    ipcrm -m $shm_id 2>/dev/null
done
for sem_id in $(ipcs -s | grep "$USER" | awk '{print $2}'); do
    ipcrm -s $sem_id 2>/dev/null
done

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Stage 5 completed successfully!${NC}"
    echo -e "${GREEN}🎉 ALL MAIN STAGES PASSED!${NC}"
    echo ""
    echo "Your program works correctly!"
    echo "Now you can:"
    echo "  - Add additional filters (--ip, --time)"
    echo "  - Improve statistics output"
    echo "  - Add a progress bar"
    echo "  - Optimize performance"
    exit 0
else
    echo -e "${YELLOW}⚠ There are failed tests${NC}"
    echo "Fix race conditions and synchronization issues"
    exit 1
fi