Script Summary

This Bash script automates the setup and configuration of a server with essential tools and services, specifically targeting a Rocky Linux environment. It installs and configures phpIPAM, Webmin, Grafana, MariaDB, and Apache, ensuring all components work together seamlessly. Below is a detailed explanation of its functionality:
Key Features:

    System Preparation:
        Updates the system packages using dnf to ensure the latest updates and security patches are applied.

    Apache Web Server Installation:
        Installs and configures Apache to serve as the primary web server.
        Configures the firewall to allow HTTP and HTTPS traffic.

    PHP 8.3 Installation:
        Installs PHP 8.3 and necessary extensions for phpIPAM compatibility.
        Configures PHP-FPM and restarts the services for proper integration.

    MariaDB (MySQL) Setup:
        Installs and secures MariaDB by removing default insecure configurations.
        Creates a dedicated database (phpipam) and user with appropriate permissions for phpIPAM.

    phpIPAM Installation:
        Clones the latest phpIPAM code from GitHub.
        Configures the database connection in phpIPAM's configuration file.
        Initializes the database schema and sets up the admin password.

    Webmin Installation:
        Installs Webmin for server administration.
        Configures the Webmin admin account and updates firewall rules to allow Webmin access (port 10000).

    Grafana Installation:
        Installs Grafana and configures it to start on boot.
        Sets up Grafana to query the phpIPAM MySQL database as a data source using provided credentials.

    Credential Management:
        Prompts the user for MySQL root, Webmin admin, phpIPAM admin, and Grafana admin passwords.
        Allows customization of phpIPAM database credentials and other settings.

    Firewall Configuration:
        Opens necessary ports (80, 443 for HTTP/HTTPS, 10000 for Webmin, and 3000 for Grafana) to allow external access to the services.

    Logging:
        Logs all commands and their outputs to a file for troubleshooting and auditing.

    Final Output:
        Displays server IP addresses and URLs for accessing:
            phpIPAM: http://<server_ip>/
            Webmin: https://<server_ip>:10000
            Grafana: http://<server_ip>:3000

    Cleanup:
        Removes temporary installation files to keep the system clean.

Usage and Customization:

    User Input: The script prompts the user to enter required credentials (or use defaults) for MySQL, phpIPAM, Webmin, and Grafana.
    Flexibility: You can override default values during the setup process to fit your specific requirements.
    Warnings: Includes a disclaimer to remind users to review and test the script before deploying it in production.

This script simplifies setting up a robust server environment for managing IP addresses (phpIPAM), monitoring data (Grafana), and server administration (Webmin), all while providing centralized logging and a clean post-installation experience.
