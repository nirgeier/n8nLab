#!/bin/bash
# Setup script for The specific MkDocs project

set -euo pipefail # Exit on error, undefined vars, pipe failures

# Get the root of the Git Project
# If running inside a submodule (.git is a file, not a directory),
# navigate up to the actual parent project root.
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
if [[ -f "${PROJECT_ROOT}/.git" ]]; then
    PROJECT_ROOT=$(git -C "${PROJECT_ROOT}/.." rev-parse --show-toplevel 2>/dev/null || dirname "${PROJECT_ROOT}")
fi

# Directories
SHARED_MKDOCS_DIR="${PROJECT_ROOT}/.mkdocs-shared/mkdocs" # shared base (submodule)
PROJECT_MKDOCS_DIR="${PROJECT_ROOT}/mkdocs"               # project-specific overrides
BUILD_DIR="${PROJECT_ROOT}/.mkdocs-build"                 # merged output (always used)

# Configuration
MKDOCS_CONFIG_FILE="${BUILD_DIR}/01-mkdocs-site.yml"
readonly VENV_DIR="${PROJECT_ROOT}/.venv"
REQUIREMENTS_FILE="${BUILD_DIR}/requirements.txt"

# Fallback: if shared submodule not present, use project mkdocs/ directly
if [[ ! -d "${SHARED_MKDOCS_DIR}" ]]; then
    SHARED_MKDOCS_DIR="${PROJECT_MKDOCS_DIR}"
fi

# Global variables
REPO_OWNER=""
REPO_NAME=""
SITE_URL=""
REPO_URL=""
ROOT_FOLDER=""

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#######################################
# Show usage information
#######################################
show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

A robust setup script for MkDocs projects that automatically configures
site URLs based on git remote information.

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    --no-serve      Build documentation but don't start the server
    --clean         Clean build directory before building
    --deploy        Deploy documentation to GitHub Pages

DESCRIPTION:
    This script performs the following actions:
    1. Loads environment variables from .env if present
    2. Detects git repository information from remote origin
    3. Generates appropriate site_url and repo_url values
    4. Updates MkDocs configuration files (only empty fields)
    5. Sets up Python virtual environment if needed
    6. Builds and serves the documentation

EXAMPLES:
    $0                  # Full setup and serve
    $0 --no-serve       # Setup and build only
    $0 --clean          # Clean build and serve
    $0 --deploy         # Setup, build and deploy to GitHub Pages
    $0 --help           # Show this help

EOF
}

#######################################
# Parse command line arguments
#######################################
parse_arguments() {
    VERBOSE=false
    NO_SERVE=false
    CLEAN_BUILD=false
    DEPLOY=false

    while [[ $# -gt 0 ]]; do
        case $1 in
        -h | --help)
            show_usage
            exit 0
            ;;
        -v | --verbose)
            VERBOSE=true
            shift
            ;;
        --no-serve)
            NO_SERVE=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --deploy)
            DEPLOY=true
            NO_SERVE=true # Don't serve when deploying
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        esac
    done
}
print_color() {
    printf "${1}%s${NC}\n" "$2"
}

#######################################
# Print info message
# Arguments:
#   $1: message
#######################################
print_info() {
    print_color "$BLUE" "ℹ️  $1"
}

#######################################
# Print success message
# Arguments:
#   $1: message
#######################################
print_success() {
    print_color "$GREEN" "✅ $1"
}

#######################################
# Print warning message
# Arguments:
#   $1: message
#######################################
print_warning() {
    print_color "$YELLOW" "⚠️  $1"
}

#######################################
# Print error message
# Arguments:
#   $1: message
#######################################
print_error() {
    print_color "$RED" "❌ $1"
}

#######################################
# Load environment variables from .env file
#######################################
load_env() {
    if [[ -f .env ]]; then
        print_info "Loading environment variables from .env"
        set -a # automatically export all variables
        # shellcheck source=/dev/null
        source .env
        set +a
    fi
}

#######################################
# Initialize working directory to git root
#######################################
init_workspace() {
    ROOT_FOLDER="${PROJECT_ROOT}"
    print_info "Changing to project root: $ROOT_FOLDER"
    cd "$ROOT_FOLDER"
}

