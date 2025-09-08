#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command_exists docker-compose; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    if ! command_exists git; then
        print_error "Git is not installed. Please install Git first."
        exit 1
    fi
    
    if ! command_exists openssl; then
        print_error "OpenSSL is not installed. Please install OpenSSL first."
        exit 1
    fi
    
    print_info "All prerequisites met!"
}

# Setup environment file
setup_env() {
    print_info "Setting up environment configuration..."
    
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            print_info "Created .env from .env.example"
        else
            print_error ".env.example not found!"
            exit 1
        fi
    else
        print_warning ".env already exists, skipping creation"
        return
    fi
    
    # Generate secure passwords
    POSTGRES_PASS=$(openssl rand -base64 32)
    FRONTEND_SECRET=$(openssl rand -base64 32)
    
    # Update .env with generated values
    sed -i.bak "s/meuse_secure_password_change_me/${POSTGRES_PASS}/" .env
    sed -i.bak "s/your_32_character_secret_here_change_me/${FRONTEND_SECRET}/" .env
    rm .env.bak 2>/dev/null || true
    
    print_info "Generated secure passwords in .env"
    print_warning "Please edit .env and update the DOMAIN variable with your actual domain"
}

# Create required directories
create_directories() {
    print_info "Creating required directories..."
    
    mkdir -p logs/nginx
    mkdir -p config
    
    print_info "Directories created"
}

# Setup configuration
setup_config() {
    print_info "Setting up Meuse configuration..."
    
    if [ ! -f config/config.yaml ]; then
        print_error "config/config.yaml not found! Make sure you have the config template."
        print_info "You should have a config/config.yaml file. Please create it from the template."
        exit 1
    fi
    
    print_warning "Please edit config/config.yaml and update the Git repository URL (metadata.url)"
    print_info "You need to fork https://github.com/rust-lang/crates.io-index and use your fork's URL"
}

# Build and start services
deploy() {
    print_info "Building and starting services..."
    
    # Stop any existing containers
    docker-compose down 2>/dev/null || true
    
    # Build and start services
    docker-compose up -d --build
    
    print_info "Services starting up..."
    print_info "Waiting for services to be ready..."
    
    # Wait for services to be healthy
    sleep 30
    
    # Check service status
    if docker-compose ps | grep -q "Up"; then
        print_info "Services are running!"
        docker-compose ps
    else
        print_error "Some services failed to start"
        docker-compose logs
        exit 1
    fi
}

# Check health endpoints
check_health() {
    print_info "Checking service health..."
    
    max_attempts=10
    attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s http://localhost/healthz > /dev/null 2>&1; then
            print_info "Health check passed!"
            break
        else
            print_info "Health check attempt $attempt/$max_attempts failed, retrying..."
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "Health checks failed after $max_attempts attempts"
        print_info "Check the logs with: docker-compose logs"
        exit 1
    fi
}

# Display next steps
show_next_steps() {
    print_info "Deployment completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "1. Create a root user (see DOCKER_SETUP.md for detailed instructions)"
    echo "2. Fork and configure the crates.io-index repository"
    echo "3. Update config/config.yaml with your Git repository URL"
    echo "4. Set up Cloudflare SSL (see DOCKER_SETUP.md)"
    echo "5. Configure Cargo to use your registry"
    echo ""
    print_info "Useful commands:"
    echo "  docker-compose logs -f meuse    # View Meuse logs"
    echo "  docker-compose ps               # Check service status"
    echo "  docker-compose down             # Stop all services"
    echo "  docker-compose up -d            # Start services"
    echo ""
    print_info "Documentation: See DOCKER_SETUP.md for complete setup guide"
    echo ""
    print_warning "Don't forget to:"
    echo "- Update your domain in .env"
    echo "- Configure your Git index repository"
    echo "- Create the root user"
    echo "- Set up Cloudflare SSL"
}

# Main execution
main() {
    print_info "Starting Meuse Docker deployment setup..."
    
    # Check if we're in the right directory
    if [ ! -f "Dockerfile" ] || [ ! -f "docker-compose.yml" ]; then
        print_error "Please run this script from the Meuse project root directory"
        exit 1
    fi
    
    check_prerequisites
    setup_env
    create_directories
    setup_config
    
    # Ask user if they want to deploy immediately
    echo ""
    read -p "Do you want to build and start the services now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy
        check_health
        show_next_steps
    else
        print_info "Skipping deployment. Run 'docker-compose up -d --build' when ready."
        print_info "See DOCKER_SETUP.md for complete setup instructions."
    fi
    
    print_info "Setup script completed!"
}

# Handle script interruption
trap 'print_error "Setup interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"