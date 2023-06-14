This example demonstrates how to make a simple python app in Docker available via Border0

## Youtube Video demo
  [![Video demo](https://img.youtube.com/vi/SrT0V4QCUgM/0.jpg)](https://www.youtube.com/watch?v=SrT0V4QCUgM "video demo python docker")
  
  https://www.youtube.com/watch?v=SrT0V4QCUgM
  
We have 3 files
Dockerfile       
border0.yaml     
supervisord.conf

Next, you need to create a token here: https://portal.border0.com/organizations/current?tab=tokens

we recommend you create a 'connector' token. It has limited access (can only create new sockets and manage sockets it created).
set that as an env variable: 
export BORDER0_ADMIN_TOKEN=<YOUR token here>

build container:
docker build . -t border0container

Then run it like:
docker run -e BORDER0_ADMIN_TOKEN=$BORDER0_ADMIN_TOKEN -p 12345:12345  border0container

And you will have a service called, web-<ORGNAME>.border0.io 
You can change the name by changing the name of the socket in the border0.yaml file.

You can play with policies here and control who has access to this new service:
https://portal.border0.com/policies
  

  
