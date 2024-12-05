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

# Function to install packages based on OS
install_dependencies() {
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        print_status "Installing dependencies for Debian/Ubuntu..."
        sudo apt-get update
        sudo apt-get install -y \
            git \
            nodejs \
            npm \
            postgresql \
            postgresql-contrib \
            curl \
            build-essential \
            python3 \
            libpq-dev
        
        # Install latest Node.js using n
        sudo npm install -g n
        sudo n stable
        
        # Start PostgreSQL service
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
        
    elif [ -f /etc/redhat-release ]; then
        # RHEL/CentOS
        print_status "Installing dependencies for RHEL/CentOS..."
        sudo yum update -y
        sudo yum install -y \
            git \
            nodejs \
            npm \
            postgresql-server \
            postgresql-contrib \
            curl \
            gcc \
            gcc-c++ \
            make \
            python3
        
        # Initialize PostgreSQL
        sudo postgresql-setup initdb
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
        
    elif [ -f /etc/arch-release ]; then
        # Arch Linux
        print_status "Installing dependencies for Arch Linux..."
        sudo pacman -Syu --noconfirm
        sudo pacman -S --noconfirm \
            git \
            nodejs \
            npm \
            postgresql \
            curl \
            base-devel \
            python3
        
        # Initialize PostgreSQL
        sudo -u postgres initdb -D /var/lib/postgres/data
        sudo systemctl start postgresql
        sudo systemctl enable postgresql
        
    else
        print_error "Unsupported operating system"
    fi
}

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_status "$1 is not installed. Installing..."
        return 1
    fi
    return 0
}

# Check and install dependencies
print_status "Checking system dependencies..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_status "Please run as root or with sudo privileges"
    exit 1
fi

# Check for required commands and install if missing
check_command "git" || install_dependencies
check_command "node" || install_dependencies
check_command "npm" || install_dependencies
check_command "psql" || install_dependencies
check_command "curl" || install_dependencies

# Check Node.js version and upgrade if needed
NODE_VERSION=$(node -v | cut -d 'v' -f 2)
if [ $(echo "$NODE_VERSION 14.0.0" | awk '{print ($1 < $2)}') -eq 1 ]; then
    print_status "Node.js version is below 14.0.0. Upgrading..."
    sudo npm install -g n
    sudo n stable
    # Reload PATH to use new Node.js version
    PATH="$PATH"
fi

# Install global npm packages
print_status "Installing global npm packages..."
sudo npm install -g pm2 nodemon typescript @angular/cli

# Verify PostgreSQL installation
print_status "Verifying PostgreSQL installation..."
if ! systemctl is-active --quiet postgresql; then
    print_status "Starting PostgreSQL service..."
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
fi

# Wait for PostgreSQL to be ready
print_status "Waiting for PostgreSQL to be ready..."
until sudo -u postgres psql -c '\l' >/dev/null 2>&1; do
    echo -n "."
    sleep 1
done

print_success "All dependencies installed and verified!"

# Rest of your existing script continues here...

# Create installation directory
INSTALL_DIR="stockpile-app"
print_status "Creating installation directory..."
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR || print_error "Failed to create installation directory"

# Clone the repository
print_status "Cloning the Stockpile App repository..."
git clone https://github.com/dhnorval/testing.git . || print_error "Failed to clone repository"

# Create necessary directories and files
print_status "Creating project structure..."
mkdir -p backend/src/{models,routes,middleware,utils}
mkdir -p frontend/src/{app,assets,environments}

# Create package.json files first
print_status "Creating package.json files..."
cat > backend/package.json << 'EOF'
{
  "name": "stockpile-app-backend",
  "version": "1.0.0",
  "description": "Backend for Stockpile Management Application",
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
    "express-rate-limit": "^6.7.0",
    "helmet": "^6.1.5",
    "jsonwebtoken": "^9.0.0",
    "morgan": "^1.10.0",
    "pg": "^8.10.0",
    "pg-hstore": "^2.3.4"
  },
  "devDependencies": {
    "jest": "^29.5.0",
    "nodemon": "^2.0.22",
    "supertest": "^6.3.3"
  }
}
EOF

