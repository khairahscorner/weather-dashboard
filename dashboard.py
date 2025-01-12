import os
import json
import boto3
import requests
from datetime import datetime
from dotenv import load_dotenv
import streamlit as st

# Load environment variables
load_dotenv()

class WeatherDashboard:
    def __init__(self):
        self.api_key = os.getenv('OPENWEATHER_API_KEY')
        self.bucket_name = os.getenv('AWS_BUCKET_NAME')
        self.region = os.getenv('AWS_REGION')
        self.s3_client = boto3.client('s3', region_name=self.region)

    def create_bucket_if_not_exists(self):
        """First check if bucket exists"""
        try:
            self.s3_client.head_bucket(Bucket=self.bucket_name)
            print(f"Bucket {self.bucket_name} exists")
            return
        except:
            print(f"bucket {self.bucket_name} does not exist, will be created")
        
        try:
            if self.region == "us-east-1":
                # us-east-1 does not require the LocationConstraint parameter
                self.s3_client.create_bucket(Bucket=self.bucket_name)
            else:
                location = {'LocationConstraint': self.region}
                self.s3_client.create_bucket(Bucket=self.bucket_name,
                                    CreateBucketConfiguration=location)
            print(f"Successfully created bucket '{self.bucket_name}' in region '{self.region}'")
        except Exception as e:
            print(f"Error creating bucket: {e}")

    def fetch_weather(self, city):
        """Fetch weather data from OpenWeather API"""
        base_url = "http://api.openweathermap.org/data/2.5/weather"
        params = {
            "q": city,
            "appid": self.api_key,
            "units": "imperial"
        }
        
        try:
            response = requests.get(base_url, params=params)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            print(f"Error fetching weather data: {e}")
            return None

    def save_to_s3(self, weather_data, city):
        """Save weather data to S3 bucket"""
        if not weather_data:
            return False
            
        timestamp = datetime.now().strftime('%d%m%Y-%H%M%S')
        file_name = f"weather-data/{city}-{timestamp}.json"
        
        try:
            weather_data['timestamp'] = timestamp
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=file_name,
                Body=json.dumps(weather_data),
                ContentType='application/json'
            )
            print(f"Successfully saved data for {city} to S3")
            return True
        except Exception as e:
            print(f"Error saving to S3: {e}")
            return False


## Streamlit UI
st.title("Weather App")
st.write("Enter a city to get the current weather data.")

#setup session state to track input field
if "city_name" not in st.session_state:
    st.session_state.city_name = ""

# Input field for the city name
city = st.text_input("City Name", placeholder="Enter a city (e.g., New York)", key="city_name")


## Run Streamlit App
dashboard = WeatherDashboard()
    
# Create bucket if needed
dashboard.create_bucket_if_not_exists()

# Fetch and display weather data when the button is clicked
if st.button("Get Weather"):
    if city.strip():  
        data = dashboard.fetch_weather(city)
        print(data)
        if "error" in data:
            st.error(f"Error: {data['error']}")
        else:
            weather = data.get("weather", [{}])[0].get("description", "N/A")
            temp = data.get("main", {}).get("temp", "N/A")
            humidity = data.get("main", {}).get("humidity", "N/A")
            wind_speed = data.get("wind", {}).get("speed", "N/A")
            today = datetime.fromtimestamp(data["sys"]["sunset"]).strftime('%d-%m-%Y')

            st.success(f"Weather in {city} today ({today}):")
            st.write(f"- **Condition**: {weather.capitalize()}")
            st.write(f"- **Temperature**: {temp}°F")
            st.write(f"- **Humidity**: {humidity}%")
            st.write(f"- **Wind Speed**: {wind_speed} m/s")

            success = dashboard.save_to_s3(data, city)
            if success:
                st.success("Data also saved to S3!")
            else:
                st.error("Could not save to S3, please try later.")
                
    else:
        st.warning("Please enter a city name.")
