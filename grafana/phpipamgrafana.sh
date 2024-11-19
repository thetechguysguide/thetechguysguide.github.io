#!/bin/bash

# -----------------------------
# Legal Disclaimer:
# -----------------------------
# This script is provided "as is" and without any express or implied warranties, including, without limitation, the implied warranties of merchantability and fitness for a particular purpose. 
# The author of this script assumes no liability for any damage or data loss caused by the use of this script, directly or indirectly. 
# It is the user's responsibility to thoroughly review, test, and modify this script before deploying it in a production environment.
# This script is intended for educational and informational purposes only. Use it at your own risk and discretion.

clear

# This script installs Webmin, Grafana, MariaDB, PHP, and phpIPAM on Rocky Linux.
# Please review and confirm default values before running.

# Define log file with date in filename for uniqueness
LOGFILE="/var/log/setup_script_$(date +'%Y%m%d').log"

# Function to log and execute commands with timestamp
log_and_run() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Running: $1" | tee -a $LOGFILE
    eval $1 2>&1 | tee -a $LOGFILE
}

# Description Key and Default Settings
echo "Welcome to the phpIPAM setup script. Below, you'll enter credentials and settings needed for installation."
echo "You can press Enter to use the default values shown in brackets."
echo ""
echo "The following settings are required:"
echo "  - MySQL Root Password: For administrative access to MySQL. Not shown as you type."
echo "  - phpIPAM Database Credentials: Name, User, Password, Host, and Port for phpIPAM database access."
echo "  - Webmin Admin Password: Set the password for Webmin access."
echo "  - phpIPAM Admin Password: Set the password for the phpIPAM admin user."
echo "  - Grafana Admin Password: Password for Grafana initial setup."
echo ""

# Prompt for passwords and other values with default settings
echo "Please enter the following credentials for setup. Press Enter to use defaults where available."

# MySQL root password prompt
read -sp "MySQL Root Password: " MYSQL_ROOT_PASS
echo

# Webmin credentials
WEBMIN_USER="admin"  # Default Webmin username
read -sp "Webmin Admin Password: " WEBMIN_PASS
echo

# phpIPAM admin password prompt
read -sp "phpIPAM Admin Password: " PHPIPAM_ADMIN_PASS
echo

# Grafana admin password prompt
read -sp "Grafana Admin Password: " GRAFANA_ADMIN_PASS
echo

# phpIPAM database credentials with defaults
PHPIPAM_DB="phpipam"          # Default database name
PHPIPAM_USER="phpipam"        # Default username
PHPIPAM_PASS="phpipamadmin"   # Default password
PHPIPAM_HOST="localhost"      # Default host not needed addressed with sed
PHPIPAM_PORT="3306"           # Default port not needed addressed with sed

# phpIPAM database please confirm or override defaults
echo ""
echo "Confirm or override defaults"
echo ""

read -p "phpIPAM Database Name [default: $PHPIPAM_DB]: " input
PHPIPAM_DB="${input:-$PHPIPAM_DB}"

read -p "phpIPAM Database User [default: $PHPIPAM_USER]: " input
PHPIPAM_USER="${input:-$PHPIPAM_USER}"

read -sp "phpIPAM Database Password [default: $PHPIPAM_PASS]: " input
PHPIPAM_PASS="${input:-$PHPIPAM_PASS}"
echo

# Summary of entered settings for confirmation
echo ""
echo "You have entered the following settings:"
echo "  - MySQL Root Password: [hidden]"
echo "  - Webmin Admin Username: $WEBMIN_USER"
echo "  - Webmin Admin Password: [hidden]"
echo "  - phpIPAM Admin Password: [hidden]"
echo "  - phpIPAM Database Name: $PHPIPAM_DB"
echo "  - phpIPAM Database User: $PHPIPAM_USER"
echo "  - phpIPAM Database Password: [hidden]"
echo "  - phpIPAM Database Host: $PHPIPAM_HOST"
echo "  - phpIPAM Database Port: $PHPIPAM_PORT"

echo ""
echo "If these settings are correct, press Enter to continue, or Ctrl+C to abort."
read -p ""

# Update the system
log_and_run "dnf -y update"

# Install Apache and firewall configuration
log_and_run "dnf install -y httpd httpd-tools"
log_and_run "systemctl enable httpd"
log_and_run "systemctl start httpd"
log_and_run "firewall-cmd --permanent --zone=public --add-service=http"
log_and_run "firewall-cmd --permanent --zone=public --add-service=https"
log_and_run "firewall-cmd --reload"

