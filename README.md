Forked from: https://github.com/demonrik/HDHR-DVR-docker

# HDHR-DVR-docker
Docker Wrapper for SiliconDust's HDHomeRun DVR Record Engine

Image based on latest Alpine Linux https://alpinelinux.org/

Contains a script to download the latest engine when the engine is started.  
To update the engine stop the container and then start it again and it will get the latest.

Is important for HDHomeRun system to have everything on the same Network. While this is considered a possible security risk for some, the alternatives seem to be too cumbersome (but open to suggestions). For now, run the run the container with the host network selected, i.e.
```
--network host
```
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


## Docker Run
```
docker run -d --name dvr \
  --restart=unless-stopped \
  --network host \
  -e PGID = numeric_Group_ID \
  -e PUID = numeric_User_ID \
  -v /path/to/hdhomerun/tempdata:/dvrdata \
  -v /path/to/hdhomerun/recordings:/dvrrec \
  jackdock96/hdh_dvr:latest
  
  (original before fork: demonrik/hdhrdvr-docker)
```
