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

# Function to check PostgreSQL connection
check_postgres() {
    su - postgres -c "psql -c '\q'" >/dev/null 2>&1
    return $?
}

# Check system dependencies
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
    
    # Verify installation
    if ! command_exists node || ! command_exists npm; then
        print_error "Failed to install Node.js and npm"
    fi
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2)
if [ "${NODE_VERSION%%.*}" -lt 16 ]; then
    print_error "Node.js version must be 16 or higher. Current version: ${NODE_VERSION}"
fi

# Check/Install PostgreSQL
if ! command_exists psql; then
    print_status "Installing PostgreSQL..."
    apt-get install -y postgresql postgresql-contrib
    
    # Start PostgreSQL service
    systemctl start postgresql
    systemctl enable postgresql
    
    # Verify installation
    if ! check_postgres; then
        print_error "Failed to install PostgreSQL"
    fi
fi

# Check/Install Git
if ! command_exists git; then
    print_status "Installing git..."
    apt-get install -y git
fi

# Create project directory
PROJECT_DIR="/opt/stockpile-app"
print_status "Creating project directory at ${PROJECT_DIR}..."
mkdir -p ${PROJECT_DIR}
cd ${PROJECT_DIR}

# Create project directory structure
print_status "Creating project directory structure..."
mkdir -p ${PROJECT_DIR}/{backend,frontend}
mkdir -p ${PROJECT_DIR}/backend/{src,config,models,controllers,routes,middleware}
mkdir -p ${PROJECT_DIR}/frontend/web/{src,public,src/components,src/pages,src/utils,src/services}

# Setup PostgreSQL database
print_status "Setting up PostgreSQL database..."
su - postgres << EOF
psql -c "CREATE DATABASE stockpile;"
psql -c "CREATE USER stockpileuser WITH PASSWORD 'your_password_here';"
psql -c "ALTER ROLE stockpileuser SET client_encoding TO 'utf8';"
psql -c "ALTER ROLE stockpileuser SET default_transaction_isolation TO 'read committed';"
psql -c "ALTER ROLE stockpileuser SET timezone TO 'UTC';"
psql -c "GRANT ALL PRIVILEGES ON DATABASE stockpile TO stockpileuser;"
EOF

# Create backend files
print_status "Creating backend files..."

# Create backend package.json
cat > ${PROJECT_DIR}/backend/package.json << 'EOL'
{
    "name": "stockpile-backend",
    "version": "1.0.0",
    "description": "Backend for Stockpile Management System",
    "main": "src/server.js",
    "scripts": {
        "start": "node src/server.js",
        "dev": "nodemon src/server.js",
        "test": "jest"
    },
    "dependencies": {
        "bcryptjs": "^2.4.3",
        "cors": "^2.8.5",
        "dotenv": "^16.0.3",
        "express": "^4.18.2",
        "helmet": "^6.0.1",
        "jsonwebtoken": "^9.0.0",
        "morgan": "^1.10.0",
        "pg": "^8.9.0",
        "pg-hstore": "^2.3.4",
        "sequelize": "^6.28.0"
    },
    "devDependencies": {
        "jest": "^29.4.3",
        "nodemon": "^2.0.20"
    }
}
EOL

# Create database config
cat > ${PROJECT_DIR}/backend/config/database.js << 'EOL'
require('dotenv').config();

module.exports = {
    database: process.env.DB_NAME || 'stockpile',
    username: process.env.DB_USER || 'stockpileuser',
    password: process.env.DB_PASSWORD || 'your_password_here',
    host: process.env.DB_HOST || 'localhost',
    dialect: 'postgres',
    port: process.env.DB_PORT || 5432,
    pool: {
        max: 5,
        min: 0,
        acquire: 30000,
        idle: 10000
    }
};
EOL

# Create Stockpile model
cat > ${PROJECT_DIR}/backend/models/Stockpile.js << 'EOL'
module.exports = (sequelize, DataTypes) => {
    const Stockpile = sequelize.define('Stockpile', {
        name: {
            type: DataTypes.STRING,
            allowNull: false
        },
        material: {
            type: DataTypes.STRING,
            allowNull: false
        },
        grade: {
            type: DataTypes.STRING,
            allowNull: false
        },
        dimensions: {
            type: DataTypes.JSONB,
            allowNull: false,
            defaultValue: {
                length: 0,
                width: 0,
                height: 0
            }
        },
        volume: {
            type: DataTypes.FLOAT,
            allowNull: false
        },
        location: {
            type: DataTypes.GEOMETRY('POINT'),
            allowNull: false
        },
        status: {
            type: DataTypes.ENUM('active', 'processed', 'reclaimed'),
            defaultValue: 'active'
        }
    });

    return Stockpile;
};
EOL

