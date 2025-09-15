#!/bin/bash

# BunnyCDN Whitelist Updater Script
# Updates CrowdSec whitelist with latest BunnyCDN edge server IPs (IPv4 & IPv6)
# Author: Generated for CrowdSec configuration
# Usage: ./update-bunnycdn-whitelist.sh

set -e

# Configuration
WHITELIST_FILE="/etc/crowdsec/parsers/s02-enrich/00-realstack-bunnycdn-whitelist.yaml"
TEMP_DIR="/tmp/bunnycdn_update"
DATE=$(date +"%Y-%m-%d")

# Colors for output (disabled if running in cron or redirected)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

echo -e "${GREEN}🚀 BunnyCDN Whitelist Updater${NC} - $(date)"
echo "================================================"

# Create temp directory
mkdir -p "$TEMP_DIR"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check dependencies
echo -e "${YELLOW}📋 Checking dependencies...${NC}"
if ! command_exists curl; then
    echo -e "${RED}❌ curl is required but not installed.${NC}"
    exit 1
fi

if ! command_exists jq; then
    echo -e "${RED}❌ jq is required but not installed. Install with: brew install jq${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All dependencies found${NC}"

# Fetch IPv4 addresses
echo -e "${YELLOW}📥 Fetching IPv4 addresses from BunnyCDN API...${NC}"
if curl -s "https://bunnycdn.com/api/system/edgeserverlist" | jq -r '.[]' > "$TEMP_DIR/ipv4_list.txt"; then
    IPV4_COUNT=$(wc -l < "$TEMP_DIR/ipv4_list.txt")
    echo -e "${GREEN}✅ Fetched $IPV4_COUNT IPv4 addresses${NC}"
else
    echo -e "${RED}❌ Failed to fetch IPv4 addresses${NC}"
    exit 1
fi

# Fetch IPv6 addresses
echo -e "${YELLOW}📥 Fetching IPv6 addresses from BunnyCDN API...${NC}"
if curl -s "https://bunnycdn.com/api/system/edgeserverlist/IPv6" | jq -r '.[]' > "$TEMP_DIR/ipv6_list.txt"; then
    IPV6_COUNT=$(wc -l < "$TEMP_DIR/ipv6_list.txt")
    echo -e "${GREEN}✅ Fetched $IPV6_COUNT IPv6 addresses${NC}"
else
    echo -e "${RED}❌ Failed to fetch IPv6 addresses${NC}"
    exit 1
fi

# Generate new whitelist file
echo -e "${YELLOW}📝 Generating new whitelist...${NC}"
cat > "$WHITELIST_FILE" << EOF
name: realstack/bunnycdn-ip-whitelist
description: "Whitelist BunnyCDN edge server IPs (IPv4 & IPv6) from their official API"
whitelist:
  reason: "BunnyCDN edge servers - legitimate CDN traffic"
  ip:
    # BunnyCDN Edge Servers IPv4 (from https://bunnycdn.com/api/system/edgeserverlist)
    # Last updated: $DATE
EOF

# Add IPv4 addresses
while IFS= read -r ip; do
    echo "    - \"$ip\"" >> "$WHITELIST_FILE"
done < "$TEMP_DIR/ipv4_list.txt"

# Add IPv6 section (in the same ip array as IPv4)
cat >> "$WHITELIST_FILE" << EOF
    # BunnyCDN Edge Servers IPv6 (from https://bunnycdn.com/api/system/edgeserverlist/IPv6)
    # Last updated: $DATE
EOF

# Add IPv6 addresses to the same ip array
while IFS= read -r ip; do
    echo "    - \"$ip\"" >> "$WHITELIST_FILE"
done < "$TEMP_DIR/ipv6_list.txt"

# Clean up
rm -rf "$TEMP_DIR"

echo -e "${GREEN}✅ Whitelist updated successfully!${NC}"

# Restart CrowdSec to apply changes
echo -e "${YELLOW}🔄 Restarting CrowdSec to apply changes...${NC}"
if sudo systemctl restart crowdsec; then
    echo -e "${GREEN}✅ CrowdSec restarted successfully${NC}"
else
    echo -e "${RED}❌ Failed to restart CrowdSec${NC}"
    exit 1
fi
echo "================================================"
echo -e "${GREEN}📊 Summary:${NC}"
echo -e "  • IPv4 addresses: $IPV4_COUNT"
echo -e "  • IPv6 addresses: $IPV6_COUNT"
echo -e "  • Total addresses: $((IPV4_COUNT + IPV6_COUNT))"
echo -e "  • File: $WHITELIST_FILE"
echo ""
echo -e "${YELLOW}🔄 What happened:${NC}"
echo "  1. Fetched latest BunnyCDN edge server IPs"
echo "  2. Updated whitelist configuration"
echo "  3. Restarted CrowdSec service"
echo ""
echo -e "${GREEN}🎉 Update completed at $(date)${NC}"
echo ""