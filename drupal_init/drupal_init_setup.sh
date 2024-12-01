#!/bin/bash
set -x
set -euo pipefail
trap 'echo "An error occurred during Drupal setup. Check logs for details."; exit 1;' ERR

# Source configuration file
CONFIG_FILE="$HOME/scripts/project_init/config.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
fi

# Log file
LOG_FILE="$LOG_DIR/drupal_setup_$(date +%F_%T).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Arguments
PROJECT_DIR="$1"
GIT_SOLUTION="$2"
INIT_REMOTE="$3"
SETUP_CICD="$4"

# Step 1: Install dependencies
echo "Installing dependencies for Drupal 10..."
DEPENDENCIES=("php" "php-gd" "php-intl" "php-fpm" "composer" "mariadb" "apache")
for package in "${DEPENDENCIES[@]}"; do
    if ! pacman -Qi $package &> /dev/null; then
        echo "Installing $package..."
        sudo pacman -S --noconfirm $package || {
            echo "Error: Failed to install $package. Check your package manager."
            exit 1
        }
    else
        echo "$package is already installed."
    fi
done

# Step 2: Ensure services are running
echo "Ensuring Apache and PHP-FPM are enabled and running..."
sudo systemctl enable --now httpd || {
    echo "Error: Failed to start Apache. Check logs for details."
    exit 1
}
sudo systemctl enable --now php-fpm || {
    echo "Error: Failed to start PHP-FPM. Check logs for details."
    exit 1
}

# Step 3: Ensure Apache is using mpm_prefork
echo "Ensuring Apache is using mpm_prefork..."
sudo sed -i 's/LoadModule mpm_event_module/#LoadModule mpm_event_module/' /etc/httpd/conf/httpd.conf
sudo sed -i '/#LoadModule mpm_prefork_module/s/^#//' /etc/httpd/conf/httpd.conf
sudo systemctl restart httpd

# Step 4: Configure MariaDB
echo "Configuring MariaDB..."
sudo systemctl enable --now mariadb
sudo mariadb-secure-installation || {
    echo "Error during MariaDB secure installation."
    exit 1
}

DB_NAME=$(basename "$PROJECT_DIR")
DB_USER="drupal_user"
DB_PASS="drupal_pass"

echo "Creating database and user for Drupal..."

# Step 1: Check if the database exists
DB_EXISTS=$(sudo mariadb -N -e "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = '$DB_NAME';")
if [ "$DB_EXISTS" -eq 0 ]; then
    sudo mariadb -e "CREATE DATABASE $DB_NAME;" || {
        echo "Error: Failed to create database '$DB_NAME'."
        exit 1
    }
    echo "Database '$DB_NAME' created."
else
    echo "Database '$DB_NAME' already exists. Skipping creation."
fi

# Step 2: Check if the user exists
USER_EXISTS=$(sudo mariadb -N -e "SELECT COUNT(*) FROM mysql.user WHERE user = '$DB_USER';")
if [ "$USER_EXISTS" -eq 0 ]; then
    # Create the user if it doesn't exist
    sudo mariadb -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" || {
        echo "Error: Failed to create user '$DB_USER'."
        exit 1
    }
    echo "User '$DB_USER' created."
else
    echo "User '$DB_USER' already exists. Ensuring correct privileges..."
    # Update the user if it already exists
    sudo mariadb -e "ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';" || {
        echo "Error: Failed to update password for user '$DB_USER'."
        exit 1
    }
fi

# Step 3: Grant privileges to the user for the new database
GRANT_EXISTS=$(sudo mariadb -N -e "SELECT COUNT(*) FROM information_schema.schema_privileges WHERE grantee = '''$DB_USER''@''localhost''' AND privilege_type = 'ALL' AND table_schema = '$DB_NAME';")
if [ "$GRANT_EXISTS" -eq 0 ]; then
    sudo mariadb -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';" || {
        echo "Error: Failed to grant privileges to user '$DB_USER'."
        exit 1
    }
    echo "Privileges granted to '$DB_USER' for database '$DB_NAME'."
else
    echo "Privileges for '$DB_USER' on database '$DB_NAME' already exist. Skipping."
fi

# Step 4: Flush privileges to apply changes
sudo mariadb -e "FLUSH PRIVILEGES;" || {
    echo "Error: Failed to flush privileges."
    exit 1
}

echo "Database and user setup complete."


# Step 5: Set up Drupal project
echo "Setting up Drupal project in $PROJECT_DIR..."
composer create-project drupal/recommended-project "$PROJECT_DIR" || {
    echo "Error during Composer project creation."
    exit 1
}

# Configure settings.php
cd "$PROJECT_DIR" || exit
cp web/sites/default/default.settings.php web/sites/default/settings.php
chmod 664 web/sites/default/settings.php
mkdir -p web/sites/default/files
chmod 775 web/sites/default/files

# Update database credentials in settings.php
sed -i "s/'database' => ''/'database' => '$DB_NAME'/g" web/sites/default/settings.php
sed -i "s/'username' => ''/'username' => '$DB_USER'/g" web/sites/default/settings.php
sed -i "s/'password' => ''/'password' => '$DB_PASS'/g" web/sites/default/settings.php

# Step 6: Configure virtual host
VHOST_FILE="/etc/httpd/conf/extra/$DB_NAME.conf"
if [ ! -f "$VHOST_FILE" ]; then
    echo "Creating virtual host file $VHOST_FILE..."
    sudo tee "$VHOST_FILE" > /dev/null <<EOL
<VirtualHost *:80>
    ServerName $DB_NAME.local
    DocumentRoot "$PROJECT_DIR/web"
    <Directory "$PROJECT_DIR/web">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOL
fi

echo "Ensuring Apache includes the virtual host..."
if ! grep -q "$VHOST_FILE" /etc/httpd/conf/httpd.conf; then
    sudo sed -i "/#Include conf\/extra\/httpd-vhosts.conf/a Include $VHOST_FILE" /etc/httpd/conf/httpd.conf
fi
sudo systemctl restart httpd || {
    echo "Error: Failed to restart Apache. Check logs for details."
    exit 1
}

# Step 7: Update /etc/hosts
echo "Updating /etc/hosts..."
if ! grep -q "$DB_NAME.local" /etc/hosts; then
    echo "127.0.0.1 $DB_NAME.local" | sudo tee -a /etc/hosts
fi

# Step 8: Initialize Git repository
if [ "$INIT_REMOTE" = "yes" ]; then
    echo "Initializing Git repository..."
    "$HOME/scripts/project_init/git-init-repo/git-init-repo" "$PROJECT_DIR" "$GIT_SOLUTION" || {
        echo "Error initializing Git repository."
        exit 1
    }
fi

# Step 9: Final checks
echo "Final checks..."
if ! systemctl is-active --quiet httpd; then
    echo "Error: Apache is not running."
    exit 1
fi

if ! systemctl is-active --quiet php-fpm; then
    echo "Error: PHP-FPM is not running."
    exit 1
fi

echo "Setup completed successfully! Visit http://$DB_NAME.local in your browser."
exit 0
