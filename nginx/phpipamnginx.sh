#!/bin/bash

# =============================================================================
#                  Thank you for using this script from TechGuysGuide!
# =============================================================================
# Disclaimer of Use:
# This script is provided as-is without any warranty or guarantee of performance.
# The TechGuysGuide are not responsible for any damages or loss of data incurred during
# the use of this script. It is recommended that you review and test the script
# in a development environment before running it on production systems.
#
# By using this script, you agree that you take full responsibility for its use
# and any consequences thereof. Proceed with caution and ensure that you have
# proper backups in place before running.
#
# =============================================================================
# Script Description:
# This script automates the installation and configuration of phpIPAM, along
# with necessary services like Nginx, MariaDB, and PHP. It also provides an
# optional installation of Webmin for system management. Below are the features
# and actions performed by the script:
#
# 1. Adding EPEL and REMI Repository:
#    - Installs the latest EPEL and Remi repositories for Fedora/RHEL 9 to enable
#      access to additional packages, including the latest versions of PHP.
#
# 2. Enabling PHP Remi repository:
#    - Resets any existing PHP modules and enables the Remi repository for PHP 8.3.
#
# 3. Installing requirements:
#    - Installs Nginx, MariaDB (MySQL-compatible database), PHP, and all dependencies
#      required for phpIPAM, including PHP-FPM, git, and other necessary tools.
#
# 4. Starting and enabling services:
#    - Ensures that Nginx, MariaDB, and PHP-FPM start and are enabled on boot so that
#      they run automatically after a system reboot.
#
# 5. MariaDB Secure Installation:
#    - Automates the equivalent of the `mysql_secure_installation` process, setting
#      a root password, removing anonymous users, and disabling remote root login.
#
# 6. Cloning phpIPAM:
#    - Clones the official phpIPAM repository into the `/var/www/html/` directory
#      for setting up the IP Address Management system.
#
# 7. Setting permissions:
#    - Adjusts ownership and permissions to ensure that Nginx can properly serve
#      the phpIPAM web files.
#
# 8. Configuring PHP-FPM:
#    - Updates the PHP-FPM configuration to run under the Nginx user and group,
#      optimizing compatibility and security for the Nginx web server.
#
# 9. Nginx configuration for phpIPAM:
#    - Adds a virtual host configuration for phpIPAM in `/etc/nginx/conf.d/phpipam.conf`.
#      This enables Nginx to correctly serve the phpIPAM application.
#
# 10. Optional Webmin installation:
#     - If enabled (via a switch at the top of the script), this installs Webmin,
#       a web-based system management tool for Unix-like systems, and configures it
#       for use.
#
# 11. Firewall configuration:
#     - Opens the HTTP port (80) in the firewall, and if Webmin is installed, also
#       opens port 10000 for Webmin.
#
# 12. Display information:
#     - Shows the IP address, hostname, and status of key services (Nginx, MariaDB, PHP-FPM)
#       at the end of the script to help verify that the installation completed successfully.
#
# 13. Curl test of webpage:
#     - Performs a basic `curl` test to ensure that the phpIPAM webpage is reachable
#       and functioning as expected.
#
# =============================================================================

# Set the MySQL root password
# MYSQL_ROOT_PASSWORD="secret"
# MYSQL_ROOT_PASSWORD="PutMYSQLpasswordhere"
# Prompt for the MySQL root password securely
read -sp "Please enter the MySQL root password: " MYSQL_ROOT_PASSWORD
echo

# Prompt for Webmin installation
echo "The Userid for Webmin is root and password is roots password from the system"
read -p "Would you like to install Webmin? (y/n): " INSTALL_WEBMIN_INPUT

# Convert user input to lowercase and set the flag
if [[ "$INSTALL_WEBMIN_INPUT" =~ ^[Yy]$ ]]; then
    INSTALL_WEBMIN=true
else
    INSTALL_WEBMIN=false
fi

echo "**** Add EPEL and REMI Repository."
dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm

echo "**** Enable PHP Remi repository."
dnf module reset php
dnf -y module enable php:remi-8.3

echo "**** Install required packages for phpIPAM and Webmin."
sudo dnf -y install nginx mariadb-server mariadb fping php php-fpm php-gmp php-pear php-mysqlnd php-gd php-mbstring php-json php-xml php-curl php-mbstring php-json php-xml php-curl git perl perl-Net-SSLeay perl-Encode-Detect perl-HTML-Parser php-pear-Mail php-snmp

echo "**** Start and enable Nginx, MariaDB, and PHP-FPM services."
sudo systemctl start nginx
sudo systemctl enable nginx

sudo systemctl start mariadb
sudo systemctl enable mariadb

sudo systemctl start php-fpm
sudo systemctl enable php-fpm

# Automate MySQL Secure Installation
echo "**** Automating MySQL Secure Installation steps."

# Set root password
sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';"

# Remove anonymous users
sudo mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='';"

