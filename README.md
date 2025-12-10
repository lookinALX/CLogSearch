# logsearch

A parallel log file search utility for web server logs (Apache/Nginx access logs) written in C. The program uses multiple worker processes to speed up processing of large files and employs IPC mechanisms (shared memory and semaphores) for synchronization and result aggregation.

## Features

- ✅ Parse and search through Apache/Nginx access logs
- ✅ Filter by HTTP method (GET, POST, PUT, DELETE, etc.)
- ✅ Filter by HTTP status code (200, 404, 500, etc.)
- ✅ Multi-process parallel processing using `fork()`
- ✅ Shared memory for statistics aggregation
- ✅ Semaphores for synchronization
- ✅ Configurable number of worker processes
- ✅ Statistics output (total lines processed, matches found)

## Requirements

- **OS:** Linux (Ubuntu, Debian, or similar)
- **Compiler:** gcc
- **Standard:** C99 or newer
- **Dependencies:** POSIX IPC support

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd logsearch

# Build
make

# Generate test data
make generate-logs
```

## Usage

### Basic Usage

```bash
# Search all lines in a log file
./logsearch -f access.log

# Use 4 worker processes
./logsearch -f access.log -w 4

# Filter by HTTP method
./logsearch -f access.log -p GET

# Filter by status code
./logsearch -f access.log -s 404

# Combine filters
./logsearch -f access.log -w 8 -p POST -s 200
```

### Command-line Options

**Required:**
- `-f <file>` - Path to the log file

**Optional:**
- `-w <number>` - Number of worker processes (default: 1, max: 32)
- `-p <method>` - Filter by HTTP method (GET, POST, PUT, DELETE, etc.)
- `-s <code>` - Filter by HTTP status code (200, 404, 500, etc.)
- `--ip <address>` - Filter by IP address (if implemented)
- `--count` - Show statistics only, don't print lines (if implemented)
- `-h, --help` - Show help message

### Examples

```bash
# Find all 404 errors using 4 workers
./logsearch -f access.log -w 4 -s 404

# Find all POST requests with 200 status
./logsearch -f access.log -p POST -s 200

# Process large file with 16 workers
./logsearch -f large.log -w 16

# Search for specific IP
./logsearch -f access.log --ip 192.168.1.1
```

## Log File Format

The program expects log files in Apache/Nginx Combined Log Format:

```
IP - - [Timestamp] "METHOD PATH PROTOCOL" STATUS SIZE
```

**Example:**
```
192.168.1.1 - - [03/Dec/2024:10:00:01 +0000] "GET /index.html HTTP/1.1" 200 1234
192.168.1.2 - - [03/Dec/2024:10:00:02 +0000] "POST /api/login HTTP/1.1" 200 567
192.168.1.1 - - [03/Dec/2024:10:00:03 +0000] "GET /style.css HTTP/1.1" 404 0
```

## Architecture

### Process Model

```
Parent Process
├── Parse arguments
├── Validate input
├── Create shared memory
├── Create semaphores
├── Calculate file chunks
├── fork() × N workers
├── Wait for all workers (waitpid)
├── Print statistics
└── Cleanup IPC resources

Worker Process (×N)
├── Open log file
├── Seek to assigned chunk
├── Read and parse lines
├── Apply filters
├── Print matching lines
├── Update shared memory (with semaphore lock)
└── Exit
```

### IPC Mechanisms

**Shared Memory:**
- Stores global statistics (total lines processed, matches found)
- Stores per-worker statistics
- Accessed by all workers

**Semaphores:**
- Binary semaphore (mutex) protects shared memory
- Lock before accessing shared memory
- Unlock after updates

## Development

### Project Structure

```
logsearch/
├── src/
│   ├── logsearch.c          # Main program
│   └── ...                   # Other source files
├── tests/
│   ├── generate_logs.sh      # Test data generator
│   ├── test_phase1.sh        # Phase 1 tests
│   ├── test_phase2.sh        # Phase 2 tests
│   ├── test_phase3.sh        # Phase 3 tests
│   ├── test_phase4.sh        # Phase 4 tests
│   └── test_phase5.sh        # Phase 5 tests
├── Makefile
├── README.md
```

### Building

```bash
# Compile the program
make

# Clean build artifacts
make clean

# Clean IPC resources (useful during debugging)
make clean-ipc
```

### Generating Test Data

```bash
# Generate all test logs
make generate-logs

# Or individually:
make generate-small    # 10 lines
make generate-medium   # 1,000 lines
make generate-large    # 100,000 lines
```
