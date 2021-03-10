#!/bin/sh
############################################################################################################
# hdhomerun.sh
# Shell Script to prepare the container data and execute the record engine
# Version 2.5
# engine is run inside docker container, only exposing configuration and recording directory
# freely after https://github.com/demonrik/HDHR-DVR-docker
# TODO: more elegant engine replacement (only when newer than installed)

# Parameters - make sure these match the DockerFile
HDHR_HOME=/HDHomeRunDVR
HDHR_USER=hdhr
HDHR_GRP=hdhr
DVRData=/dvrdata
DVRRec=/dvrrec
DefaultPort=59090
BetaEngine=0
# configuration file used during engine startup
DVRConf=dvr.conf
# dvr engine name
DVRBin=hdhomerun_record
# Log file name and location
HDHR_LOG=${DVRData}/HDHomeRunDVR.log
# force regeneration of configuration file (0 no, 1 yes)
force_config=0
# Download URLs from Silicondust - Shouldn't change much
# Check https://info.hdhomerun.com/info/dvr:linux
DownloadURL=https://download.silicondust.com/hdhomerun/hdhomerun_record_linux
BetaURL=https://download.silicondust.com/hdhomerun/hdhomerun_record_linux_beta

##############################################################################################################
# (Re)create hdhr user to run the DVR as,if they aren't passed into container default to 1000:1000
#
#
create_hdhr_user()
{
        CURR_USER="$(id -u)"
        echo "$(date -u)" "Current User ID is $CURR_USER" >> ${HDHR_LOG}
        if [ "$CURR_USER" = "0" ] ; then
                echo "$(date -u)" "Checking whether PGID and PUID have been set" >> ${HDHR_LOG}
				if [ -z "${PGID}" ] ; then
						echo "$(date -u)" "Group ID (PGID) was not set, defaulting to 1000" >> ${HDHR_LOG}
						PGID=1000
                else
						echo "$(date -u)" "PGID was set to ${PGID}" >> $(HDHR_LOG)
                fi
                if [ -z "${PUID}" ] ; then
						echo "$(date -u)" "User ID (PUID) was not set, defaulting to 1000" >> ${HDHR_LOG}
						PUID=1000
                else
						echo "$(date -u)" "PUID was set to ${PUID}" >> $(HDHR_LOG)                                        
                fi                                                                                                         
                                                                                                                           
                echo "$(date -u)" "Checking whether PGID $PGID exists" >> ${HDHR_LOG}                                     
                if ! grep -qF ":$PGID:" /etc/group ; then                                                                  
                        echo "$(date -u)" "Does not exist creating Group $HDHR_GRP with ID $PGID" >> ${HDHR_LOG}          
                        GO_CREATE="t"                                                                                      


                else                                                                                                       
                        echo "$(date -u)" "Group ${PGID} exists... using existing group" >> ${HDHR_LOG}
                        GO_CREATE="f"
                        HDHR_GRP=$(grep -F ":$PGID:" /etc/group | cut -d: -f1)
                fi
                echo "$(date -u)" "Checking whether PUID $PUID exists" >> ${HDHR_LOG}
                if ! grep -qF ":$PUID:" /etc/passwd ; then
                        echo "$(date -u)" "PUID ${PUID} doesn't exist... creating User $HDHR_USER with ID $PUID in Group $HDHR_GRP" >> ${HDHR_LOG}
                        GO_CREATE="${GO_CREATE}t"

                else
                        echo "$(date -u)" "Exists... Using existing User" >> ${HDHR_LOG}
                        GO_CREATE="${GO_CREATE}f"
                        HDHR_USER=$(grep -F ":$PUID:" /etc/passwd | cut -d: -f1)
                fi

                case "${GO_CREATE}" in
                        "tt") # user create, group create
                                deluser ${HDHR_USER} # ensure that Username doesn't exist
								# deluser seems to remove group in this case, too, so no delgroup necessary                
                                addgroup -g $PGID $HDHR_GRP                                                                
                                adduser -HDG "$HDHR_GRP" -u $PUID $HDHR_USER
                                ;;
                        "tf" | "ft") # user create, group remains
                                deluser ${HDHR_USER}
                                adduser -HDG "$HDHR_GRP" -u $PUID $HDHR_USER
                                ;;
                        "ff") # no user creation required
                                echo "$(date -u)" "User Validation/creation complete" >> ${HDHR_LOG}
                                ;;
                        "*") # all else
                                echo "$(date -u)" "unknown error happened during user validation/creation" >> ${HDHR_LOG}
                                ;;
                esac
        else
                echo "$(date -u)" "Running as non-root user $(id -nu)! Assuming use of  -user option on docker, skipping setup of user..." >> ${HDHR_LOG}
        fi
}

