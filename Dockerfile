# Dockerfile for HDHomeRun DVR
# The initial container will create a base Alpine Linux image and install
# runtime script which will download the latest record engine, configure it
# if no config already exists and then start the engine.
# To update the record engine, simply stop the container, and restart

# Base Image to use - let's see whether latest alpine image causes issues
# FROM alpine:3.11.6
FROM alpine:latest as builder

##########################################################################
# Base Variables
# Default Directories
ARG wrkdir = /HDHomeRunDVR
ARG dvrdata = /dvrdata
ARG dvrrec = /dvrrec
# User/User Group
ARG user=hdhr
ARG group=hdhr
# Default PGID/PUID
ARG uid=1000
ARG gid=1000
# Default Ports
# https://info.hdhomerun.com/info/dvr:troubleshooting#firewall
# 65001/udp required for HDHomeRun discovery and for clients to discover the record engine
ARG udp_port = 65001
# anyport/tcp for client interaction with dvr
# If changing, requires hdhomerun.sh adjustment (to update config file) as well
ARG tcp_port = 59090

##########################################################################
# update/add packages
RUN apk update
RUN apk add wget
RUN apk add grep

##########################################################################
# Create working directory
RUN mkdir -p ${wrkdir}

##########################################################################
# Create volume mount points
RUN mkdir ${dvrdata}
RUN mkdir ${dvrrec}

##########################################################################
# Move Startup Script into Image, will be run every time container is started
COPY hdhomerun.sh /HDHomeRunDVR

##########################################################################
# Add default user/group
RUN groupadd -g ${gid} ${group} && useradd -u ${uid} -g ${group} -s /bin/sh ${user}

##########################################################################
##########################################################################
# Compressed Image with entry point
##########################################################################
##########################################################################
FROM builder as final
# Set Volumes to be added for external mapping
VOLUME [${dvrdata}, ${dvrrec}]

# Mapping for engine to outside world
EXPOSE ${udp_port}/udp
EXPOSE ${tcp_port}/tcp

# And setup to run by default
ENTRYPOINT ["/bin/sh","/HDHomeRunDVR/hdhomerun.sh"]
