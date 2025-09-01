#!/bin/bash

# CVAT Storage Verification Script
# This script verifies the current CVAT storage setup

set -e

# Configuration
CVAT_STORAGE_PATH="/mnt/cvat_drive"

echo "CVAT Storage Verification"
echo "========================"
echo ""

# Check if storage path exists
if [ -d "$CVAT_STORAGE_PATH" ]; then
    echo "✓ Storage path exists: $CVAT_STORAGE_PATH"
else
    echo "✗ Storage path does not exist: $CVAT_STORAGE_PATH"
    exit 1
fi

# Check if it's mounted
if mountpoint -q "$CVAT_STORAGE_PATH"; then
    echo "✓ Storage path is mounted"

    # Show mount information
    echo "Mount information:"
    mount | grep "$CVAT_STORAGE_PATH" || echo "  No mount info found"
else
    echo "⚠ Storage path is not mounted (this might be OK if it's a local directory)"
fi

# Check required directories
echo ""
echo "Checking CVAT directories:"

REQUIRED_DIRS=("db" "data" "keys" "logs" "redis_inmem" "clickhouse" "redis_cache")

for dir in "${REQUIRED_DIRS[@]}"; do
    full_path="$CVAT_STORAGE_PATH/$dir"
    if [ -d "$full_path" ]; then
        echo "✓ $dir/ exists"

        # Check permissions
        owner=$(stat -c '%U:%G' "$full_path" 2>/dev/null || echo "unknown")
        perms=$(stat -c '%a' "$full_path" 2>/dev/null || echo "unknown")
        echo "  Owner: $owner, Permissions: $perms"

        # Check if directory is writable
        if [ -w "$full_path" ]; then
            echo "  ✓ Directory is writable"
        else
            echo "  ✗ Directory is not writable"
        fi
    else
        echo "✗ $dir/ does not exist"
    fi
done

# Check disk space
echo ""
echo "Disk space information:"
df -h "$CVAT_STORAGE_PATH"

# Check if CVAT is running
echo ""
echo "CVAT container status:"
if command -v docker &> /dev/null; then
    if docker compose ps 2>/dev/null | grep -q "Up"; then
        echo "✓ CVAT containers are running"
    else
        echo "⚠ CVAT containers are not running"
    fi
else
    echo "⚠ Docker not available"
fi

echo ""
echo "Verification complete!"
