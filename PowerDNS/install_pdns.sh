#!/bin/bash
echo "*********************************************************************************************************"
echo "🚀 PowerDNS + MariaDB Installation Script (Rocky Linux 9.5)"
echo "This script automates the setup of PowerDNS with a MySQL backend, ensuring all necessary configurations, security settings, "
echo "and firewall rules are properly applied."
echo ""
echo "✅ Key Features:"
echo "- Installs PowerDNS and MariaDB"
echo "- Secures and configures the MySQL database"
echo "- Sets up PowerDNS with a MySQL backend"
echo "- Configures PowerDNS API and web interface (Port 8081)"
echo "- Opens required firewall ports for DNS and remote access"
echo "- Adjusts SELinux for compatibility"
echo ""
echo "🔹 Estimated Time: ~2-3 minutes"
echo "🔹 No manual input required. Everything is automated!"
echo ""
echo "*********************************************************************************************************"
echo "🔐 Default Credentials Used in This Setup:"
echo ""
echo "  ➤ **MariaDB Root User:**"
echo "     - Username: root"
echo "     - Password: StrongRootPass123"
echo "     - Purpose: Full administrative access to MariaDB"
echo ""
echo "  ➤ **PowerDNS Database User:**"
echo "     - Username: powerdns"
echo "     - Password: StrongPDNSPass"
echo "     - Purpose: Grants PowerDNS access to its MySQL database"
echo ""
echo "  ➤ **PowerDNS API Access:**"
echo "     - API Key: SuperSecretAPIKey"
echo "     - Purpose: Allows external management of PowerDNS via API"
echo ""
echo ""
echo "*********************************************************************************************************"
echo "🛠 SELinux and Firewall Ports Adjustments:"
echo ""
echo "  ➤ **Allows MariaDB to Connect Externally:**"
echo "     - Command: setsebool -P mysql_connect_any on"
echo ""
echo "  ➤ **Allows HTTPD and Other Services to Access the Database:**"
echo "     - Command: setsebool -P httpd_can_network_connect_db on"
echo ""
echo "  ➤ **Restores Correct SELinux Contexts for MySQL Data Directory:**"
echo "     - Command: restorecon -Rv /var/lib/mysql"
echo ""
echo "  ➤ **Firewall Ports Opened:**"
echo "     - DNS (UDP/TCP): 53"
echo "     - PowerDNS Web UI/API: 8081"
echo "     - MariaDB Remote Access: 3306"
echo ""
echo "*********************************************************************************************************"
echo "💡 **Important:** It is strongly recommended to change the default passwords after installation!"
echo "*********************************************************************************************************"
echo ""
echo "Starting installation..."



# Define log file
LOGFILE="/var/log/setup_script.log"

# Function to log and execute commands
log_and_run() {
    echo "Running: $1" | tee -a $LOGFILE
    eval $1 2>&1 | tee -a $LOGFILE
}

echo "🔹 Installing PowerDNS and MariaDB..."

# Install required packages
log_and_run "sudo dnf install -y epel-release"
log_and_run "sudo dnf install -y mariadb-server mariadb pdns pdns-backend-mysql bind-utils"

# Start and enable MariaDB
log_and_run "sudo systemctl enable --now mariadb"

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

# Create PowerDNS database and user
echo "🔹 Creating PowerDNS database..."
sudo mysql -u root -pStrongRootPass123 <<EOF
CREATE DATABASE powerdns;
CREATE USER 'powerdns'@'%' IDENTIFIED BY 'StrongPDNSPass';
GRANT ALL PRIVILEGES ON powerdns.* TO 'powerdns'@'%';
FLUSH PRIVILEGES;
EOF

# Import PowerDNS schema
echo "🔹 Importing PowerDNS database schema..."
if [ -f /usr/share/doc/pdns/schema.mysql.sql ]; then
    sudo mysql -u root -pStrongRootPass123 powerdns < /usr/share/doc/pdns/schema.mysql.sql
elif [ -f /usr/share/pdns-backend-mysql/schema.mysql.sql ]; then
    sudo mysql -u root -pStrongRootPass123 powerdns < /usr/share/pdns-backend-mysql/schema.mysql.sql
else
    echo "❌ Error: PowerDNS database schema file not found!"
    exit 1
fi

# Configure PowerDNS
echo "🔹 Configuring PowerDNS..."
sudo tee /etc/pdns/pdns.conf > /dev/null <<EOF
launch=gmysql
gmysql-host=127.0.0.1
gmysql-user=powerdns
gmysql-password=StrongPDNSPass
gmysql-dbname=powerdns
api=yes
api-key=SuperSecretAPIKey
webserver=yes
webserver-address=0.0.0.0
webserver-port=8081
webserver-allow-from=0.0.0.0/0,::/0
EOF

# Restart PDNS
echo "🔹 Restarting PowerDNS..."
log_and_run "sudo systemctl enable --now pdns"

# Open firewall ports for PowerDNS & MySQL remote access
echo "🔹 Configuring Firewall..."
log_and_run "sudo firewall-cmd --permanent --add-port=53/udp"
log_and_run "sudo firewall-cmd --permanent --add-port=53/tcp"
log_and_run "sudo firewall-cmd --permanent --add-port=8081/tcp"
log_and_run "sudo firewall-cmd --permanent --add-service=mysql"
log_and_run "sudo firewall-cmd --permanent --add-port=3306/tcp"
log_and_run "sudo firewall-cmd --reload"

# Allow Remote MySQL Connections
echo "🔹 Configuring MariaDB for Remote Access..."
log_and_run "sudo sed -i 's/^bind-address.*/bind-address=0.0.0.0/' /etc/my.cnf.d/mariadb-server.cnf"
log_and_run "sudo systemctl restart mariadb"

# Grant remote MySQL access for phpIPAM
echo "🔹 Granting Remote Access to MySQL Users..."
sudo mysql -u root -pStrongRootPass123 <<EOF
GRANT ALL PRIVILEGES ON powerdns.* TO 'powerdns'@'%' IDENTIFIED BY 'StrongPDNSPass';
FLUSH PRIVILEGES;
EOF

# Configure SELinux to allow MySQL remote access
echo "🔹 Configuring SELinux..."
log_and_run "sudo setsebool -P mysql_connect_any on"
log_and_run "sudo setsebool -P httpd_can_network_connect_db on"
log_and_run "sudo restorecon -Rv /var/lib/mysql"

echo "*********************************************************************************************************"
echo "*********************************************************************************************************"
echo "*********************************************************************************************************"
echo ""
echo "✅ PowerDNS installation complete!"
echo "Thank you for using this script!" | tee -a $LOGFILE
echo "Check out my YouTube channel: https://www.youtube.com/@thetechguysguide" | tee -a $LOGFILE
echo "Follow me on Twitter: https://twitter.com/thetechguyguide" | tee -a $LOGFILE
echo "Visit my GitHub for Scripts and Config Files: https://github.com/thetechguysguide/thetechguysguide.github.io" | tee -a $LOGFILE
