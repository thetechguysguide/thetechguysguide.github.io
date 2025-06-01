#!/bin/bash
# install-phpipam.sh – Automated Installation Script for phpIPAM on Debian/Ubuntu Systems
#
# Description:
# This script automates the installation and configuration of phpIPAM, an open-source IP address management (IPAM) tool,
# on Debian-based or Ubuntu-based Linux systems. It sets up a complete LAMP stack (Apache2, MariaDB, PHP 8.2) and configures
# phpIPAM with a secure MariaDB database, Apache virtual host, and firewall rules. The script uses the 'expect' utility to
# automate the 'mysql_secure_installation' process, ensuring a secure MariaDB setup by setting the root password, removing
# anonymous users, disabling remote root login, and dropping the test database.
#
# Target Systems:
# - Debian 11 (Bullseye) or later
# - Ubuntu 20.04 (Focal Fossa), 22.04 (Jammy Jellyfish), or later
# - Other Debian-based distributions with compatible package management (apt)
#
# Prerequisites:
# - Must be run with root privileges (sudo) to install packages and modify system files.
# - Internet access for downloading packages and the phpIPAM repository from GitHub.
# - A clean system or one where existing MariaDB data can be safely backed up and removed.
# - The 'expect' package is required for automating MariaDB secure installation.
#
# Key Features:
# - Installs required packages: Apache2, MariaDB, PHP 8.2, and dependencies.
# - Resets existing MariaDB data (with backup) to ensure a clean setup.
# - Initializes the MariaDB data directory and sets correct permissions.
# - Automates 'mysql_secure_installation' to configure the MariaDB root user and secure the database.
# - Creates a dedicated phpIPAM database and user with secure credentials.
# - Configures Apache2 with a virtual host for phpIPAM and enables URL rewriting.
# - Sets up UFW firewall rules to allow HTTP (port 80) and SSH access.
# - Clones the phpIPAM repository from GitHub and configures initial settings.
# - Generates a post-GUI setup script to disable phpIPAM installation scripts after web-based setup.
# - Logs all actions to 'install-phpipam.log' for debugging and verification.
#
# Usage:
#   sudo ./install-phpipam.sh
# After running, complete the phpIPAM web-based setup at http://<server-ip> and then run:
#   sudo bash /var/www/html/phpipam/post-gui-setup.sh
#
# Notes:
# - Ensure sufficient disk space for package installation and MariaDB data.
# - The script backs up existing MariaDB data to /var/lib/mysql.bak-<timestamp> before removal.
# - Customize configurable settings (e.g., database name, passwords, hostname) at the top of the script.
# - Check 'install-phpipam.log' for errors if the script fails.
# - AppArmor or SELinux may require configuration if file access issues occur.
#
# Author: [Your Name or leave blank]
# Last Updated: June 1, 2025

set -e
export DEBIAN_FRONTEND=noninteractive

# ----------- CONFIGURABLE SETTINGS -----------
IPAM_DB_NAME="phpipam"
IPAM_DB_USER="phpipamuser"
IPAM_DB_PASS="StrongPassword123!"
MYSQL_ROOT_PASSWORD="MyRootPass123!"
WEB_DIR="/var/www/html/phpipam"
TIMEZONE="America/Los_Angeles"
HOSTNAME="phpipam-server"
LOGFILE="install-phpipam.log"
# ---------------------------------------------

exec > >(tee -a "$LOGFILE") 2>&1

echo "==> Installing required tools..."
sudo apt update && sudo apt install -y expect curl wget nano ufw git unzip net-tools software-properties-common lsb-release ca-certificates apt-transport-https gnupg apache2 mariadb-server

echo "==> Checking for existing MariaDB data..."
if [ -d "/var/lib/mysql" ]; then
    echo "Warning: Existing MariaDB data found. Stopping MariaDB and removing..."
    sudo systemctl stop mariadb || true
    if systemctl is-active --quiet mariadb; then
        echo "Error: Failed to stop MariaDB service. Check logs with 'journalctl -u mariadb'."
        exit 1
    fi
    sudo rm -rf /var/lib/mysql.bak-$(date +%F_%H-%M-%S) || true
    sudo mv /var/lib/mysql /var/lib/mysql.bak-$(date +%F_%H-%M-%S) || {
        echo "Error: Failed to move /var/lib/mysql. Check permissions or file locks."
        exit 1
    }
    echo "MariaDB data backed up to /var/lib/mysql.bak-$(date +%F_%H-%M-%S)"