#######################################
# Parse GitHub repository information from git remote URL
# Sets global variables: REPO_OWNER, REPO_NAME
#######################################
parse_git_remote() {
    local remote_url

    if ! remote_url=$(git -C "${PROJECT_ROOT}" remote get-url origin 2>/dev/null); then
        print_error "Could not get git remote URL. Please ensure origin remote is configured."
        exit 1
    fi

    print_info "Remote URL: $remote_url"

    # Parse GitHub repository information from different URL formats
    if [[ $remote_url =~ git@github\.com:([^/]+)/([^.]+)\.git ]]; then
        # SSH format: git@github.com:owner/repo.git
        REPO_OWNER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
    elif [[ $remote_url =~ https://github\.com/([^/]+)/([^.]+)\.git ]]; then
        # HTTPS format: https://github.com/owner/repo.git
        REPO_OWNER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
    elif [[ $remote_url =~ https://github\.com/([^/]+)/([^/]+)$ ]]; then
        # HTTPS format without .git: https://github.com/owner/repo
        REPO_OWNER="${BASH_REMATCH[1]}"
        REPO_NAME="${BASH_REMATCH[2]}"
    else
        print_warning "Could not parse GitHub repository information from remote URL: $remote_url"
        print_warning "Using default values..."
        REPO_OWNER="nirgeier"
        REPO_NAME="mkdocs"
    fi

    print_success "Repository Owner: $REPO_OWNER"
    print_success "Repository Name: $REPO_NAME"
}

#######################################
# Generate URLs based on repository information
# Sets global variables: SITE_URL, REPO_URL
#######################################
generate_urls() {
    SITE_URL="https://${REPO_OWNER}.github.io/${REPO_NAME}/"
    REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"

    print_info "Generated Site URL: $SITE_URL"
    print_info "Generated Repo URL: $REPO_URL"
}

#######################################
# Initialize and update git submodule if present
#######################################
init_submodule() {
    local submodule_dir="${PROJECT_ROOT}/.mkdocs-shared"

    if [[ ! -d "${submodule_dir}" ]]; then
        return 0
    fi

    print_info "Initializing .mkdocs-shared submodule..."

    if [[ ! -f "${submodule_dir}/.git" && ! -d "${submodule_dir}/.git" ]]; then
        git submodule update --init --recursive .mkdocs-shared
    fi

    git submodule update --remote .mkdocs-shared 2>/dev/null || true

    print_success "Submodule initialized and updated"
}

#######################################
# Copy assets from .mkdocs-build/overrides/assets/ → Labs/assets/
# Labs/assets/ is gitignored and fully generated at build time.
#######################################
copy_assets() {
    local src="${BUILD_DIR}/overrides/assets"
    local dst="${PROJECT_ROOT}/Labs/assets"

    if [[ ! -d "${src}" ]]; then
        print_warning "Assets source not found: ${src}, skipping"
        return 0
    fi

    print_info "Copying assets from .mkdocs-build/overrides/assets/ → Labs/assets/..."
    rm -rf "${dst}"
    cp -r "${src}" "${dst}"
    print_success "Copied assets → Labs/assets/"
}

#######################################
# Build .mkdocs-build/ by merging shared base + project overrides
#
# Step 1: Copy .mkdocs-shared/mkdocs/  → .mkdocs-build/  (shared base)
# Step 2: Copy project mkdocs/          → .mkdocs-build/  (project wins)
# Step 3: Fix custom_dir → .mkdocs-build/overrides
#######################################
merge_shared_configs() {
    print_info "Building ${BUILD_DIR}..."

    # ── Step 1: fresh copy of the shared base ────────────────────────────
    rm -rf "${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"

    if [[ -d "${SHARED_MKDOCS_DIR}" ]]; then
        cp -r "${SHARED_MKDOCS_DIR}/." "${BUILD_DIR}/"
        print_success "Step 1: Copied shared base → ${BUILD_DIR}"
    else
        print_error "Shared mkdocs dir not found: ${SHARED_MKDOCS_DIR}"
        return 1
    fi

    # ── Step 2: overlay project mkdocs/ on top (project always wins) ─────
    if [[ -d "${PROJECT_MKDOCS_DIR}" ]]; then
        cp -rf "${PROJECT_MKDOCS_DIR}/." "${BUILD_DIR}/"
        print_success "Step 2: Overlaid project overrides from mkdocs/ → ${BUILD_DIR}"
    fi

    # ── Step 3: fix custom_dir so overrides resolve from the build dir ───
    local theme_config="${BUILD_DIR}/02-mkdocs-theme.yml"
    if [[ -f "${theme_config}" ]]; then
        sed -i.bak "s|custom_dir:.*|custom_dir: .mkdocs-build/overrides|" "${theme_config}"
        rm -f "${theme_config}.bak"
        print_success "Step 3: Set custom_dir → .mkdocs-build/overrides"
    fi

    # Remove scripts/ - not needed in the merged config output
    rm -rf "${BUILD_DIR}/scripts"

    print_success "Merge complete → ${BUILD_DIR}"
}

#######################################
# Update a YAML field in a configuration file if the field is empty.
# Arguments:
#   $1: field name (e.g., "site_name")
#   $2: field value to set if empty
#   $3: path to the YAML config file
# Returns:
#   0 if successful, 1 if config file not found
#   Prints info/warning messages about the update status
#######################################
update_yaml_field_if_empty() {
    local field_name="$1"
    local field_value="$2"
    local config_file="$3"

    if [[ ! -f "$config_file" ]]; then
        print_error "Config file not found: $config_file"
        return 1
    fi

    # Check if field doesn't exist at all
    if ! grep -q "^${field_name}:" "$config_file"; then
        print_info "Adding $field_name to: $field_value"
        echo "${field_name}: ${field_value}" >>"$config_file"
    # Check if field exists but is empty or contains only whitespace/empty quotes/null
    elif grep -qE "^${field_name}:\s*(\"\s*\"|'\s*'|null|~)?\s*$" "$config_file"; then
        print_info "Setting $field_name to: $field_value"
        sed -i.bak "s|^${field_name}:.*$|${field_name}: ${field_value}|g" "$config_file"
    else
        print_warning "$field_name already has a value, skipping"
    fi
}

#######################################
# Update usage.md with project-specific links
# Replaces placeholders with actual values derived from git remote
#######################################
#######################################
# Replace __TOKEN__ placeholders in a file with actual repo values.
# Tokens: __REPO_URL__, __REPO_OWNER__, __REPO_NAME__, __SITE_URL__
# Arguments:
#   $1: path to the file
#######################################
replace_tokens() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        print_warning "replace_tokens: file not found: $file, skipping"
        return 0
    fi

    sed -i.bak \
        -e "s|__REPO_URL__|${REPO_URL}|g" \
        -e "s|__REPO_OWNER__|${REPO_OWNER}|g" \
        -e "s|__REPO_NAME__|${REPO_NAME}|g" \
        -e "s|__SITE_URL__|${SITE_URL}|g" \
        "$file"
    rm -f "${file}.bak"

    print_success "Replaced tokens in $(basename "$file")"
}

update_usage_md() {
    local usage_file="${BUILD_DIR}/overrides/partials/usage.md"

    if [[ ! -f "$usage_file" ]]; then
        print_warning "usage.md not found: $usage_file, skipping"
        return 0
    fi

    print_info "Updating usage.md with project-specific links..."

    # Generate killercoda scenario name (repo name without hyphens)
    local killercoda_scenario="${REPO_NAME//-/}"
    local killercoda_url="https://killercoda.com/codewizard/scenario/${killercoda_scenario}"

    # Generate GHCR image name (lowercase repo owner/name)
    local repo_name_lower
    repo_name_lower=$(echo "${REPO_NAME}" | tr '[:upper:]' '[:lower:]')
    local ghcr_image="ghcr.io/${REPO_OWNER}/${repo_name_lower}"

    # Detect the setup lab directory (first directory in Labs/, any naming convention)
    local setup_lab_dir="000-setup"
    if [[ -d "Labs" ]]; then
        local first_lab
        first_lab=$(find Labs -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | head -1 | xargs -I{} basename {} 2>/dev/null || true)
        if [[ -n "$first_lab" ]]; then
            setup_lab_dir="$first_lab"
        fi
    fi

    sed -i.bak \
        -e "s|__KILLERCODA_URL__|${killercoda_url}|g" \
        -e "s|__GHCR_IMAGE__|${ghcr_image}|g" \
        -e "s|__REPO_URL__|${REPO_URL}|g" \
        -e "s|__REPO_NAME__|${REPO_NAME}|g" \
        -e "s|__SETUP_LAB_DIR__|${setup_lab_dir}|g" \
        "$usage_file"

    rm -f "${usage_file}.bak"

    # Create a stable path so welcome.md can always include from the same location
    # regardless of standalone (mkdocs/) or submodule (.mkdocs-build/) mode
    local stable_path="${BUILD_DIR}/overrides/partials/usage.md"
    local docs_include_dir="Labs/assets/partials"
    mkdir -p "$docs_include_dir"
    cp "$stable_path" "${docs_include_dir}/usage.md"
    print_success "Copied usage.md to ${docs_include_dir}/usage.md"

    print_success "Updated usage.md with project-specific links"
}

#######################################
# Replace default 'mkdocs' placeholder values in a YAML config file.
# If the repo name is not 'mkdocs' and a field still contains the
# default mkdocs-based value, replace it with the correct value.
# Arguments:
#   $1: field name
#   $2: correct field value
#   $3: path to the YAML config file
#######################################
replace_default_mkdocs_value() {
    local field_name="$1"
    local field_value="$2"
    local config_file="$3"

    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    # Only act when the actual repo is NOT 'mkdocs'
    if [[ "$REPO_NAME" == "mkdocs" ]]; then
        return 0
    fi

    # Check if the field currently holds a default mkdocs-based value
    if grep -qE "^${field_name}:.*(/mkdocs[/\"' ]*$|: mkdocs$|/mkdocs$)" "$config_file" ||
        grep -q "^${field_name}: mkdocs$" "$config_file"; then
        print_info "Replacing default mkdocs value for $field_name with: $field_value"
        sed -i.bak "s|^${field_name}:.*$|${field_name}: ${field_value}|g" "$config_file"
        rm -f "${config_file}.bak"
    fi
}

#######################################
# Update social links in configuration files
# Arguments:
#   $1: config file path
#######################################
update_social_links() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        print_warning "Config file not found: $config_file"
        return 1
    fi

    print_info "Updating social links in $config_file..."

    # Update GitHub repository URLs in social links
    # Update plugin repository references (like git-committers)
    # Update any other GitHub URLs
    sed -i.bak \
        -e 's|link: https://github\.com/[^/]*/[^/]*$|link: '"${REPO_URL}"'|g' \
        -e 's|link: https://github\.com/[^/]*/[^/]*/stargazers|link: '"${REPO_URL}"'/stargazers|g' \
        -e 's|link: https://github\.com/[^/]*/[^/]*/network/members|link: '"${REPO_URL}"'/network/members|g' \
        -e 's|repository: [^/]*/[^/]*$|repository: '"${REPO_OWNER}"'/'"${REPO_NAME}"'|g' \
        "$config_file"

    # Clean up backup files
    rm -f "${config_file}.bak"

    print_success "Updated social links in $config_file"
}

#######################################
# Update copyright year in theme configuration
#######################################
update_copyright_year() {
    local theme_config_file="${BUILD_DIR}/02-mkdocs-theme.yml"
    local current_year
    current_year=$(date +%Y)

    if [[ ! -f "$theme_config_file" ]]; then
        print_warning "Theme config file not found: $theme_config_file"
        return 1
    fi

    print_info "Updating copyright year to $current_year in $theme_config_file..."

    # Replace any copyright line with the current year
    sed -i.bak "s/^copyright: .*/copyright: \"©2021-${current_year} Nir Geier\"/" "$theme_config_file"

    # Clean up backup file
    rm -f "${theme_config_file}.bak"
}

#######################################
# Update CSS version to force reload
#######################################
update_css_version() {
    local config_file="${BUILD_DIR}/03-mkdocs-extra.yml"
    local timestamp=$(date +%s)

    if [[ ! -f "$config_file" ]]; then
        print_warning "Config file not found: $config_file"
        return 1
    fi

    print_info "Updating CSS version in $config_file..."

    # Replace all CSS lines with the new version
    # Matches any line ending in .css or .css?v=...
    sed -i.bak "s|\([[:space:]]*-[[:space:]]*.*\.css\).*|\1?v=${timestamp}|" "$config_file"

    # Clean up backup file
    rm -f "${config_file}.bak"

    print_success "Updated CSS version to v=${timestamp}"

}

#######################################
# Update JS version to force reload
#######################################
update_js_version() {
    local config_file="${BUILD_DIR}/03-mkdocs-extra.yml"
    local timestamp=$(date +%s)

    if [[ ! -f "$config_file" ]]; then
        print_warning "Config file not found: $config_file"
        return 1
    fi

    print_info "Updating JS version in $config_file..."

    # Replace all JS lines with the new version
    # Matches any line ending in .js or .js?v=...
    sed -i.bak "s|\([[:space:]]*-[[:space:]]*.*\.js\).*|\1?v=${timestamp}|" "$config_file"

    # Clean up backup file
    rm -f "${config_file}.bak"

    print_success "Updated JS version to v=${timestamp}"
}

#######################################
# Update all MkDocs configuration fields
#######################################
update_mkdocs_config() {
    print_info "Checking and updating empty values in $MKDOCS_CONFIG_FILE..."

    if [[ ! -f "$MKDOCS_CONFIG_FILE" ]]; then
        print_error "MkDocs config file not found: $MKDOCS_CONFIG_FILE"
        exit 1
    fi

    # Replace default mkdocs placeholder values with actual repo values
    replace_default_mkdocs_value "site_name" "$REPO_NAME" "$MKDOCS_CONFIG_FILE"
    replace_default_mkdocs_value "site_url" "$SITE_URL" "$MKDOCS_CONFIG_FILE"
    replace_default_mkdocs_value "repo_url" "$REPO_URL" "$MKDOCS_CONFIG_FILE"
    replace_default_mkdocs_value "repo_name" "$REPO_OWNER/$REPO_NAME" "$MKDOCS_CONFIG_FILE"
    replace_default_mkdocs_value "site_description" "A collection of $REPO_NAME Labs" "$MKDOCS_CONFIG_FILE"

    # Update each field if empty
    update_yaml_field_if_empty "site_name" "$REPO_NAME" "$MKDOCS_CONFIG_FILE"
    update_yaml_field_if_empty "site_url" "$SITE_URL" "$MKDOCS_CONFIG_FILE"
    update_yaml_field_if_empty "repo_url" "$REPO_URL" "$MKDOCS_CONFIG_FILE"
    update_yaml_field_if_empty "repo_name" "$REPO_OWNER/$REPO_NAME" "$MKDOCS_CONFIG_FILE"

    # Clean up backup files
    rm -f "${MKDOCS_CONFIG_FILE}.bak"

    print_success "Updated $MKDOCS_CONFIG_FILE with dynamic values (only empty fields)"

    # Update copyright year in theme configuration
    update_copyright_year

    # Replace __REPO_URL__ and other tokens in the site configuration
    replace_tokens "${BUILD_DIR}/01-mkdocs-site.yml"

    # Replace __REPO_URL__ and other tokens in the extra configuration
    replace_tokens "${BUILD_DIR}/03-mkdocs-extra.yml"

    # Update CSS version
    update_css_version
    update_js_version

    # Update repository references in plugins configuration
    update_social_links "${BUILD_DIR}/04-mkdocs-plugins.yml"

    # Fix paths that reference mkdocs/ - they should point to .mkdocs-build/ after the merge
    local plugins_config="${BUILD_DIR}/04-mkdocs-plugins.yml"
    if [[ -f "${plugins_config}" ]]; then
        sed -i.bak "s|password_file:.*\"mkdocs/|password_file: \".mkdocs-build/|g" "${plugins_config}"
        rm -f "${plugins_config}.bak"
        print_success "Fixed password_file path → .mkdocs-build/ in 04-mkdocs-plugins.yml"
    fi

    # Update usage.md with project-specific links (killercoda, GHCR, etc.)
    update_usage_md
}

#######################################
# Concatenate 01-06 config files from BUILD_DIR into mkdocs.yml
#######################################
build_mkdocs_config() {
    print_info "Building ${PROJECT_ROOT}/mkdocs.yml from ${BUILD_DIR} (files 01-06)..."

    # Clear the output file
    : >"${PROJECT_ROOT}/mkdocs.yml"

    # Concat 01 → 06 explicitly in order
    for n in 01 02 03 04 05 06; do
        local matched
        matched=$(ls "${BUILD_DIR}/${n}-"*.yml 2>/dev/null | head -1)
        if [[ -f "${matched}" ]]; then
            cat "${matched}" >>"${PROJECT_ROOT}/mkdocs.yml"
            print_success "  Added: $(basename "${matched}")"
        else
            print_warning "  ${n}-*.yml not found in ${BUILD_DIR}, skipping"
        fi
    done

    update_social_links "${PROJECT_ROOT}/mkdocs.yml"

    print_success "Built mkdocs.yml"
}

#######################################
# Build dynamic navigation structure
#######################################
build_dynamic_navigation() {
    print_info "Building dynamic navigation structure..."

    # Look for build_nav.sh in multiple locations
    local nav_script=""
    for candidate in \
        "${PROJECT_ROOT}/content/scripts/build_nav.sh" \
        "${PROJECT_ROOT}/build_nav.sh" \
        "${PROJECT_ROOT}/scripts/build_nav.sh"; do
        if [[ -f "$candidate" ]]; then
            nav_script="$candidate"
            break
        fi
    done

    if [[ -n "$nav_script" ]]; then
        if bash "$nav_script" --sort numeric; then
            print_success "Dynamic navigation built successfully"
        else
            print_warning "Dynamic navigation build failed, using existing navigation"
        fi
    else
        print_warning "Navigation builder script not found, using existing navigation"
    fi
}

#######################################
# Setup Python virtual environment
#######################################
setup_python_env() {
    if [[ -d "$VENV_DIR" ]]; then
        print_info "Virtual environment found, activating..."
        # shellcheck source=/dev/null
        source "$VENV_DIR/bin/activate"
    else
        print_info "Creating new virtual environment..."
        python3 -m venv "$VENV_DIR"
        # shellcheck source=/dev/null
        source "$VENV_DIR/bin/activate"

        print_info "Upgrading pip..."
        uv pip install --upgrade pip

        if [[ -f "$REQUIREMENTS_FILE" ]]; then
            print_info "Installing requirements from $REQUIREMENTS_FILE..."
            uv pip install -r "$REQUIREMENTS_FILE"
        else
            print_warning "Requirements file not found: $REQUIREMENTS_FILE"
        fi

        print_success "Virtual environment created and configured"
    fi
}

#######################################
# Build MkDocs documentation
#######################################
build_docs() {
    if [[ "$CLEAN_BUILD" == true ]]; then
        print_info "Cleaning build directory..."
        rm -rf mkdocs-site/
    fi

    print_info "Building documentation..."

    if ! mkdocs build; then
        print_error "Failed to build documentation"
        return 1
    fi

    print_success "Documentation built successfully"
}

#######################################
# Deploy MkDocs documentation to GitHub Pages
#######################################
deploy_docs() {
    print_info "Deploying documentation to GitHub Pages..."

    if ! mkdocs gh-deploy --clean; then
        print_error "Failed to deploy documentation to GitHub Pages"
        return 1
    fi

    print_success "Documentation deployed successfully to GitHub Pages"
    print_success "Site should be available at: $SITE_URL"
}

#######################################
# Serve MkDocs documentation
#######################################
serve_docs() {
    if [[ "$NO_SERVE" == true ]]; then
        print_info "Skipping server start (--no-serve flag provided)"
        return 0
    fi

    local port="${PORT:-8000}"
    print_info "Starting MkDocs development server on port ${port}..."
    print_info "Press Ctrl+C to stop the server"

    # Use exec to replace the current shell process
    exec mkdocs serve --dev-addr "0.0.0.0:${port}" --watch-theme --watch "${PROJECT_MKDOCS_DIR}"
}

#######################################
# Main function to orchestrate the setup
#######################################
main() {
    # Parse command line arguments
    parse_arguments "$@"

    if [[ "$VERBOSE" == true ]]; then
        set -x # Enable debug mode
    fi

    print_info "Starting MkDocs project setup..."

    # Load environment variables
    load_env

    # Initialize workspace
    init_workspace

    # Parse git repository information
    parse_git_remote

    # Generate URLs
    generate_urls

    # Initialize submodule and merge shared configs (if submodule mode)
    init_submodule
    merge_shared_configs

    # Copy assets from .mkdocs-build/overrides/assets/ → Labs/assets/ (generated, gitignored)
    copy_assets

    # Update MkDocs configuration
    update_mkdocs_config

    # Build final configuration
    build_mkdocs_config

    # Setup Python environment
    setup_python_env

    # Build documentation
    if build_docs; then
        print_success "Setup complete! URLs updated based on git remote origin."
        print_success "Site URL: $SITE_URL"
        print_success "Repo URL: $REPO_URL"

        # Deploy or serve documentation
        if [[ "$DEPLOY" == true ]]; then
            deploy_docs
        else
            serve_docs
        fi
    else
        print_error "Setup failed during documentation build"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
