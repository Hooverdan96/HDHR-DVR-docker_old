Forked from: https://github.com/demonrik/HDHR-DVR-docker

# HDHR-DVR-docker
Docker Wrapper for SiliconDust's HDHomeRun DVR Record Engine

Image based on latest Alpine Linux https://alpinelinux.org/

Contains a script to download the latest engine when the engine is started.  
To update the engine stop the container and then start it again and it will get the latest.

## DVR Engine User
The container is run as a root user (unless specified differently in docker run command), but the engine can be run with a different user altogether, e.g. if the resulting files should be managed through a Plex server, then the user of the HDHomeRun DVR needs to be aligned with the user/user group of the Plex instance (or jellyfin, emby, kodi, etc.).

| Environment Variable | Description |
|  --------| ------- |
| PGID | User Group ID (numeric value, not name), if not specified it will default to 1000 |
| PUID | User ID (numeric value, not name), if not specificied it will default to 1000 |

The values to be used can be determined in a variety of ways (search for "Linux find PGID, PUID").

## Volumes
| Volume | Description |
| --------| ------- |
| dvrrec | Recordings and the engine logs will be stored here |
| dvrdata | Temporary data such as the engine itself, the config file, and a log output of the containers script |

## Port Mapping
As the dvr engine resides inside the docker container, two ports need to be mapped.

| Destination Port | Description |
| --------| ------- |
| 65001 | udp port that is fixed, i.e. the mapping **always** has to be 65001:65001, this port is used by the HDHomeRun tuners and other clients to discover the dvr engine |
| 59090 | this tcp port can be mapped to from any port, e.g. 23000:59090 as this is used for the dvr engine's interaction with tuners/clients |

**Comment on using Host Network instead**

If desired, the container can be run with the option to use the host's network stack and then no port mapping is required. Before using that option, please consider security implications to your environment.
```
--network host
```

## Docker Run Example
```
docker run -d --name dvr \
  --restart=unless-stopped \
  -p 65001:65001/udp \
  -p any_tcp_port:59090 \
  -e PGID = numeric_Group_ID \
  -e PUID = numeric_User_ID \
  -v /path/to/hdhomerun/tempdata:/dvrdata \
  -v /path/to/hdhomerun/recordings:/dvrrec \
  jackdock96/hdh_dvr:latest
  
  (original before fork: demonrik/hdhrdvr-docker)
```
