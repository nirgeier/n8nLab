#!/bin/bash

##############################################################################
# n8n Cleanup Script
#
# This script cleanly stops and removes n8n Docker containers and volumes
# Usage: ./scripts/cleanup.sh
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
# Cleanup Functions
##############################################################################

stop_services() {
  print_header "Stopping Services"

  cd "$PROJECT_DIR"

  if docker-compose ps | grep -q "n8n-local"; then
    print_info "Stopping n8n and PostgreSQL..."
    docker-compose stop
    print_success "Services stopped"
  else
    print_info "No running services found"
  fi
}

remove_containers() {
  print_header "Removing Containers"

  cd "$PROJECT_DIR"

  print_info "Removing containers..."
  docker-compose rm -f
  print_success "Containers removed"
}

remove_volumes() {
  print_header "Removing Data Volumes"

  read -p "Remove data volumes? (WARNING: This will delete all n8n data and workflows) (y/n) " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$PROJECT_DIR"
    print_warning "Removing volumes..."
    docker-compose down -v
    print_success "Volumes removed"
  else
    print_info "Skipped volume removal"
  fi
}

remove_env_file() {
  print_header "Cleaning Up Environment"

  read -p "Remove .env file? (y/n) " -n 1 -r
  echo

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f "$PROJECT_DIR/.env" ]; then
      rm "$PROJECT_DIR/.env"
      print_success ".env file removed"
    fi
  else
    print_info "Kept .env file"
  fi
}

show_cleanup_summary() {
  print_header "Cleanup Summary"

  echo "✅ All n8n services have been cleaned up"
  echo ""
  echo "📝 To set up n8n again, run:"
  echo "   ${BLUE}./scripts/setup.sh${NC}"
  echo ""
}

##############################################################################
# Main Execution
##############################################################################

main() {
  print_header "🧹 n8n Cleanup"

  print_warning "This will stop and remove n8n services"
  read -p "Continue? (y/n) " -n 1 -r
  echo

  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Cleanup cancelled"
    exit 0
  fi

  stop_services
  remove_containers
  remove_volumes
  remove_env_file
  show_cleanup_summary

  print_success "Cleanup completed!"
}

# Run main function
main