# Disallow root login remotely
sudo mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DELETE FROM mysql.user WHERE User='root' AND Host!='localhost';"

# Remove the test database
sudo mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"

# Reload privilege tables
sudo mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"

echo "**** MariaDB secure installation steps completed."
# Sleep
sleep 3

echo "**** Start git clone in the background."
sudo git clone --recursive https://github.com/phpipam/phpipam.git /var/www/html/ &
clone_pid=$!

# Wait for the clone process to finish
wait $clone_pid

# Ensure submodules are updated properly after the clone
cd /var/www/html
sudo git submodule update --init --recursive

# Checkout version 1.6
git checkout -b 1.6 origin/1.6

echo "**** Git clone completed."
# Sleep
sleep 3

echo "**** Change ownership to Nginx and adjust permissions."
sudo chown -R nginx:nginx /var/www/html
sudo chmod -R 755 /var/www/html

echo "**** Copy and modify config.php."
cp config.dist.php config.php
sed -i "s/\$db\['host'\] = '127.0.0.1';/\$db\['host'\] = 'localhost';/" config.php

echo "**** Configure PHP-FPM to use Nginx."
sed -i "s/user = apache/user = nginx/" /etc/php-fpm.d/www.conf
sed -i "s/group = apache/group = nginx/" /etc/php-fpm.d/www.conf
sed   -i "s/;listen.owner = nobody/listen.owner = nginx/" /etc/php-fpm.d/www.conf
sed -i "s/;listen.group = nobody/listen.group = nginx/" /etc/php-fpm.d/www.conf
sed -i "s/;listen.mode = 0660/listen.mode = 0660/" /etc/php-fpm.d/www.conf

echo "**** Restart PHP-FPM service to apply changes."
sudo systemctl restart php-fpm

echo "**** Configure Nginx for phpIPAM."
cat <<EOL | sudo tee /etc/nginx/conf.d/phpipam.conf
server {
    listen 80;
    server_name your_domain_or_ip;

    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php\$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:/run/php-fpm/www.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    error_log /var/log/nginx/phpipam_error.log;
    access_log /var/log/nginx/phpipam_access.log;
}
EOL

echo "**** Test Nginx configuration and restart service."
sudo nginx -t

**** Pause
sleep 5

sudo systemctl restart nginx

echo "**** Configure firewall to allow HTTP traffic."
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload

# Check if Webmin installation is enabled
if [ "$INSTALL_WEBMIN" = true ]; then
    echo "**** Webmin installation is enabled. Installing Webmin..."
   
    # Create the Webmin repository file
    cat <<EOL | sudo tee /etc/yum.repos.d/webmin.repo
[Webmin]
name=Webmin Distribution Neutral
baseurl=https://download.webmin.com/download/yum
enabled=1
gpgcheck=1
gpgkey=https://download.webmin.com/jcameron-key.asc
EOL

    # Install Webmin
    sudo dnf -y install webmin

    # Start and enable Webmin
    sudo systemctl start webmin
    sudo systemctl enable webmin

    # Open firewall port for Webmin
    sudo firewall-cmd --add-port=10000/tcp --permanent
    sudo firewall-cmd --reload

    echo "**** Webmin installation completed."
else
    echo "**** Webmin installation is skipped."
fi


# Display status of key services (Nginx, MariaDB, PHP-FPM)
echo "**** Checking status of important services."
# Check Nginx status
if systemctl is-active --quiet nginx; then
  echo "Nginx is running."
else
  echo "Nginx is not running. Please check the configuration."
fi
# Check MariaDB status
if systemctl is-active --quiet mariadb; then
  echo "MariaDB is running."
else
  echo "MariaDB is not running. Please check the configuration."
fi

# Check PHP-FPM status
if systemctl is-active --quiet php-fpm; then
  echo "PHP-FPM is running."
else
  echo "PHP-FPM is not running. Please check the configuration."
fi

# Perform a curl test to check if the website is reachable
WEBPAGE_URL="http://localhost"

echo "**** Performing curl test to check if the webpage is running at $WEBPAGE_URL"

# Using curl to test the webpage
HTTP_STATUS=$(curl -o /dev/null -s -w "%{http_code}" $WEBPAGE_URL)

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "Webpage is accessible and returned HTTP status 200 (OK)."
else
  echo "Webpage returned HTTP status $HTTP_STATUS. Something might be wrong."
fi

# Suggest checking log files for troubleshooting
echo "**** Please review log files for any errors:"
echo "Nginx log: /var/log/nginx/error.log"
echo "MariaDB log: /var/log/mariadb/mariadb.log"
echo "PHP-FPM log: /var/log/php-fpm/error.log"

# Check for any failed systemd services
echo "**** Checking for failed systemd services."
systemctl --failed

echo "**** Script is done! Showing server information."
echo ""
echo ""
echo ""
echo "Thanks for using this script the Techguysguide."
echo ""
echo ""
echo ""
echo ""