############################################################################################################
# Read configuration file (if exists)
# Ingest any Parameters relevant to this script (can't use declare or regex as not part of busybox bash)
# if [ "$line" =~ "^([^=]+)=(.*)$" ]
# 
read_config_file()
{                                                                                                 
        echo "$(date -u)" "** Read config file (if it exists) for special parameters" >> ${HDHR_LOG}

        if [ -e ${DVRData}/${DVRConf} ] ; then
	        while read -r line; do                                                      
			if [ $(contains "${line}" "BetaEngine") -eq 0 ] ; then
				# read 1 character right of equal sign
				BetaEngine="${line#*=}"
				echo "$(date -u)" "Assigned BetaEngine Parameter value:" $BetaEngine  >> ${HDHR_LOG}
			elif [ $(contains "${line}" "RecordPath") -eq 0 ] ; then               
				# read string right of equal sign             
				RecordPath="${line#*=}"                                                                  
				echo "$(date -u)" "Assigned RecordPath Parameter value:" $RecordPath  >> ${HDHR_LOG}
			elif [ $(contains "${line}" "Port") -eq 0 ] ; then          
				# read characters right of equal sign                                  
				Port="${line#*=}"                                                     
				echo "$(date -u)" "Assigned Port Parameter value:" $Port  >> ${HDHR_LOG}
			else 
				echo "$(date -u)" "${line}"  >> ${HDHR_LOG}
			fi	                                                                                    
	        done < "${DVRData}/${DVRConf}"
		echo "$(date -u)" "configuration file exists parameters read and assigned"  >> ${HDHR_LOG}
       else                     
		echo "$(date -u)" "configuration file doesn't exist"  >> ${HDHR_LOG}
		force_config=1
       fi
}


############################################################################################################
# Helper function for /bin/sh limited regex capabilities
contains()
{  
	if	[ "$1" ] &&            # Is there a source string.
		[ "$2" ] &&            # Is there a substring.
		[ -z "${1##*"$2"*}" ];  then # Test substring in source.
		echo 0;                # Print a "0" for a match.
	else
		echo 1;                # Print a "1" if no match.
	fi;
}

############################################################################################################
# Creates the initial config file for the engine in /HDHomeRunDVR/data
# Sets Following defaults
#   RecordPath = /dvrrec		    # Should always be this
#   Port = 59090                            # must match the Dockerfile
#   RecordStreamsMax=16                     # Enable max recordings
#   BetaEngine=0                            # Used by this script (default 0)
#
create_initial_config()
{
	echo "$(date -u)" "** Creating Initial Config File" >> ${HDHR_LOG}
	touch  ${DVRData}/${DVRConf}
	echo "RecordPath=${DVRRec}" >> ${DVRData}/${DVRConf}
	echo "Port=${DefaultPort}" >> ${DVRData}/${DVRConf}
	echo "RecordStreamsMax=16" >>  ${DVRData}/${DVRConf}
	echo "BetaEngine=${BetaEngine}" >>  ${DVRData}/${DVRConf}
	echo "$(date -u)" "** Finished creating Initial Config File" >> ${HDHR_LOG}
}

