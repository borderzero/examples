from flask import Flask, request, jsonify, abort, make_response
from datetime import datetime
from retrying import retry
import os
import random
import logging
import pytz
import requests

# default to 'superSecret' if not set
API_SECRET = os.environ.get('API_SECRET', 'superSecret')  
WEATHER_API_KEY = os.environ.get('WEATHER_API_KEY', '')  


tzcache = {}
app = Flask(__name__)

@app.route('/fridayrule', methods=['POST'])
def friday_rule_policy():
  auth_request()
  current_day = None
  try:
    data = request.json
    ip = data['ip']
    

    tz_info = get_timezone(ip)
    current_day = datetime.now(pytz.timezone(tz_info['timezone'])).weekday()
    app.logger.info(f"Current day: {current_day}")
  except Exception as e:
    app.logger.error(f"Error occurred: {str(e)}")
    return jsonify({'error': str(e)}), 400

  if current_day == 4:  # 0 is Monday, 4 is Friday  
    return jsonify({"current_day": current_day}), 401
  else:
    return jsonify({"current_day": current_day}), 200



@app.route('/random', methods=['POST'])
def evaluate():
  # Check for Authorization header

  auth_request()
  #yo!

  # Get the data from the request
  try:
    data = request.json

    ip = data['ip']
    user = data['user']
    protocol = data['protocol']

  except Exception as e:
    # deal with error handling here
    app.logger.error(f"Error occurred: {str(e)}")
    return jsonify({'error': str(e)}), 400

  # Log details of the request, easy for debugging
  #app.logger.info(f"Received data from {get_remote_ip(request)}: {data}")

  # Ok, Now we have the data, and we can make our own Policy decision!

  # These are just placeholders, replace these checks with your own validation logic

  # Let's not allowd HTTP services for example
  if protocol == "http":
    return jsonify({"confidence_score": 0}), 401

  # For the remaining checks, we will just generate a random confidence score
  # This is just a placeholder, replace it with your own logic
  score = random.randint(60, 100)
  app.logger.info(f"random number is : {score}")

  # Return the confidence score (optional)
  # And a 200 status code (OK) (you could use just status code for example)
  return jsonify({"confidence_score": score}), 200


@app.route('/rainorshine', methods=['POST'])
def rain_or_shine_policy():
  auth_request()
  is_raining = False

  try:
    data = request.json
    
    ip = data['ip']
    tz_info = get_timezone(ip)

    # Get the location of the user based on the IP address
    location = tz_info['city'] + ',' + tz_info['countryCode']

    # WeatherAPI Key
    #https://www.weatherapi.com/my/ 
    if WEATHER_API_KEY == '':
        app.logger.error(f"Error occurred: WEATHER_API_KEY not set")
        return jsonify({'error': "WEATHER_API_KEY not set, create one here https://www.weatherapi.com/my/"}), 400


    # WeatherAPI endpoint
    weather_url = f"https://api.weatherapi.com/v1/current.json?key={WEATHER_API_KEY }&q={location}"

    # Fetching the weather data
    weather_data = requests.get(weather_url).json()

    # Get the current condition of the weather
    current_weather = weather_data['current']['condition']['text'].lower()

    if "rain" in current_weather:
      is_raining = True
  except Exception as e:
    app.logger.error(f"Error occurred: {str(e)}")
    return jsonify({'error': str(e)}), 400

  return jsonify({"is_raining": is_raining}), 200


@app.route('/businesshours', methods=['POST'])
def business_hours_policy():
  auth_request()
  current_hour = None
  current_day = None
  try:
    data = request.json

    ip = data['ip']
    tz_info = get_timezone(ip)
    current_time = datetime.now(pytz.timezone(tz_info['timezone']))
    current_day = datetime.now(pytz.timezone(tz_info['timezone'])).weekday()
    current_hour = int(current_time.hour)

    """
    Enable this to validate server side. 
    With this disabled, you'll need to do repsonse validation in the border0 config.
    This can be done using the following Body repsonse expression:
    hour_of_day >= 9 and .hour_of_day < 18 and .current_day < 6
    Which will check if the local's user time is after 9am, but before 6pm.
    It will also check if the current day is either mon(0), Tue(1), wed(2), Thu(4) or friday(5)
    
    # Return 401 if it's not monday-Friday or locally it's not between 9 and 18
    if current_day not in [0,1,2,3,4,5] or current_hour < 9 or current_hour > 17:
      return jsonify({"hour_of_day": current_hour, "current_day": current_day, "error": "denied not in business hours"}), 401
    """
  
  except Exception as e:
    app.logger.error(f"Error occurred: {str(e)}")
    return jsonify({'error2': str(e)}), 400
  
  return jsonify({"hour_of_day": current_hour, "current_day": current_day }), 200



""" 
Check for Authorization header and has the valid password/secret.
If not then abort with 401 status code (Unauthorized)
"""
def auth_request():
  auth = request.headers.get('Authorization', None)
  if auth != API_SECRET:
    app.logger.info(f"Unauthorized access attempt from IP: {get_remote_ip(request)}, Authorization: {auth}")
    response = make_response(jsonify({'error': "Invalid Authorization key"}),401)
    abort(response)


@retry(stop_max_attempt_number=7)
def get_timezone(ip):
  # we use a little cache, to make sure we dont hit the upstream API too hard
  global tzcache
  
  if ip in tzcache:
    return tzcache[ip]
  else:
    tz_info = requests.get(f'http://ip-api.com/json/{ip}').json()
    tzcache[ip] = tz_info
    return tz_info



""" 
A Helper function to Get the remote IP address of the request 
Just in case this code runs behind a load balancer or proxy
"""

def get_remote_ip(request):
  if request.access_route:
    return request.access_route[0]
  else:
    return request.remote_addr


# Main app starts here
if __name__ == '__main__':
  logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
  app.run(host='0.0.0.0', debug=True)