fi

echo "==> Ensuring MariaDB data directory..."
sudo mkdir -p /var/lib/mysql
sudo chown mysql:mysql /var/lib/mysql
sudo chmod 700 /var/lib/mysql

echo "==> Installing MariaDB..."
sudo apt install -y mariadb-server

echo "==> Initializing MariaDB data directory..."
if [ -z "$(ls -A /var/lib/mysql)" ]; then
    sudo mariadb-install-db --user=mysql --datadir=/var/lib/mysql
    if [ $? -ne 0 ]; then
        echo "Error: Failed to initialize MariaDB data directory. Check logs."
        exit 1
    fi
else
    echo "Warning: /var/lib/mysql is not empty. Ensuring correct permissions..."
    sudo chown -R mysql:mysql /var/lib/mysql
    sudo chmod -R 700 /var/lib/mysql
fi

echo "==> Starting MariaDB service..."
sudo systemctl enable mariadb
sudo systemctl start mariadb
if ! systemctl is-active --quiet mariadb; then
    echo "Error: MariaDB service failed to start. Check logs with 'journalctl -u mariadb'."
    sudo journalctl -u mariadb -n 50 --no-pager
    exit 1
fi

echo "==> Automating mysql_secure_installation using expect..."
sudo expect <<EOD
set timeout 30
spawn mysql_secure_installation
expect {
    "Enter current password for root (enter for none):" {
        send "\r"
        exp_continue
    }
    "Switch to unix_socket authentication" {
        send "n\r"
        exp_continue
    }
    "Change the root password?" {
        send "y\r"
    }
    "Set root password?" {
        send "y\r"
    }
    timeout {
        send_user "Error: mysql_secure_installation timed out waiting for prompt.\n"
        exit 1
    }
}
expect {
    "New password:" {
        send "$MYSQL_ROOT_PASSWORD\r"
    }
    timeout {
        send_user "Error: Timed out waiting for password prompt.\n"
        exit 1
    }
}
expect {
    "Re-enter new password:" {
        send "$MYSQL_ROOT_PASSWORD\r"
    }
    timeout {
        send_user "Error: Timed out waiting for re-enter password prompt.\n"
        exit 1
    }
}
expect {
    "Remove anonymous users?" {
        send "y\r"
    }
    timeout {
        send_user "Error: Timed out waiting for anonymous users prompt.\n"
        exit 1
    }
}
expect {
    "Disallow root login remotely?" {
        send "y\r"
    }
    timeout {
        send_user "Error: Timed out waiting for remote login prompt.\n"
        exit 1
    }
}
expect {
    "Remove test database and access to it?" {
        send "y\r"
    }
    timeout {
        send_user "Error: Timed out waiting for test database prompt.\n"
        exit 1
    }
}
expect {
    "Reload privilege tables now?" {
        send "y\r"
    }
    timeout {
        send_user "Error: Timed out waiting for reload privileges prompt.\n"
        exit 1
    }
}
expect eof
EOD
if [ $? -ne 0 ]; then
    echo "Error: mysql_secure_installation failed. Check logs for details."
    sudo journalctl -u mariadb -n 50 --no-pager
    exit 1
fi

echo "==> Testing MariaDB root login..."
if ! mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" 2>/dev/null; then
    echo "Error: Cannot connect to MariaDB as root. Attempting to reset password..."
    sudo systemctl stop mariadb
    sudo mysqld_safe --skip-grant-tables &
    sleep 5
    mysql -u root <<EOF
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
EOF
    sudo killall mysqld
    sudo systemctl start mariadb
    if ! systemctl is-active --quiet mariadb; then
        echo "Error: MariaDB service failed to start after password reset. Check logs with 'journalctl -u mariadb'."
        sudo journalctl -u mariadb -n 50 --no-pager
        exit 1
    fi
    if ! mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" 2>/dev/null; then
        echo "Error: Failed to reset root password. Check logs."
        sudo journalctl -u mariadb -n 50 --no-pager
        exit 1
    fi
