#!/bin/bash
#
# DNS Test Script for OpenClaw Container
# Run with: docker exec openclaw-openclaw-gateway-1 /bin/bash /tmp/dns-test.sh
#

# Don't exit on error - we want to catch failures
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Domains to test
DOMAINS=(
    "slack.com"
    "wss-primary.slack.com"
    "api.telegram.org"
    "api.notion.com"
    "smtp.gmail.com"
    "www.googleapis.com"
    "moltbook.com"
    "google.com"
    "github.com"
    "cloudflare.com"
)

# Test configuration
TIMEOUT_SECONDS=5
REPEAT_COUNT=3
DELAY_BETWEEN=1

# Output functions
print_header() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Get timestamp in ms
timestamp_ms() {
    date +%s%N 2>/dev/null | cut -b1-13 || date +%s000
}

# Test single DNS lookup with timeout
test_dns_lookup() {
    local domain=$1
    local start_time end_time duration_ms
    local result ip
    
    start_time=$(timestamp_ms)
    
    # Use timeout to prevent hanging
    result=$(timeout $TIMEOUT_SECONDS getent hosts "$domain" 2>&1)
    local exit_code=$?
    
    end_time=$(timestamp_ms)
    duration_ms=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        # Get first IP
        ip=$(echo "$result" | head -1 | awk '{print $1}')
        echo "OK|$duration_ms|$ip"
        return 0
    elif [ $exit_code -eq 124 ]; then
        echo "TIMEOUT|$duration_ms|N/A"
        return 1
    else
        echo "FAIL|$duration_ms|N/A"
        return 1
    fi
}

# Get DNS servers from resolv.conf (properly)
get_dns_servers() {
    grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | grep -v "^#"
}

