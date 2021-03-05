# Dockerfile for HDHomeRun DVR
# The initial container will create a base Alpine Linux image and install
# runtime script which will download the latest record engine, configure it
# if no config already exists and then start the engine.
# To update the record engine, simply stop the container, and restart

# Base Image to use - let's see whether latest alpine image causes issues
# FROM alpine:3.11.6
FROM alpine:latest as builder

# Build up new image
# Layer 1
COPY install.sh /
# Layer 2
RUN /bin/sh /install.sh
# Layer 3
COPY hdhomerun.sh /HDHomeRunDVR

FROM builder as final
# Set Volumes to be added
VOLUME ["/dvrrec", "/dvrdata"]

# Will use this port for mapping engine to the outside world
# https://info.hdhomerun.com/info/dvr:troubleshooting#firewall
# 65001/udp required for HDHomeRun discovery and for clients to discover the record engine
EXPOSE 65001/udp
# anyport/tcp for client interaction with dvr
# If changing, requires hdhomerun.sh adjustment (to update config file) as well
EXPOSE 59090/tcp

# And setup to run by default
ENTRYPOINT ["/bin/sh","/HDHomeRunDVR/hdhomerun.sh"]
