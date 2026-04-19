#!/bin/bash
# Migration script: Convert a Labs project to use mkdocs shared submodule
#
# This script:
#   1. Adds the mkdocs repo as a git submodule at .mkdocs-shared/
#   2. Identifies which files in mkdocs/ are project-specific vs shared
#   3. Removes shared files from mkdocs/ (keeping only project-specific)
#   4. Updates .gitignore to exclude .mkdocs-build/
#
# Usage:
#   bash .mkdocs-shared/mkdocs/scripts/setup-submodule.sh
#   # or after cloning the script locally:
#   bash setup-submodule.sh
#
# After running this script:
#   - .mkdocs-shared/  contains the shared mkdocs template (submodule)
#   - mkdocs/          contains ONLY project-specific files
#   - .mkdocs-build/   is generated at build time by init_site.sh (merged output)
#   - init_site.sh     automatically detects submodule mode and merges configs

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_info()    { printf "${BLUE}ℹ️  %s${NC}\n" "$1"; }
print_success() { printf "${GREEN}✅ %s${NC}\n" "$1"; }
print_warning() { printf "${YELLOW}⚠️  %s${NC}\n" "$1"; }
print_error()   { printf "${RED}❌ %s${NC}\n" "$1"; }

# Submodule remote URL
MKDOCS_REPO="https://github.com/nirgeier/mkdocs.git"
SUBMODULE_DIR=".mkdocs-shared"

# Project-specific files that should remain in mkdocs/
# These are the ONLY files a project needs to maintain
PROJECT_SPECIFIC_FILES=(
    "01-mkdocs-site.yml"
    "06-mkdocs-nav.yml"
)

#######################################
# Navigate to project root
#######################################
cd_to_root() {
    local root
    if ! root=$(git rev-parse --show-toplevel 2>/dev/null); then
        print_error "Not in a git repository"
        exit 1
    fi
    cd "$root"
    print_info "Working in: $root"
}

#######################################
# Add mkdocs repo as a git submodule
#######################################
add_submodule() {
    if [[ -d "$SUBMODULE_DIR" ]]; then
        print_warning "Submodule directory $SUBMODULE_DIR already exists, skipping add"
        return 0
    fi

    print_info "Adding mkdocs repo as submodule at $SUBMODULE_DIR..."
    git submodule add "$MKDOCS_REPO" "$SUBMODULE_DIR"
    git submodule update --init --recursive "$SUBMODULE_DIR"
    print_success "Submodule added at $SUBMODULE_DIR"
}

#######################################
# Check if a file is project-specific
#######################################
is_project_specific() {
    local filename
    filename=$(basename "$1")

    for pf in "${PROJECT_SPECIFIC_FILES[@]}"; do
        if [[ "$filename" == "$pf" ]]; then
            return 0
        fi
    done
    return 1
}