############################################################################################################
# Verifies the config file dvr.conf exists in /HDHomeRunDVR/data and ensure
# is writable so Engine can update the StorageID
# If the file doesnt exist, create one.
#
validate_config_file()
{
	# Read and assign configuration parameters relevant to validating configuration
	read_config_file
	echo "$(date -u)" "** Validating the Config File is available and set up correctly" >> ${HDHR_LOG}
	if [ -e ${DVRData}/${DVRConf} ] ; then
		echo "$(date -u)" "Config File exists and is writable - is record path and port correct"  >> ${HDHR_LOG}
		.  ${DVRData}/${DVRConf}
		if [ "${DVRRec}" = "${RecordPath}" ] ; then
			echo "$(date -u)" "Recording Path correct" >> ${HDHR_LOG}
		else
			echo "$(date -u)" "Recording Path in configuration file ${RecordPath} not matching with default path ${DVRRec}" >> ${HDHR_LOG}
			force_config=1
		fi
		if [ "${DefaultPort}" = "${Port}" ] ; then
			echo "$(date -u)" "Port Assignment correct" >> ${HDHR_LOG}
		else
			echo "$(date -u)" "Port in configuration file ${Port} not matching with default port ${DefaultPort}" >> ${HDHR_LOG}
			force_config=1
		fi
	else
		# config file is missing
		echo "$(date -u)" "Config is missing - creating initial version" >> ${HDHR_LOG}
			force_config=1
	fi
	# any misalignments or missing file, the configuration file is recreated
	if [ "${force_config}" -eq "1" ] ; then
		echo "$(date -u)" "Creating initial version next ..." >> ${HDHR_LOG}
		create_initial_config
		force_config=0
	fi
}

############################################################################################################
# Get latest Record Engine(s) from SiliconDust, delete any previous
# Get Beta (if enabled in conf) and released engine and compare dates
# Select the newest amnd make it the default
#
update_engine()
{
	echo "$(date -u)" "** Installing the HDHomeRunDVR Record Engine"  >> ${HDHR_LOG}
	if [ -f "${HDHR_HOME}/${DVRBin}" ] ; then
		echo "$(date -u)" "removing any existing engine - always going to use the latest ... " >> ${HDHR_LOG}
		echo "$(date -u)" "checking current engine file owner" >> ${HDHR_LOG}
		BinOwner="$(stat -c %U ${HDHR_HOME}/${DVRBin})"
		CurrentUser="$(id -un)"
		echo "$(date -u)" "file owner:""$BinOwner" "/ USER:""$CurrentUser" >> ${HDHR_LOG}
		if [ "${BinOwner}" = "${CurrentUser}" ] ; then
			echo "$(date -u)" "Current owner same as user:" "$BinOwner" ". Trying to remove current engine ..." >> ${HDHR_LOG}
			if rm -f  ${HDHR_HOME}/${DVRBin}; then
				echo "$(date -u)" "engine deletion successful" >> ${HDHR_LOG}
			else
				echo "$(date -u)" "attempt to force owner to current user one more time" >> ${HDHR_LOG}
				chown "$CurrentUser" "${HDHR_HOME}/${DVRBin}"
				if rm -f  ${HDHR_HOME}/${DVRBin}; then
					echo "$(date -u)" "engine deletion successful" >> ${HDHR_LOG}
				else
					echo "$(date -u)" "something went wrong during engine removal, exiting engine_update, might need to delete manually" >> ${HDHR_LOG}
					exit
				fi
			fi
		else
			echo "$(date -u)" "attempting to change engine file owner for deletion" >> ${HDHR_LOG}
			chown "$CurrentUser" "${HDHR_HOME}/${DVRBin}"
			if rm -f  ${HDHR_HOME}/${DVRBin};then
				echo "$(date -u)" "deletion successful" >> ${HDHR_LOG}
			else
				echo "$(date -u)" "engine cannot be removed. Current owner:" "${BinOwner}" "current User:""${CurrentUser}" "exiting engine_update" >> ${HDHR_LOG}
				exit
			fi
		fi
	fi
		
	echo "$(date -u)" "Downloading latest release" >> ${HDHR_LOG}
	wget -qO ${HDHR_HOME}/${DVRBin}_rel ${DownloadURL}
	if [ "$BetaEngine" -eq "1" ]; then
		echo "$(date -u)" "Downloading latest beta" >> ${HDHR_LOG}
		wget -qO ${HDHR_HOME}/${DVRBin}_beta ${BetaURL}
		echo "$(date -u)" "Comparing which is newest" >>  ${HDHR_LOG}
		if [ ${HDHR_HOME}/${DVRBin}_rel -nt  ${DVRData}/${DVRBin}_beta ] ; then
			echo "$(date -u)" "Release version is newer - selecting as record engine" >> ${HDHR_LOG}
			mv ${HDHR_HOME}/${DVRBin}_rel ${DVRData}/${DVRBin}
			rm ${HDHR_HOME}/${DVRBin}_beta
			chmod u+x ${DVRData}/${DVRBin}
		elif [ ${HDHR_HOME}/${DVRBin}_rel -ot  ${HDHR_HOME}/${DVRBin}_beta ]; then
			echo "$(date -u)" "Beta version is newer - selecting as record engine" >> ${HDHR_LOG}
			mv ${HDHR_HOME}/${DVRBin}_beta ${HDHR_HOME}/${DVRBin}
			rm ${HDHR_HOME}/${DVRBin}_rel
			chmod u+x ${HDHR_HOME}/${DVRBin}
		else
			echo "$(date -u)" "Both versions are same - using the Release version" >> ${HDHR_LOG}
			mv ${HDHR_HOME}/${DVRBin}_rel ${HDHR_HOME}/${DVRBin}
			rm ${HDHR_HOME}/${DVRBin}_beta
			chmod u+x ${HDHR_HOME}/${DVRBin}
		fi
	else
			mv ${HDHR_HOME}/${DVRBin}_rel ${HDHR_HOME}/${DVRBin}
			chmod u+x ${HDHR_HOME}/${DVRBin}
	fi

	EngineVer=$(sh ${HDHR_HOME}/${DVRBin}  version | awk 'NR==1{print $4}')
	echo "$(date -u)" "Engine Updated to... " "${EngineVer}" >>  ${HDHR_LOG}
}