# Main test function
main() {
    print_header "DNS Health Check for OpenClaw Container"
    
    echo ""
    echo "Container: $(hostname)"
    echo "Date: $(date)"
    echo "Timeout per lookup: ${TIMEOUT_SECONDS}s"
    echo ""
    
    # Check DNS configuration
    print_header "DNS Configuration"
    
    if [ -f /etc/resolv.conf ]; then
        echo ""
        echo "/etc/resolv.conf:"
        cat /etc/resolv.conf | sed 's/^/  /'
    fi
    
    echo ""
    echo "DNS Servers found:"
    dns_servers=$(get_dns_servers)
    
    if [ -z "$dns_servers" ]; then
        print_error "No DNS servers configured!"
    else
        for server in $dns_servers; do
            echo "  - $server"
        done
    fi
    
    # Test DNS server reachability
    echo ""
    echo "Testing DNS server connectivity:"
    
    if [ -z "$dns_servers" ]; then
        print_error "No DNS servers to test!"
    else
        for server in $dns_servers; do
            # Try to reach DNS port (53) with timeout
            if timeout 2 bash -c "exec 3<>/dev/tcp/$server/53" 2>/dev/null; then
                print_success "DNS server $server:53 reachable (TCP)"
            else
                print_error "DNS server $server:53 NOT reachable (TCP)"
            fi
        done
    fi
    
    # Test domain resolution
    print_header "Domain Resolution Tests"
    
    echo ""
    printf "%-30s %-12s %-15s %-10s\n" "DOMAIN" "STATUS" "IP" "TIME(ms)"
    printf "%-30s %-12s %-15s %-10s\n" "------" "------" "--" "---------"
    
    total_domains=0
    failed_domains=0
    timeout_domains=0
    total_time_ms=0
    
    for domain in "${DOMAINS[@]}"; do
        total_domains=$((total_domains + 1))
        
        result=$(test_dns_lookup "$domain")
        status=$(echo "$result" | cut -d'|' -f1)
        time_ms=$(echo "$result" | cut -d'|' -f2)
        ip=$(echo "$result" | cut -d'|' -f3)
        
        # Cap time at reasonable value for average calculation
        if [ "$time_ms" -gt 30000 ]; then
            time_ms=30000
        fi
        total_time_ms=$((total_time_ms + time_ms))
        
        if [ "$status" = "OK" ]; then
            printf "%-30s ${GREEN}%-12s${NC} %-15s %-10s\n" "$domain" "OK" "$ip" "$time_ms"
        elif [ "$status" = "TIMEOUT" ]; then
            printf "%-30s ${YELLOW}%-12s${NC} %-15s %-10s\n" "$domain" "TIMEOUT" "-" ">${TIMEOUT_SECONDS}s"
            timeout_domains=$((timeout_domains + 1))
            failed_domains=$((failed_domains + 1))
        else
            printf "%-30s ${RED}%-12s${NC} %-15s %-10s\n" "$domain" "FAIL" "-" "$time_ms"
            failed_domains=$((failed_domains + 1))
        fi
        
        # Warn about slow lookups
        if [ "$status" = "OK" ] && [ "$time_ms" -gt 2000 ]; then
            print_warning "  ^ Slow lookup (${time_ms}ms) - DNS may be degraded"
        fi
    done
    
    # Summary
    print_header "Summary"
    
    success_count=$((total_domains - failed_domains))
    success_rate=$((success_count * 100 / total_domains))
    
    # Don't divide by zero
    if [ $total_domains -gt 0 ]; then
        avg_time=$((total_time_ms / total_domains))
    else
        avg_time=0
    fi
    
    echo ""
    echo "Total domains tested: $total_domains"
    echo "Successful: $success_count"
    echo "Timed out: $timeout_domains"
    echo "Failed: $failed_domains"
    echo "Success rate: ${success_rate}%"
    echo "Average lookup time: ${avg_time}ms"
    
    # Performance assessment
    echo ""
    echo "DNS Performance Assessment:"
    if [ $avg_time -lt 100 ]; then
        print_success "Excellent (< 100ms avg)"
    elif [ $avg_time -lt 500 ]; then
        print_success "Good (< 500ms avg)"
    elif [ $avg_time -lt 2000 ]; then
        print_warning "Slow (1-2s avg) - consider checking DNS configuration"
    else
        print_error "Very slow (> 2s avg) - DNS is severely degraded!"
    fi
    
    # Overall status
    if [ $failed_domains -eq 0 ]; then
        echo ""
        print_success "All DNS lookups successful!"
        exit_code=0
    elif [ $success_rate -ge 80 ]; then
        echo ""
        print_warning "DNS partially working ($failed_domains domains failed/timeout)"
        exit_code=1
    else
        echo ""
        print_error "DNS severely degraded! Check configuration."
        exit_code=2
    fi
    
    # Continuous monitoring mode option
    if [ "$1" = "--monitor" ]; then
        echo ""
        print_header "Continuous Monitoring Mode"
        echo "Testing critical domains every 10 seconds. Press Ctrl+C to stop."
        echo "Legend: . = OK, ! = FAIL, T = TIMEOUT"
        echo ""
        
        # Header
        printf "%-20s | %-10s %-10s %-10s\n" "TIMESTAMP" "slack" "telegram" "google"
        printf "%-20s | %-10s %-10s %-10s\n" "--------------------" "----------" "----------" "----------"
        
        while true; do
            timestamp=$(date '+%H:%M:%S')
            
            # Test critical domains with single character output
            slack_result=$(timeout $TIMEOUT_SECONDS getent hosts slack.com >/dev/null 2>&1 && echo -n "." || echo -n "!")
            telegram_result=$(timeout $TIMEOUT_SECONDS getent hosts api.telegram.org >/dev/null 2>&1 && echo -n "." || echo -n "!")
            google_result=$(timeout $TIMEOUT_SECONDS getent hosts google.com >/dev/null 2>&1 && echo -n "." || echo -n "!")
            
            printf "%-20s | %-10s %-10s %-10s\n" "$timestamp" "$slack_result" "$telegram_result" "$google_result"
            
            sleep 10
        done
    fi
    
    # Stress test option
    if [ "$1" = "--stress" ]; then
        echo ""
        print_header "DNS Stress Test"
        echo "Running $REPEAT_COUNT lookups per domain..."
        echo ""
        
        failed_lookups=0
        total_lookups=0
        
        for domain in "${DOMAINS[@]}"; do
            results=""
            for i in $(seq 1 $REPEAT_COUNT); do
                total_lookups=$((total_lookups + 1))
                
                if timeout $TIMEOUT_SECONDS getent hosts "$domain" >/dev/null 2>&1; then
                    results="${results}."
                else
                    results="${results}!"
                    failed_lookups=$((failed_lookups + 1))
                fi
            done
            echo "[$results] $domain"
            sleep $DELAY_BETWEEN
        done
        
        echo ""
        echo "Stress test complete: $total_lookups lookups, $failed_lookups failures"
        
        if [ $failed_lookups -gt 0 ]; then
            failure_rate=$((failed_lookups * 100 / total_lookups))
            print_error "Failure rate: ${failure_rate}%"
            exit 3
        else
            print_success "All lookups successful!"
        fi
    fi
    
    exit $exit_code
}

# Show usage
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "DNS Test Script for OpenClaw Container"
    echo ""
    echo "Usage:"
    echo "  docker exec openclaw-openclaw-gateway-1 /bin/bash /tmp/dns-test.sh"
    echo ""
    echo "Options:"
    echo "  --monitor    Continuous monitoring mode (10s interval)"
    echo "  --stress     Stress test (multiple lookups per domain)"
    echo "  --help       Show this help"
    echo ""
    echo "Exit codes:"
    echo "  0 - All tests passed"
    echo "  1 - Partial failures (80%+ success)"
    echo "  2 - Severe degradation (<80% success)"
    echo "  3 - Stress test failures"
    exit 0
fi

# Run main function
main "$@"
