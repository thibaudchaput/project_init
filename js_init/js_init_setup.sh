#!/bin/bash
set -euo pipefail
trap 'echo "An error occurred. Exiting..."; exit 1;' ERR

# Source configuration file
CONFIG_FILE="$HOME/project_init/config.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
fi

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Set log file name with timestamp
LOG_FILE="$LOG_DIR/js_project_setup_$(date +'%Y%m%d_%H%M%S').log"

# Redirect stdout and stderr to the log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Check for the project directory and other arguments
if [ -z "${1-}" ]; then
    echo "Usage: $0 <project-directory> [git-solution] [init-remote] [setup-cicd]"
    exit 1
fi

PROJECT_DIR="$1"
GIT_SOLUTION="${2:-$DEFAULT_GIT_SOLUTION}"
INIT_REMOTE="${3:-$INIT_REMOTE}"
SETUP_CICD="${4:-$SETUP_CICD}"

# Initialize Git repository and remote if required
if [ "$INIT_REMOTE" = "yes" ]; then
    echo "Initializing Git repository in '$PROJECT_DIR' with '$GIT_SOLUTION'..."
    "$HOME/project_init/git-init-repo/git-init-repo" "$PROJECT_DIR" "$GIT_SOLUTION"
else
    echo "Skipping remote repository initialization."
    # Initialize local Git repository without remote
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    git init
    echo "Initialized local Git repository in '$PROJECT_DIR'."
fi

cd "$PROJECT_DIR"

# Extract project name from PROJECT_DIR
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Create back-end directories and files
echo "Creating back-end directories and files..."
mkdir -p back/{data,src/{database,models,auth,controllers,middlewares,routers}}
echo "Back-end structure created."

# Create front-end directories and files
echo "Creating front-end directories and files..."
mkdir -p front/src
touch front/{index.html,.env,.env.example}
echo "Front-end structure created."

# Initialize npm in back-end
echo "Initializing npm in back-end..."
cd back
npm init -y

# Update package.json using Node.js script
echo "Updating package.json..."

# Create update_package_json.js
cat <<EOL > update_package_json.js
// update_package_json.js

const fs = require('fs');

const packageJson = JSON.parse(fs.readFileSync('package.json', 'utf8'));

const projectName = process.argv[2];

packageJson.name = projectName;
packageJson.main = 'index.js';
packageJson.directories = { doc: 'docs' };
packageJson.scripts = {
    start: 'node index.js',
    dev: 'nodemon index.js'
};

fs.writeFileSync('package.json', JSON.stringify(packageJson, null, 2));
EOL

# Run the Node.js script
node update_package_json.js "$PROJECT_NAME"

# Remove the temporary script
rm update_package_json.js

# Ensure npm progress bar is enabled
npm set progress=true

# Install dependencies
echo "Installing back-end dependencies (this may take a while)..."
npm install express sequelize

# Install devDependencies
echo "Installing back-end devDependencies (this may take a while)..."
npm install --save-dev eslint nodemon prettier eslint-config-prettier eslint-plugin-prettier

echo "Back-end npm setup complete."

# Copy ESLint and Prettier configurations
echo "Copying ESLint and Prettier configurations..."
cp "$ESLINT_CONFIG" .
cp "$PRETTIER_CONFIG" .
echo "Configuration files copied."

# Create base index.js
echo "Creating base index.js..."
cat <<EOL > index.js
const express = require('express');
const app = express();
const router = require('./src/routers/router');

app.use(express.json());
app.use('/', router);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(\`Server is running on http://localhost:\${PORT}\`);
});
EOL

# Create example router.js
echo "Creating example router.js..."
mkdir -p src/routers
cat <<EOL > src/routers/router.js
const express = require('express');
const router = express.Router();
const controller = require('../controllers/controller');

router.get('/', controller.home);

module.exports = router;
EOL

# Create example controller.js
echo "Creating example controller.js..."
mkdir -p src/controllers
cat <<EOL > src/controllers/controller.js
exports.home = (req, res) => {
    res.send('Hello, World!');
};
EOL

# Return to project root directory
cd ..

# Set up CI/CD pipeline if required
if [ "$SETUP_CICD" = "yes" ]; then
    echo "Setting up CI/CD pipeline..."
    mkdir -p .github/workflows
    cat <<EOL > .github/workflows/nodejs.yml
name: Node.js CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:

    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3
    - name: Use Node.js 14.x
      uses: actions/setup-node@v3
      with:
        node-version: 14
    - run: npm install
    - run: npm test
EOL
    echo "CI/CD pipeline setup complete."
fi

# Commit all changes
echo "Committing project files to Git repository..."
git add .
git commit -m "Set up project structure and dependencies"

# Add remote origin and push if INIT_REMOTE is yes
if [ "$INIT_REMOTE" = "yes" ]; then
    echo "Adding remote origin and pushing to '$GIT_SOLUTION'..."
    REPO_NAME="$PROJECT_NAME"
    case "$GIT_SOLUTION" in
        github)
            REMOTE_URL="git@github.com:thibaudchaput/$REPO_NAME.git"
            ;;
        gitlab)
            REMOTE_URL="git@gitlab.com:thibaudchaput/$REPO_NAME.git"
            ;;
    esac
    git remote add origin "$REMOTE_URL"
    # Push to remote repository
    git push -u origin main
fi

# Open project in VS Code with the JavaScript development profile
echo "Opening project in VS Code with JavaScript Development profile..."
code --profile "javascript development" .

echo "Project setup complete."
