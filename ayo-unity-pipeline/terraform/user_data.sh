#!/bin/bash

# Update system
apt-get update -y
apt-get upgrade -y

# Install Docker
apt-get install -y docker.io curl git unzip

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ubuntu

# Install Docker Compose v2
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create project directory
mkdir -p /opt/unity-pipeline
chown ubuntu:ubuntu /opt/unity-pipeline

# Create docker group if it doesn't exist
groupadd -f docker
usermod -a -G docker ubuntu

# Set up environment variables
echo "export AWS_DEFAULT_REGION=eu-west-2" >> /home/ubuntu/.bashrc

# Create welcome message
cat > /home/ubuntu/README.txt << 'WELCOME'
🎉 Unity CI/CD Pipeline Server Ready!

📂 Project Directory: /opt/unity-pipeline
🐳 Docker: Installed and running
📦 Docker Compose: v2.20.0
☁️  AWS CLI: v2 installed

🌐 Service URLs (after deployment):
- Jenkins: http://THIS_IP:8080
- Grafana: http://THIS_IP:3000 
- Prometheus: http://THIS_IP:9090
- Kibana: http://THIS_IP:5601

📝 Next Steps:
1. cd /opt/unity-pipeline
2. Clone your unity-cicd-pipeline repository
3. Run the deployment script
WELCOME

chown ubuntu:ubuntu /home/ubuntu/README.txt

# Install Python3 and pip
apt-get install -y python3 python3-pip python3-venv

# Signal that user data script completed successfully
touch /tmp/user-data-completed
echo "$(date): User data script completed successfully" >> /var/log/user-data.log
