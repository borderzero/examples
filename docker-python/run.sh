docker build . -t border0container
docker run -e BORDER0_ADMIN_TOKEN=$BORDER0_ADMIN_TOKEN -p 12345:12345  border0container
