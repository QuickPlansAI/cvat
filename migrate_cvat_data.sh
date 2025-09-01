#!/bin/bash

# CVAT Data Migration Script
# This script migrates existing CVAT data to a new mounted drive location

set -e

# Configuration
NEW_STORAGE_PATH="/mnt/cvat_drive"
BACKUP_PATH="./cvat_backup_$(date +%Y%m%d_%H%M%S)"

# Get Docker volume paths
echo "Detecting existing CVAT data locations..."

# Define CVAT-specific volume names to avoid affecting other containers
CVAT_VOLUMES=(
    "cvat_cvat_data"
    "cvat_cvat_db"
    "cvat_cvat_inmem_db"
    "cvat_cvat_cache_db"
    "cvat_cvat_events_db"
    "cvat_cvat_keys"
    "cvat_cvat_logs"
)

echo "Scanning for CVAT-specific volumes only..."

# Check if CVAT data volume exists and get its mount point
if docker volume inspect cvat_cvat_data >/dev/null 2>&1; then
    OLD_DATA_PATH=$(docker volume inspect cvat_cvat_data | grep -o '"/var/lib/docker/volumes/[^"]*"' | head -1 | tr -d '"')
    echo "Found CVAT data volume at: $OLD_DATA_PATH"
else
    echo "No existing CVAT data volume found."
    OLD_DATA_PATH=""
fi

# Check if CVAT database volume exists and get its mount point
if docker volume inspect cvat_cvat_db >/dev/null 2>&1; then
    OLD_DB_PATH=$(docker volume inspect cvat_cvat_db | grep -o '"/var/lib/docker/volumes/[^"]*"' | head -1 | tr -d '"')
    echo "Found CVAT database volume at: $OLD_DB_PATH"
else
    echo "No existing CVAT database volume found."
    OLD_DB_PATH=""
fi

# List all CVAT volumes found
echo ""
echo "CVAT volumes detected:"
CVAT_VOLUMES_FOUND=()
for volume in "${CVAT_VOLUMES[@]}"; do
    if docker volume inspect "$volume" >/dev/null 2>&1; then
        vol_path=$(docker volume inspect "$volume" | grep -o '"/var/lib/docker/volumes/[^"]*"' | head -1 | tr -d '"')
        echo "  ✓ $volume -> $vol_path"
        CVAT_VOLUMES_FOUND+=("$volume")
    else
        echo "  - $volume (not found)"
    fi
done

