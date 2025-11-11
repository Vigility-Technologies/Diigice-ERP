# Frappe/ERPNext Setup Fixes - Documentation

This document outlines all the fixes applied to resolve issues when migrating a Frappe/ERPNext bench from Ubuntu to macOS.

## Table of Contents

1. [Issues Encountered](#issues-encountered)
2. [Fixes Applied](#fixes-applied)
3. [Step-by-Step Setup Guide](#step-by-step-setup-guide)
4. [Configuration Files Modified](#configuration-files-modified)
5. [Important Notes](#important-notes)

---

## Issues Encountered

### 1. Node.js Path Issue

- **Error**: `/bin/sh: /usr/bin/node: No such file or directory`
- **Cause**: Hardcoded Node.js path from Ubuntu system

### 2. Redis Configuration Paths

- **Error**: `FATAL CONFIG FILE ERROR (Redis) ... 'dir /home/ghild/erp-next/config/pids' No such file or directory`
- **Cause**: Hardcoded paths from Ubuntu system

### 3. Missing Node.js Dependencies

- **Error**: `Error: Cannot find module 'socket.io'`
- **Cause**: Node.js dependencies not installed

### 4. Python Module Not Found

- **Error**: `ModuleNotFoundError: No module named 'frappe'`
- **Cause**: Virtual environment issues and modules not installed in editable mode

### 5. SCSS Compilation Errors

- **Error**: `Could not resolve "onscan.js"` and `ENOENT: ...highlight.js/styles/tomorrow.css`
- **Cause**: Missing Node.js dependencies and incorrect import paths

### 6. Broken Symlinks

- **Error**: `ENOENT: no such file or directory` for assets
- **Cause**: Symlinks pointing to old Ubuntu paths

### 7. Virtual Environment Architecture Mismatch

- **Error**: `ImportError: dlopen(...): mach-o file, but is an incompatible architecture (have 'arm64', need 'x86_64')`
- **Cause**: Virtual environment created on Ubuntu (x86_64) being used on macOS (ARM64)

### 8. MySQL Client Linking Issue

- **Error**: `symbol not found in flat namespace '_mysql_affected_rows'`
- **Cause**: `mysqlclient` not properly linked to MariaDB connector libraries

### 9. Database Authentication Error

- **Error**: `MySQLdb.OperationalError: (1045, "Access denied for user '_499a4a30007070b4'@'localhost'")`
- **Cause**: Database user doesn't exist in local MariaDB

### 10. Empty Database

- **Error**: `MySQLdb.ProgrammingError: (1146, "Table '_499a4a30007070b4.tabdefaultvalue' doesn't exist")`
- **Cause**: Database created but not bootstrapped with Frappe schema

---

## Fixes Applied

### 1. Fixed Node.js Path in Procfile

**File**: `Procfile`

**Change**:

```diff
- socketio: /usr/bin/node apps/frappe/socketio.js
+ socketio: node apps/frappe/socketio.js
```

### 2. Updated Redis Configuration Paths

**Files**:

- `config/redis_cache.conf`
- `config/redis_queue.conf`

**Changes**: Updated hardcoded paths from `/home/ghild/erp-next/config/pids` to `/Users/anmolkhurana/repos/vigility/digiice-erp/config/pids`

**Example**:

```diff
- dir /home/ghild/erp-next/config/pids
+ dir /Users/anmolkhurana/repos/vigility/digiice-erp/config/pids
```

### 3. Fixed Python Virtual Environment

**Action**: Recreated virtual environment with correct Python version for macOS

**Commands**:

```bash
# Backup old venv
mv env env.old.ubuntu

# Create new venv with Python 3.12
/opt/homebrew/bin/python3.12 -m venv env

# Upgrade pip
./env/bin/pip install --upgrade pip
```

### 4. Fixed MySQL Client Installation

**Action**: Installed `mysqlclient` with proper MariaDB linking

**Commands**:

```bash
export MYSQLCLIENT_CFLAGS="-I/opt/homebrew/Cellar/mariadb-connector-c/3.4.7/include/mariadb"
export MYSQLCLIENT_LDFLAGS="-L/opt/homebrew/Cellar/mariadb-connector-c/3.4.7/lib/mariadb -lmariadb"
./env/bin/pip install --no-cache-dir mysqlclient
```

### 5. Installed Frappe and ERPNext in Editable Mode

**Commands**:

```bash
# Set MariaDB paths (required for frappe installation)
export MYSQLCLIENT_CFLAGS="-I/opt/homebrew/Cellar/mariadb-connector-c/3.4.7/include/mariadb"
export MYSQLCLIENT_LDFLAGS="-L/opt/homebrew/Cellar/mariadb-connector-c/3.4.7/lib/mariadb -lmariadb"

# Install frappe
./env/bin/pip install -e apps/frappe

# Install erpnext
./env/bin/pip install -e apps/erpnext
```

### 6. Fixed SCSS Import Path

**File**: `apps/frappe/frappe/public/scss/desk.bundle.scss`

**Change**:

```diff
- @import "frappe/public/node_modules/highlight.js/styles/tomorrow.css";
+ @import "~highlight.js/styles/tomorrow";
```

### 7. Fixed Broken Symlinks

**Action**: Recreated symlinks for assets

**Commands**:

```bash
# Remove broken symlinks
rm sites/assets/erpnext
rm sites/assets/frappe

# Create new symlinks
ln -s /Users/anmolkhurana/repos/vigility/digiice-erp/apps/erpnext/erpnext/public sites/assets/erpnext
ln -s /Users/anmolkhurana/repos/vigility/digiice-erp/apps/frappe/frappe/public sites/assets/frappe

# Create missing directory
mkdir -p sites/assets/erpnext/dist/js
```

### 8. Installed Node.js Dependencies

**Commands**:

```bash
# Install dependencies for frappe
cd apps/frappe
npm install
cd ../..

# Install dependencies for erpnext (requires yarn)
cd apps/erpnext
yarn install
cd ../..
```

### 9. Created Database User and Database

**Action**: Created database user and database in MariaDB

**SQL Script** (`create_db_user.sql`):

```sql
CREATE USER IF NOT EXISTS '_499a4a30007070b4'@'localhost' IDENTIFIED BY 'ZS1T3oQzr6wjeVg6';
CREATE DATABASE IF NOT EXISTS `_499a4a30007070b4` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON `_499a4a30007070b4`.* TO '_499a4a30007070b4'@'localhost';
FLUSH PRIVILEGES;
```

**Command**:

```bash
sudo /opt/homebrew/Cellar/mysql-client/9.5.0/bin/mysql < create_db_user.sql
```

### 10. Bootstrapped Database with Frappe Schema

**Action**: Imported Frappe framework SQL to create all required tables

**Command**:

```bash
export PATH="/opt/homebrew/Cellar/mysql-client/9.5.0/bin:$PATH"
cd /Users/anmolkhurana/repos/vigility/digiice-erp
./env/bin/python -c "
import sys
sys.path.insert(0, 'apps')
import frappe
from frappe.database.mariadb.setup_db import bootstrap_database

frappe.init(site='erp-next.localhost', sites_path='sites')
bootstrap_database(verbose=True)
"
```

### 11. Created Required Directories

**Commands**:

```bash
# Create logs directory
mkdir -p erp-next.localhost/logs
mkdir -p logs
```

### 12. Updated Procfile for Virtual Environment

**File**: `Procfile`

**Changes**: Updated Python-based services to activate virtual environment

**Before**:

```bash
web: bench serve --port 8001
```

**After**:

```bash
web: bash -c 'source env/bin/activate && bench serve --port 8001'
```

**Applied to**: `web`, `watch`, `schedule`, `worker` services

---

## Step-by-Step Setup Guide

### For a Fresh Setup on macOS

1. **Create Virtual Environment**

   ```bash
   cd /path/to/your/repo
   /opt/homebrew/bin/python3.12 -m venv env
   ./env/bin/pip install --upgrade pip
   ```

2. **Install MySQL Client with Proper Linking**

   ```bash
   export MYSQLCLIENT_CFLAGS="-I/opt/homebrew/Cellar/mariadb-connector-c/3.4.7/include/mariadb"
   export MYSQLCLIENT_LDFLAGS="-L/opt/homebrew/Cellar/mariadb-connector-c/3.4.7/lib/mariadb -lmariadb"
   ./env/bin/pip install --no-cache-dir mysqlclient
   ```

3. **Install Frappe and ERPNext**

   ```bash
   export MYSQLCLIENT_CFLAGS="-I/opt/homebrew/Cellar/mariadb-connector-c/3.4.7/include/mariadb"
   export MYSQLCLIENT_LDFLAGS="-L/opt/homebrew/Cellar/mariadb-connector-c/3.4.7/lib/mariadb -lmariadb"
   ./env/bin/pip install -e apps/frappe
   ./env/bin/pip install -e apps/erpnext
   ```

4. **Install Node.js Dependencies**

   ```bash
   cd apps/frappe && npm install && cd ../..
   cd apps/erpnext && yarn install && cd ../..
   ```

5. **Create Database User and Database**

   ```bash
   # Create SQL file with your database credentials
   cat > create_db_user.sql << EOF
   CREATE USER IF NOT EXISTS 'your_db_user'@'localhost' IDENTIFIED BY 'your_db_password';
   CREATE DATABASE IF NOT EXISTS \`your_db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   GRANT ALL PRIVILEGES ON \`your_db_name\`.* TO 'your_db_user'@'localhost';
   FLUSH PRIVILEGES;
   EOF

   # Run with sudo
   sudo /opt/homebrew/Cellar/mysql-client/9.5.0/bin/mysql < create_db_user.sql
   ```

6. **Bootstrap Database**

   ```bash
   export PATH="/opt/homebrew/Cellar/mysql-client/9.5.0/bin:$PATH"
   ./env/bin/python -c "
   import sys
   sys.path.insert(0, 'apps')
   import frappe
   from frappe.database.mariadb.setup_db import bootstrap_database

   frappe.init(site='your-site-name', sites_path='sites')
   bootstrap_database(verbose=True)
   "
   ```

7. **Create Required Directories**

   ```bash
   mkdir -p logs
   mkdir -p sites/your-site-name/logs
   mkdir -p sites/assets/erpnext/dist/js
   ```

8. **Fix Symlinks**

   ```bash
   rm -f sites/assets/erpnext sites/assets/frappe
   ln -s $(pwd)/apps/erpnext/erpnext/public sites/assets/erpnext
   ln -s $(pwd)/apps/frappe/frappe/public sites/assets/frappe
   ```

---

## Configuration Files Modified

### 1. `Procfile`

- Changed Node.js path from `/usr/bin/node` to `node`
- Updated Python services to activate virtual environment

### 2. `config/redis_cache.conf`

- Updated `dir` path to current system path

### 3. `config/redis_queue.conf`

- Updated `dir` path to current system path

### 4. `apps/frappe/frappe/public/scss/desk.bundle.scss`

- Fixed highlight.js import path

### 5. `sites/erp-next.localhost/site_config.json`

- Added `mariadb_root_password: ""` (if needed)

---

## Important Notes

### 1. MariaDB Connector Path

The MariaDB connector path may vary. To find it:

```bash
find /opt/homebrew -name "libmariadb.dylib" 2>/dev/null
```

Then update the `MYSQLCLIENT_CFLAGS` and `MYSQLCLIENT_LDFLAGS` accordingly.

### 2. MySQL Client PATH

If you encounter "mariadb not found in PATH" errors, add to your `~/.zshrc`:

```bash
export PATH="/opt/homebrew/Cellar/mysql-client/9.5.0/bin:$PATH"
```

### 3. Python Version

Ensure you're using Python 3.12:

```bash
/opt/homebrew/bin/python3.12 --version
```

### 4. Virtual Environment

Always activate the virtual environment before running bench commands:

```bash
source env/bin/activate
```

### 5. Database Credentials

Database credentials are stored in:

- `sites/erp-next.localhost/site_config.json`

**Important**: Never commit database passwords to version control!

### 6. Architecture Compatibility

When migrating between systems:

- **Ubuntu (x86_64)** → **macOS (ARM64)**: Must recreate virtual environment
- Virtual environments are not portable between different architectures

### 7. Node.js Package Managers

- Frappe uses `npm`
- ERPNext uses `yarn`
- Both need to be installed separately

### 8. Redis Configuration

Redis config files contain absolute paths. Update them when moving the bench:

- `config/redis_cache.conf`
- `config/redis_queue.conf`

---

## Verification Commands

### Check Database Connection

```bash
./env/bin/python -c "import frappe; frappe.init(site='erp-next.localhost', sites_path='sites'); frappe.connect(); print('✓ Database connection successful!')"
```

### Check Tables Exist

```bash
/opt/homebrew/Cellar/mysql-client/9.5.0/bin/mysql -u '_499a4a30007070b4' -p'ZS1T3oQzr6wjeVg6' -e "SHOW TABLES LIKE 'tab%';" _499a4a30007070b4
```

### Check Python Modules

```bash
./env/bin/python -c "import frappe; import erpnext; import MySQLdb; print('✓ All modules work')"
```

### Check Node.js Dependencies

```bash
cd apps/frappe && npm list socket.io && cd ../..
cd apps/erpnext && yarn list | grep -i highlight && cd ../..
```

---

## Troubleshooting

### Issue: "mariadb not found in PATH"

**Solution**: Add mysql client to PATH:

```bash
export PATH="/opt/homebrew/Cellar/mysql-client/9.5.0/bin:$PATH"
```

### Issue: "Table doesn't exist"

**Solution**: Bootstrap the database:

```bash
export PATH="/opt/homebrew/Cellar/mysql-client/9.5.0/bin:$PATH"
./env/bin/python -c "import sys; sys.path.insert(0, 'apps'); import frappe; from frappe.database.mariadb.setup_db import bootstrap_database; frappe.init(site='erp-next.localhost', sites_path='sites'); bootstrap_database(verbose=True)"
```

### Issue: "Access denied for user"

**Solution**: Create the database user:

```bash
sudo /opt/homebrew/Cellar/mysql-client/9.5.0/bin/mysql < create_db_user.sql
```

### Issue: "symbol not found \_mysql_affected_rows"

**Solution**: Reinstall mysqlclient with proper flags:

```bash
export MYSQLCLIENT_CFLAGS="-I/opt/homebrew/Cellar/mariadb-connector-c/3.4.7/include/mariadb"
export MYSQLCLIENT_LDFLAGS="-L/opt/homebrew/Cellar/mariadb-connector-c/3.4.7/lib/mariadb -lmariadb"
./env/bin/pip install --no-cache-dir --force-reinstall mysqlclient
```

---

## Summary

All fixes have been applied to successfully migrate the Frappe/ERPNext bench from Ubuntu to macOS. The application should now run correctly with `bench start`.

**Key Takeaways**:

1. Virtual environments must be recreated when changing architectures
2. All hardcoded paths need to be updated for the new system
3. Database must be bootstrapped after creation
4. Node.js dependencies must be installed for both frappe and erpnext
5. MySQL client must be properly linked during installation
