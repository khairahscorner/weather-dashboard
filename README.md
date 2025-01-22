# Weather Dashboard

## About
A Streamlit app that fetches and displays real-time weather data for cities.

## Stack
- Python
- Boto3
- Streamlit (open-source Python library for web apps)
- AWS S3
- AWS ECS/Fargate (deploy)

## Architectural Diagram
![Diagram](architecture.png)

## Features
- Fetches real-time weather data for any specified city of choice
- Displays weather conditions like temperature (°F), humidity, etc
- Automatically saves weather data to AWS S3 with timestamps for historical tracking

![App](deployed-app-comp.gif)

## Concepts Learnt
- Python web app development (using Streamlit)
- Infrastructure as Code (using SDKs)
- Cloud Storage (AWS S3)
- Containerisation (Docker)
- Container App Deployment (AWS ECS with Fargate)

## Development Process
  - [Documentation](docs.md)
  - [Blog post](https://khairahscorner.hashnode.dev/build-and-deploy-weather-app-using-streamlit-and-aws-ecs-with-fargate)

## Enhancements
- CI/CD to trigger redeploy: GitHub Actions, AWS
