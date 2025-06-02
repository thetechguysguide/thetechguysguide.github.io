phpIPAM Installation Script

Overview

This repository contains a Bash script (install-phpipam.sh) that automates the installation and configuration of phpIPAM, an open-source IP address management (IPAM) tool, on Debian-based or Ubuntu-based Linux systems. The script sets up a complete LAMP stack (Apache2, MariaDB, PHP 8.2) and configures phpIPAM with a secure MariaDB database, Apache virtual host, and firewall rules.

Features
  Automated LAMP Stack Setup: Installs Apache2, MariaDB, PHP 8.2, and required dependencies.
  Secure MariaDB Configuration: Uses the expect utility to automate mysql_secure_installation, setting a root password, removing anonymous users, disabling remote root login, and dropping the test database.
  phpIPAM Database Setup: Creates a dedicated database and user for phpIPAM with secure credentials.
  Apache Configuration: Sets up a virtual host for phpIPAM and enables URL rewriting.

Firewall Rules: Configures UFW to allow HTTP (port 80) and SSH access.

Post-GUI Setup: Generates a script to disable phpIPAM installation scripts after web-based setup.

Logging: All actions are logged to install-phpipam.log for debugging and verification.

Prerequisites
  Operating System: Debian 11 (Bullseye) or later, Ubuntu 20.04 (Focal Fossa), 22.04 (Jammy Jellyfish), or other compatible Debian-based distributions.
  Root Privileges: Script must be run with sudo to install packages and modify system files.
  Internet Access: Required for downloading packages and cloning the phpIPAM repository from GitHub.
  Clean System: Existing MariaDB data will be backed up and removed. Ensure critical data is backed up manually.
  Disk Space: Sufficient space for package installation and MariaDB data.
  Expect Package: Required for automating MariaDB secure installation.

Installation
  Clone or Download the Script:
  git clone <repository-url>
  cd <repository-directory>
  
  Make the Script Executable:
    chmod +x install-phpipam.sh
  Run the Script:
    sudo ./install-phpipam.sh

Complete Web-Based Setup:

After the script completes, open a browser and navigate to http://<server-ip> to run the phpIPAM web installer.

Follow the on-screen instructions to configure phpIPAM.
Run Post-GUI Setup Script:

sudo bash /var/www/html/phpipam/post-gui-setup.sh

This disables the phpIPAM installation scripts for security.

Configuration

Edit the configurable settings at the top of install-phpipam.sh to customize:
  IPAM_DB_NAME: Database name (default: phpipam)
  IPAM_DB_USER: Database user (default: phpipamuser)
  IPAM_DB_PASS: Database user password (default: StrongPassword123!)
  MYSQL_ROOT_PASSWORD: MariaDB root password (default: MyRootPass123!)
  WEB_DIR: Web directory (default: /var/www/html/phpipam)
  TIMEZONE: System timezone (default: America/Los_Angeles)
  HOSTNAME: System hostname (default: phpipam-server)
  LOGFILE: Log file name (default: install-phpipam.log)

Notes
  Backup: Existing MariaDB data is backed up to /var/lib/mysql.bak-<timestamp> before removal.
  Logs: Check install-phpipam.log for errors if the script fails.
  Security: Ensure strong passwords for MYSQL_ROOT_PASSWORD and IPAM_DB_PASS.
  AppArmor/SELinux: May require configuration if file access issues occur.
  PHP Version: The script installs PHP 8.2 via the ondrej/php PPA.

Troubleshooting

MariaDB Errors: Check logs with journalctl -u mariadb -n 50 --no-pager.
Apache Errors: Verify configuration with apache2ctl configtest and check logs in /var/log/apache2/.
Permissions: Ensure /var/www/html/phpipam is owned by www-data:www-data.
Firewall: Confirm UFW rules with sudo ufw status.

Regularly update phpIPAM and system packages:

sudo apt update && sudo apt upgrade
cd /var/www/html/phpipam
sudo git pull

License
  This script is provided under the MIT License. See LICENSE for details.

Author: thetechguysguide

Last Updated
June 1, 2025