# Create .env file
print_status "Creating environment file..."
cat > backend/.env << 'EOF'
# ... (your .env content)
EOF

# Install backend dependencies
print_status "Installing backend dependencies..."
cd backend || print_error "Failed to change to backend directory"
npm install || print_error "Failed to install backend dependencies"

# Create source files
print_status "Creating source files..."

# Create server.js
print_status "Creating server.js..."
cat > src/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const morgan = require('morgan');
const dotenv = require('dotenv');

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors({
    origin: process.env.CORS_ORIGIN,
    credentials: true
}));
app.use(express.json());
app.use(morgan('combined'));

// Rate limiting
const limiter = rateLimit({
    windowMs: process.env.RATE_LIMIT_WINDOW * 60 * 1000,
    max: process.env.RATE_LIMIT_MAX_REQUESTS
});
app.use('/api/', limiter);

// Routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/stockpiles', require('./routes/stockpiles'));

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.status(200).json({ status: 'healthy' });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ 
        error: 'Internal Server Error',
        message: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
});

app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

module.exports = app;
EOF

# Create models
print_status "Creating models..."
cat > src/models/User.js << 'EOF'
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

const pool = new Pool();

class User {
    static async findOne(email) {
        const result = await pool.query(
            'SELECT * FROM users WHERE email = $1',
            [email]
        );
        return result.rows[0];
    }

    static async create(userData) {
        const hashedPassword = await bcrypt.hash(userData.password, 12);
        const result = await pool.query(
            'INSERT INTO users (email, password, name, role) VALUES ($1, $2, $3, $4) RETURNING *',
            [userData.email, hashedPassword, userData.name, userData.role]
        );
        return result.rows[0];
    }

    static async comparePassword(password, hashedPassword) {
        return bcrypt.compare(password, hashedPassword);
    }
}

module.exports = User;
EOF

cat > src/models/Stockpile.js << 'EOF'
const { Pool } = require('pg');
const pool = new Pool();

class Stockpile {
    static async findAll() {
        const result = await pool.query(
            'SELECT * FROM stockpiles ORDER BY created_at DESC'
        );
        return result.rows;
    }

    static async create(stockpileData) {
        const result = await pool.query(
            'INSERT INTO stockpiles (name, material, grade, volume, location, responsible_team_id) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
            [stockpileData.name, stockpileData.material, stockpileData.grade, stockpileData.volume, stockpileData.location, stockpileData.responsibleTeamId]
        );
        return result.rows[0];
    }

    static async update(id, stockpileData) {
        const result = await pool.query(
            'UPDATE stockpiles SET name = $1, material = $2, grade = $3, volume = $4, location = $5, responsible_team_id = $6, updated_at = CURRENT_TIMESTAMP WHERE id = $7 RETURNING *',
            [stockpileData.name, stockpileData.material, stockpileData.grade, stockpileData.volume, stockpileData.location, stockpileData.responsibleTeamId, id]
        );
        return result.rows[0];
    }

    static async delete(id) {
        const result = await pool.query(
            'DELETE FROM stockpiles WHERE id = $1 RETURNING *',
            [id]
        );
        return result.rows[0];
    }
}

module.exports = Stockpile;
EOF

# Create middleware
print_status "Creating middleware..."
cat > src/middleware/auth.js << 'EOF'
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const auth = async (req, res, next) => {
    try {
        const token = req.header('Authorization')?.replace('Bearer ', '');
        
        if (!token) {
            throw new Error();
        }

        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await User.findOne(decoded.id);

        if (!user || !user.active) {
            throw new Error();
        }

        req.user = user;
        req.token = token;
        next();
    } catch (error) {
        res.status(401).json({ error: 'Please authenticate' });
    }
};

const authorize = (...roles) => {
    return (req, res, next) => {
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({ 
                error: 'You do not have permission to perform this action' 
            });
        }
        next();
    };
};

module.exports = { auth, authorize };
EOF

# Create routes
print_status "Creating routes..."
cat > src/routes/auth.js << 'EOF'
const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { auth } = require('../middleware/auth');

const router = express.Router();