# Safety confirmation
if [ ${#CVAT_VOLUMES_FOUND[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  SAFETY WARNING ⚠️"
    echo "The following CVAT volumes will be migrated:"
    for volume in "${CVAT_VOLUMES_FOUND[@]}"; do
        echo "  - $volume"
    done
    echo ""
    echo "This will only affect CVAT-related volumes. Other Docker volumes will NOT be touched."
    echo ""
    read -p "Do you want to proceed with the migration? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration cancelled."
        exit 0
    fi
else
    echo ""
    echo "No CVAT volumes found to migrate."
fi

echo "CVAT Data Migration Script"
echo "=========================="
echo ""

# Check if CVAT is running
if docker compose ps | grep -q "Up"; then
    echo "Warning: CVAT appears to be running!"
    echo "Please stop CVAT first: docker compose down"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration cancelled."
        exit 1
    fi
fi

# Check if new storage path exists
if [ ! -d "$NEW_STORAGE_PATH" ]; then
    echo "Error: New storage path $NEW_STORAGE_PATH does not exist!"
    echo "Please run setup_cvat_storage.sh first."
    exit 1
fi

# Check if new storage path is mounted (optional check)
if ! mountpoint -q "$NEW_STORAGE_PATH"; then
    echo "Warning: $NEW_STORAGE_PATH might not be mounted."
    echo "This could cause issues if the path is not on a separate drive."
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration cancelled."
        exit 1
    fi
fi

# Check if we found any existing data
if [ -z "$OLD_DATA_PATH" ] && [ -z "$OLD_DB_PATH" ]; then
    echo "No existing CVAT data found in Docker volumes."
    echo "This might be a fresh installation."
    echo ""
    read -p "Do you want to continue with setup only? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    echo "Setting up directories and permissions only..."
    sudo mkdir -p "$NEW_STORAGE_PATH"/{db,data,keys,logs,redis_inmem,clickhouse,redis_cache}
    sudo chown -R 1000:1000 "$NEW_STORAGE_PATH"
    sudo chmod -R 755 "$NEW_STORAGE_PATH"
    sudo chmod 700 "$NEW_STORAGE_PATH/db"
    sudo chmod 700 "$NEW_STORAGE_PATH/keys"
    echo "Setup completed successfully!"
    exit 0
fi

echo "Creating backup of existing data..."
mkdir -p "$BACKUP_PATH"

# Create directories if they don't exist
sudo mkdir -p "$NEW_STORAGE_PATH"/{db,data,keys,logs,redis_inmem,clickhouse,redis_cache}

# Check if data already exists in new location
if [ -d "$NEW_STORAGE_PATH/data" ] && [ "$(ls -A "$NEW_STORAGE_PATH/data" 2>/dev/null)" ]; then
    echo "Warning: Data already exists in $NEW_STORAGE_PATH/data"
    echo "This might be a fresh installation or data was already migrated."
    echo ""
    read -p "Do you want to continue with migration anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Migration skipped."
        echo "Setting permissions only..."
        sudo chown -R 1000:1000 "$NEW_STORAGE_PATH"
        sudo chmod -R 755 "$NEW_STORAGE_PATH"
        sudo chmod 700 "$NEW_STORAGE_PATH/db"
        sudo chmod 700 "$NEW_STORAGE_PATH/keys"
        echo "Permissions set successfully!"
        exit 0
    fi
fi

echo "Migrating data to new location..."

# Migrate CVAT data volume
if [ -n "$OLD_DATA_PATH" ] && [ -d "$OLD_DATA_PATH/_data" ]; then
    echo "Migrating CVAT data files..."
    sudo cp -r "$OLD_DATA_PATH/_data"/* "$NEW_STORAGE_PATH/data/" 2>/dev/null || true
    echo "Backing up data volume..."
    sudo cp -r "$OLD_DATA_PATH" "$BACKUP_PATH/cvat_data_volume" 2>/dev/null || true
fi

# Migrate database volume
if [ -n "$OLD_DB_PATH" ] && [ -d "$OLD_DB_PATH/_data" ]; then
    echo "Migrating database files..."
    sudo cp -r "$OLD_DB_PATH/_data"/* "$NEW_STORAGE_PATH/db/" 2>/dev/null || true
    echo "Backing up database volume..."
    sudo cp -r "$OLD_DB_PATH" "$BACKUP_PATH/cvat_db_volume" 2>/dev/null || true
fi

# Migrate other CVAT volumes safely
echo "Migrating other CVAT volumes..."

for volume in "${CVAT_VOLUMES[@]}"; do
    if docker volume inspect "$volume" >/dev/null 2>&1; then
        vol_path=$(docker volume inspect "$volume" | grep -o '"/var/lib/docker/volumes/[^"]*"' | head -1 | tr -d '"')

        case $volume in
            cvat_cvat_inmem_db)
                if [ -d "$vol_path/_data" ]; then
                    echo "Migrating Redis in-memory data..."
                    sudo cp -r "$vol_path/_data"/* "$NEW_STORAGE_PATH/redis_inmem/" 2>/dev/null || true
                    echo "Backing up Redis in-memory volume..."
                    sudo cp -r "$vol_path" "$BACKUP_PATH/cvat_inmem_volume" 2>/dev/null || true
                fi
                ;;
            cvat_cvat_cache_db)
                if [ -d "$vol_path/_data" ]; then
                    echo "Migrating Redis cache data..."
                    sudo cp -r "$vol_path/_data"/* "$NEW_STORAGE_PATH/redis_cache/" 2>/dev/null || true
                    echo "Backing up Redis cache volume..."
                    sudo cp -r "$vol_path" "$BACKUP_PATH/cvat_cache_volume" 2>/dev/null || true
                fi
                ;;
            cvat_cvat_events_db)
                if [ -d "$vol_path/_data" ]; then
                    echo "Migrating ClickHouse data..."
                    sudo cp -r "$vol_path/_data"/* "$NEW_STORAGE_PATH/clickhouse/" 2>/dev/null || true
                    echo "Backing up ClickHouse volume..."
                    sudo cp -r "$vol_path" "$BACKUP_PATH/cvat_events_volume" 2>/dev/null || true
                fi
                ;;
            cvat_cvat_keys)
                if [ -d "$vol_path/_data" ]; then
                    echo "Migrating Django keys..."
                    sudo cp -r "$vol_path/_data"/* "$NEW_STORAGE_PATH/keys/" 2>/dev/null || true
                    echo "Backing up keys volume..."
                    sudo cp -r "$vol_path" "$BACKUP_PATH/cvat_keys_volume" 2>/dev/null || true
                fi
                ;;
            cvat_cvat_logs)
                if [ -d "$vol_path/_data" ]; then
                    echo "Migrating logs..."
                    sudo cp -r "$vol_path/_data"/* "$NEW_STORAGE_PATH/logs/" 2>/dev/null || true
                    echo "Backing up logs volume..."
                    sudo cp -r "$vol_path" "$BACKUP_PATH/cvat_logs_volume" 2>/dev/null || true
                fi
                ;;
        esac
    fi
done



# Set proper permissions
echo "Setting permissions..."
sudo chown -R 1000:1000 "$NEW_STORAGE_PATH"
sudo chmod -R 755 "$NEW_STORAGE_PATH"
sudo chmod 700 "$NEW_STORAGE_PATH/db"
sudo chmod 700 "$NEW_STORAGE_PATH/keys"

echo ""
echo "Migration completed successfully!"
echo ""
echo "Backup created at: $BACKUP_PATH"
echo "New data location: $NEW_STORAGE_PATH"
echo ""
echo "You can now start CVAT with: docker compose up -d"
echo ""
echo "To verify the migration, you can:"
echo "1. Start CVAT: docker compose up -d"
echo "2. Check if your data is accessible in the web interface"
echo "3. If everything works, you can remove the backup: rm -rf $BACKUP_PATH"
