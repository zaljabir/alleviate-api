#!/bin/bash

# Alleviate Health API - Update Deployment Script
# This script updates your running API with the latest changes

set -e

# Configuration
INSTANCE_IP="54.198.22.93"
KEY_FILE="alleviate-health-api-key.pem"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if deployment info exists
check_deployment_info() {
    if [ ! -f "deployment/deployment-info.txt" ]; then
        print_error "deployment/deployment-info.txt not found. Cannot determine instance details."
        print_status "Please run this script from the project root directory"
        exit 1
    fi
}

# Function to read deployment info
read_deployment_info() {
    print_status "Reading deployment information..."
    
    INSTANCE_IP=$(grep "Public IP:" deployment/deployment-info.txt | cut -d' ' -f3)
    KEY_NAME=$(grep "Key Name:" deployment/deployment-info.txt | cut -d' ' -f3)
    
    if [ -z "$INSTANCE_IP" ]; then
        print_error "Could not find Public IP in deployment/deployment-info.txt"
        exit 1
    fi
    
    KEY_FILE="deployment/${KEY_NAME}.pem"
    
    print_success "Deployment info loaded"
    print_status "Instance IP: $INSTANCE_IP"
    print_status "Key file: $KEY_FILE"
}

# Function to check if key file exists
check_key_file() {
    if [ ! -f "$KEY_FILE" ]; then
        print_error "Key file $KEY_FILE not found"
        exit 1
    fi
}

# Function to push changes to GitHub
push_changes() {
    print_status "Pushing changes to GitHub..."
    
    # Check if there are uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        print_status "Found uncommitted changes. Please commit them first:"
        print_status "  git add ."
        print_status "  git commit -m 'Your commit message'"
        print_status "  git push"
        exit 1
    fi
    
    # Push to GitHub
    git push origin main
    
    print_success "Changes pushed to GitHub"
}

# Function to update the instance
update_instance() {
    print_status "Updating instance: $INSTANCE_IP"
    
    # SSH into instance and update
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << 'EOF'
        echo "🔄 Updating Alleviate Health API..."
        
        # Navigate to project directory
        cd /home/ec2-user/alleviate-api
        
        # Pull latest changes
        echo "📥 Pulling latest changes from GitHub..."
        git pull origin main
        
        # Stop current container
        echo "⏹️ Stopping current container..."
        sudo docker stop alleviate-api || true
        sudo docker rm alleviate-api || true
        
        # Rebuild container
        echo "🔨 Rebuilding container..."
        sudo docker build -t alleviate-api .
        
        # Start new container
        echo "🚀 Starting updated container..."
        sudo docker run -d -p 3000:3000 --name alleviate-api --restart=always alleviate-api
        
        # Wait for container to start
        echo "⏳ Waiting for container to start..."
        sleep 10
        
        # Test the API
        echo "🧪 Testing API..."
        if curl -f http://localhost:3000/health > /dev/null 2>&1; then
            echo "✅ API is responding successfully!"
        else
            echo "❌ API is not responding. Check logs with: sudo docker logs alleviate-api"
        fi
        
        echo "🎉 Update completed!"
EOF
    
    print_success "Instance updated successfully"
}

# Function to test the updated API
test_api() {
    print_status "Testing updated API..."
    
    # Wait a bit for the container to fully start
    sleep 5
    
    # Test health endpoint
    if curl -f http://$INSTANCE_IP:3000/health > /dev/null 2>&1; then
        print_success "Health endpoint is responding"
    else
        print_warning "Health endpoint not responding yet. It may take a few more minutes."
    fi
    
    # Test API docs
    if curl -f http://$INSTANCE_IP:3000/api-docs > /dev/null 2>&1; then
        print_success "API documentation is accessible"
    else
        print_warning "API documentation not accessible yet"
    fi
}

# Function to display update summary
display_summary() {
    echo ""
    echo "=========================================="
    echo "🔄 UPDATE COMPLETE!"
    echo "=========================================="
    echo ""
    echo "Instance IP: $INSTANCE_IP"
    echo "Update time: $(date)"
    echo ""
    echo "🌐 API Endpoints:"
    echo "  Health Check: http://$INSTANCE_IP:3000/health"
    echo "  API Docs: http://$INSTANCE_IP:3000/api-docs"
    echo "  Phone Update: http://$INSTANCE_IP:3000/settings/phone"
    echo ""
    echo "🔧 Management Commands:"
    echo "  SSH Access: ssh -i $KEY_FILE ec2-user@$INSTANCE_IP"
    echo "  View Logs: ssh -i $KEY_FILE ec2-user@$INSTANCE_IP 'sudo docker logs alleviate-api'"
    echo "  Restart: ssh -i $KEY_FILE ec2-user@$INSTANCE_IP 'sudo docker restart alleviate-api'"
    echo ""
}

# Main execution
main() {
    echo "🔄 Alleviate Health API - Update Deployment"
    echo "=========================================="
    echo ""
    
    check_deployment_info
    read_deployment_info
    check_key_file
    push_changes
    update_instance
    test_api
    display_summary
    
    print_success "Update completed successfully!"
}

# Run main function
main "$@"
