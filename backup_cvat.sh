#!/bin/bash

# CVAT Automated Backup Script
# This script creates backups of CVAT database and data

# Configuration
BACKUP_DIR=~/cvat_backups
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE=~/cvat_backups/backup.log

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Log function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Start backup
log_message "Starting CVAT backup..."

# Check if CVAT is running
if ! docker compose ps | grep -q "Up"; then
    log_message "ERROR: CVAT is not running. Skipping backup."
    exit 1
fi

# Create backup filename
BACKUP_FILE="cvat_backup_$DATE.sql"

# Perform database backup
log_message "Creating database backup: $BACKUP_FILE"
if docker compose exec cvat_db pg_dump -U cvat -d cvat > $BACKUP_DIR/$BACKUP_FILE 2>/dev/null; then
    log_message "Database backup completed successfully"

    # Get file size
    FILE_SIZE=$(du -h $BACKUP_DIR/$BACKUP_FILE | cut -f1)
    log_message "Backup file size: $FILE_SIZE"

    # Keep only last 5 days of DB backups
    log_message "Cleaning old DB backups (keeping last 5 days)..."
    find $BACKUP_DIR -name "cvat_backup_*.sql" -mtime +5 -delete 2>/dev/null

    log_message "Database backup step completed"
else
    log_message "ERROR: Database backup failed"
    exit 1
fi

# Media (images/videos) backup from /mnt/cvat_drive/data
MEDIA_SRC_DIR="/mnt/cvat_drive/data"
MEDIA_BACKUP_FILE="cvat_data_$DATE.tar.gz"

if [ -d "$MEDIA_SRC_DIR" ]; then
    log_message "Starting media backup from $MEDIA_SRC_DIR to $BACKUP_DIR/$MEDIA_BACKUP_FILE"
    if tar -C /mnt/cvat_drive -czf "$BACKUP_DIR/$MEDIA_BACKUP_FILE" data 2>/dev/null; then
        MEDIA_SIZE=$(du -h "$BACKUP_DIR/$MEDIA_BACKUP_FILE" | cut -f1)
        log_message "Media backup completed successfully (size: $MEDIA_SIZE)"
    else
        log_message "ERROR: Media backup failed"
        exit 1
    fi

    # Retain only last 5 days of media backups
    log_message "Cleaning old media backups (keeping last 5 days)..."
    find $BACKUP_DIR -name "cvat_data_*.tar.gz" -mtime +5 -delete 2>/dev/null
else
    log_message "WARNING: Media source directory $MEDIA_SRC_DIR not found. Skipping media backup."
fi

log_message "All backup steps completed"
