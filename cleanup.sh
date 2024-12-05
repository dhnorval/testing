#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${YELLOW}[*] $1${NC}"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}[+] $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}[-] $1${NC}"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root or with sudo privileges"
fi

# Stop and remove systemd services
print_status "Stopping and removing services..."
systemctl stop stockpile-backend stockpile-frontend
systemctl disable stockpile-backend stockpile-frontend
rm -f /etc/systemd/system/stockpile-backend.service
rm -f /etc/systemd/system/stockpile-frontend.service
systemctl daemon-reload

# Remove database and user
print_status "Removing PostgreSQL database and user..."
sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS stockpile;
DROP USER IF EXISTS postgres;
EOF

# Remove installation directory
print_status "Removing installation directory..."
rm -rf /opt/stockpile-app

# Remove global npm packages
print_status "Removing global npm packages..."
npm uninstall -g pm2 nodemon typescript @angular/cli

# Clean npm cache
print_status "Cleaning npm cache..."
npm cache clean --force

print_success "Cleanup completed successfully!"
echo -e "${YELLOW}Note: This script did not remove the following:${NC}"
echo "1. PostgreSQL installation"
echo "2. Node.js and npm"
echo "3. Git"
echo -e "\nTo remove these completely, use your package manager:"
echo "For Debian/Ubuntu: sudo apt remove postgresql postgresql-contrib nodejs npm git"
echo "For RHEL/CentOS: sudo yum remove postgresql postgresql-contrib nodejs npm git"
echo "For Arch Linux: sudo pacman -R postgresql nodejs npm git" 