############################################################################################################
# Start the engine in foreground, redirect stderr and stdout to the logfile
#
start_engine()
{
	echo "$(date -u)" "** Starting the HDHomrun DVR Engine as user $HDHR_USER" >> ${HDHR_LOG}
	su ${HDHR_USER} -c "${HDHR_HOME}/${DVRBin} foreground --conf ${DVRData}/${DVRConf}" >> ${HDHR_LOG} 2>&1
}

############################################################################################################
# Stop the engine if running.
#
stop_engine()
{
	echo "$(date -u)" "** Attempting to stop HDHomrun DVR Engine" >> ${HDHR_LOG}
	if ps | grep -F -m 1 "${DVRBin}" | grep -v grep ; then
		echo "$(date -u)" "engine is running - return code: "$? >> ${HDHR_LOG}
		./${HDHR_HOME}/${DVRBin} stop
		echo "$(date -u)" "engine stopped" >> ${HDHR_LOG}
	else
		echo "$(date -u)" "engine not running - return code: "$? >> ${HDHR_LOG}
	fi
}
###########################################################################################################               
# Adjust File/directory properties to hdhr user/group
#
#
adjust_ownership()                                                                                                         
{
        # adjust directories
        chown ${HDHR_USER}:${HDHR_GRP} ${DVRData}
        chown ${HDHR_USER}:${HDHR_GRP} ${DVRRec}
        chown ${HDHR_USER}:${HDHR_GRP} ${HDHR_HOME}
        # adjust files                                                                       
        chown ${HDHR_USER}:${HDHR_GRP} ${HDHR_HOME}/${DVRBin}
        chown ${HDHR_USER}:${HDHR_GRP} ${HDHR_LOG}
}
############################################################################################################
# Main loop
#
#
stop_engine
create_hdhr_user
validate_config_file
update_engine
adjust_ownership
start_engine