# Create server.js
cat > ${PROJECT_DIR}/backend/src/server.js << 'EOL'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const db = require('../models');
const app = express();

// Middleware
app.use(cors());
app.use(helmet());
app.use(morgan('dev'));
app.use(express.json());

// Routes
app.use('/api/stockpiles', require('../routes/stockpiles'));
app.use('/api/users', require('../routes/users'));

// Database synchronization and server start
const PORT = process.env.PORT || 5000;

db.sequelize.sync({ alter: true })
    .then(() => {
        app.listen(PORT, () => {
            console.log(`Server running on port ${PORT}`);
        });
    })
    .catch(err => {
        console.error('Unable to connect to the database:', err);
    });
EOL

# Create frontend files
print_status "Creating frontend files..."

# Create public directory and files
mkdir -p ${PROJECT_DIR}/frontend/web/public

# Create index.html
cat > ${PROJECT_DIR}/frontend/web/public/index.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta name="description" content="Stockpile Management System" />
    <link rel="apple-touch-icon" href="%PUBLIC_URL%/logo192.png" />
    <link rel="manifest" href="%PUBLIC_URL%/manifest.json" />
    <title>Stockpile Manager</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOL

# Create manifest.json
cat > ${PROJECT_DIR}/frontend/web/public/manifest.json << 'EOL'
{
  "short_name": "Stockpile",
  "name": "Stockpile Management System",
  "icons": [
    {
      "src": "favicon.ico",
      "sizes": "64x64 32x32 24x24 16x16",
      "type": "image/x-icon"
    }
  ],
  "start_url": ".",
  "display": "standalone",
  "theme_color": "#000000",
  "background_color": "#ffffff"
}
EOL

# Create robots.txt
cat > ${PROJECT_DIR}/frontend/web/public/robots.txt << 'EOL'
# https://www.robotstxt.org/robotstxt.html
User-agent: *
Disallow:
EOL

# Create src directory and files
mkdir -p ${PROJECT_DIR}/frontend/web/src

# Create index.js
cat > ${PROJECT_DIR}/frontend/web/src/index.js << 'EOL'
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOL

# Create index.css
cat > ${PROJECT_DIR}/frontend/web/src/index.css << 'EOL'
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, 'Courier New',
    monospace;
}
EOL

# Create App.js
cat > ${PROJECT_DIR}/frontend/web/src/App.js << 'EOL'
import React from 'react';
import { BrowserRouter as Router, Route, Switch } from 'react-router-dom';
import { ThemeProvider, createTheme } from '@material-ui/core/styles';
import CssBaseline from '@material-ui/core/CssBaseline';
import Navigation from './components/Navigation';

const theme = createTheme({
  palette: {
    primary: {
      main: '#1976d2',
    },
    secondary: {
      main: '#dc004e',
    },
  },
});

function App() {
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Router>
        <Navigation />
        <Switch>
          <Route exact path="/" component={Dashboard} />
          <Route path="/stockpiles" component={StockpileList} />
          <Route path="/add-stockpile" component={StockpileForm} />
          <Route path="/login" component={Login} />
        </Switch>
      </Router>
    </ThemeProvider>
  );
}

export default App;
EOL

# Create Navigation component
cat > ${PROJECT_DIR}/frontend/web/src/components/Navigation.js << 'EOL'
import React from 'react';
import { AppBar, Toolbar, Typography, Button, makeStyles } from '@material-ui/core';
import { Link as RouterLink } from 'react-router-dom';

const useStyles = makeStyles((theme) => ({
    root: {
        flexGrow: 1,
    },
    title: {
        flexGrow: 1,
    },
    link: {
        color: 'white',
        textDecoration: 'none',
        marginLeft: theme.spacing(2),
    },
}));

function Navigation() {
    const classes = useStyles();

    return (
        <AppBar position="static">
            <Toolbar>
                <Typography variant="h6" className={classes.title}>
                    Stockpile Manager
                </Typography>
                <Button color="inherit" component={RouterLink} to="/">
                    Dashboard
                </Button>
                <Button color="inherit" component={RouterLink} to="/stockpiles">
                    Stockpiles
                </Button>
                <Button color="inherit" component={RouterLink} to="/add-stockpile">
                    Add Stockpile
                </Button>
                <Button color="inherit" component={RouterLink} to="/login">
                    Login
                </Button>
            </Toolbar>
        </AppBar>
    );
}

