#!/bin/bash

# Hello,
# 
# This Bash script is used to build a fresh instance of phpIPAM from a minimal OS install. 
# It has been confirmed to work with Rocky Linux versions 9.1 to 9.4. 
# The following items are installed:
# 
# 	Apache, with firewall configured (ports 80/443 opened).
# 	EPEL and Remi repositories.
# 	PHP 8.3, along with necessary packages for phpIPAM and Webmin.
# 	MariaDB, installed and configured with MySQL secure installation.
# 	Webmin, installed and firewall configured (accessible at https://yourserverIP:10000).
# 	phpIPAM, downloaded from Git and installed as version 1.6, then configured for initial setup.
# 	Note: All user IDs and passwords are as follows:
# 		MariaDB: root/<password>
# 		Webmin: admin/<password>
#
# Thanks for using this script have a great day!


# Define log file
LOGFILE="/var/log/setup_script.log"

# Function to log and execute commands
log_and_run() {
    echo "Running: $1" | tee -a $LOGFILE
    eval $1 2>&1 | tee -a $LOGFILE
}

# Update the system
log_and_run "dnf -y update"

# Install Apache and tools
log_and_run "dnf install -y httpd httpd-tools"
log_and_run "systemctl enable httpd"
log_and_run "systemctl start httpd"

# Wait for Apache to start
sleep 5

# Configure firewall for HTTP and HTTPS
log_and_run "firewall-cmd --permanent --zone=public --add-service=http"
log_and_run "firewall-cmd --permanent --zone=public --add-service=https"
log_and_run "firewall-cmd --reload"

# Install EPEL and Remi repositories
log_and_run "dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm"
log_and_run "dnf -y install https://rpms.remirepo.net/enterprise/remi-release-9.rpm"

# Enable PHP 8.3 module and install PHP
log_and_run "dnf -y module enable php:remi-8.3"
log_and_run "dnf -y install php"

# Install additional PHP packages and other software
log_and_run "dnf -y install php php-cli php-gd php-fpm php-common php-ldap php-pdo php-mysqlnd php-pear php-snmp php-xml php-mbstring php-mcrypt php-gmp git nginx wget tar perl net-snmp"

# Enable and start PHP-FPM
log_and_run "systemctl enable php-fpm"
log_and_run "systemctl start php-fpm"

# Wait for PHP-FPM to start
sleep 5

# Restart Apache to apply changes
log_and_run "systemctl restart httpd"

# Install and configure MariaDB
log_and_run "dnf install -y mariadb-server mariadb"
log_and_run "systemctl enable mariadb"
log_and_run "systemctl start mariadb"

# Wait for MariaDB to start
sleep 5

# Install expect for automating mysql_secure_installation
log_and_run "dnf -y install expect"

# Create the expect script for mysql_secure_installation
cat << 'EOF' > mysql_secure_installation.expect
#!/usr/bin/expect -f

spawn mysql_secure_installation

expect "Enter current password for root (enter for none):"
send "\r"
expect "Switch to unix_socket authentication \[Y/n\]" 
send "y\r"
expect "Set root password? \[Y/n\]"
send "y\r"
expect "New password:"
send "<password>\r"
expect "Re-enter new password:"
send "<password>\r"
expect "Remove anonymous users? \[Y/n\]"
send "y\r"
expect "Disallow root login remotely? \[Y/n\]"
send "y\r"
expect "Remove test database and access to it? \[Y/n\]"
send "y\r"
expect "Reload privilege tables now? \[Y/n\]"
send "y\r"
expect eof
EOF

# Make the expect script executable
log_and_run "chmod +x mysql_secure_installation.expect"

# Run mysql_secure_installation using expect script
log_and_run "./mysql_secure_installation.expect"

# Install Perl DBI MySQL
log_and_run "dnf -y install 'perl(DBD::mysql)'"

# Install Perl WebMin Module
log_and_run "dnf -y install 'perl(IO::Pty)'"


# Download and set up Webmin
log_and_run "wget https://www.webmin.com/download/webmin-current.tar.gz"

sleep 10

log_and_run "tar xvf webmin-current.tar.gz"

sleep 5

log_and_run "sudo mkdir -p /usr/local/webmin"

sleep 5

# Create the expect script for Webmin setup
cat << 'EOF' > webmin_setup.expect
#!/usr/bin/expect -f

spawn sudo ./webmin-2.202/setup.sh /usr/local/webmin/

expect {
    "Config file directory" { send "\r"; exp_continue }
    "Log file directory" { send "\r"; exp_continue }
    "Full path to perl" { send "\r"; exp_continue }
    "Web server port" { send "\r"; exp_continue }
    "Login name" { send "\r"; exp_continue }
    "Login password:" { send "<password>\r"; exp_continue }
    "Password again:" { send "<password>\r"; exp_continue }
    "Use SSL (y/n):" { send "y\r"; exp_continue }
    "Start Webmin at boot time (y/n):" { send "y\r"; exp_continue }
}
expect eof
EOF

# Make the expect script executable
log_and_run "chmod +x webmin_setup.expect"
sleep 5

# Run Webmin setup using expect script
log_and_run "./webmin_setup.expect"


# Configure firewall for Webmin
log_and_run "sudo firewall-cmd --add-port=10000/tcp --permanent"
log_and_run "sudo firewall-cmd --reload"

# Install additional PHP packages and other software
log_and_run "sudo dnf -y install git php-gmp php-pdo_mysql php-gd php-pear-Mail php-snmp fping"

# Clone phpIPAM repository
log_and_run "git clone --recursive https://github.com/phpipam/phpipam.git /var/www/html/"

# Change to phpIPAM directory
cd /var/www/html/

# Checkout the 1.6 branch
log_and_run "git checkout -b 1.6 origin/1.6"

# Copy configuration file
log_and_run "cp config.dist.php config.php"

# Automate changing 127.0.0.1 to localhost in config.php
log_and_run "sed -i 's/127.0.0.1/localhost/' config.php"

# Display server IP address and phpIPAM URL
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Server IP Address: $SERVER_IP" | tee -a $LOGFILE
echo "phpIPAM URL: http://$SERVER_IP/" | tee -a $LOGFILE
echo "Webmin URL: http://$SERVER_IP:10000" | tee -a $LOGFILE

# Thank you message and links
echo "Thank you for using this script!" | tee -a $LOGFILE
echo "Check out my YouTube channel: https://www.youtube.com/channel/UCPrivMRhAQF_FpAmsO-wxUQ" | tee -a $LOGFILE
echo "Follow me on Twitter: https://twitter.com/thetechguyguide" | tee -a $LOGFILE
echo "Visit my GitHub: https://github.com/thetechguysguide" | tee -a $LOGFILE

# Cleanup Installation files
log_and_run "rm -f /root/webmin-current.tar.gz"
log_and_run "rm -rf /root/webmin-2.202"
log_and_run "rm -f /root/mysql_secure_installation.expect"
log_and_run "rm -f /root/webmin_setup.expect"