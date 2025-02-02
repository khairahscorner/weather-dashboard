#!/bin/bash

ROLE_NAME="ecsTaskExecutionRoleV1"
POLICY_ARN="arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
TRUST_POLICY_FILE="policy.json"
CLUSTER_NAME=streamlit-cluster
TASK_NAME=streamlit-app
SERVICE_NAME=streamlit_service

# retrieve necessary variables from .env (Modifying for GHA: envs directly set in workflow)
# export $(grep -v '^#' .env | xargs)

TASK_DEFINITION=$(cat <<EOF
{
  "family": "$TASK_NAME",
  "executionRoleArn": "arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME",
  "containerDefinitions": [
    {
      "name": "streamlit-container",
      "image": "$IMAGE_URL",
      "memory": 512,
      "cpu": 256,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8501,
          "hostPort": 8501,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "OPENWEATHER_API_KEY",
          "value": "$OPENWEATHER_API_KEY"
        },
        {
          "name": "AWS_BUCKET_NAME",
          "value": "$AWS_BUCKET_NAME"
        },
        {
          "name": "AWS_REGION",
          "value": "$AWS_REGION"
        }
      ]
    }
  ],
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512"
}
EOF
)

# Check if the role already exists
echo "Checking if the IAM role '$ROLE_NAME' exists..."
aws iam get-role --role-name $ROLE_NAME > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "IAM role '$ROLE_NAME' does not exist. Creating the role..."
  aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://$TRUST_POLICY_FILE

  if [ $? -eq 0 ]; then
    echo "Role '$ROLE_NAME' created successfully."
  else
    echo "Error creating role '$ROLE_NAME'. Exiting."
    exit 1
  fi
else
  echo "IAM role '$ROLE_NAME' already exists. Moving to next step"
fi


# Check if the required policy is attached
aws iam list-attached-role-policies --role-name $ROLE_NAME | grep -q "$POLICY_ARN"

if [ $? -ne 0 ]; then
  echo "Attaching policy '$POLICY_ARN' to the role..."
  aws iam attach-role-policy --role-name $ROLE_NAME --policy-arn $POLICY_ARN

  if [ $? -eq 0 ]; then
    echo "Policy attached successfully."
  else
    echo "Error attaching policy. Exiting."
    exit 1
  fi
else
    echo "Policy already attached to the role."
fi

# Register the new task definition
echo "Registering task definition with image: $IMAGE_URL"
aws ecs register-task-definition --cli-input-json "$TASK_DEFINITION" > /dev/null 2>&1

if [ $? -ne 0 ]; then
  echo "Error with registering"
  exit 1
fi

# Check if cluster exists
echo "Checking for cluster"
aws ecs list-clusters | grep -q "$CLUSTER_NAME"
if [ $? -ne 0 ]; then
  #Create cluster if not already exists
  echo "Now creating cluster: $CLUSTER_NAME"
  aws ecs create-cluster --cluster-name $CLUSTER_NAME > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "Error with creating cluster"
    exit 1
  fi
else
  echo "Cluster already exists"
fi


echo "checking if service already exists"
if aws ecs list-services --cluster $CLUSTER_NAME --query "serviceArns" --output text | grep -q $SERVICE_NAME; then
  echo "Service already exists, updating..."
  aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment > /dev/null 2>&1
  
  if [ $? -ne 0 ]; then
    echo "Error updating service in cluster"
    exit 1
  fi
else
  echo "Now creating service"
  aws ecs create-service --cluster $CLUSTER_NAME --service-name $SERVICE_NAME \
    --task-definition $TASK_NAME --desired-count 1 --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=$SUBNETS,securityGroups=$SECURITY_GROUPS,assignPublicIp=\"ENABLED\"}" > /dev/null 2>&1

  if [ $? -ne 0 ]; then
    echo "Error with creating service"
    exit 1
  fi
fi