fi

echo "==> Creating phpIPAM database and user..."
mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF
CREATE DATABASE IF NOT EXISTS $IPAM_DB_NAME;
CREATE USER IF NOT EXISTS '$IPAM_DB_USER'@'localhost' IDENTIFIED BY '$IPAM_DB_PASS';
GRANT ALL PRIVILEGES ON $IPAM_DB_NAME.* TO '$IPAM_DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "==> Setting hostname and timezone..."
sudo hostnamectl set-hostname "$HOSTNAME"
sudo timedatectl set-timezone "$TIMEZONE"

echo "==> Firewall rules..."
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw --force enable

echo "==> Installing PHP 8.2 and dependencies..."
sudo apt purge -y php* libapache2-mod-php || true
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y php8.2 php8.2-mysql php8.2-gd php8.2-curl php8.2-mbstring php8.2-xml php8.2-zip php8.2-gmp php8.2-bcmath php8.2-intl php8.2-cli php-pear libapache2-mod-php8.2
sudo update-alternatives --install /usr/bin/php php /usr/bin/php8.2 82
sudo update-alternatives --set php /usr/bin/php8.2

echo "==> Downloading and configuring phpIPAM..."
cd /var/www/html
sudo rm -rf phpipam
sudo git clone https://github.com/phpipam/phpipam.git
sudo chown -R www-data:www-data phpipam
cd phpipam
sudo cp config.dist.php config.php

echo "==> Creating Apache virtual host..."
sudo tee /etc/apache2/sites-available/phpipam.conf > /dev/null <<EOF
<VirtualHost *:80>
    DocumentRoot /var/www/html/phpipam
    ServerName phpipam.local

    <Directory /var/www/html/phpipam>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

sudo a2ensite phpipam.conf
sudo a2dissite 000-default.conf
sudo a2enmod rewrite
sudo systemctl reload apache2

echo "==> Creating post-GUI setup script..."
INSTALL_DIR="/var/www/html/phpipam"
sudo tee "$INSTALL_DIR/post-gui-setup.sh" > /dev/null <<EOP
#!/bin/bash
CONFIG_FILE="/var/www/html/phpipam/config.php"
if [ ! -f "\$CONFIG_FILE" ]; then
    echo "Error: \$CONFIG_FILE does not exist."
    exit 1
fi
if ! sudo test -w "\$CONFIG_FILE"; then
    echo "Error: \$CONFIG_FILE is not writable. Check permissions."
    exit 1
fi
if grep -q 'disable_installer' "\$CONFIG_FILE"; then
    sudo sed -i 's/\$disable_installer *= *false;/\$disable_installer = true;/' "\$CONFIG_FILE"
    if grep -q '\$disable_installer = true;' "\$CONFIG_FILE"; then
        echo "Installation script disabled in config.php"
    else
        echo "Error: Failed to update \$disable_installer in \$CONFIG_FILE."
        exit 1
    fi
else
    echo "disable_installer setting not found in config.php"
    exit 1
fi
EOP

if [ -f "$INSTALL_DIR/post-gui-setup.sh" ]; then
    sudo chmod +x "$INSTALL_DIR/post-gui-setup.sh"
    echo "Post-GUI setup script created at $INSTALL_DIR/post-gui-setup.sh"
else
    echo "Error: Failed to create post-gui-setup.sh. Check permissions in $INSTALL_DIR."
    exit 1
fi

SERVER_IP=$(hostname -I | awk '{print $1}')
echo
echo "  INSTALLATION COMPLETE"
echo "--------------------------------------------------"
echo "Access phpIPAM in your browser at: http://$SERVER_IP"
echo
echo "  AFTER completing the GUI installer, run:"
echo "   sudo bash $INSTALL_DIR/post-gui-setup.sh"
echo "--------------------------------------------------"
