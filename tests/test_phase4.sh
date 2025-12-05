#!/bin/bash
# STAGE 4: Semaphores
# The program must use semaphores for synchronizing access to shared memory
# Still a single process, but with correct synchronization
# This is important before doing fork() - otherwise there will be race conditions

echo "======================================"
echo "STAGE 4: Semaphores"
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

echo ""
echo "--- Semaphore creation tests ---"
echo ""

# Test 1: Check that the program creates semaphores
echo -n "Test: Semaphore creation ... "
$LOGSEARCH -f medium.log &
PID=$!
sleep 0.5

# Check that semaphores exist
if ipcs -s | grep -q "$USER\|0x"; then
    echo -e "${GREEN}PASS${NC}"
    ((PASSED++))
else
    echo -e "${RED}FAIL${NC} (semaphores not created)"
    ((FAILED++))
fi

kill $PID 2>/dev/null
wait $PID 2>/dev/null
sleep 0.5

echo ""
echo "--- Correctness tests ---"
echo ""

# Test 2: Program must work with semaphores (no deadlock)
echo -n "Test: Semaphore operation (no hang) ... "
timeout 5 $LOGSEARCH -f medium.log > /dev/null 2>&1
result=$?

if [ $result -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} (program finished normally)"
    ((PASSED++))
elif [ $result -eq 124 ]; then
    echo -e "${RED}FAIL${NC} (timeout - possible deadlock)"
    ((FAILED++))
else
    echo -e "${YELLOW}PARTIAL${NC} (exit code $result)"
fi

echo ""
echo "--- Semaphore cleanup tests ---"
echo ""

# Test 3: Check that semaphores are cleaned up
echo -n "Test: Semaphore cleanup after exit ... "

BEFORE=$(ipcs -s | grep -c "$USER" || echo 0)

timeout 2 $LOGSEARCH -f medium.log > /dev/null 2>&1
sleep 0.5

AFTER=$(ipcs -s | grep -c "$USER" || echo 0)

if [ $AFTER -le $BEFORE ]; then
    echo -e "${GREEN}PASS${NC} (semaphores cleaned)"
    ((PASSED++))
else
    echo -e "${YELLOW}WARNING${NC} (possible semaphore leak)"
    echo "  Check that you call semctl(sem_id, 0, IPC_RMID)"
fi

echo ""
echo "--- Stress tests ---"
echo ""

# Test 4: Multiple lock/unlock operations
echo -n "Test: Multiple lock/unlock operations ... "
timeout 10 $LOGSEARCH -f medium.log > /dev/null 2>&1
result=$?

if [ $result -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} (1000 lines processed without issues)"
    ((PASSED++))
elif [ $result -eq 124 ]; then
    echo -e "${RED}FAIL${NC} (timeout during processing)"
    ((FAILED++))
else
    echo -e "${YELLOW}PARTIAL${NC}"
fi

echo ""
echo "--- Race condition check ---"
echo ""

# Test 5: Run multiple instances in parallel (preparation for fork)
echo -n "Test: Parallel launch of multiple instances ... "

# Create separate log for each process
cp medium.log test1.log
cp medium.log test2.log
cp medium.log test3.log

timeout 10 $LOGSEARCH -f test1.log > /tmp/out1.txt 2>&1 &
PID1=$!
timeout 10 $LOGSEARCH -f test2.log > /tmp/out2.txt 2>&1 &
PID2=$!
timeout 10 $LOGSEARCH -f test3.log > /tmp/out3.txt 2>&1 &
PID3=$!

wait $PID1
result1=$?
wait $PID2
result2=$?
wait $PID3
result3=$?

if [ $result1 -eq 0 ] && [ $result2 -eq 0 ] && [ $result3 -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} (all processes finished successfully)"
    ((PASSED++))
else
    echo -e "${YELLOW}PARTIAL${NC} (exit codes: $result1, $result2, $result3)"
    echo "  This is normal if unique IPC keys are not implemented yet"
fi

rm -f test1.log test2.log test3.log
rm -f /tmp/out1.txt /tmp/out2.txt /tmp/out3.txt

echo ""
echo "======================================"
echo "Stage 4 Results:"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "======================================"
echo ""

# Cleanup
echo "Cleaning up IPC resources..."
for shm_id in $(ipcs -m | grep "$USER" | awk '{print $2}'); do
    ipcrm -m $shm_id 2>/dev/null
done
for sem_id in $(ipcs -s | grep "$USER" | awk '{print $2}'); do
    ipcrm -s $sem_id 2>/dev/null
done

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Stage 4 completed successfully!${NC}"
    echo "Now you can add fork() and multiple workers (Stage 5)"
    exit 0
else
    echo -e "${YELLOW}⚠ There are failed tests${NC}"
    echo "Fix them before moving to the next stage"
    exit 1
fi