
1) Outline app/project requirements: I wanted a UI-based app that users can enter the city instead of hard-coding (rest of functionalty remains the same)
Answer: streamlit

2) It's advisable to run python apps in virtual environments to ensure installed dependencies are isolated and do not have general side-effects
MacOS
 - virtualenv -p python3 .venv
 - source .venv/bin/activate

 - deactivate

3) Run pip install -r requirements.txt

4) Start app with streamlit run src/dashboard.py

5) explain code

6) Run with Docker:
- Build image: docker build -t streamlit_app . 
- Run container app: docker run --env-file .env -p 8501:8501 streamlit_app


7) Deploy to ECS
- setup env: `sh ecr_setup.sh`
- configure ECS and deploy: `sh ecs_task_setup.sh`


Ensure that the security group allows inbound access from port 8501