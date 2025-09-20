# 🚀 EC2 Spot Instance Deployment - Cheapest Option

This guide provides the **most cost-effective deployment option** for your Alleviate Health API when running infrequently (few times per month).

## 💰 Cost Analysis

### **EC2 Spot Instance Pricing:**
- **t3.medium**: ~$0.008/hour (80% cheaper than on-demand)
- **t3.large**: ~$0.016/hour (if more resources needed)
- **Monthly cost for 10 executions**: ~$0.08

### **Comparison with Other Options:**
| Option | Monthly Cost (10 runs) | Setup Time | Playwright Support |
|--------|------------------------|------------|-------------------|
| **EC2 Spot** | $0.08 | 5 minutes | ✅ Full |
| Lambda | $0.01 | 2 minutes | ⚠️ Limited |
| ECS Fargate | $0.02 | 30 minutes | ✅ Full |
| EC2 On-Demand | $0.40 | 5 minutes | ✅ Full |

## 🎯 Why EC2 Spot Instances?

### **Advantages:**
- ✅ **80% cost savings** compared to on-demand instances
- ✅ **Full Playwright support** with browser automation
- ✅ **Quick deployment** (5 minutes setup)
- ✅ **Auto-shutdown** after 30 minutes of inactivity
- ✅ **Reliable execution** for complex operations
- ✅ **Easy management** with provided scripts

### **Considerations:**
- ⚠️ **Spot interruption risk** (rare, but possible)
- ⚠️ **No guaranteed availability** (though very reliable)
- ⚠️ **Manual cleanup** required (automated with scripts)

## 🚀 Quick Start

### **Prerequisites:**
1. **AWS CLI installed and configured**
   ```bash
   aws configure
   ```

2. **Git repository cloned**
   ```bash
   git clone https://github.com/zaljabir/alleviate-api.git
   cd alleviate-api
   ```

### **One-Command Deployment:**
```bash
# Make script executable
chmod +x deploy-spot-instance.sh

# Deploy to AWS (takes ~5 minutes)
./deploy-spot-instance.sh
```

### **One-Command Cleanup:**
```bash
# Clean up all resources
./cleanup-spot-instance.sh
```

## 📋 What the Scripts Do

### **deploy-spot-instance.sh:**
1. **Creates security group** with HTTP/SSH access
2. **Generates SSH key pair** for instance access
3. **Launches spot instance** with auto-setup
4. **Installs Docker, Node.js, and dependencies**
5. **Clones and deploys your API**
6. **Sets up auto-shutdown** after 30 minutes of inactivity
7. **Tests API endpoints** and displays access information

### **cleanup-spot-instance.sh:**
1. **Terminates EC2 instance**
2. **Deletes security group**
3. **Removes key pair**
4. **Cleans up local files**
5. **Shows cost summary**

## 🔧 Manual Deployment Steps

If you prefer manual deployment:

### **Step 1: Create Security Group**
```bash
aws ec2 create-security-group \
  --group-name alleviate-health-api-sg \
  --description "Security group for Alleviate Health API" \
  --vpc-id vpc-12345

# Allow HTTP traffic
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345 \
  --protocol tcp \
  --port 3000 \
  --cidr 0.0.0.0/0
```

### **Step 2: Create Key Pair**
```bash
aws ec2 create-key-pair \
  --key-name alleviate-health-api-key \
  --query 'KeyMaterial' \
  --output text > alleviate-health-api-key.pem

chmod 400 alleviate-health-api-key.pem
```

### **Step 3: Launch Spot Instance**
```bash
aws ec2 run-instances \
  --image-id ami-0c02fb55956c7d316 \
  --count 1 \
  --instance-type t3.medium \
  --key-name alleviate-health-api-key \
  --security-group-ids sg-12345 \
  --subnet-id subnet-12345 \
  --user-data file://user-data.sh \
  --instance-market-options '{
    "MarketType": "spot",
    "SpotOptions": {
      "MaxPrice": "0.01",
      "SpotInstanceType": "one-time"
    }
  }'
```

## 🌐 Accessing Your API

After deployment, your API will be available at:

- **Health Check**: `http://YOUR_PUBLIC_IP:3000/health`
- **API Documentation**: `http://YOUR_PUBLIC_IP:3000/api-docs`
- **Phone Update Endpoint**: `http://YOUR_PUBLIC_IP:3000/settings/phone`

### **Example API Call:**
```bash
# Health check
curl http://YOUR_PUBLIC_IP:3000/health

# Update phone number
curl -X POST http://YOUR_PUBLIC_IP:3000/settings/phone \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic $(echo -n 'username:password' | base64)" \
  -d '{"phoneNumber": "+1234567890"}'
```

## 🔧 Management Commands

### **SSH Access:**
```bash
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP
```

### **Start/Stop API:**
```bash
# Start API
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP './start-api.sh'

# Stop API
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP './stop-api.sh'
```

### **View Logs:**
```bash
# View API logs
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'journalctl -u alleviate-api -f'

# View deployment logs
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'cat /var/log/alleviate-deployment.log'
```

## ⚡ Auto-Shutdown Feature

The deployment includes an **intelligent auto-shutdown** system:

