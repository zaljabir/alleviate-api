# AWS Deployment Guide for Alleviate Health API

This guide provides multiple deployment options for your Alleviate Health API on AWS, considering the Playwright browser automation requirements.

## 🚀 Deployment Options

### Option 1: AWS ECS with Fargate (Recommended)
**Best for**: Production workloads, serverless containers, auto-scaling

### Option 2: AWS EC2 with Docker
**Best for**: Full control, custom configurations, cost optimization

### Option 3: AWS Lambda with Container Images
**Best for**: Event-driven, pay-per-request, but limited for Playwright

## 📋 Prerequisites

1. **AWS CLI installed and configured**
   ```bash
   aws configure
   ```

2. **Docker installed locally**
   ```bash
   docker --version
   ```

3. **AWS Account with appropriate permissions**

## 🐳 Option 1: AWS ECS with Fargate (Recommended)

### Step 1: Build and Push Docker Image to ECR

```bash
# Create ECR repository
aws ecr create-repository --repository-name alleviate-health-api --region us-east-1

# Get login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build image
docker build -t alleviate-health-api .

# Tag image
docker tag alleviate-health-api:latest YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/alleviate-health-api:latest

# Push image
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/alleviate-health-api:latest
```

### Step 2: Create ECS Cluster

```bash
# Create cluster
aws ecs create-cluster --cluster-name alleviate-health-cluster --region us-east-1
```

### Step 3: Create Task Definition

Create `task-definition.json`:

```json
{
  "family": "alleviate-health-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "1024",
  "memory": "2048",
  "executionRoleArn": "arn:aws:iam::YOUR_ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "alleviate-health-api",
      "image": "YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/alleviate-health-api:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PORT",
          "value": "3000"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/alleviate-health-api",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

### Step 4: Register Task Definition

```bash
aws ecs register-task-definition --cli-input-json file://task-definition.json --region us-east-1
```

### Step 5: Create ECS Service

```bash
aws ecs create-service \
  --cluster alleviate-health-cluster \
  --service-name alleviate-health-service \
  --task-definition alleviate-health-api:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-12345,subnet-67890],securityGroups=[sg-12345],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:us-east-1:YOUR_ACCOUNT_ID:targetgroup/alleviate-health-tg/1234567890abcdef,containerName=alleviate-health-api,containerPort=3000" \
  --region us-east-1
```

## 🖥️ Option 2: AWS EC2 with Docker

### Step 1: Launch EC2 Instance

```bash
# Launch t3.medium or larger instance (Playwright needs resources)
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --count 1 \
  --instance-type t3.medium \
  --key-name your-key-pair \
  --security-group-ids sg-12345 \
  --subnet-id subnet-12345 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=alleviate-health-api}]'
```

### Step 2: Connect and Setup

```bash
# SSH into instance
ssh -i your-key.pem ec2-user@your-instance-ip

# Install Docker
sudo yum update -y
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Step 3: Deploy Application

```bash
# Clone repository
git clone https://github.com/zaljabir/alleviate-api.git
cd alleviate-api

# Build and run with Docker Compose
docker-compose up -d
```

## 🔧 Option 3: AWS Lambda (Limited Support)

**Note**: Playwright in Lambda has limitations due to:
- 15-minute execution limit
- Cold start delays
- Memory constraints
- Browser binary size

If you still want to try Lambda:

### Step 1: Create Lambda Function with Container

```bash
# Build for Lambda
docker build -t alleviate-health-lambda .

# Tag for Lambda
docker tag alleviate-health-lambda:latest YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/alleviate-health-lambda:latest

# Push to ECR
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/alleviate-health-lambda:latest

# Create Lambda function
aws lambda create-function \
  --function-name alleviate-health-api \
  --package-type Image \
  --code ImageUri=YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/alleviate-health-lambda:latest \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/lambda-execution-role \
  --timeout 900 \
  --memory-size 3008 \
  --region us-east-1
```

## 🌐 Load Balancer Setup

### Application Load Balancer (ALB)

```bash
# Create target group
aws elbv2 create-target-group \
  --name alleviate-health-tg \
  --protocol HTTP \
  --port 3000 \
  --vpc-id vpc-12345 \
  --target-type ip \
  --health-check-path /health \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3 \
  --region us-east-1

# Create load balancer
aws elbv2 create-load-balancer \
  --name alleviate-health-alb \
  --subnets subnet-12345 subnet-67890 \
  --security-groups sg-12345 \
  --region us-east-1
```

## 🔒 Security Considerations

### 1. IAM Roles and Policies

Create IAM role for ECS tasks:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2. Security Groups

```bash
# Create security group
aws ec2 create-security-group \
  --group-name alleviate-health-sg \
  --description "Security group for Alleviate Health API" \
  --vpc-id vpc-12345

# Allow HTTP traffic
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345 \
  --protocol tcp \
  --port 3000 \
  --cidr 0.0.0.0/0

# Allow HTTPS traffic
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345 \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

## 📊 Monitoring and Logging

### CloudWatch Logs

```bash
# Create log group
aws logs create-log-group \
  --log-group-name /ecs/alleviate-health-api \
  --region us-east-1
```

### CloudWatch Alarms

```bash
# Create CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "alleviate-health-cpu-high" \
  --alarm-description "CPU utilization is high" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:alleviate-health-alerts
```

## 🚀 CI/CD Pipeline

### GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to AWS ECS

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Build, tag, and push image to Amazon ECR
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        ECR_REPOSITORY: alleviate-health-api
        IMAGE_TAG: ${{ github.sha }}
      run: |
        docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
    
    - name: Deploy to Amazon ECS
      uses: aws-actions/amazon-ecs-deploy-task-definition@v1
      with:
        task-definition: task-definition.json
        service: alleviate-health-service
        cluster: alleviate-health-cluster
```

## 💰 Cost Optimization

### ECS Fargate Pricing (us-east-1)
- **vCPU**: $0.04048 per vCPU per hour
- **Memory**: $0.004445 per GB per hour
- **Recommended**: 1 vCPU, 2GB RAM = ~$0.05/hour

### EC2 Pricing
- **t3.medium**: ~$0.0416/hour
- **t3.large**: ~$0.0832/hour (if more resources needed)

## 🔧 Troubleshooting

### Common Issues

1. **Playwright browser not found**
   ```bash
   # Ensure browsers are installed in container
   npx playwright install chromium
   ```

2. **Memory issues**
   ```bash
   # Increase memory allocation
   # ECS: 2GB minimum
   # EC2: t3.medium or larger
   ```

3. **Timeout issues**
   ```bash
   # Increase timeout in task definition
   # Set to 900 seconds (15 minutes)
   ```

### Health Check Failures

```bash
# Check container logs
aws logs get-log-events \
  --log-group-name /ecs/alleviate-health-api \
  --log-stream-name ecs/alleviate-health-api/container-id
```

## 📝 Environment Variables

Create `.env.production`:

```env
NODE_ENV=production
PORT=3000
# Add any other environment variables needed
```

## 🎯 Next Steps

1. **Choose your deployment option** (ECS Fargate recommended)
2. **Set up your AWS resources** following the steps above
3. **Configure monitoring and alerts**
4. **Set up CI/CD pipeline**
5. **Test your deployment**
6. **Configure custom domain** (optional)

## 📞 Support

For issues with this deployment guide, please:
1. Check AWS documentation
2. Review container logs
3. Verify security group and IAM permissions
4. Ensure sufficient resources for Playwright

---

**Recommended**: Start with ECS Fargate for the best balance of simplicity, scalability, and cost-effectiveness for your Playwright-based API.
