# Use a base image with Python installed
FROM python:3.8-slim

# Install 'border0' package and supervisord
RUN apt-get update && apt-get install -y supervisor

# Copy our supervisord.conf file from our project directory into the Docker container
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

ADD https://download.border0.com/linux_amd64/border0 /
run chmod a+rx /border0
COPY border0.yaml /etc/border0.yaml

# Run supervisord
CMD ["/usr/bin/supervisord"]


