#!/bin/bash

##############################################################################
# n8n Status Check Script
#
# This script checks the status of n8n services and displays useful info
# Usage: ./scripts/status.sh
##############################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

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
# Status Check Functions
##############################################################################

check_docker() {
  print_header "Docker Status"

  if docker ps &>/dev/null; then
    print_success "Docker daemon is running"
  else
    print_error "Docker daemon is not running"
    return 1
  fi
}

check_containers() {
  print_header "Container Status"

  cd "$PROJECT_DIR"

  if ! docker-compose ps >/dev/null 2>&1; then
    print_warning "No docker-compose project found"
    return 1
  fi

  # Check n8n container
  if docker-compose ps n8n | grep -q "Up"; then
    print_success "n8n container is running"
    local n8n_status=0
  else
    print_error "n8n container is not running"
    local n8n_status=1
  fi

  # Check PostgreSQL container
  if docker-compose ps postgres | grep -q "Up"; then
    print_success "PostgreSQL container is running"
    local postgres_status=0
  else
    print_error "PostgreSQL container is not running"
    local postgres_status=1
  fi

  # Check pgAdmin container
  if docker-compose ps pgadmin | grep -q "Up"; then
    print_success "pgAdmin container is running"
  else
    print_info "pgAdmin container is not running (optional)"
  fi

  return $((n8n_status + postgres_status))
}

check_n8n_health() {
  print_header "n8n Health Check"

  cd "$PROJECT_DIR"

  if docker-compose ps n8n | grep -q "Up"; then
    if docker-compose exec -T n8n wget --quiet --tries=1 --spider http://localhost:5678/healthz 2>/dev/null; then
      print_success "n8n API is responding"

      # Try to get version info
      local version=$(docker-compose exec -T n8n curl -s http://localhost:5678/api/n8n/config 2>/dev/null | grep -o '"version":"[^"]*' | cut -d'"' -f4)
      if [ -n "$version" ]; then
        print_info "n8n Version: $version"
      fi
    else
      print_warning "n8n API is not responding yet (still initializing?)"
    fi
  else
    print_info "n8n container is not running"
  fi
}

show_connection_urls() {
  print_header "Connection URLs"

  echo -e "${GREEN}n8n Editor:${NC}"
  echo "   ${BLUE}http://localhost:5678${NC}"
  echo ""

  echo -e "${GREEN}pgAdmin (Database):${NC}"
  echo "   ${BLUE}http://localhost:5050${NC}"
  echo ""

  echo -e "${GREEN}Database Connection:${NC}"
  if [ -f "$PROJECT_DIR/.env" ]; then
    local db_user=$(grep DB_USER "$PROJECT_DIR/.env" | cut -d '=' -f2)
    local db_name=$(grep DB_NAME "$PROJECT_DIR/.env" | cut -d '=' -f2)
    echo "   Host: ${BLUE}postgres${NC}"
    echo "   User: ${BLUE}$db_user${NC}"
    echo "   Database: ${BLUE}$db_name${NC}"
  fi
  echo ""
}

show_logs() {
  print_header "Recent Logs"

  read -p "View logs? (y/n) " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$PROJECT_DIR"
    echo -e "${YELLOW}--- n8n Logs (last 20 lines) ---${NC}"
    docker-compose logs n8n | tail -20
  fi
}

show_disk_usage() {
  print_header "Disk Usage"

  cd "$PROJECT_DIR"

  echo "Docker images:"
  docker images | grep -E "n8nio|postgres|pgadmin" || echo "  No n8n-related images found"

  echo ""
  echo "Volumes:"
  docker volume ls | grep n8nlab || echo "  No n8n volumes found"

  echo ""
  echo "Local directories:"
  for dir in workflows data backups; do
    if [ -d "$PROJECT_DIR/$dir" ]; then
      local size=$(du -sh "$PROJECT_DIR/$dir" 2>/dev/null | cut -f1)
      print_info "$dir: $size"
    fi
  done
}

show_useful_commands() {
  print_header "Useful Commands"

  echo "Start services:"
  echo "   ${BLUE}docker-compose up -d${NC}"
  echo ""

  echo "Stop services:"
  echo "   ${BLUE}docker-compose stop${NC}"
  echo ""

  echo "Restart services:"
  echo "   ${BLUE}docker-compose restart${NC}"
  echo ""

  echo "View all logs:"
  echo "   ${BLUE}docker-compose logs -f${NC}"
  echo ""

  echo "Access container shell:"
  echo "   ${BLUE}docker-compose exec n8n /bin/sh${NC}"
  echo ""

  echo "Database shell:"
  echo "   ${BLUE}docker-compose exec postgres psql -U n8n -d n8n${NC}"
  echo ""
}

##############################################################################
# Main Execution
##############################################################################

main() {
  print_header "🔍 n8n Status Check"

  check_docker || exit 1
  check_containers
  check_n8n_health
  show_connection_urls
  show_disk_usage
  show_useful_commands
  show_logs

  print_success "Status check complete!"
}

# Run main function
main
