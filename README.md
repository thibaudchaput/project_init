# Project Setup Automation

## Overview

This repository provides a streamlined solution for initializing development environments for various project types, including **JavaScript**, **React**, **Drupal**, and **Unity**. It automates the setup process to ensure consistency and save time by managing dependencies, configuration files, and development tools like **Git** and **VS Code** profiles. The solution is modular, extensible, and supports adding additional languages and environments in the future.

---

## Features

- **Automated Setup**:
  - Installs dependencies for supported project types.
  - Configures servers and databases (e.g., Apache, PHP, MariaDB for Drupal projects).
  - Initializes Git repositories and optionally sets up remote repositories.
  - Creates project structures and configuration files automatically.

- **Modular Design**:
  - Easily expandable to include new languages and environments.

- **Customizable Configurations**:
  - Supports custom `.env` files, ESLint/Prettier settings, and CI/CD pipelines.

- **VS Code Integration**:
  - Launches projects with preconfigured VS Code profiles tailored to each project type.

- **Comprehensive Logging**:
  - Logs all setup actions for debugging and auditing purposes.

---

## Repository Structure

```plaintext
.
├── config.conf                 # Global configuration file
├── configs/                    # Directory for additional config files (e.g., ESLint, Prettier)
│   └── js_config/
│       ├── .eslintrc.json      # ESLint configuration for JavaScript
│       └── .prettierrc         # Prettier configuration for JavaScript
├── drupal_init/
│   └── drupal_init_setup.sh    # Script to set up Drupal projects
├── git-init-repo/
│   └── git-init-repo           # Script to initialize Git repositories
├── js_init/
│   └── js_init_setup.sh        # Script to set up JavaScript projects
├── logs/                       # Directory for setup logs
├── project_setup.sh            # Master script for project setup
└── README.md                   # Documentation (this file)
```

---

## Prerequisites

### Operating System

- Arch Linux (or compatible systems with the `pacman` package manager).

### Packages

Ensure the following tools are installed:

- Git
- Node.js/NPM
- PHP
- Apache
- MariaDB
- Composer

### Tools

- `gh` for GitHub CLI (if using GitHub).
- `glab` for GitLab CLI (if using GitLab).
- VS Code installed with profiles enabled.

---

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/your-repo/project-init.git ~/scripts/project_init
   ```

2. Update the `config.conf` file:
   - Set `DEFAULT_PROJECTS_DIR`, `DEFAULT_GIT_SOLUTION`, and other default settings.
   - Add paths to configuration files for supported languages/environments.

3. Ensure all scripts are executable:

   ```bash
   chmod +x ~/scripts/project_init/**/*.sh
   ```

---

## Usage

### Interactive Mode

Run the `project_setup.sh` script without arguments to use the interactive mode:

```bash
./project_setup.sh
```

You will be prompted for the following inputs:

- **Project Type**: Choose from `js`, `react`, `drupal`, or `unity`.
- **Project Name**: Name of the new project.
- **Custom Project Directory**: Leave blank to use the default directory (`DEFAULT_PROJECTS_DIR`).
- **Git Solution**: Choose `github` or `gitlab`.
- **Initialize Remote Repository**: Specify `yes` or `no`.
- **Set Up CI/CD Pipeline**: Specify `yes` or `no`.

### Command-Line Mode

Run the script with arguments for automation:

```bash
./project_setup.sh -t <project-type> -n <project-name> [-d <project-directory>] [-g <git-solution>] [--no-remote] [--setup-cicd]
```

**Example**:

```bash
./project_setup.sh -t drupal -n my_drupal_project --setup-cicd
```

---

## Extending the Project

### Adding New Languages/Environments

1. Create a new setup script in the appropriate directory (e.g., `python_init/python_init_setup.sh` for Python projects).
2. Update `project_setup.sh` to recognize the new project type and call the corresponding script.
3. Add configuration files to the `configs/` directory as needed.

### Customizing Project Setup

- **Environment Files**: Extend the script to prompt for `.env` variables or load templates for each project type.
- **Specific Modules**:
  - For **Drupal**: Modify `drupal_init_setup.sh` to allow users to select additional modules during setup.
  - For **JavaScript**: Include popular frameworks or tools (e.g., Webpack, Babel).

### Configuring VS Code Profiles

- Create language-specific profiles in VS Code.
- Use `--profile <profile-name>` when launching VS Code in the scripts.
- Add new profiles for each supported language/environment in the VS Code settings.

---

## Logs

All logs are stored in the `logs/` directory. Each setup run generates a timestamped log file:

```plaintext
logs/
├── drupal_setup_YYYY-MM-DD_HH-MM-SS.log
├── js_project_setup_YYYYMMDD_HHMMSS.log
```

Use these logs to troubleshoot setup errors.

---

## Future Enhancements

- **Language Support**: Add Python, Ruby, and Go setups.
- **Dynamic Configuration**: Extend configuration files for environment-specific settings.
- **Advanced CI/CD**: Expand pipeline options for GitHub Actions, GitLab CI, and Jenkins.
- **Dependency Management**: Support alternative package managers like Yarn, Pipenv, etc.

---

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create a feature branch.
3. Submit a pull request with a detailed explanation of your changes.

---

## License

This project is licensed under the MIT License. Feel free to use and adapt it for your needs.
