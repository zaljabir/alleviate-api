#!/bin/bash

# Alleviate Health API - EC2 Spot Instance Cleanup Script
# This script cleans up all resources created by the deployment script

set -e

# Configuration
REGION="us-east-1"

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
        print_error "deployment/deployment-info.txt not found. Cannot determine which resources to clean up."
        print_status "Please run this script from the project root directory"
        exit 1
    fi
}

# Function to read deployment info
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

# Function to terminate instance
terminate_instance() {
    print_status "Terminating EC2 instance: $INSTANCE_ID"
    
    # Check if instance exists and is running
    INSTANCE_STATE=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text \
        --region $REGION 2>/dev/null || echo "not-found")
    
    if [ "$INSTANCE_STATE" = "not-found" ]; then
        print_warning "Instance $INSTANCE_ID not found or already terminated"
        return
    fi
    
    if [ "$INSTANCE_STATE" = "terminated" ]; then
        print_warning "Instance $INSTANCE_ID is already terminated"
        return
    fi
    
    # Terminate the instance
    aws ec2 terminate-instances \
        --instance-ids $INSTANCE_ID \
        --region $REGION
    
    print_status "Waiting for instance to terminate..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region $REGION
    
    print_success "Instance terminated successfully"
}

# Function to delete security group
delete_security_group() {
    if [ -z "$SECURITY_GROUP" ]; then
        print_warning "No security group ID found, skipping deletion"
        return
    fi
    
    print_status "Deleting security group: $SECURITY_GROUP"
    
    # Check if security group exists
    if ! aws ec2 describe-security-groups --group-ids $SECURITY_GROUP --region $REGION > /dev/null 2>&1; then
        print_warning "Security group $SECURITY_GROUP not found or already deleted"
        return
    fi
    
    # Delete security group
    aws ec2 delete-security-group \
        --group-id $SECURITY_GROUP \
        --region $REGION
    
    print_success "Security group deleted successfully"
}

# Function to delete key pair
delete_key_pair() {
    if [ -z "$KEY_NAME" ]; then
        print_warning "No key name found, skipping deletion"
        return
    fi
    
    print_status "Deleting key pair: $KEY_NAME"
    
    # Delete key pair from AWS
    aws ec2 delete-key-pair \
        --key-name $KEY_NAME \
        --region $REGION
    
    # Delete local key file
    if [ -f "${KEY_NAME}.pem" ]; then
        rm -f "${KEY_NAME}.pem"
        print_success "Local key file deleted: ${KEY_NAME}.pem"
    fi
    
    print_success "Key pair deleted successfully"
}

# Function to clean up local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    # Remove deployment info
    if [ -f "deployment/deployment-info.txt" ]; then
        rm -f deployment/deployment-info.txt
        print_success "Removed deployment/deployment-info.txt"
    fi
    
    # Remove user data script
    if [ -f "user-data.sh" ]; then
        rm -f user-data.sh
        print_success "Removed user-data.sh"
    fi
    
    # Remove any temporary files
    rm -f *.tmp *.log 2>/dev/null || true
    
    print_success "Local files cleaned up"
}

# Function to display cleanup summary
display_cleanup_summary() {
    echo ""
    echo "=========================================="
    echo "🧹 CLEANUP COMPLETE!"
    echo "=========================================="
    echo ""
    echo "Resources cleaned up:"
    echo "  ✅ EC2 Instance: $INSTANCE_ID"
    echo "  ✅ Security Group: $SECURITY_GROUP"
    echo "  ✅ Key Pair: $KEY_NAME"
    echo "  ✅ Local files"
    echo ""
    echo "💰 Cost savings:"
    echo "  No more charges for the terminated instance"
    echo "  Estimated savings: ~\$0.008/hour"
    echo ""
    echo "📋 Next steps:"
    echo "  1. Verify no unexpected charges in AWS billing"
    echo "  2. Run 'aws ec2 describe-instances' to confirm cleanup"
    echo "  3. Check AWS Cost Explorer for final costs"
    echo ""
}

# Function to confirm cleanup
confirm_cleanup() {
    echo ""
    print_warning "This will permanently delete all resources created by the deployment:"
    echo "  - EC2 Instance: $INSTANCE_ID"
    echo "  - Security Group: $SECURITY_GROUP"
    echo "  - Key Pair: $KEY_NAME"
    echo "  - Local files"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_status "Cleanup cancelled"
        exit 0
    fi
}

# Function to check for running instances
check_running_instances() {
    print_status "Checking for other running instances..."
    
    RUNNING_INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' \
        --output text \
        --region $REGION)
    
    if [ -n "$RUNNING_INSTANCES" ]; then
        print_warning "Other running instances found:"
        echo "$RUNNING_INSTANCES"
        echo ""
    else
        print_success "No other running instances found"
    fi
}

# Function to show cost estimate
show_cost_estimate() {
    print_status "Calculating cost estimate..."
    
    # This is a simplified calculation
    # In reality, you'd want to use AWS Cost Explorer API
    print_status "To get accurate costs, check AWS Cost Explorer or billing dashboard"
    print_status "Estimated cost for this deployment: ~\$0.008/hour"
}

# Main execution
main() {
    echo "🧹 Alleviate Health API - EC2 Spot Instance Cleanup"
    echo "=================================================="
    echo ""
    
    check_deployment_info
    read_deployment_info
    confirm_cleanup
    
    terminate_instance
    delete_security_group
    delete_key_pair
    cleanup_local_files
    
    check_running_instances
    show_cost_estimate
    display_cleanup_summary
    
    print_success "Cleanup completed successfully!"
}

# Run main function
main "$@"
