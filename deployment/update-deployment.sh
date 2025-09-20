#!/bin/bash

# Alleviate Health API - Simplified Update Deployment Script
# Updates your running API with the latest changes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if deployment info exists
check_deployment_info() {
    if [ ! -f "deployment/deployment-info.txt" ]; then
        print_error "deployment/deployment-info.txt not found"
        print_status "Please run this script from the project root directory"
        exit 1
    fi
}

# Read deployment info
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

# Check if key file exists
check_key_file() {
    if [ ! -f "$KEY_FILE" ]; then
        print_error "Key file not found: $KEY_FILE"
        exit 1
    fi
}

# Test SSH connection
test_ssh() {
    print_status "Testing SSH connection..."
    
    if ! ssh -i "$KEY_FILE" -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        ec2-user@$INSTANCE_IP "echo 'SSH connection successful'" > /dev/null 2>&1; then
        print_error "Cannot connect to instance via SSH"
        print_status "Make sure the instance is running and accessible"
        exit 1
    fi
    
    print_success "SSH connection successful"
}

# Update the deployment
update_deployment() {
    print_status "Updating deployment..."
    
    # Stop the current container
    print_status "Stopping current container..."
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP \
        "cd /home/ec2-user/alleviate-api && docker stop alleviate-api-container || true"
    
    # Remove old container
    print_status "Removing old container..."
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP \
        "cd /home/ec2-user/alleviate-api && docker rm alleviate-api-container || true"
    
    # Pull latest code
    print_status "Pulling latest code..."
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP \
        "cd /home/ec2-user/alleviate-api && git pull origin main"
    
    # Rebuild Docker image
    print_status "Rebuilding Docker image..."
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP \
        "cd /home/ec2-user/alleviate-api && docker build -t alleviate-api ."
    
    # Start new container
    print_status "Starting new container..."
    ssh -i "$KEY_FILE" -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP \
        "cd /home/ec2-user/alleviate-api && docker run -d --name alleviate-api-container \
        -p 3000:3000 --restart unless-stopped alleviate-api"
    
    print_success "Deployment updated"
}

# Test the updated API
test_api() {
    print_status "Testing updated API..."
    
    # Wait for API to be ready
    for i in {1..30}; do
        if curl -s http://$INSTANCE_IP:3000/health > /dev/null; then
            print_success "API is responding!"
            break
        fi
        sleep 5
    done
    
    if [ $i -eq 30 ]; then
        print_error "API not responding after 2.5 minutes"
        exit 1
    fi
}

# Display final information
show_final_info() {
    echo ""
    echo "🎉 Update Complete!"
    echo ""
    echo "🌐 API Endpoints:"
    echo "  Health Check: http://$INSTANCE_IP:3000/health"
    echo "  API Docs: http://$INSTANCE_IP:3000/api-docs"
    echo "  Phone Update: http://$INSTANCE_IP:3000/settings/phone"
    echo ""
    echo "🔧 Management:"
    echo "  SSH Access: ssh -i $KEY_FILE ec2-user@$INSTANCE_IP"
    echo "  Cleanup: ./deployment/cleanup-spot-instance-simple.sh"
    echo ""
}

# Main execution
main() {
    echo "🔄 Alleviate Health API - Simplified Update Deployment"
    echo ""
    
    check_deployment_info
    read_deployment_info
    check_key_file
    test_ssh
    update_deployment
    test_api
    show_final_info
    
    echo "✅ Update completed successfully!"
}

# Run main function
main "$@"
