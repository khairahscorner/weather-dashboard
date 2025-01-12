#!/bin/bash

# retrieve necessary variables from .env
export $(grep -v '^#' .env | xargs)

# Other variables
REPOSITORY_NAME="weather-dashboard"

# Check if repository exists
# redirects standard output of running the aws ecr command to a special file that discards the contents automatically (/dev/null)
#if there is a standard error i.e 2 (e.g repo was not found), it should redirect to same location as stdout (special file) i.e &1

echo "Checking if ECR repository exists..."
aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $AWS_REGION > /dev/null 2>&1

# "$?"" checks status code of previous command for errors (0: successful, 1: fail)
if [ $? -ne 0 ]; then
  echo "Repository does not exist. Creating repository: $REPOSITORY_NAME..."
  aws ecr create-repository --repository-name $REPOSITORY_NAME --region $AWS_REGION
else
  echo "Repository $REPOSITORY_NAME already exists."
fi

# Authenticate Docker to Amazon ECR
echo "Authenticating Docker to Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build Docker image (optional - if not already built)
echo "Building Docker image..."
docker build -t $REPOSITORY_NAME .

# Tag the Docker image
echo "Tagging Docker image..."
docker tag $REPOSITORY_NAME:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/$REPOSITORY_NAME:latest

# Push the Docker image to Amazon ECR
echo "Pushing Docker image to Amazon ECR..."
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/$REPOSITORY_NAME:latest
echo "Docker image pushed successfully!"

if ! grep -q "^IMAGE_URL=" .env; then
  echo "Adding IMAGE_URL to .env file..."
  echo "\\nIMAGE_URL=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/$REPOSITORY_NAME:latest" >> .env
else
  echo "IMAGE_URL is already defined in .env file."
fi