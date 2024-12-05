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

# Remove PostgreSQL database and user
print_status "Removing PostgreSQL database and user..."
su - postgres << EOF
psql -c "DROP DATABASE IF EXISTS stockpile;"
psql -c "DROP USER IF EXISTS stockpileuser;"
EOF

# Remove project directory
print_status "Removing project directory..."
rm -rf /opt/stockpile-app

# Clean npm cache
print_status "Cleaning npm cache..."
npm cache clean --force

print_success "Cleanup completed successfully!"

# Print optional cleanup instructions
echo -e "\n${YELLOW}Optional cleanup steps:${NC}"
echo "To remove installed dependencies, run:"
echo "1. PostgreSQL: sudo apt-get remove postgresql postgresql-contrib"
echo "2. Node.js: sudo apt-get remove nodejs npm"
echo "3. Git: sudo apt-get remove git"
echo -e "\nTo remove all configuration files:"
echo "sudo apt-get purge postgresql postgresql-contrib nodejs npm git"
echo -e "\nTo remove unused packages:"
echo "sudo apt-get autoremove"