# Install EPEL and Remi repositories for PHP and related packages
log_and_run "dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm"
log_and_run "dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm"

# Enable PHP 8.3 and install additional PHP packages and tools
log_and_run "dnf -y module enable php:remi-8.3"
log_and_run "dnf -y install php php-cli php-fpm php-common php-gd php-ldap php-pdo php-mysqlnd php-pear php-snmp php-xml php-mbstring php-gmp php-mcrypt wget tar perl perl-DBD-MySQL net-snmp fping git nginx"
log_and_run "dnf --enablerepo=devel -y install perl-IO-Tty"


# Start and enable PHP-FPM
log_and_run "systemctl enable php-fpm"
log_and_run "systemctl start php-fpm"
log_and_run "systemctl restart httpd"

# Install MariaDB (MySQL)
log_and_run "dnf install -y mariadb-server mariadb"
log_and_run "systemctl enable mariadb"
log_and_run "systemctl start mariadb"

# Secure MySQL installation
log_and_run "mysql -u root -p$MYSQL_ROOT_PASS -e \"DELETE FROM mysql.user WHERE User='';\""
log_and_run "mysql -u root -p$MYSQL_ROOT_PASS -e \"DROP DATABASE IF EXISTS test;\""
log_and_run "mysql -u root -p$MYSQL_ROOT_PASS -e \"DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';\""
log_and_run "mysql -u root -p$MYSQL_ROOT_PASS -e \"FLUSH PRIVILEGES;\""

# Create phpIPAM database and user
log_and_run "mysql -u root -p$MYSQL_ROOT_PASS -e \"CREATE DATABASE $PHPIPAM_DB;\""
log_and_run "mysql -u root -p$MYSQL_ROOT_PASS -e \"CREATE USER '$PHPIPAM_USER'@'$PHPIPAM_HOST' IDENTIFIED BY '$PHPIPAM_PASS';\""
log_and_run "mysql -u root -p$MYSQL_ROOT_PASS -e \"GRANT ALL PRIVILEGES ON $PHPIPAM_DB.* TO '$PHPIPAM_USER'@'$PHPIPAM_HOST';\""
log_and_run "mysql -u root -p$MYSQL_ROOT_PASS -e \"FLUSH PRIVILEGES;\""

# Restart MariaDB
log_and_run "systemctl restart mariadb"
sleep 10

# Clone phpIPAM repository
log_and_run "git clone --recursive https://github.com/phpipam/phpipam.git /var/www/html/"

# Copy config.dist.php to config.php if it does not exist
log_and_run "cp /var/www/html/config.dist.php /var/www/html/config.php"

# Change to phpIPAM directory and import schema
cd /var/www/html
log_and_run "mysql -u $PHPIPAM_USER -p$PHPIPAM_PASS $PHPIPAM_DB < /var/www/html/db/SCHEMA.sql"

# Update phpIPAM config.php with database details
# log_and_run "sed -i \"s/\$db\['host'\] = 'localhost';/\$db\['host'\] = '$PHPIPAM_HOST';/\" /var/www/html/config.php"
# log_and_run "sed -i \"s/\$db\['user'\] = 'phpipam';/\$db\['user'\] = '$PHPIPAM_USER';/\" /var/www/html/config.php"
# log_and_run "sed -i \"s/\$db\['pass'\] = 'phpipamadmin';/\$db\['pass'\] = '$PHPIPAM_PASS';/\" /var/www/html/config.php"
# log_and_run "sed -i \"s/\$db\['name'\] = 'phpipam';/\$db\['name'\] = '$PHPIPAM_DB';/\" /var/www/html/config.php"
# log_and_run "sed -i \"s/\$db\['port'\] = 3306;/\$db\['port'\] = $PHPIPAM_PORT;/\" /var/www/html/config.php"

# Automate changing 127.0.0.1 to localhost in config.php
log_and_run "sed -i 's/127.0.0.1/localhost/' config.php"

# Automate changing disable_installer = false to disable_installer = true in config.php
log_and_run "sed -i 's/disable_installer = false/disable_installer = true/' config.php"

# Hash the phpIPAM admin password
HASHED_PASS=$(php -r "echo password_hash('$PHPIPAM_ADMIN_PASS', PASSWORD_DEFAULT);")

