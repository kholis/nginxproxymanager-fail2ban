#!/bin/bash
# Test script to verify NPM_DATA_DIR replacement works correctly

echo "Testing NPM_DATA_DIR replacement..."
echo "==================================="

# Test 1: Default path
echo ""
echo "Test 1: Default path"
NPM_DATA_DIR="/apps/nginxproxymanager/data"
echo "Setting NPM_DATA_DIR=${NPM_DATA_DIR}"
result=$(cat jail.d/nginx-proxy-manager.local | sed "s|{{NPM_DATA_DIR}}|${NPM_DATA_DIR}|g" | grep "logpath")
echo "Result: $result"
if [[ "$result" == *"/apps/nginxproxymanager/data/logs"* ]]; then
    echo "✓ Pass"
else
    echo "✗ Fail"
fi

# Test 2: Custom path
echo ""
echo "Test 2: Custom path"
NPM_DATA_DIR="/opt/npm"
echo "Setting NPM_DATA_DIR=${NPM_DATA_DIR}"
result=$(cat jail.d/nginx-proxy-manager.local | sed "s|{{NPM_DATA_DIR}}|${NPM_DATA_DIR}|g" | grep "logpath")
echo "Result: $result"
if [[ "$result" == *"/opt/npm/logs"* ]]; then
    echo "✓ Pass"
else
    echo "✗ Fail"
fi

# Test 3: Path with spaces (should work with | delimiter)
echo ""
echo "Test 3: Path with special characters"
NPM_DATA_DIR="/var/lib/docker/volumes/npm_data/_data"
echo "Setting NPM_DATA_DIR=${NPM_DATA_DIR}"
result=$(cat jail.d/nginx-proxy-manager.local | sed "s|{{NPM_DATA_DIR}}|${NPM_DATA_DIR}|g" | grep "logpath")
echo "Result: $result"
if [[ "$result" == *"/var/lib/docker/volumes/npm_data/_data/logs"* ]]; then
    echo "✓ Pass"
else
    echo "✗ Fail"
fi

echo ""
echo "==================================="
echo "All tests completed!"