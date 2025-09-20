#!/bin/bash

# Alleviate Health API - Simplified EC2 Spot Instance Cleanup Script
# Cleans up all resources created by the deployment script

set -e

# Configuration
REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
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
    
    INSTANCE_ID=$(grep "Instance ID:" deployment/deployment-info.txt | cut -d' ' -f3)
    KEY_NAME=$(grep "Key Name:" deployment/deployment-info.txt | cut -d' ' -f3)
    SECURITY_GROUP=$(grep "Security Group:" deployment/deployment-info.txt | cut -d' ' -f3)
    PUBLIC_IP=$(grep "Public IP:" deployment/deployment-info.txt | cut -d' ' -f3)
    
    if [ -z "$INSTANCE_ID" ]; then
        print_error "Could not find Instance ID in deployment/deployment-info.txt"
        exit 1
    fi
    
    print_success "Deployment info loaded"
    print_status "Instance ID: $INSTANCE_ID"
    print_status "Key Name: $KEY_NAME"
    print_status "Security Group: $SECURITY_GROUP"
}

# Confirm cleanup
confirm_cleanup() {
    echo ""
    print_warning "This will permanently delete:"
    echo "  - EC2 Instance: $INSTANCE_ID"
    echo "  - Security Group: $SECURITY_GROUP"
    echo "  - Key Pair: $KEY_NAME"
    echo "  - Local files: deployment-info.txt, .pem file"
    echo ""
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
}

# Terminate instance
terminate_instance() {
    print_status "Terminating EC2 instance..."
    
    if aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION > /dev/null; then
        print_success "Instance termination initiated: $INSTANCE_ID"
        
        # Wait for termination
        print_status "Waiting for instance to terminate..."
        aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region $REGION
        print_success "Instance terminated"
    else
        print_warning "Instance may already be terminated or not found"
    fi
}

# Delete security group
delete_security_group() {
    print_status "Deleting security group..."
    
    if aws ec2 delete-security-group --group-id $SECURITY_GROUP --region $REGION > /dev/null 2>&1; then
        print_success "Security group deleted: $SECURITY_GROUP"
    else
        print_warning "Security group may already be deleted or not found"
    fi
}

# Delete key pair
delete_key_pair() {
    print_status "Deleting key pair..."
    
    if aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION > /dev/null 2>&1; then
        print_success "Key pair deleted: $KEY_NAME"
    else
        print_warning "Key pair may already be deleted or not found"
    fi
}

# Clean up local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    # Remove deployment info
    if [ -f "deployment/deployment-info.txt" ]; then
        rm -f deployment/deployment-info.txt
        print_success "Removed deployment/deployment-info.txt"
    fi
    
    # Remove key file
    if [ -f "deployment/${KEY_NAME}.pem" ]; then
        rm -f deployment/${KEY_NAME}.pem
        print_success "Removed deployment/${KEY_NAME}.pem"
    fi
    
    # Remove user data script if it exists
    if [ -f "user-data.sh" ]; then
        rm -f user-data.sh
        print_success "Removed user-data.sh"
    fi
}

# Display final information
show_final_info() {
    echo ""
    echo "🎉 Cleanup Complete!"
    echo ""
    echo "✅ All resources have been cleaned up:"
    echo "  - EC2 Instance terminated"
    echo "  - Security Group deleted"
    echo "  - Key Pair deleted"
    echo "  - Local files removed"
    echo ""
    echo "💰 You are no longer being charged for these resources"
    echo ""
    echo "🚀 To deploy again, run: ./deployment/deploy-spot-instance-simple.sh"
    echo ""
}

# Main execution
main() {
    echo "🧹 Alleviate Health API - Simplified Cleanup"
    echo ""
    
    check_deployment_info
    read_deployment_info
    confirm_cleanup
    terminate_instance
    delete_security_group
    delete_key_pair
    cleanup_local_files
    show_final_info
    
    echo "✅ Cleanup completed successfully!"
}

# Run main function
main "$@"
