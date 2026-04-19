#!/bin/bash

##############################################################################
# n8n Local Setup Script
#
# This script sets up a local n8n instance with PostgreSQL database
# Usage: ./scripts/setup.sh
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"
ENV_EXAMPLE="$PROJECT_DIR/.env.example"

##############################################################################
# Helper Functions
##############################################################################

print_header() {
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
  echo -e "${GREEN}✅  $1${NC}"
}

print_error() {
  echo -e "${RED}❌  $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️   $1${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ️   $1${NC}"
}

##############################################################################
# Prerequisite Checks
##############################################################################

check_prerequisites() {
  print_header "Checking Prerequisites"

  local missing_tools=()

  # Check Docker
  if ! command -v docker &>/dev/null; then
    missing_tools+=("docker")
  else
    print_success "Docker installed: $(docker --version)"
  fi

  # Check Docker Compose
  if ! command -v docker-compose &>/dev/null; then
    missing_tools+=("docker-compose")
  else
    print_success "Docker Compose installed: $(docker-compose --version)"
  fi

  if [ ${#missing_tools[@]} -gt 0 ]; then
    print_error "Missing required tools: ${missing_tools[*]}"
    echo -e "${RED}Please install Docker and Docker Compose:${NC}"
    echo "  macOS: brew install docker docker-compose"
    echo "  Linux: https://docs.docker.com/get-docker/"
    echo "  Windows: https://docs.docker.com/desktop/windows/install/"
    exit 1
  fi

  # Check Docker daemon
  if ! docker ps &>/dev/null; then
    print_error "Docker daemon is not running"
    echo "Please start Docker Desktop or the Docker daemon"
    exit 1
  fi

  print_success "All prerequisites met!"
}

##############################################################################
# Environment Setup
##############################################################################

setup_environment() {
  print_header "Setting Up Environment"

  if [ -f "$ENV_FILE" ]; then
    print_warning ".env file already exists"
    read -p "Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_info "Keeping existing .env file"
      return
    fi
  fi

  if [ -f "$ENV_EXAMPLE" ]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    print_success ".env file created"
  else
    print_warning ".env.example not found, creating .env manually"
    cat >"$ENV_FILE" <<'EOF'
DB_USER=n8n
DB_PASSWORD=n8n_password
DB_NAME=n8n
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
TZ=UTC
NODE_ENV=development
EOF
  fi
}

##############################################################################
# Create Workflows Directory
##############################################################################

create_directories() {
  print_header "Creating Required Directories"

  local dirs=("workflows" "data" "backups")

  for dir in "${dirs[@]}"; do
    if [ ! -d "$PROJECT_DIR/$dir" ]; then
      mkdir -p "$PROJECT_DIR/$dir"
      print_success "Created directory: $dir"
    else
      print_info "Directory already exists: $dir"
    fi
  done
}

##############################################################################
# Docker Compose Validation
##############################################################################

validate_docker_compose() {
  print_header "Validating Docker Compose Configuration"

  if ! docker-compose -f "$PROJECT_DIR/docker-compose.yml" config >/dev/null 2>&1; then
    print_error "Docker Compose configuration is invalid"
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" config
    exit 1
  fi

  print_success "Docker Compose configuration is valid"
}

##############################################################################
# Start Services
##############################################################################

start_services() {
  print_header "Starting n8n Services"

  cd "$PROJECT_DIR"

  print_info "Pulling latest Docker images..."
  docker-compose pull

  print_info "Starting services (this may take a minute)..."
  docker-compose up -d

  # Wait for n8n to be ready
  print_info "Waiting for n8n to be ready..."
  local max_attempts=30
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if docker-compose exec -T n8n wget --quiet --tries=1 --spider http://localhost:5678/healthz 2>/dev/null; then
      print_success "n8n is ready!"
      break
    fi

    attempt=$((attempt + 1))
    echo -n "."
    sleep 2
  done

  if [ $attempt -eq $max_attempts ]; then
    print_warning "n8n startup timeout (may still be initializing)"
  fi
}

##############################################################################
# Display Connection Info
##############################################################################

display_connection_info() {
  print_header "🚀 n8n Setup Complete!"

  echo -e "${GREEN}Your n8n instance is ready!${NC}\n"

  echo "📱 Access n8n:"
  echo "   URL: ${BLUE}http://localhost:5678${NC}"
  echo ""

  echo "🗄️  Database Management (pgAdmin):"
  echo "   URL: ${BLUE}http://localhost:5050${NC}"
  echo "   Email: ${BLUE}admin@n8n.local${NC}"
  echo "   Password: ${BLUE}admin${NC}"
  echo ""

  echo "📊 Database Connection:"
  echo "   Host: ${BLUE}postgres${NC}"
  echo "   Port: ${BLUE}5432${NC}"
  echo "   User: ${BLUE}$(grep DB_USER "$ENV_FILE" | cut -d '=' -f2)${NC}"
  echo "   Database: ${BLUE}$(grep DB_NAME "$ENV_FILE" | cut -d '=' -f2)${NC}"
  echo ""

  echo "📝 Useful Commands:"
  echo "   View logs:     ${BLUE}docker-compose logs -f n8n${NC}"
  echo "   Stop services: ${BLUE}docker-compose down${NC}"
  echo "   Restart:       ${BLUE}docker-compose restart${NC}"
  echo "   Status:        ${BLUE}docker-compose ps${NC}"
  echo ""

  echo "📚 Next Steps:"
  echo "   1. Open http://localhost:5678 in your browser"
  echo "   2. Create your first workflow"
  echo "   3. Check out Lab 001-012 for workflow examples"
  echo ""
}

##############################################################################
# Main Execution
##############################################################################

main() {
  print_header "🎯 n8n Local Setup"

  check_prerequisites
  setup_environment
  create_directories
  validate_docker_compose
  start_services
  display_connection_info

  print_success "Setup completed successfully!"
}

# Run main function
main
