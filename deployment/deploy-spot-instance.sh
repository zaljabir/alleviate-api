#!/bin/bash

# Alleviate Health API - Simplified EC2 Spot Instance Deployment
# Deploys API to the cheapest AWS option for infrequent usage

set -e

# Configuration
REGION="us-east-1"
INSTANCE_TYPE="t3.micro"
SPOT_PRICE="0.01"
AMI_ID="ami-0c02fb55956c7d316"  # Amazon Linux 2 AMI

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check AWS CLI
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not installed. Install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI not configured. Run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI configured"
}

# Get default VPC and subnet
get_network() {
    print_status "Getting default VPC and subnet..."
    
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" \
        --query 'Vpcs[0].VpcId' --output text --region $REGION)
    
    if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
        print_error "No default VPC found"
        exit 1
    fi
    
    SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
        "Name=availability-zone,Values=us-east-1a" --query 'Subnets[0].SubnetId' \
        --output text --region $REGION)
    
    print_success "Using VPC: $VPC_ID, Subnet: $SUBNET_ID"
}

# Create security group
create_security_group() {
    print_status "Creating security group..."
    
    SECURITY_GROUP=$(aws ec2 create-security-group \
        --group-name alleviate-health-api-sg \
        --description "Security group for Alleviate Health API" \
        --vpc-id $VPC_ID \
        --query 'GroupId' --output text --region $REGION)
    
    # Allow HTTP and SSH
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP \
        --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region $REGION
    
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP \
        --protocol tcp --port 22 --cidr 0.0.0.0/0 --region $REGION
    
    print_success "Security group created: $SECURITY_GROUP"
}

# Create key pair
create_key_pair() {
    print_status "Creating key pair..."
    
    KEY_NAME="alleviate-health-api-key"
    
    # Remove existing key if it exists
    aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION 2>/dev/null || true
    
    # Create new key pair
    aws ec2 create-key-pair \
        --key-name $KEY_NAME \
        --query 'KeyMaterial' --output text \
        --region $REGION > deployment/${KEY_NAME}.pem
    
    chmod 400 deployment/${KEY_NAME}.pem
    print_success "Key pair created: deployment/${KEY_NAME}.pem"
}

# Create user data script
create_user_data() {
    print_status "Creating user data script..."
    
    cat > user-data.sh << 'EOF'
#!/bin/bash

# Update system and install Docker
yum update -y
yum install -y docker git
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Create application directory
mkdir -p /home/ec2-user/alleviate-api
cd /home/ec2-user/alleviate-api

# Clone repository
git clone https://github.com/zaljabir/alleviate-api.git .

# Build and run Docker container
docker build -t alleviate-api .
docker run -d --name alleviate-api-container \
    -p 3000:3000 \
    --restart unless-stopped \
    alleviate-api

# Create systemd service for auto-start
cat > /etc/systemd/system/alleviate-api.service << 'SERVICE_EOF'
[Unit]
Description=Alleviate Health API
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ec2-user/alleviate-api
ExecStart=/usr/bin/docker start alleviate-api-container
ExecStop=/usr/bin/docker stop alleviate-api-container
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE_EOF

systemctl enable alleviate-api.service
systemctl start alleviate-api.service

echo "Deployment completed at $(date)" >> /var/log/alleviate-deployment.log
EOF

    print_success "User data script created"
}

# Launch spot instance
launch_instance() {
    print_status "Launching EC2 Spot instance..."
    
    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id $AMI_ID \
        --count 1 \
        --instance-type $INSTANCE_TYPE \
        --key-name $KEY_NAME \
        --security-group-ids $SECURITY_GROUP \
        --subnet-id $SUBNET_ID \
        --user-data file://user-data.sh \
        --instance-market-options '{
            "MarketType": "spot",
            "SpotOptions": {
                "MaxPrice": "'$SPOT_PRICE'",
                "SpotInstanceType": "one-time"
            }
        }' \
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=alleviate-health-api}]' \
        --query 'Instances[0].InstanceId' --output text --region $REGION)
    
    print_success "Spot instance launched: $INSTANCE_ID"
}

# Wait for instance and get details
wait_and_get_details() {
    print_status "Waiting for instance to be running..."
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION
    
    print_status "Waiting for application to deploy (5-10 minutes)..."
    sleep 300  # 5 minutes
    
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text --region $REGION)
    
    PRIVATE_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text --region $REGION)
    
    print_success "Instance is running at $PUBLIC_IP"
}

# Test API
test_api() {
    print_status "Testing API endpoints..."
    
    # Wait for API to be ready
    for i in {1..30}; do
        if curl -s http://$PUBLIC_IP:3000/health > /dev/null; then
            print_success "API is responding!"
            break
        fi
        sleep 10
    done
    
    if [ $i -eq 30 ]; then
        print_error "API not responding after 5 minutes"
        exit 1
    fi
}

# Save deployment info
save_info() {
    print_status "Saving deployment information..."
    
    cat > deployment/deployment-info.txt << EOF
Deployment Date: $(date)
Instance ID: $INSTANCE_ID
Public IP: $PUBLIC_IP
Private IP: $PRIVATE_IP
Region: $REGION
Instance Type: $INSTANCE_TYPE
Spot Price: $SPOT_PRICE
Key Name: $KEY_NAME
Security Group: $SECURITY_GROUP
Subnet ID: $SUBNET_ID
VPC ID: $VPC_ID

API Endpoints:
- Health Check: http://$PUBLIC_IP:3000/health
- API Docs: http://$PUBLIC_IP:3000/api-docs
- Phone Update: http://$PUBLIC_IP:3000/settings/phone

SSH Access:
ssh -i deployment/${KEY_NAME}.pem ec2-user@$PUBLIC_IP
EOF

    print_success "Deployment info saved to deployment/deployment-info.txt"
}

# Display final information
show_final_info() {
    echo ""
    echo "🎉 Deployment Complete!"
    echo ""
    echo "📊 Instance Details:"
    echo "  Instance ID: $INSTANCE_ID"
    echo "  Public IP: $PUBLIC_IP"
    echo "  Instance Type: $INSTANCE_TYPE"
    echo "  Spot Price: \$$SPOT_PRICE/hour"
    echo ""
    echo "🌐 API Endpoints:"
    echo "  Health Check: http://$PUBLIC_IP:3000/health"
    echo "  API Docs: http://$PUBLIC_IP:3000/api-docs"
    echo "  Phone Update: http://$PUBLIC_IP:3000/settings/phone"
    echo ""
    echo "🔧 Management:"
    echo "  SSH Access: ssh -i deployment/${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
    echo "  Update: ./deployment/update-deployment-simple.sh"
    echo "  Cleanup: ./deployment/cleanup-spot-instance-simple.sh"
    echo ""
    echo "💰 Cost: ~\$$SPOT_PRICE/hour (\$0.08 for 10 hours/month)"
    echo ""
}

# Cleanup
cleanup() {
    rm -f user-data.sh
    print_success "Temporary files cleaned up"
}

# Main execution
main() {
    echo "🚀 Alleviate Health API - Simplified EC2 Spot Deployment"
    echo ""
    
    check_aws_cli
    get_network
    create_security_group
    create_key_pair
    create_user_data
    launch_instance
    wait_and_get_details
    test_api
    save_info
    show_final_info
    cleanup
    
    echo "✅ Deployment completed successfully!"
}

# Run main function
main "$@"