router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;
        const user = await User.findOne(email);

        if (!user || !(await User.comparePassword(password, user.password))) {
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const token = jwt.sign(
            { id: user.id },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN }
        );

        res.json({ token, user: {
            id: user.id,
            email: user.email,
            name: user.name,
            role: user.role
        }});
    } catch (error) {
        res.status(500).json({ error: 'Login failed' });
    }
});

router.get('/me', auth, (req, res) => {
    res.json(req.user);
});

module.exports = router;
EOF

cat > src/routes/stockpiles.js << 'EOF'
const express = require('express');
const Stockpile = require('../models/Stockpile');
const { auth, authorize } = require('../middleware/auth');

const router = express.Router();

router.get('/', auth, async (req, res) => {
    try {
        const stockpiles = await Stockpile.findAll();
        res.json(stockpiles);
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch stockpiles' });
    }
});

router.post('/', auth, authorize('admin', 'supervisor'), async (req, res) => {
    try {
        const stockpile = await Stockpile.create(req.body);
        res.status(201).json(stockpile);
    } catch (error) {
        res.status(400).json({ error: 'Failed to create stockpile' });
    }
});

router.put('/:id', auth, authorize('admin', 'supervisor'), async (req, res) => {
    try {
        const stockpile = await Stockpile.update(req.params.id, req.body);
        if (!stockpile) {
            return res.status(404).json({ error: 'Stockpile not found' });
        }
        res.json(stockpile);
    } catch (error) {
        res.status(400).json({ error: 'Failed to update stockpile' });
    }
});

