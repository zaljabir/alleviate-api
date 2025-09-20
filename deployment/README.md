# Deployment Scripts

This folder contains all deployment-related scripts and files for the Alleviate Health API.

## 📁 Files

- **`deploy-spot-instance.sh`** - Deploy API to AWS EC2 Spot instance
- **`update-deployment.sh`** - Update existing deployment with new code
- **`cleanup-spot-instance.sh`** - Clean up all AWS resources
- **`deployment-info.txt`** - Generated file with deployment details (auto-created)
- **`alleviate-health-api-key.pem`** - SSH private key (auto-created)
- **`DEPLOYMENT.md`** - General deployment documentation
- **`SPOT-DEPLOYMENT.md`** - EC2 Spot instance specific guide

## 🚀 Quick Start

1. **Deploy**: `./deployment/deploy-spot-instance.sh`
2. **Update**: `./deployment/update-deployment.sh`
3. **Cleanup**: `./deployment/cleanup-spot-instance.sh`

## ⚠️ Important Notes

- Run all scripts from the **project root directory**
- The `.pem` file and `deployment-info.txt` are automatically created
- These files are in `.gitignore` for security
- Never commit private keys to version control

## 🔧 Usage

All scripts should be run from the project root:

```bash
# From project root (/Users/zainaljabiry/Code/Alleviate Health API)
./deployment/deploy-spot-instance.sh
./deployment/update-deployment.sh
./deployment/cleanup-spot-instance.sh
```

## 📋 Prerequisites

- AWS CLI configured
- Docker installed locally
- Node.js and npm installed locally
- Proper AWS permissions for EC2, IAM, and VPC
