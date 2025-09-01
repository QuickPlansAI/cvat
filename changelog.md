# Changelog

## [2025-08-12] - CVAT Storage Migration Setup

### Added
- Modified `docker-compose.override.yml` to use mounted drive for all CVAT data volumes
- Created `setup_cvat_storage.sh` script to prepare mounted drive directories
- Created `migrate_cvat_data.sh` script to migrate existing data to new location

### Changes
- **Volume Configuration**: All CVAT volumes now use bind mounts to `/mnt/cvat_data/`
- **Data Locations**:
  - PostgreSQL DB: `/mnt/cvat_data/db`
  - CVAT Data: `/mnt/cvat_data/data`
  - Django Keys: `/mnt/cvat_data/keys`
  - Logs: `/mnt/cvat_data/logs`
  - Redis In-Memory: `/mnt/cvat_data/redis_inmem`
  - ClickHouse: `/mnt/cvat_data/clickhouse`
  - Redis Cache: `/mnt/cvat_data/redis_cache`

### Usage Instructions
1. Mount your drive: `sudo mount /dev/sdb1 /mnt/cvat_drive`
2. Run setup: `./setup_cvat_storage.sh` (requires sudo)
3. Migrate existing data: `./migrate_cvat_data.sh` (if applicable, requires sudo)
4. Start CVAT: `docker compose up -d`

### Bug Fixes
- Fixed permission issues in setup scripts by using `sudo` for directory creation
- Added sudo privilege checks to prevent permission denied errors
- Made mount point checks optional to handle local directory scenarios
- **CRITICAL FIX**: Updated migration script to properly detect and migrate existing Docker volume data
- Migration script now automatically finds CVAT Docker volumes and migrates all data types
- Fixed issue where migration script was looking in wrong location (`./data` instead of Docker volumes)

### Safety Improvements
- **CRITICAL SAFETY**: Migration script now only targets CVAT-specific volumes to prevent affecting other containers
- Added predefined list of CVAT volume names to avoid accidental migration of unrelated data
- Added safety confirmation prompt showing exactly which volumes will be migrated
- Enhanced backup system with individual volume backups
- Added clear warnings about which volumes will be affected


## [2025-08-12] - CVAT Data Storage Research

### Added
- Research on CVAT default data sharing locations and storage configuration
- Documentation of Docker volume mappings and data directory structure

### Findings
- **Default Data Location**: `/home/django/data` inside CVAT containers
- **Docker Volume**: `cvat_data` volume mapped to `/home/django/data`
- **Local Path**: `./data` relative to CVAT installation directory
- **Shared Across**: All CVAT services (server, workers) share the same data volume
- **Data Types**: Uploaded media files, annotations, cache, models, and temporary files

### Technical Details
- Data is stored in Docker volumes for persistence
- Main data volume `cvat_data` is shared across all CVAT containers
- Directory structure includes: data/, cache/, jobs/, tasks/, projects/, models/, storages/, tmp/
- PostgreSQL database stored separately in `cvat_db` volume
- Logs stored in `cvat_logs` volume
- Keys stored in `cvat_keys` volume

## [2025-08-29] - Automated Backups Added

### Added
- Created `backup_cvat.sh` to back up PostgreSQL DB (pg_dump) and media files
- Media backup archives `/mnt/cvat_drive/data` to timestamped `.tar.gz` under `~/cvat_backups`
- Logging to `~/cvat_backups/backup.log`

### Changes
- Backup retention set to 5 days for both DB dumps and media archives
- Recommended cron schedules for IST: 2 PM and 7 PM (08:30 and 13:30 UTC)

### Usage
- One-time: `chmod +x /home/azureuser/cvat/backup_cvat.sh`
- Manual run: `/home/azureuser/cvat/backup_cvat.sh`
- Cron (run `crontab -e` and add):
  - `30 8 * * * /home/azureuser/cvat/backup_cvat.sh`
  - `30 13 * * * /home/azureuser/cvat/backup_cvat.sh`

