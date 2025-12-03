CC = gcc
CFLAGS = -std=c99 -pedantic -Wall -D_DEFAULT_SOURCE -D_BSD_SOURCE -D_SVID_SOURCE -D_POSIX_C_SOURCE=200809L
TARGET = logsearch
SRC_DIR = src
TEST_DIR = tests

SOURCES = $(wildcard $(SRC_DIR)/*.c)

all: $(TARGET)

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) -o $(TARGET) $(SOURCES)

clean:
	rm -f $(TARGET)
	rm -f $(TEST_DIR)/*.log

generate-logs:
	cd $(TEST_DIR) && ./generate_logs.sh all

generate-small:
	cd $(TEST_DIR) && ./generate_logs.sh small

generate-medium:
	cd $(TEST_DIR) && ./generate_logs.sh medium

generate-large:
	cd $(TEST_DIR) && ./generate_logs.sh large

test1: $(TARGET)
	cd $(TEST_DIR) && ./test_phase1.sh

test2: $(TARGET)
	cd $(TEST_DIR) && ./test_phase2.sh

test3: $(TARGET)
	cd $(TEST_DIR) && ./test_phase3.sh

test4: $(TARGET)
	cd $(TEST_DIR) && ./test_phase4.sh

test5: $(TARGET)
	cd $(TEST_DIR) && ./test_phase5.sh

test-all: $(TARGET)
	@echo "Running all tests..."
	@cd $(TEST_DIR) && ./test_phase1.sh && \
	./test_phase2.sh && \
	./test_phase3.sh && \
	./test_phase4.sh && \
	./test_phase5.sh

.PHONY: all clean generate-logs generate-small generate-medium generate-large \