#!/bin/bash
# script for generating test logs

generate_small_log() {
    cat > small.log << 'EOF'
192.168.1.1 - - [03/Dec/2024:10:00:01 +0000] "GET /index.html HTTP/1.1" 200 1234
192.168.1.2 - - [03/Dec/2024:10:00:02 +0000] "POST /api/login HTTP/1.1" 200 567
192.168.1.1 - - [03/Dec/2024:10:00:03 +0000] "GET /style.css HTTP/1.1" 404 0
192.168.1.3 - - [03/Dec/2024:10:00:04 +0000] "GET /image.jpg HTTP/1.1" 200 8901
192.168.1.2 - - [03/Dec/2024:10:00:05 +0000] "POST /api/data HTTP/1.1" 500 123
192.168.1.1 - - [03/Dec/2024:10:00:06 +0000] "GET /about.html HTTP/1.1" 200 2345
192.168.1.4 - - [03/Dec/2024:10:00:07 +0000] "GET /admin HTTP/1.1" 403 0
192.168.1.3 - - [03/Dec/2024:10:00:08 +0000] "DELETE /api/user/5 HTTP/1.1" 204 0
192.168.1.2 - - [03/Dec/2024:10:00:09 +0000] "GET /notfound HTTP/1.1" 404 0
192.168.1.1 - - [03/Dec/2024:10:00:10 +0000] "GET /index.html HTTP/1.1" 200 1234
EOF
    echo "✓ Created small.log (10 lines)"
}

generate_medium_log() {
    echo "I generate medium.log (1000 lines)..."
    > medium.log
    
    IPS=("192.168.1.1" "192.168.1.2" "192.168.1.3" "10.0.0.5" "172.16.0.10")
    METHODS=("GET" "POST" "PUT" "DELETE")
    PATHS=("/index.html" "/api/users" "/api/data" "/images/logo.png" "/admin" "/notfound")
    CODES=(200 200 200 404 500 403 304 201)
    
    for i in {1..1000}; do
        IP=${IPS[$RANDOM % ${#IPS[@]}]}
        METHOD=${METHODS[$RANDOM % ${#METHODS[@]}]}
        PATH=${PATHS[$RANDOM % ${#PATHS[@]}]}
        CODE=${CODES[$RANDOM % ${#CODES[@]}]}
        SIZE=$((RANDOM % 10000))
        
        printf '%s - - [03/Dec/2024:10:%02d:%02d +0000] "%s %s HTTP/1.1" %d %d\n' \
            "$IP" $((i/60)) $((i%60)) "$METHOD" "$PATH" $CODE $SIZE >> medium.log
    done
    echo "✓ Created medium.log (1000 lines)"
}

generate_large_log() {
    echo "I generate large.log (100000 lines, I can take time)..."
    > large.log
    
    IPS=("192.168.1.1" "192.168.1.2" "192.168.1.3" "10.0.0.5" "172.16.0.10" "8.8.8.8" "1.1.1.1")
    METHODS=("GET" "GET" "GET" "POST" "PUT" "DELETE")
    PATHS=("/index.html" "/api/users" "/api/data" "/images/logo.png" "/admin" "/notfound" "/api/products")
    CODES=(200 200 200 200 404 500 403 304 201 502)
    
    for i in {1..100000}; do
        IP=${IPS[$RANDOM % ${#IPS[@]}]}
        METHOD=${METHODS[$RANDOM % ${#METHODS[@]}]}
        PATH=${PATHS[$RANDOM % ${#PATHS[@]}]}
        CODE=${CODES[$RANDOM % ${#CODES[@]}]}
        SIZE=$((RANDOM % 10000))
        
        printf '%s - - [03/Dec/2024:10:%02d:%02d +0000] "%s %s HTTP/1.1" %d %d\n' \
            "$IP" $((i/3600)) $((i%3600/60)) "$METHOD" "$PATH" $CODE $SIZE
    done >> large.log
    echo "✓ Created large.log (100000 lines)"
}

echo "=== Test log generator ==="
echo ""

if [ "$1" == "all" ]; then
    generate_small_log
    generate_medium_log
    generate_large_log
elif [ "$1" == "small" ]; then
    generate_small_log
elif [ "$1" == "medium" ]; then
    generate_medium_log
elif [ "$1" == "large" ]; then
    generate_large_log
else
    echo "Usage: $0 [small|medium|large|all]"
    echo ""
    echo "  small  - 10 lines"
    echo "  medium - 1000 lines"
    echo "  large  - 100000 lines"
    echo "  all    - create all"
    exit 1
fi

echo ""
echo "Ready!"