export default Navigation;
EOL

# Create frontend package.json
cat > ${PROJECT_DIR}/frontend/web/package.json << 'EOL'
{
    "name": "stockpile-frontend",
    "version": "1.0.0",
    "private": true,
    "dependencies": {
        "@material-ui/core": "^4.12.4",
        "@material-ui/icons": "^4.11.3",
        "@testing-library/jest-dom": "^5.16.5",
        "@testing-library/react": "^13.4.0",
        "@testing-library/user-event": "^13.5.0",
        "axios": "^1.3.4",
        "chart.js": "^4.2.1",
        "mapbox-gl": "^2.13.0",
        "react": "^18.2.0",
        "react-chartjs-2": "^5.2.0",
        "react-dom": "^18.2.0",
        "react-router-dom": "^6.8.2",
        "react-scripts": "5.0.1",
        "web-vitals": "^2.1.4"
    },
    "scripts": {
        "start": "react-scripts start",
        "build": "react-scripts build",
        "test": "react-scripts test",
        "eject": "react-scripts eject"
    },
    "eslintConfig": {
        "extends": [
            "react-app",
            "react-app/jest"
        ]
    },
    "browserslist": {
        "production": [
            ">0.2%",
            "not dead",
            "not op_mini all"
        ],
        "development": [
            "last 1 chrome version",
            "last 1 firefox version",
            "last 1 safari version"
        ]
    }
}
EOL

# Setup backend
print_status "Setting up backend..."
cd ${PROJECT_DIR}/backend
npm install

# Create backend environment file
cat > .env << EOL
PORT=5000
DB_HOST=localhost
DB_PORT=5432
DB_NAME=stockpile
DB_USER=stockpileuser
DB_PASSWORD=your_password_here
JWT_SECRET=$(openssl rand -hex 32)
NODE_ENV=production
EOL

# Setup frontend
print_status "Setting up frontend..."
cd ${PROJECT_DIR}/frontend/web
npm install --legacy-peer-deps

# Create frontend environment file
cat > .env << EOL
REACT_APP_API_URL=http://localhost:5000/api
REACT_APP_MAPBOX_TOKEN=your_mapbox_token_here
EOL

# Build the frontend
npm run build

# Setup systemd services
print_status "Setting up systemd services..."

# Backend service
cat > /etc/systemd/system/stockpile-backend.service << EOL
[Unit]
Description=Stockpile App Backend
After=network.target postgresql.service

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

# Frontend service
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
systemctl enable stockpile-backend stockpile-frontend
systemctl start stockpile-backend stockpile-frontend

# Verify services are running
if ! systemctl is-active --quiet stockpile-backend; then
    print_error "Backend service failed to start"
fi

if ! systemctl is-active --quiet stockpile-frontend; then
    print_error "Frontend service failed to start"
fi

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

# Create models/index.js
cat > ${PROJECT_DIR}/backend/models/index.js << 'EOL'
const fs = require('fs');
const path = require('path');
const Sequelize = require('sequelize');
const config = require('../config/database');

const db = {};

const sequelize = new Sequelize(
    config.database,
    config.username,
    config.password,
    config
);

// Read all model files in the current directory
fs.readdirSync(__dirname)
    .filter(file => {
        return (file.indexOf('.') !== 0) && 
               (file !== 'index.js') && 
               (file.slice(-3) === '.js');
    })
    .forEach(file => {
        const model = require(path.join(__dirname, file))(sequelize, Sequelize.DataTypes);
        db[model.name] = model;
    });

// Set up associations
Object.keys(db).forEach(modelName => {
    if (db[modelName].associate) {
        db[modelName].associate(db);
    }
});

db.sequelize = sequelize;
db.Sequelize = Sequelize;

module.exports = db;
EOL

# Create User model
cat > ${PROJECT_DIR}/backend/models/User.js << 'EOL'
module.exports = (sequelize, DataTypes) => {
    const User = sequelize.define('User', {
        username: {
            type: DataTypes.STRING,
            allowNull: false,
            unique: true
        },
        email: {
            type: DataTypes.STRING,
            allowNull: false,
            unique: true,
            validate: {
                isEmail: true
            }
        },
        password: {
            type: DataTypes.STRING,
            allowNull: false
        },
        role: {
            type: DataTypes.ENUM('admin', 'supervisor', 'worker'),
            defaultValue: 'worker'
        }
    });

    return User;
};
EOL