# Update phpIPAM admin password using single quotes for the SQL statement
log_and_run "mysql -u $PHPIPAM_USER -p$PHPIPAM_PASS $PHPIPAM_DB -e 'UPDATE users SET password = \"$HASHED_PASS\" WHERE username = \"Admin\";'"

log_and_run "mysql -u root -p$MYSQL_ROOT_PASS -D phpipam -e \"UPDATE users SET passChange = 'No' WHERE username = 'Admin';\""
sleep 5

# Install Webmin
log_and_run "dnf -y install perl perl-DBI perl-IO-Tty"
log_and_run "wget https://www.webmin.com/download/webmin-current.tar.gz"
tar xvf webmin-current.tar.gz
WEBMIN_DIR=$(tar -tf webmin-current.tar.gz | head -1 | cut -f1 -d"/")
log_and_run "sudo mkdir -p /usr/local/webmin"
# Define the absolute path for Webmin installation
WEBMIN_INSTALL_DIR="/usr/local/webmin"

# Run Webmin setup script with absolute paths
sudo ./$WEBMIN_DIR/setup.sh $WEBMIN_INSTALL_DIR <<EOF
/etc/webmin
/var/webmin
/usr/bin/perl
10000
$WEBMIN_USER
$WEBMIN_PASS
$WEBMIN_PASS
y
y
EOF

# Configure firewall for Webmin
log_and_run "sudo firewall-cmd --add-port=10000/tcp --permanent"
log_and_run "sudo firewall-cmd --reload"

# Restart Webmin
log_and_run "sudo systemctl restart webmin"

# Install perl-DBD-MYSQL for Webmin  Moved to top
# log_and_run "sudo dnf install -y perl-DBD-MySQL"

sleep 5
# Install Grafana repository and Grafana itself
echo "[grafana]
name=Grafana Repository
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key" | sudo tee /etc/yum.repos.d/grafana.repo > /dev/null

log_and_run "dnf -y install grafana"
log_and_run "systemctl start grafana-server"
log_and_run "systemctl enable grafana-server"

# Enable Grafana through the firewall on port 3000
log_and_run "firewall-cmd --zone=public --add-port=3000/tcp --permanent"
log_and_run "firewall-cmd --reload"

# Configure MySQL Data Source in Grafana
GRAFANA_API_URL="http://localhost:3000/api/datasources"
GRAFANA_ADMIN_USER="admin"  # Assuming default admin username
PHPIPAM_DB_HOST="localhost" # Host of phpIPAM's MariaDB database
GRAFANA_ADMIN_PASS="$GRAFANA_ADMIN_PASS"  # Admin Password from top
PHPIPAM_DB="$PHPIPAM_DB"
PHPIPAM_USER="$PHPIPAM_USER"  
PHPIPAM_PASS="$PHPIPAM_PASS"

# Update Grafana Admin Password
echo "Resetting Grafana Admin Password..."
grafana-cli admin reset-admin-password $GRAFANA_ADMIN_PASS
if [ $? -ne 0 ]; then
    echo "Failed to reset Grafana admin password"
    exit 1
fi

# Restart Grafana Server
systemctl restart grafana-server
if [ $? -ne 0 ]; then
    echo "Failed to restart Grafana server"
    exit 1
fi

# JSON payload for MySQL data source setup in Grafana
MYSQL_DATASOURCE_JSON=$(cat <<EOF
{
  "name": "phpIPAM MySQL",
  "type": "mysql",
  "access": "proxy",
  "url": "$PHPIPAM_DB_HOST:3306",
  "database": "$PHPIPAM_DB",
  "user": "$PHPIPAM_USER",
  "secureJsonData": {
    "password": "$PHPIPAM_PASS"
  }
}
EOF
)

# Create MySQL data source in Grafana
curl -X POST $GRAFANA_API_URL \
    -H "Content-Type: application/json" \
    -u $GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASS \
    -d "$MYSQL_DATASOURCE_JSON"


# Clean up installation files
log_and_run "rm -f webmin-current.tar.gz"
log_and_run "rm -rf $WEBMIN_DIR"

clear
sleep 2
echo "**** Script is done!"
echo ""
echo ""
echo ""
echo "Thanks for using this script the Techguysguide."
echo ""
echo ""
echo ""
echo ""
# Display server information and URLs
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Server Information and URLs!"
echo "phpIPAM: http://$SERVER_IP/"
echo "Webmin: https://$SERVER_IP:10000"
echo "Grafana: http://$SERVER_IP:3000"
