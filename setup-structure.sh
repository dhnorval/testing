#!/bin/bash

# Create main project directory
mkdir -p testing
cd testing

# Create backend structure
mkdir -p backend/src/{models,routes,middleware,utils}

# Create frontend structure
mkdir -p frontend/src/app/{components,services}
mkdir -p frontend/src/app/components/{login,dashboard,stockpile-list,stockpile-form}
mkdir -p frontend/src/{assets,environments}

# Create necessary files
touch backend/src/server.js
touch backend/src/models/{User,Stockpile}.js
touch backend/src/routes/{auth,stockpiles}.js
touch backend/src/middleware/auth.js
touch backend/src/utils/database.js
touch backend/.env.example
touch backend/package.json

touch frontend/src/app/services/{auth,stockpile}.service.ts
touch frontend/src/app/{app.component.ts,app.component.html,app.component.scss,app.module.ts,app-routing.module.ts}
touch frontend/src/environments/environment.ts
touch frontend/src/{index.html,styles.scss}
touch frontend/package.json

touch {install,cleanup}.sh
touch README.md

# Make scripts executable
chmod +x {install,cleanup}.sh 