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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check and install system dependencies
print_status "Checking system dependencies..."

# Check/Install curl
if ! command_exists curl; then
    print_status "Installing curl..."
    apt-get update && apt-get install -y curl
fi

# Check/Install Node.js and npm
if ! command_exists node; then
    print_status "Installing Node.js and npm..."
    curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
    apt-get install -y nodejs
fi

# Check/Install Git
if ! command_exists git; then
    print_status "Installing git..."
    apt-get install -y git
fi

# Check/Install MongoDB
if ! command_exists mongod; then
    print_status "Installing MongoDB..."
    wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-5.0.list
    apt-get update
    apt-get install -y mongodb-org
    systemctl start mongod
    systemctl enable mongod
fi

# Create project directory
PROJECT_DIR="/opt/stockpile-app"
print_status "Creating project directory at ${PROJECT_DIR}..."
mkdir -p ${PROJECT_DIR}
cd ${PROJECT_DIR}

# Clone the repository
print_status "Cloning repository..."
git clone https://github.com/dhnorval/testing.git .

# Setup backend
print_status "Setting up backend..."
cd ${PROJECT_DIR}/backend
npm install

# Create backend environment file
cat > .env << EOL
PORT=5000
MONGODB_URI=mongodb://localhost:27017/stockpile
JWT_SECRET=your_jwt_secret_here
NODE_ENV=production
EOL

# Setup frontend
print_status "Setting up frontend..."
cd ${PROJECT_DIR}/frontend/web
npm install
npm run build

# Create frontend environment file
cat > .env << EOL
REACT_APP_API_URL=http://localhost:5000/api
REACT_APP_MAPBOX_TOKEN=your_mapbox_token_here
EOL

# Setup systemd service for backend
cat > /etc/systemd/system/stockpile-backend.service << EOL
[Unit]
Description=Stockpile App Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${PROJECT_DIR}/backend
ExecStart=/usr/bin/npm start
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOL

# Setup systemd service for frontend
cat > /etc/systemd/system/stockpile-frontend.service << EOL
[Unit]
Description=Stockpile App Frontend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${PROJECT_DIR}/frontend/web
ExecStart=/usr/bin/npm start
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOL

# Start services
print_status "Starting services..."
systemctl daemon-reload
systemctl enable stockpile-backend
systemctl enable stockpile-frontend
systemctl start stockpile-backend
systemctl start stockpile-frontend

# Set proper permissions
chown -R root:root ${PROJECT_DIR}
chmod -R 755 ${PROJECT_DIR}

print_success "Installation completed successfully!"
echo -e "\nServices running at:"
echo "Backend: http://localhost:5000"
echo "Frontend: http://localhost:3000"
echo -e "\nCheck service status with:"
echo "systemctl status stockpile-backend"
echo "systemctl status stockpile-frontend"