#######################################
# Clean shared files from mkdocs/, keeping only project-specific ones
#######################################
clean_shared_files() {
    if [[ ! -d "mkdocs" ]]; then
        print_warning "No mkdocs/ directory found, creating with project-specific files"
        mkdir -p mkdocs
        return 0
    fi

    print_info "Cleaning shared files from mkdocs/ (keeping project-specific only)..."

    # Backup mkdocs/ first
    local backup_dir=".mkdocs-backup-$(date +%Y%m%d%H%M%S)"
    cp -r mkdocs "$backup_dir"
    print_info "Backup created at $backup_dir"

    # Remove shared YAML configs (keep project-specific ones)
    for yml_file in mkdocs/*.yml; do
        [[ -f "$yml_file" ]] || continue
        if ! is_project_specific "$yml_file"; then
            print_info "  Removing shared: $yml_file"
            rm -f "$yml_file"
        else
            print_success "  Keeping project-specific: $yml_file"
        fi
    done

    # Remove shared directories that are fully provided by the submodule
    # Keep overrides/ only if it has project-specific content
    local shared_dirs=("scripts" "partials")
    for dir in "${shared_dirs[@]}"; do
        if [[ -d "mkdocs/$dir" ]]; then
            print_info "  Removing shared dir: mkdocs/$dir"
            rm -rf "mkdocs/$dir"
        fi
    done

    # Remove requirements.txt (comes from shared)
    if [[ -f "mkdocs/requirements.txt" ]]; then
        print_info "  Removing shared: mkdocs/requirements.txt"
        rm -f "mkdocs/requirements.txt"
    fi

    # Remove schema file
    rm -f "mkdocs/mkdocs.yml.schema.json"

    # Clean up overrides: only keep project-specific images and custom partials
    if [[ -d "mkdocs/overrides" ]]; then
        # Remove shared partials (badges.html, usage.md are auto-generated)
        local shared_partials=("header.html" "header copy.html" "footer.html" "social.html" "source-file.html" "badges.html" "usage.md")
        for partial in "${shared_partials[@]}"; do
            if [[ -f "mkdocs/overrides/partials/$partial" ]]; then
                print_info "  Removing shared partial: $partial"
                rm -f "mkdocs/overrides/partials/$partial"
            fi
        done

        # Remove shared stylesheets (SCSS modules)
        if [[ -d "mkdocs/overrides/assets/stylesheets" ]]; then
            print_info "  Removing shared stylesheets"
            rm -rf "mkdocs/overrides/assets/stylesheets"
        fi

        # Remove shared javascripts
        if [[ -d "mkdocs/overrides/assets/javascripts" ]]; then
            print_info "  Removing shared javascripts"
            rm -rf "mkdocs/overrides/assets/javascripts"
        fi

        # Remove home.html (shared template)
        rm -f "mkdocs/overrides/home.html"

        # Keep project-specific images if they exist
        if [[ -d "mkdocs/overrides/assets/images" ]]; then
            local img_count
            img_count=$(find "mkdocs/overrides/assets/images" -type f 2>/dev/null | wc -l)
            if [[ "$img_count" -gt 0 ]]; then
                print_success "  Keeping project-specific images ($img_count files)"
            fi
        fi

        # Clean up empty directories
        find mkdocs/overrides -type d -empty -delete 2>/dev/null || true
    fi

    # Clean up empty directories in mkdocs/
    find mkdocs -type d -empty -delete 2>/dev/null || true

    print_success "Shared files cleaned from mkdocs/"
    print_info "Backup available at: $backup_dir"
}

#######################################
# Update .gitignore
#######################################
update_gitignore() {
    local gitignore=".gitignore"

    # Entries to add
    local entries=(
        "# MkDocs submodule build directory (generated)"
        ".mkdocs-build/"
        ".mkdocs-backup-*"
    )

    if [[ ! -f "$gitignore" ]]; then
        printf '%s\n' "${entries[@]}" > "$gitignore"
        print_success "Created .gitignore with mkdocs-build exclusion"
        return 0
    fi

    # Check if already present
    if grep -q ".mkdocs-build/" "$gitignore"; then
        print_warning ".mkdocs-build/ already in .gitignore"
        return 0
    fi

    # Append entries
    printf '\n%s\n' "${entries[@]}" >> "$gitignore"
    print_success "Updated .gitignore with .mkdocs-build/ exclusion"
}

#######################################
# Create init_site.sh wrapper in project root
#######################################
create_init_wrapper() {
    local wrapper="init_site.sh"

    if [[ -f "$wrapper" ]]; then
        print_warning "$wrapper already exists, skipping"
        return 0
    fi

    cat > "$wrapper" << 'WRAPPER'
#!/bin/bash
# Wrapper to run init_site.sh from the mkdocs shared submodule
# This script finds and runs the shared init_site.sh

set -euo pipefail

PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$PROJECT_ROOT"

# Determine which init_site.sh to use
if [[ -f ".mkdocs-shared/mkdocs/scripts/init_site.sh" ]]; then
    # Submodule mode: use the shared script
    exec bash .mkdocs-shared/mkdocs/scripts/init_site.sh "$@"
elif [[ -f "mkdocs/scripts/init_site.sh" ]]; then
    # Standalone mode: use local script
    exec bash mkdocs/scripts/init_site.sh "$@"
else
    echo "❌ init_site.sh not found in .mkdocs-shared/ or mkdocs/"
    exit 1
fi
WRAPPER

    chmod +x "$wrapper"
    print_success "Created $wrapper wrapper in project root"
}

#######################################
# Show summary and next steps
#######################################
show_summary() {
    echo ""
    print_success "═══════════════════════════════════════════════════"
    print_success "  Submodule setup complete!"
    print_success "═══════════════════════════════════════════════════"
    echo ""
    print_info "Structure:"
    echo "  .mkdocs-shared/   ← Shared mkdocs template (git submodule)"
    echo "  mkdocs/            ← Project-specific overrides only"
    echo "  .mkdocs-build/     ← Generated at build time (gitignored)"
    echo "  init_site.sh       ← Wrapper script"
    echo ""
    print_info "Project-specific files to maintain:"

    if [[ -d "mkdocs" ]]; then
        find mkdocs -type f | sort | while read -r f; do
            echo "  $f"
        done
    fi

    echo ""
    print_info "Next steps:"
    echo "  1. Review and commit the changes:"
    echo "     git add .gitmodules .mkdocs-shared mkdocs .gitignore init_site.sh"
    echo "     git commit -m 'Switch to mkdocs shared submodule'"
    echo ""
    echo "  2. Build docs: ./init_site.sh"
    echo ""
    echo "  3. Update shared template: git submodule update --remote .mkdocs-shared"
    echo ""
}

#######################################
# Main
#######################################
main() {
    print_info "Starting mkdocs submodule setup..."
    echo ""

    cd_to_root
    add_submodule
    clean_shared_files
    update_gitignore
    create_init_wrapper
    show_summary
}

main "$@"
