#!/bin/bash
# phpIPAM Integration with PowerDNS
# Tested on Rocky Linux 9.5
#
# This script automates the installation and configuration of phpIPAM on Rocky Linux 9.5.
# It prepares phpIPAM to integrate with a separate PowerDNS server by setting up:
#  - Apache Web Server (httpd) to host phpIPAM
#  - MariaDB as the backend database for phpIPAM
#  - SELinux and firewall rules to allow database connectivity and remote access
#
# 🔹 **Modifications for PowerDNS Integration:**
#   - **Database Configuration:** phpIPAM is set up with MariaDB, allowing external PowerDNS connectivity.
#   - **Firewall Adjustments:** Opens HTTP (80) and HTTPS (443) ports for web access.
#   - **SELinux Policies:** Configured to allow Apache to communicate with the database.
#
# 🔐 **Credentials Used in This Setup:**
#   - **MariaDB Root User**
#     - Username: `root`
#     - Password: `StrongRootPass123`
#     - Purpose: Full administrative access to MariaDB
#
#   - **phpIPAM Database User**
#     - Username: `phpipam`
#     - Password: `StrongPhpIPAMPass`
#     - Purpose: Grants phpIPAM access to its MySQL database
#
# 🔥 **Firewall Ports Opened:**
#   - HTTP (TCP): 80
#   - HTTPS (TCP): 443
#
# 🛡️ **SELinux Adjustments:**
#   - Allows Apache to connect externally: `setsebool -P httpd_can_network_connect on`
#   - Allows Apache to connect to the database: `setsebool -P httpd_can_network_connect_db on`
#   - Restores proper SELinux context for phpIPAM files: `restorecon -Rv /var/www/html`
#
# 🚀 **Expected Outcome:**
# After running this script, phpIPAM will be installed and accessible at `http://your-server-ip/`.
# You will need to configure PowerDNS separately to allow phpIPAM to manage DNS records.
#
# 📌 **Important:** It is strongly recommended to change the default passwords after installation!
#

# Define log file
LOGFILE="/var/log/setup_script.log"

# Function to log and execute commands
log_and_run() {
    echo "Running: $1" | tee -a $LOGFILE
    eval $1 2>&1 | tee -a $LOGFILE
}

echo "🔹 Installing phpIPAM Dependencies..."


# Install necessary packages
log_and_run "sudo dnf install -y epel-release"
log_and_run "sudo dnf install -y httpd mariadb-server mariadb php php-cli php-gd php-fpm php-common php-ldap php-pdo php-mysqlnd php-pear php-snmp php-xml php-mbstring php-mcrypt php-gmp git wget tar perl unzip"

# Start and enable required services
sudo systemctl enable --now mariadb httpd

# Secure MariaDB
echo "🔹 Configuring MariaDB..."
sudo mysql_secure_installation <<EOF

y
StrongRootPass123
StrongRootPass123
y
y
y
y
EOF

# Download and Install phpIPAM
echo "🔹 Installing phpIPAM..."
log_and_run "cd /var/www/html"
log_and_run "sudo git clone --depth=1 https://github.com/phpipam/phpipam.git ."
log_and_run "sudo cp config.dist.php config.php"

# Update database settings in phpIPAM config
echo "🔹 Configuring phpIPAM database settings..."
log_and_run "sudo sed -i "s/'DB_HOST', 'localhost'/'DB_HOST', '127.0.0.1'/" config.php"
log_and_run "sudo sed -i "s/'DB_USER', 'phpipam'/'DB_USER', 'phpipam'/" config.php"

# Restart Apache
echo "🔹 Restarting Apache..."
log_and_run "sudo systemctl restart httpd"

# Configure Firewall
echo "🔹 Configuring Firewall..."
log_and_run "sudo firewall-cmd --permanent --add-service=http"
log_and_run "sudo firewall-cmd --permanent --add-service=https"
log_and_run "sudo firewall-cmd --reload"

# Set SELinux Policies
echo "🔹 Configuring SELinux..."
log_and_run "sudo setsebool -P httpd_can_network_connect on"
log_and_run "sudo setsebool -P httpd_can_network_connect_db on"
log_and_run "sudo restorecon -Rv /var/www/html"

echo "✅ phpIPAM installation complete!"
echo "🔹 Access phpIPAM at http://your-server-ip/"
echo "Thank you for using this script!" | tee -a $LOGFILE
echo "Check out my YouTube channel: https://www.youtube.com/@thetechguysguide" | tee -a $LOGFILE
echo "Follow me on Twitter: https://twitter.com/thetechguyguide" | tee -a $LOGFILE
echo "Visit my GitHub for Scripts and Config Files: https://github.com/thetechguysguide/thetechguysguide.github.io" | tee -a $LOGFILE
