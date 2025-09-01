#!/bin/bash

# CVAT Storage Setup Script
# This script prepares a mounted drive for CVAT data storage

set -e

# Configuration
CVAT_STORAGE_PATH="/mnt/cvat_drive"
CVAT_USER="1000:1000"  # Default CVAT container user (django)

echo "Setting up CVAT storage on $CVAT_STORAGE_PATH"

# Check if user has sudo privileges
if ! sudo -n true 2>/dev/null; then
    echo "This script requires sudo privileges to create directories and set permissions."
    echo "Please ensure you have sudo access."
fi

# Check if the mount point exists
if [ ! -d "$CVAT_STORAGE_PATH" ]; then
    echo "Error: Mount point $CVAT_STORAGE_PATH does not exist!"
    echo "Please mount your drive to $CVAT_STORAGE_PATH first."
    echo "Example: sudo mount /dev/sdb1 /mnt/cvat_drive"
    exit 1
fi

# Check if the mount point is actually mounted (optional check)
if ! mountpoint -q "$CVAT_STORAGE_PATH"; then
    echo "Warning: $CVAT_STORAGE_PATH might not be mounted."
    echo "This could cause issues if the path is not on a separate drive."
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 1
    fi
fi

# Create CVAT directories (will not fail if they already exist)
echo "Creating CVAT directories..."

sudo mkdir -p "$CVAT_STORAGE_PATH"/{db,data,keys,logs,redis_inmem,clickhouse,redis_cache}

echo "Directories created/verified successfully!"

# Set proper permissions for CVAT containers
echo "Setting permissions for CVAT containers..."

# Set ownership to match CVAT container user (django:1000)
sudo chown -R $CVAT_USER "$CVAT_STORAGE_PATH"

# Set directory permissions
sudo chmod -R 755 "$CVAT_STORAGE_PATH"

# Set specific permissions for database directories
sudo chmod 700 "$CVAT_STORAGE_PATH/db"
sudo chmod 700 "$CVAT_STORAGE_PATH/keys"

echo "CVAT storage setup completed successfully!"
echo ""
echo "Directory structure created:"
echo "  $CVAT_STORAGE_PATH/"
echo "  ├── db/           (PostgreSQL database)"
echo "  ├── data/         (CVAT data files)"
echo "  ├── keys/         (Django secret keys)"
echo "  ├── logs/         (Application logs)"
echo "  ├── redis_inmem/  (Redis in-memory database)"
echo "  ├── clickhouse/   (ClickHouse analytics database)"
echo "  └── redis_cache/  (Redis cache database)"
echo ""
echo "You can now start CVAT with: docker compose up -d"
echo ""
echo "Note: If you have existing CVAT data, you may need to migrate it:"
echo "1. Stop CVAT: docker compose down"
echo "2. Copy existing data to the new location"
echo "3. Start CVAT: docker compose up -d"
