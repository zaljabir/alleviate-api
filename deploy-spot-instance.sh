#!/bin/bash

# Alleviate Health API - EC2 Spot Instance Deployment Script
# This script deploys your API to the cheapest possible AWS option for infrequent usage

set -e

# Configuration
REGION="us-east-1"
INSTANCE_TYPE="t3.medium"
SPOT_PRICE="0.01"
KEY_NAME=""
SECURITY_GROUP=""
SUBNET_ID=""
AMI_ID="ami-0c02fb55956c7d316"  # Amazon Linux 2 AMI

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

# Function to check if AWS CLI is installed and configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI is configured"
}

# Function to get default VPC and subnet
get_default_network() {
    print_status "Getting default VPC and subnet..."
    
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --region $REGION)
    if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
        print_error "No default VPC found. Please specify VPC_ID and SUBNET_ID manually."
        exit 1
    fi
    
    SUBNET_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[0].SubnetId' --output text --region $REGION)
    
    print_success "Using VPC: $VPC_ID, Subnet: $SUBNET_ID"
}

# Function to create security group
create_security_group() {
    print_status "Creating security group..."
    
    SECURITY_GROUP=$(aws ec2 create-security-group \
        --group-name alleviate-health-api-sg \
        --description "Security group for Alleviate Health API" \
        --vpc-id $VPC_ID \
        --query 'GroupId' \
        --output text \
        --region $REGION)
    
    # Allow HTTP traffic
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP \
        --protocol tcp \
        --port 3000 \
        --cidr 0.0.0.0/0 \
        --region $REGION
    
    # Allow SSH access (optional, for debugging)
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region $REGION
    
    print_success "Security group created: $SECURITY_GROUP"
}

# Function to create key pair
create_key_pair() {
    print_status "Creating key pair..."
    
    KEY_NAME="alleviate-health-api-key"
    
    # Remove existing key if it exists
    aws ec2 delete-key-pair --key-name $KEY_NAME --region $REGION 2>/dev/null || true
    
    # Create new key pair
    aws ec2 create-key-pair \
        --key-name $KEY_NAME \
        --query 'KeyMaterial' \
        --output text \
        --region $REGION > ${KEY_NAME}.pem
    
    chmod 400 ${KEY_NAME}.pem
    
    print_success "Key pair created: ${KEY_NAME}.pem"
}

# Function to create user data script
create_user_data() {
    print_status "Creating user data script..."
    
    cat > user-data.sh << 'EOF'
#!/bin/bash

# Update system
yum update -y

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Git
yum install -y git

# Install Node.js (for direct deployment option)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install 18
nvm use 18

# Create application directory
mkdir -p /home/ec2-user/alleviate-api
cd /home/ec2-user/alleviate-api

# Clone repository
git clone https://github.com/zaljabir/alleviate-api.git .

# Install dependencies
npm install

# Install Playwright browsers
npx playwright install chromium

# Create systemd service for auto-start
cat > /etc/systemd/system/alleviate-api.service << 'SERVICE_EOF'
[Unit]
Description=Alleviate Health API
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/alleviate-api
Environment=NODE_ENV=production
Environment=PORT=3000
ExecStart=/home/ec2-user/.nvm/versions/node/v18.17.0/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Enable and start service
systemctl daemon-reload
systemctl enable alleviate-api
systemctl start alleviate-api

# Create auto-shutdown script
cat > /home/ec2-user/auto-shutdown.sh << 'SHUTDOWN_EOF'
#!/bin/bash

# Check if API is being used (simple check)
if ! curl -f http://localhost:3000/health > /dev/null 2>&1; then
    # API is not responding, check if it's been idle for 30 minutes
    LAST_ACCESS=$(stat -c %Y /var/log/messages 2>/dev/null || echo 0)
    CURRENT_TIME=$(date +%s)
    IDLE_TIME=$((CURRENT_TIME - LAST_ACCESS))
    
    if [ $IDLE_TIME -gt 1800 ]; then  # 30 minutes
        echo "Shutting down due to inactivity"
        shutdown -h now
    fi
fi
SHUTDOWN_EOF

chmod +x /home/ec2-user/auto-shutdown.sh

# Add cron job for auto-shutdown (every 10 minutes)
echo "*/10 * * * * /home/ec2-user/auto-shutdown.sh" | crontab -u ec2-user -

# Create startup script
cat > /home/ec2-user/start-api.sh << 'START_EOF'
#!/bin/bash
cd /home/ec2-user/alleviate-api
systemctl start alleviate-api
echo "API started at $(date)"
START_EOF

chmod +x /home/ec2-user/start-api.sh

# Create stop script
cat > /home/ec2-user/stop-api.sh << 'STOP_EOF'
#!/bin/bash
systemctl stop alleviate-api
echo "API stopped at $(date)"
STOP_EOF

chmod +x /home/ec2-user/stop-api.sh

# Log completion
echo "Deployment completed at $(date)" >> /var/log/alleviate-deployment.log
EOF

    print_success "User data script created"
}

