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

# Default values from config.conf
PROJECT_TYPE=""
PROJECT_NAME=""
PROJECT_DIR=""
GIT_SOLUTION="$DEFAULT_GIT_SOLUTION"
CUSTOM_PROJECT_DIR=""

# Function to display usage
usage() {
    echo "Usage: $0 -t <project-type> -n <project-name> [-d <project-directory>] [-g <git-solution>] [--no-remote] [--setup-cicd]"
    echo "Or run without arguments for interactive mode."
    echo "Project types: js, react, drupal, unity"
    echo "Git solutions: github, gitlab"
    exit 1
}

if [ $# -eq 0 ]; then
    INTERACTIVE_MODE=true
else
    INTERACTIVE_MODE=false
fi

if [ "$INTERACTIVE_MODE" = true ]; then
    echo "Interactive Mode: Please provide the following information."
    read -p "Project type (js/react/drupal/unity): " PROJECT_TYPE
    read -p "Project name: " PROJECT_NAME
    read -p "Custom project directory (leave empty to use default path) [$DEFAULT_PROJECTS_DIR]: " CUSTOM_PROJECT_DIR_INPUT
    CUSTOM_PROJECT_DIR="${CUSTOM_PROJECT_DIR_INPUT:-$DEFAULT_PROJECTS_DIR}"
    read -p "Git solution (github/gitlab) [$GIT_SOLUTION]: " GIT_SOLUTION_INPUT
    GIT_SOLUTION="${GIT_SOLUTION_INPUT:-$GIT_SOLUTION}"
    read -p "Initialize remote repository? (yes/no) [$INIT_REMOTE]: " INIT_REMOTE_INPUT
    INIT_REMOTE="${INIT_REMOTE_INPUT:-$INIT_REMOTE}"
    read -p "Set up CI/CD pipeline? (yes/no) [$SETUP_CICD]: " SETUP_CICD_INPUT
    SETUP_CICD="${SETUP_CICD_INPUT:-$SETUP_CICD}"

    # Construct the full project directory path
    PROJECT_DIR="$CUSTOM_PROJECT_DIR/$PROJECT_NAME"
else
    # Parse options
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -t) PROJECT_TYPE="$2"; shift ;;
            -n) PROJECT_NAME="$2"; shift ;;
            -d) CUSTOM_PROJECT_DIR="$2"; shift ;;
            -g) GIT_SOLUTION="$2"; shift ;;
            --no-remote) INIT_REMOTE="no" ;;
            --setup-cicd) SETUP_CICD="yes" ;;
            *) usage ;;
        esac
        shift
    done

    # Construct the full project directory path
    if [ -n "$CUSTOM_PROJECT_DIR" ]; then
        PROJECT_DIR="$CUSTOM_PROJECT_DIR/$PROJECT_NAME"
    elif [ -n "$PROJECT_NAME" ]; then
        PROJECT_DIR="$DEFAULT_PROJECTS_DIR/$PROJECT_NAME"
    else
        echo "Error: Project name cannot be empty."
        usage
    fi
fi

# Validate project type
case "$PROJECT_TYPE" in
    js|react|drupal|unity)
        echo "Project type: $PROJECT_TYPE"
        ;;
    *)
        echo "Error: Unsupported project type '$PROJECT_TYPE'"
        usage
        ;;
esac

# Validate project directory
if [ -z "$PROJECT_DIR" ]; then
    echo "Error: Project directory cannot be empty."
    usage
fi

# Validate git solution
case "$GIT_SOLUTION" in
    github|gitlab)
        echo "Git solution: $GIT_SOLUTION"
        ;;
    *)
        echo "Error: Unsupported git solution '$GIT_SOLUTION'"
        usage
        ;;
esac

# Debug output for variables
echo "Project name: $PROJECT_NAME"
echo "Project directory: $PROJECT_DIR"
echo "Git solution: $GIT_SOLUTION"
echo "Initialize remote repository: $INIT_REMOTE"
echo "Set up CI/CD pipeline: $SETUP_CICD"

# Determine the setup script to call
case "$PROJECT_TYPE" in
    js)
        SETUP_SCRIPT="$SCRIPT_DIR/js_init/js_init_setup.sh"
        ;;
    react)
        SETUP_SCRIPT="$SCRIPT_DIR/react_init/react_project_setup.sh"
        ;;
    drupal)
        SETUP_SCRIPT="$SCRIPT_DIR/drupal_init/drupal_init_setup.sh"
        ;;
    unity)
        SETUP_SCRIPT="$SCRIPT_DIR/unity_init/unity_project_setup.sh"
        ;;
esac

# Check if the setup script exists
if [ ! -f "$SETUP_SCRIPT" ]; then
    echo "Error: Setup script '$SETUP_SCRIPT' not found."
    exit 1
fi

# Call the setup script with the project directory and options
"$SETUP_SCRIPT" "$PROJECT_DIR" "$GIT_SOLUTION" "$INIT_REMOTE" "$SETUP_CICD"