- **Monitors API usage** every 10 minutes
- **Shuts down after 30 minutes** of inactivity
- **Saves costs** by not running when not needed
- **Can be disabled** if needed

### **Disable Auto-Shutdown:**
```bash
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'crontab -r'
```

### **Modify Shutdown Time:**
```bash
# Change to 60 minutes instead of 30
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'sed -i "s/1800/3600/g" /home/ec2-user/auto-shutdown.sh'
```

## 📊 Monitoring and Logging

### **CloudWatch Integration:**
```bash
# Create CloudWatch log group
aws logs create-log-group \
  --log-group-name /aws/ec2/alleviate-health-api \
  --region us-east-1
```

### **Cost Monitoring:**
```bash
# Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

## 🔒 Security Best Practices

### **1. Restrict SSH Access:**
```bash
# Update security group to restrict SSH to your IP only
aws ec2 authorize-security-group-ingress \
  --group-id sg-12345 \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32
```

### **2. Use HTTPS (Optional):**
```bash
# Install SSL certificate (Let's Encrypt)
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'sudo yum install -y certbot'
```

### **3. Regular Updates:**
```bash
# Update system packages
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'sudo yum update -y'
```

## 🚨 Troubleshooting

### **Common Issues:**

#### **1. Instance Not Starting:**
```bash
# Check instance status
aws ec2 describe-instances --instance-ids i-12345

# Check system logs
aws ec2 get-console-output --instance-id i-12345
```

#### **2. API Not Responding:**
```bash
# Check service status
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'systemctl status alleviate-api'

# Restart service
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'sudo systemctl restart alleviate-api'
```

#### **3. Playwright Issues:**
```bash
# Reinstall Playwright browsers
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'cd /home/ec2-user/alleviate-api && npx playwright install chromium'
```

#### **4. High Memory Usage:**
```bash
# Check memory usage
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'free -h'

# Restart if needed
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'sudo reboot'
```

## 💡 Cost Optimization Tips

### **1. Use Smaller Instance Types:**
- **t3.small**: $0.004/hour (if API is lightweight)
- **t3.medium**: $0.008/hour (recommended for Playwright)
- **t3.large**: $0.016/hour (if you need more resources)

### **2. Optimize Auto-Shutdown:**
- **Reduce idle time** from 30 to 15 minutes
- **Monitor usage patterns** and adjust accordingly

### **3. Use Reserved Instances (if running more frequently):**
- **1-year term**: 30% savings
- **3-year term**: 50% savings
- **Only cost-effective** if running >100 hours/month

## 📈 Scaling Options

### **If Usage Increases:**

#### **Option 1: Auto Scaling Group**
```bash
# Create launch template
aws ec2 create-launch-template \
  --launch-template-name alleviate-health-template \
  --launch-template-data file://launch-template.json
```

#### **Option 2: Load Balancer**
```bash
# Create application load balancer
aws elbv2 create-load-balancer \
  --name alleviate-health-alb \
  --subnets subnet-12345 subnet-67890 \
  --security-groups sg-12345
```

#### **Option 3: Move to ECS Fargate**
- **Better for** consistent usage
- **Auto-scaling** built-in
- **Higher cost** but more reliable

## 🎯 Best Practices

### **1. Regular Backups:**
```bash
# Create AMI backup
aws ec2 create-image \
  --instance-id i-12345 \
  --name "alleviate-health-api-backup-$(date +%Y%m%d)"
```

### **2. Monitor Costs:**
```bash
# Set up billing alerts
aws cloudwatch put-metric-alarm \
  --alarm-name "ec2-cost-alert" \
  --alarm-description "Alert when EC2 costs exceed $5" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --threshold 5.0 \
  --comparison-operator GreaterThanThreshold
```

### **3. Update Dependencies:**
```bash
# Regular updates
ssh -i alleviate-health-api-key.pem ec2-user@YOUR_PUBLIC_IP 'cd /home/ec2-user/alleviate-api && npm update'
```

## 📞 Support

### **Getting Help:**
1. **Check logs** first: `journalctl -u alleviate-api -f`
2. **Verify instance status**: `aws ec2 describe-instances`
3. **Test connectivity**: `curl http://YOUR_IP:3000/health`
4. **Review deployment info**: `cat deployment-info.txt`

### **Emergency Cleanup:**
```bash
# Force cleanup if scripts fail
aws ec2 terminate-instances --instance-ids i-12345
aws ec2 delete-security-group --group-id sg-12345
aws ec2 delete-key-pair --key-name alleviate-health-api-key
```

---

## 🎉 Summary

**EC2 Spot Instances** provide the **cheapest deployment option** for your infrequent Playwright-based API:

- ✅ **$0.08/month** for 10 executions
- ✅ **5-minute deployment** with automated scripts
- ✅ **Full Playwright support** for browser automation
- ✅ **Auto-shutdown** to minimize costs
- ✅ **Easy cleanup** with provided scripts

**Perfect for**: Infrequent usage, cost-conscious deployments, and reliable Playwright automation.

**Start with**: `./deploy-spot-instance.sh` and you'll have your API running in 5 minutes! 🚀