# Function to launch spot instance
launch_spot_instance() {
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
        --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=alleviate-health-api},{Key=Project,Value=alleviate-health}]' \
        --query 'Instances[0].InstanceId' \
        --output text \
        --region $REGION)
    
    print_success "Spot instance launched: $INSTANCE_ID"
}

# Function to wait for instance to be ready
wait_for_instance() {
    print_status "Waiting for instance to be running..."
    
    aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION
    
    # Wait additional time for user data script to complete
    print_status "Waiting for application to deploy (this may take 5-10 minutes)..."
    sleep 300  # 5 minutes
    
    print_success "Instance is running"
}

# Function to get instance details
get_instance_details() {
    print_status "Getting instance details..."
    
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text \
        --region $REGION)
    
    PRIVATE_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text \
        --region $REGION)
    
    print_success "Instance details retrieved"
}

# Function to test API
test_api() {
    print_status "Testing API endpoints..."
    
    # Wait a bit more for the service to fully start
    sleep 60
    
    # Test health endpoint
    if curl -f http://$PUBLIC_IP:3000/health > /dev/null 2>&1; then
        print_success "Health endpoint is working"
    else
        print_warning "Health endpoint not responding yet. It may take a few more minutes."
    fi
    
    # Test API docs
    if curl -f http://$PUBLIC_IP:3000/api-docs > /dev/null 2>&1; then
        print_success "API documentation is accessible"
    else
        print_warning "API documentation not accessible yet"
    fi
}

# Function to display deployment summary
display_summary() {
    echo ""
    echo "=========================================="
    echo "🚀 DEPLOYMENT COMPLETE!"
    echo "=========================================="
    echo ""
    echo "Instance ID: $INSTANCE_ID"
    echo "Public IP: $PUBLIC_IP"
    echo "Private IP: $PRIVATE_IP"
    echo "Region: $REGION"
    echo "Instance Type: $INSTANCE_TYPE"
    echo "Spot Price: \$$SPOT_PRICE/hour"
    echo ""
    echo "🌐 API Endpoints:"
    echo "  Health Check: http://$PUBLIC_IP:3000/health"
    echo "  API Docs: http://$PUBLIC_IP:3000/api-docs"
    echo "  Phone Update: http://$PUBLIC_IP:3000/settings/phone"
    echo ""
    echo "🔧 Management Commands:"
    echo "  SSH Access: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
    echo "  Start API: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP './start-api.sh'"
    echo "  Stop API: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP './stop-api.sh'"
    echo "  View Logs: ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP 'journalctl -u alleviate-api -f'"
    echo ""
    echo "💰 Cost Information:"
    echo "  Estimated cost: ~\$0.008/hour (\$0.08 for 10 hours/month)"
    echo "  Auto-shutdown: Enabled (30 minutes of inactivity)"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Test your API endpoints"
    echo "  2. Update your application to use the new IP"
    echo "  3. Set up monitoring if needed"
    echo "  4. Use cleanup script when done: ./cleanup-spot-instance.sh"
    echo ""
}

# Function to save deployment info
save_deployment_info() {
    cat > deployment-info.txt << EOF
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
ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP
EOF

    print_success "Deployment info saved to deployment-info.txt"
}

# Main execution
main() {
    echo "🚀 Alleviate Health API - EC2 Spot Instance Deployment"
    echo "======================================================"
    echo ""
    
    check_aws_cli
    get_default_network
    create_security_group
    create_key_pair
    create_user_data
    launch_spot_instance
    wait_for_instance
    get_instance_details
    test_api
    display_summary
    save_deployment_info
    
    print_success "Deployment completed successfully!"
}

# Run main function
main "$@"
