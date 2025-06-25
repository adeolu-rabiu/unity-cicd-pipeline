#!/bin/bash
# AWS Permission Checker for Unity CI/CD Pipeline
# Tests all required permissions for the project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 AWS Permission Checker for Unity CI/CD Pipeline${NC}"
echo "=================================================="

# Function to check command success
check_permission() {
    local service=$1
    local command=$2
    local description=$3
    
    echo -e "\n${YELLOW}Testing: ${description}${NC}"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS: ${service} - ${description}${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL: ${service} - ${description}${NC}"
        return 1
    fi
}

# Initialize counters
TOTAL_TESTS=0
PASSED_TESTS=0

# Test function wrapper
test_permission() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if check_permission "$@"; then
        PASSED_TESTS=$((PASSED_TESTS + 1))
    fi
}

echo -e "\n${BLUE}🔐 Basic Authentication${NC}"
echo "========================"

# Basic authentication test
echo -e "\n${YELLOW}Testing basic AWS authentication...${NC}"
if aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${GREEN}✅ AWS Authentication successful${NC}"
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    echo -e "User ARN: ${USER_ARN}"
    echo -e "Account ID: ${ACCOUNT_ID}"
else
    echo -e "${RED}❌ AWS Authentication failed!${NC}"
    echo -e "${RED}Please run: aws configure${NC}"
    exit 1
fi

echo -e "\n${BLUE}🖥️ EC2 (Elastic Compute Cloud) Permissions${NC}"
echo "============================================="
test_permission "EC2" "aws ec2 describe-regions" "List AWS regions"
test_permission "EC2" "aws ec2 describe-vpcs" "Describe VPCs"
test_permission "EC2" "aws ec2 describe-subnets" "Describe subnets"
test_permission "EC2" "aws ec2 describe-security-groups" "Describe security groups"
test_permission "EC2" "aws ec2 describe-key-pairs" "Describe key pairs"
test_permission "EC2" "aws ec2 describe-instances" "Describe instances"
test_permission "EC2" "aws ec2 describe-images --owners amazon --filters 'Name=name,Values=amzn2-ami-hvm-*' --query 'Images[0].ImageId'" "Describe AMIs"

# Test EC2 creation permissions (dry run)
test_permission "EC2" "aws ec2 run-instances --dry-run --image-id ami-0c02fb55956c7d316 --instance-type t3.micro" "Create EC2 instances (dry-run)"

echo -e "\n${BLUE}🪣 S3 (Simple Storage Service) Permissions${NC}"
echo "==========================================="
test_permission "S3" "aws s3 ls" "List S3 buckets"
test_permission "S3" "aws s3api list-buckets" "List buckets via API"

# Test S3 bucket creation/deletion
TEST_BUCKET="unity-pipeline-test-$(date +%s)"
test_permission "S3" "aws s3 mb s3://${TEST_BUCKET}" "Create S3 bucket"
if aws s3api head-bucket --bucket "${TEST_BUCKET}" 2>/dev/null; then
    test_permission "S3" "aws s3 cp /etc/hostname s3://${TEST_BUCKET}/test.txt" "Upload to S3"
    test_permission "S3" "aws s3 ls s3://${TEST_BUCKET}/" "List S3 objects"
    test_permission "S3" "aws s3 rm s3://${TEST_BUCKET}/test.txt" "Delete S3 object"
    test_permission "S3" "aws s3 rb s3://${TEST_BUCKET}" "Delete S3 bucket"
fi

echo -e "\n${BLUE}🔑 IAM (Identity and Access Management) Permissions${NC}"
echo "===================================================="
test_permission "IAM" "aws iam get-user" "Get user information"
test_permission "IAM" "aws iam list-attached-user-policies --user-name \$(aws sts get-caller-identity --query User.UserName --output text)" "List user policies"
test_permission "IAM" "aws iam list-roles --max-items 1" "List IAM roles"
test_permission "IAM" "aws iam get-account-summary" "Get account summary"

echo -e "\n${BLUE}🐳 ECS (Elastic Container Service) Permissions${NC}"
echo "================================================"
test_permission "ECS" "aws ecs list-clusters" "List ECS clusters"
test_permission "ECS" "aws ecs describe-clusters" "Describe ECS clusters"
test_permission "ECS" "aws ecs list-task-definitions" "List task definitions"

echo -e "\n${BLUE}🌐 VPC (Virtual Private Cloud) Permissions${NC}"
echo "============================================"
test_permission "VPC" "aws ec2 describe-vpcs" "Describe VPCs"
test_permission "VPC" "aws ec2 describe-internet-gateways" "Describe internet gateways"
test_permission "VPC" "aws ec2 describe-route-tables" "Describe route tables"
test_permission "VPC" "aws ec2 describe-network-acls" "Describe network ACLs"

echo -e "\n${BLUE}📝 CloudFormation Permissions (for Terraform)${NC}"
echo "=============================================="
test_permission "CloudFormation" "aws cloudformation list-stacks" "List CloudFormation stacks"
test_permission "CloudFormation" "aws cloudformation describe-stacks" "Describe stacks"

echo -e "\n${BLUE}🏷️ Additional Required Permissions${NC}"
echo "===================================="
test_permission "STS" "aws sts get-session-token" "Get session token"
test_permission "STS" "aws sts assume-role --role-arn arn:aws:iam::${ACCOUNT_ID}:role/NonExistentRole --role-session-name test 2>/dev/null || echo 'Role not found (expected)'" "Test assume role capability"

echo -e "\n${BLUE}📊 Permission Test Summary${NC}"
echo "============================"
echo -e "Total Tests: ${TOTAL_TESTS}"
echo -e "Passed: ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"

if [ ${PASSED_TESTS} -eq ${TOTAL_TESTS} ]; then
    echo -e "\n${GREEN}🎉 ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}✅ Your AWS user has sufficient permissions for the Unity CI/CD pipeline${NC}"
    echo -e "\n${BLUE}You can proceed with:${NC}"
    echo -e "  terraform init"
    echo -e "  terraform plan"
    echo -e "  terraform apply"
else
    echo -e "\n${RED}⚠️ SOME TESTS FAILED!${NC}"
    echo -e "${RED}❌ Your AWS user is missing some required permissions${NC}"
    echo -e "\n${YELLOW}Minimum required permissions:${NC}"
    echo -e "  • EC2: Full access (or EC2FullAccess policy)"
    echo -e "  • S3: Full access (or S3FullAccess policy)"  
    echo -e "  • IAM: Read access + role creation"
    echo -e "  • VPC: Full access for network setup"
    echo -e "  • ECS: Full access for container orchestration"
    
    echo -e "\n${YELLOW}Quick fix - Attach these AWS managed policies:${NC}"
    echo -e "  aws iam attach-user-policy --user-name YOUR_USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess"
    echo -e "  aws iam attach-user-policy --user-name YOUR_USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess"
    echo -e "  aws iam attach-user-policy --user-name YOUR_USERNAME --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess"
    echo -e "  aws iam attach-user-policy --user-name YOUR_USERNAME --policy-arn arn:aws:iam::aws:policy/IAMFullAccess"
fi

echo -e "\n${BLUE}📋 Current User Policies:${NC}"
echo "========================="
aws iam list-attached-user-policies --user-name $(aws sts get-caller-identity --query User.UserName --output text) --output table 2>/dev/null || echo "Unable to list user policies"

echo -e "\n${BLUE}🔍 For more detailed permission analysis, run:${NC}"
echo "aws iam simulate-principal-policy --policy-source-arn ${USER_ARN} --action-names ec2:RunInstances s3:CreateBucket iam:CreateRole"