router.delete('/:id', auth, authorize('admin'), async (req, res) => {
    try {
        const stockpile = await Stockpile.delete(req.params.id);
        if (!stockpile) {
            return res.status(404).json({ error: 'Stockpile not found' });
        }
        res.json({ message: 'Stockpile deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: 'Failed to delete stockpile' });
    }
});

module.exports = router;
EOF

# Return to main directory
cd ..

# Verify backend files exist
print_status "Verifying backend files..."
required_files=(
    "backend/src/server.js"
    "backend/src/models/User.js"
    "backend/src/models/Stockpile.js"
    "backend/src/routes/auth.js"
    "backend/src/routes/stockpiles.js"
    "backend/src/middleware/auth.js"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        ls -la backend/src/
        ls -la backend/src/models/
        ls -la backend/src/routes/
        ls -la backend/src/middleware/
        print_error "Missing required file: $file"
    fi
done

# Create systemd service for backend with improved logging
print_status "Creating systemd service for backend..."
sudo tee /etc/systemd/system/stockpile-backend.service << EOF
[Unit]
Description=Stockpile App Backend
After=network.target postgresql.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)/backend
ExecStart=$(which node) src/server.js
Restart=always
Environment=NODE_ENV=production
StandardOutput=append:/var/log/stockpile-backend.log
StandardError=append:/var/log/stockpile-backend.log

[Install]
WantedBy=multi-user.target
EOF

# Create log file and set permissions
sudo touch /var/log/stockpile-backend.log
sudo chown $USER:$USER /var/log/stockpile-backend.log

# Setup frontend
print_status "Setting up frontend..."
cd frontend || print_error "Failed to change to frontend directory"

# Remove any existing files to avoid conflicts
rm -rf * .[!.]*

# Install Angular CLI globally
print_status "Installing Angular CLI..."
sudo npm install -g @angular/cli@15.2.0

# Initialize Angular application
print_status "Initializing Angular application..."
ng new stockpile-frontend \
    --directory=. \
    --routing=true \
    --style=scss \
    --skip-git \
    --skip-tests \
    --skip-install \
    --defaults || print_error "Failed to create Angular application"

# Update package.json with additional dependencies
print_status "Updating package.json..."
cat > package.json << 'EOF'
{
  "name": "stockpile-app-frontend",
  "version": "1.0.0",
  "scripts": {
    "ng": "ng",
    "start": "ng serve",
    "build": "ng build",
    "watch": "ng build --watch --configuration development"
  },
  "private": true,
  "dependencies": {
    "@angular/animations": "^15.2.0",
    "@angular/common": "^15.2.0",
    "@angular/compiler": "^15.2.0",
    "@angular/core": "^15.2.0",
    "@angular/forms": "^15.2.0",
    "@angular/platform-browser": "^15.2.0",
    "@angular/platform-browser-dynamic": "^15.2.0",
    "@angular/router": "^15.2.0",
    "@mapbox/mapbox-gl-geocoder": "^5.0.1",
    "mapbox-gl": "^2.13.0",
    "chart.js": "^4.2.1",
    "rxjs": "~7.8.0",
    "tslib": "^2.5.0",
    "zone.js": "~0.12.0"
  },
  "devDependencies": {
    "@angular-devkit/build-angular": "^15.2.0",
    "@angular/cli": "~15.2.0",
    "@angular/compiler-cli": "^15.2.0",
    "@types/mapbox-gl": "^2.7.10",
    "typescript": "~4.9.4"
  }
}
EOF

# Install frontend dependencies
print_status "Installing frontend dependencies..."
npm install || print_error "Failed to install frontend dependencies"

# Create basic Angular components
print_status "Creating Angular components..."
mkdir -p src/app/components
mkdir -p src/app/services

ng generate component components/login
ng generate component components/dashboard
ng generate component components/stockpile-list
ng generate component components/stockpile-form
ng generate service services/auth
ng generate service services/stockpile

# Update frontend service
print_status "Creating systemd service for frontend..."
sudo tee /etc/systemd/system/stockpile-frontend.service << EOF
[Unit]
Description=Stockpile App Frontend
After=network.target stockpile-backend.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/npm start -- --host 0.0.0.0 --port 8080 --disable-host-check
Restart=always
Environment=NODE_ENV=production
StandardOutput=append:/var/log/stockpile-frontend.log
StandardError=append:/var/log/stockpile-frontend.log

[Install]
WantedBy=multi-user.target
EOF

# Create log file for frontend
sudo touch /var/log/stockpile-frontend.log
sudo chown $USER:$USER /var/log/stockpile-frontend.log

# Create Angular app files
print_status "Creating Angular app files..."

# Create app routing module
cat > src/app/app-routing.module.ts << 'EOF'
import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { LoginComponent } from './components/login/login.component';
import { DashboardComponent } from './components/dashboard/dashboard.component';
import { StockpileListComponent } from './components/stockpile-list/stockpile-list.component';
import { StockpileFormComponent } from './components/stockpile-form/stockpile-form.component';

const routes: Routes = [
  { path: '', redirectTo: '/dashboard', pathMatch: 'full' },
  { path: 'login', component: LoginComponent },
  { path: 'dashboard', component: DashboardComponent },
  { path: 'stockpiles', component: StockpileListComponent },
  { path: 'stockpiles/new', component: StockpileFormComponent },
  { path: 'stockpiles/edit/:id', component: StockpileFormComponent }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
EOF

# Update app.module.ts
cat > src/app/app.module.ts << 'EOF'
import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { HttpClientModule } from '@angular/common/http';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { LoginComponent } from './components/login/login.component';
import { DashboardComponent } from './components/dashboard/dashboard.component';
import { StockpileListComponent } from './components/stockpile-list/stockpile-list.component';
import { StockpileFormComponent } from './components/stockpile-form/stockpile-form.component';

@NgModule({
  declarations: [
    AppComponent,
    LoginComponent,
    DashboardComponent,
    StockpileListComponent,
    StockpileFormComponent
  ],
  imports: [
    BrowserModule,
    AppRoutingModule,
    HttpClientModule,
    FormsModule,
    ReactiveFormsModule
  ],
  providers: [],
  bootstrap: [AppComponent]
})
export class AppModule { }
EOF

# Update app.component.html
cat > src/app/app.component.html << 'EOF'
<nav class="navbar navbar-expand-lg navbar-dark bg-dark">
  <div class="container">
    <a class="navbar-brand" href="#">Stockpile App</a>
    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
      <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse" id="navbarNav">
      <ul class="navbar-nav">
        <li class="nav-item">
          <a class="nav-link" routerLink="/dashboard" routerLinkActive="active">Dashboard</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" routerLink="/stockpiles" routerLinkActive="active">Stockpiles</a>
        </li>
      </ul>
    </div>
  </div>
</nav>

<div class="container mt-4">
  <router-outlet></router-outlet>
</div>
EOF

# Update app.component.ts
cat > src/app/app.component.ts << 'EOF'
import { Component } from '@angular/core';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent {
  title = 'Stockpile Management';
}
EOF

# Add Bootstrap CSS to index.html
sed -i '/<head>/a \  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">' src/index.html

# Add basic styles
cat > src/styles.scss << 'EOF'
/* You can add global styles to this file, and also import other style files */
body {
  margin: 0;
  padding: 0;
  font-family: Arial, sans-serif;
}

.navbar {
  margin-bottom: 20px;
}

.container {
  padding: 20px;
}
EOF

# Build the application
print_status "Building Angular application..."
ng build --configuration=production || print_error "Failed to build Angular application"

# Start services with better error checking
print_status "Starting services..."
sudo systemctl daemon-reload

print_status "Starting backend service..."
if ! sudo systemctl start stockpile-backend; then
    print_status "Backend failed to start. Checking logs..."
    sudo journalctl -u stockpile-backend -n 50
    sudo cat /var/log/stockpile-backend.log
    print_error "Backend service failed to start. Check the logs above for details."
fi

sudo systemctl enable stockpile-backend

# Add a longer wait time and better verification
print_status "Waiting for backend to fully start..."
for i in {1..30}; do
    if curl -s http://localhost:3000/api/health > /dev/null; then
        print_success "Backend is running"
        break
    fi
    if [ $i -eq 30 ]; then
        print_status "Backend status check failed. Checking logs..."
        sudo journalctl -u stockpile-backend -n 50
        sudo cat /var/log/stockpile-backend.log
        print_error "Backend failed to respond to health check"
    fi
    echo -n "."
    sleep 1
done

# Start frontend service with error checking
print_status "Starting frontend service..."
if ! sudo systemctl start stockpile-frontend; then
    print_status "Frontend failed to start. Checking logs..."
    sudo journalctl -u stockpile-frontend -n 50
    sudo cat /var/log/stockpile-frontend.log
    print_error "Frontend service failed to start. Check the logs above for details."
fi

sudo systemctl enable stockpile-frontend

# Add a longer wait time and better verification for frontend
print_status "Waiting for frontend to fully start..."
for i in {1..30}; do
    if curl -s http://localhost:8080 > /dev/null; then
        print_success "Frontend is running"
        break
    fi
    if [ $i -eq 30 ]; then
        print_status "Frontend status check failed. Checking logs..."
        sudo journalctl -u stockpile-frontend -n 50
        sudo cat /var/log/stockpile-frontend.log
        print_error "Frontend failed to respond"
    fi
    echo -n "."
    sleep 1
done

# Verify installation
print_status "Verifying installation..."
sleep 5

if curl -s http://localhost:3000/api/health > /dev/null; then
    print_success "Backend is running"
else
    print_error "Backend is not running"
fi

if curl -s http://localhost:8080 > /dev/null; then
    print_success "Frontend is running"
else
    print_error "Frontend is not running"
fi

print_success "Installation completed successfully!"
echo -e "${GREEN}You can access the application at:${NC}"
echo -e "Frontend: http://localhost:8080"
echo -e "Backend API: http://localhost:3000"
echo -e "\n${YELLOW}Default admin credentials:${NC}"
echo -e "Username: ${ADMIN_EMAIL}"
echo -e "Password: Please check the .env file for the default password"

# Print post-installation instructions
cat << EOF

${YELLOW}Post-Installation Steps:${NC}
1. Configure your environment variables in backend/.env
2. Set up your SSL certificates
3. Configure your database backup strategy
4. Review and update the default security settings

${YELLOW}To manage the application services:${NC}
- Start backend: sudo systemctl start stockpile-backend
- Start frontend: sudo systemctl start stockpile-frontend
- Stop backend: sudo systemctl stop stockpile-backend
- Stop frontend: sudo systemctl stop stockpile-frontend
- View backend logs: sudo journalctl -u stockpile-backend
- View frontend logs: sudo journalctl -u stockpile-frontend

${YELLOW}For support:${NC}
- Documentation: docs/
- Issues: https://github.com/dhnorval/testing/issues
- Email: support@stockpile-app.com

EOF 