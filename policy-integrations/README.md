# Border0 Policy Engine Integration Example

This is an example project demonstrating how to integrate with the Border0 Policy Engine. This Flask application exposes a number of endpoints that can be called by the Border0 Policy Engine. It allows users to define their own logic and specify their own conditions for who should have access, using their own data and logic.

For more details also see:
https://www.border0.com/blogs/the-most-flexible-policy-engine-in-the-world
and 
https://docs.border0.com/docs/the-generic-http-api-integration

## Endpoints

The following endpoints are available:

- `/fridayrule`: An endpoint that denies access on Fridays. Uses the requester's IP address to determine their current day of the week.

- `/random`: This endpoint randomly generates a confidence score between 60 and 100. If the incoming request protocol is "http", it denies the request.

- `/rainorshine`: This endpoint uses the requester's IP address to determine their current location and fetches the current weather data. If it's raining, the response will indicate so.

- `/businesshours`: This endpoint checks if the request is made within business hours (between 9am and 6pm local time, Monday through Friday).

Each endpoint requires a valid 'Authorization' header with a secret key. The default secret key is 'superSecret', but can be changed by setting the 'API_SECRET' environment variable.



## Setup

### Requirements

This project requires Python and pip to run. The required Python libraries can be installed by running:

```bash
pip install -r requirements.txt
```

### Running the Application

To start the application, run the following command:

```bash
python app.py
```

Alternatively, you can run the application using Docker:

```bash
docker build -t border0-example .
docker run -p 5000:5000 border0-example
```

The application will start and begin listening for requests.

## Configuration

- `API_SECRET`: The secret key for the 'Authorization' header. Default is 'superSecret'.

## Usage

To use the endpoints, send a POST request with a valid 'Authorization' header and a JSON body containing the required fields.

For example:

```bash
curl -X POST http://localhost:5000/fridayrule-H "Content-Type: application/json" -d '{"ip":"1.2.3.4","user":"example@border0.com","protocol":"ssh"}'
```

Please refer to the code comments and logs for more detailed explanations of the endpoint logic and expected request/response formats.

## Support

If you encounter any issues or have any questions, please raise an issue in this repository.

## Disclaimer

This code is provided as an example only. It should be reviewed and adapted to your own requirements and testing procedures before using it in a production environment.

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.
