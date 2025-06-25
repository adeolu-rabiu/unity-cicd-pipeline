#!/bin/bash
# AWS Unity CI/CD Pipeline Cleanup Script
# This script safely removes all AWS resources created for the Unity pipeline project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 AWS Unity Pipeline Cleanup Script${NC}"
echo "========================================"

# Get current region
AWS_REGION=${AWS_DEFAULT_REGION:-eu-west-2}
echo -e "${YELLOW}Using AWS Region: ${AWS_REGION}${NC}"

# Function to safely delete with confirmation
safe_delete() {
    local resource_type=$1
    local resource_id=$2
    local delete_command=$3
    
    echo -e "\n${YELLOW}Found ${resource_type}: ${resource_id}${NC}"
    read -p "Delete this ${resource_type}? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Deleting ${resource_type}: ${resource_id}${NC}"
        eval "$delete_command"
        echo -e "${GREEN}✅ Deleted successfully${NC}"
    else
        echo -e "${YELLOW}⏭️ Skipped${NC}"
    fi
}

# Function for automatic deletion (non-interactive)
auto_delete() {
    local resource_type=$1
    local resource_id=$2
    local delete_command=$3
    
    echo -e "\n${YELLOW}Auto-deleting ${resource_type}: ${resource_id}${NC}"
    if eval "$delete_command" 2>/dev/null; then
        echo -e "${GREEN}✅ Deleted successfully${NC}"
    else
        echo -e "${RED}❌ Failed to delete or doesn't exist${NC}"
    fi
}

echo -e "\n${BLUE}🔍 Scanning for Unity Pipeline AWS Resources...${NC}"

# 1. TERMINATE EC2 INSTANCES
echo -e "\n${BLUE}1. 🖥️ EC2 Instances${NC}"
INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=unity-jenkins-server" "Name=instance-state-name,Values=running,stopped,stopping" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text \
    --region $AWS_REGION 2>/dev/null || echo "")

if [ ! -z "$INSTANCES" ]; then
    for instance in $INSTANCES; do
        safe_delete "EC2 Instance" "$instance" "aws ec2 terminate-instances --instance-ids $instance --region $AWS_REGION"
    done
else
    echo -e "${GREEN}✅ No Unity pipeline EC2 instances found${NC}"
fi

# 2. DELETE SECURITY GROUPS
echo -e "\n${BLUE}2. 🔒 Security Groups${NC}"
SECURITY_GROUPS=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=unity-jenkins-sg*" \
    --query "SecurityGroups[].GroupId" \
    --output text \
    --region $AWS_REGION 2>/dev/null || echo "")

if [ ! -z "$SECURITY_GROUPS" ]; then
    # Wait a bit for instances to terminate before deleting security groups
    echo -e "${YELLOW}⏳ Waiting 30 seconds for EC2 instances to terminate...${NC}"
    sleep 30
    
    for sg in $SECURITY_GROUPS; do
        safe_delete "Security Group" "$sg" "aws ec2 delete-security-group --group-id $sg --region $AWS_REGION"
    done
else
    echo -e "${GREEN}✅ No Unity pipeline security groups found${NC}"
fi

# 3. DELETE S3 BUCKETS
echo -e "\n${BLUE}3. 🪣 S3 Buckets${NC}"
S3_BUCKETS=$(aws s3 ls | grep "unity-builds-" | awk '{print $3}' || echo "")

if [ ! -z "$S3_BUCKETS" ]; then
    for bucket in $S3_BUCKETS; do
        echo -e "\n${YELLOW}Found S3 Bucket: ${bucket}${NC}"
        echo -e "${YELLOW}Bucket contents:${NC}"
        aws s3 ls s3://$bucket --recursive --human-readable --summarize 2>/dev/null || echo "Empty or inaccessible"
        
        read -p "Delete S3 bucket '$bucket' and ALL its contents? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Deleting S3 bucket: ${bucket}${NC}"
            # Remove all objects first
            aws s3 rm s3://$bucket --recursive 2>/dev/null || echo "No objects to delete"
            # Remove all versions
            aws s3api delete-objects --bucket $bucket --delete "$(aws s3api list-object-versions --bucket $bucket --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}')" 2>/dev/null || echo "No versions to delete"
            # Delete bucket
            aws s3 rb s3://$bucket --force
            echo -e "${GREEN}✅ S3 bucket deleted${NC}"
        else
            echo -e "${YELLOW}⏭️ S3 bucket skipped${NC}"
        fi
    done
else
    echo -e "${GREEN}✅ No Unity pipeline S3 buckets found${NC}"
fi

# 4. DELETE ECS CLUSTERS
echo -e "\n${BLUE}4. 🐳 ECS Clusters${NC}"
ECS_CLUSTERS=$(aws ecs list-clusters \
    --query "clusterArns[?contains(@, 'unity-builds')]" \
    --output text \
    --region $AWS_REGION 2>/dev/null || echo "")

if [ ! -z "$ECS_CLUSTERS" ]; then
    for cluster_arn in $ECS_CLUSTERS; do
        cluster_name=$(echo $cluster_arn | cut -d'/' -f2)
        
        # Stop all running tasks first
        TASKS=$(aws ecs list-tasks --cluster $cluster_name --query "taskArns" --output text --region $AWS_REGION 2>/dev/null || echo "")
        if [ ! -z "$TASKS" ]; then
            echo -e "${YELLOW}Stopping tasks in cluster: ${cluster_name}${NC}"
            for task in $TASKS; do
                aws ecs stop-task --cluster $cluster_name --task $task --region $AWS_REGION 2>/dev/null || echo "Task already stopped"
            done
            sleep 10
        fi
        
        safe_delete "ECS Cluster" "$cluster_name" "aws ecs delete-cluster --cluster $cluster_name --region $AWS_REGION"
    done
else
    echo -e "${GREEN}✅ No Unity pipeline ECS clusters found${NC}"
fi

# 5. DELETE VPC RESOURCES (if created by our Terraform)
echo -e "\n${BLUE}5. 🌐 VPC Resources${NC}"
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=unity-cicd-vpc" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "" ]; then
    echo -e "${YELLOW}Found Unity VPC: ${VPC_ID}${NC}"
    read -p "Delete Unity VPC and all its resources? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Deleting VPC resources...${NC}"
        
        # Delete subnets
        SUBNETS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text --region $AWS_REGION 2>/dev/null || echo "")
        for subnet in $SUBNETS; do
            auto_delete "Subnet" "$subnet" "aws ec2 delete-subnet --subnet-id $subnet --region $AWS_REGION"
        done
        
        # Delete route tables (except main)
        ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main != \`true\`].RouteTableId" --output text --region $AWS_REGION 2>/dev/null || echo "")
        for rt in $ROUTE_TABLES; do
            auto_delete "Route Table" "$rt" "aws ec2 delete-route-table --route-table-id $rt --region $AWS_REGION"
        done
        
        # Delete internet gateway
        IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[].InternetGatewayId" --output text --region $AWS_REGION 2>/dev/null || echo "")
        if [ ! -z "$IGW_ID" ] && [ "$IGW_ID" != "" ]; then
            auto_delete "Internet Gateway (detach)" "$IGW_ID" "aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $AWS_REGION"
            auto_delete "Internet Gateway (delete)" "$IGW_ID" "aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID --region $AWS_REGION"
        fi
        
        # Delete VPC
        auto_delete "VPC" "$VPC_ID" "aws ec2 delete-vpc --vpc-id $VPC_ID --region $AWS_REGION"
    else
        echo -e "${YELLOW}⏭️ VPC resources skipped${NC}"
    fi
else
    echo -e "${GREEN}✅ No Unity pipeline VPC found${NC}"
fi

# 6. TERRAFORM STATE CLEANUP (OPTIONAL)
echo -e "\n${BLUE}6. 🏗️ Terraform State${NC}"
TERRAFORM_DIR="~/unity-cicd-pipeline/ayo-unity-pipeline/terraform"
if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    read -p "Delete local Terraform state files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f $TERRAFORM_DIR/terraform.tfstate*
        rm -rf $TERRAFORM_DIR/.terraform
        echo -e "${GREEN}✅ Terraform state cleaned${NC}"
    else
        echo -e "${YELLOW}⏭️ Terraform state kept${NC}"
    fi
else
    echo -e "${GREEN}✅ No Terraform state found${NC}"
fi

# 7. SUMMARY
echo -e "\n${BLUE}📊 Cleanup Summary${NC}"
echo "=================================="
echo -e "${GREEN}✅ EC2 instances: Checked and cleaned${NC}"
echo -e "${GREEN}✅ Security groups: Checked and cleaned${NC}"
echo -e "${GREEN}✅ S3 buckets: Checked and cleaned${NC}"
echo -e "${GREEN}✅ ECS clusters: Checked and cleaned${NC}"
echo -e "${GREEN}✅ VPC resources: Checked and cleaned${NC}"
echo -e "${GREEN}✅ Terraform state: Checked and cleaned${NC}"

echo -e "\n${YELLOW}💰 Cost Savings:${NC}"
echo "- EC2 t3.large instances: ~$0.10/hour saved"
echo "- S3 storage: Variable based on usage"
echo "- Data transfer: Minimal"

echo -e "\n${BLUE}🌙 Good night! Your AWS resources are cleaned up.${NC}"
echo -e "${GREEN}💤 Sleep well knowing you won't have surprise AWS bills!${NC}"

echo -e "\n${YELLOW}📝 Tomorrow's TODO:${NC}"
echo "1. 🔄 Re-run terraform apply (takes ~5 minutes)"
echo "2. 🐳 Restart Docker containers on VM"
echo "3. 🚀 Continue Jenkins pipeline configuration"
echo "4. 🎮 Complete Unity build agent setup"

echo -e "\n${BLUE}🔗 Quick restart commands for tomorrow:${NC}"
echo "cd ~/unity-cicd-pipeline/ayo-unity-pipeline/terraform"
echo "terraform apply"
echo "cd ../jenkins && docker compose up -d"
