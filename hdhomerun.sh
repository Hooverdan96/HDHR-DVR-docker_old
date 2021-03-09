#!/bin/sh
############################################################################################################
# hdhomerun.sh
# Shell Script to prepare the container data and execute the record engine
# Version 1.3
# freely after https://github.com/demonrik/HDHR-DVR-docker

# Parameters - make sure these match the DockerFile
HDHR_HOME=/HDHomeRunDVR
HDHR_USER=hdhr
HDHR_GRP=hdhr
DVRData=${HDHR_HOME}/data
DVRRec=${HDHR_HOME}/recordings
DefaultPort=59090

# Download URLs from Silicondust - Shouldn't change much
# Check https://info.hdhomerun.com/info/dvr:linux
DownloadURL=https://download.silicondust.com/hdhomerun/hdhomerun_record_linux
BetaURL=https://download.silicondust.com/hdhomerun/hdhomerun_record_linux_beta


# Some additional params you can change
DVRConf=dvr.conf
DVRBin=hdhomerun_record
HDHR_LOG=${DVRData}/HDHomeRunDVR.log

##############################################################################################################
# Create hdhr user to run the DVR as,if they aren't passed into container default to 1000:1000
#
create_hdhr_user()
{
	CURR_USER="$(id -u)"
	echo "Current User is $CURR_USER" >> ${HDHR_LOG}
	if [ "$CURR_USER" = "0" ] ; then
		echo "Creating HDHR User" >> ${HDHR_LOG}
		if [ -z "${PGID}" ] ; then
			echo "User ID (PGID) was not set, defaulting to 1000" >> ${HDHR_LOG}
			PGID=1000
		fi
		if [ -z "${PUID}" ] ; then
			echo "User ID (PGID) was not set, defaulting to 1000" >> ${HDHR_LOG}
			PUID=1000
		fi

		echo "Checking whether $PGID exists" >> ${HDHR_LOG}
		if ! grep -qF ":$PGID:" /etc/group ; then
			echo "Does not exist creating Group $HDHR_GRP with ID $PGID" >> ${HDHR_LOG}
			delgroup $HDHR_GRP
			addgroup -g $PGID $HDHR_GRP
		else
			echo "Yep... Using existing group" >> ${HDHR_LOG}
			HDHR_GRP=$(grep -F ":$PGID:" /etc/group | cut -d: -f1)
		fi

		echo "Checking $PUID exists" >> ${HDHR_LOG}
		if ! grep -qF ":$PUID:" /etc/passwd ; then
			echo "Nope... creating User $HDHR_USER with ID $PUID in Group $HDHR_GRP " >> ${HDHR_LOG}
			deluser $HDHR_USER
			adduser -HDG "$HDHR_GRP" -u $PUID $HDHR_USER
		else
			echo "Yep... Using existing User" >> ${HDHR_LOG}
			HDHR_USER=$(grep -F ":$PUID:" /etc/passwd | cut -d: -f1)
		fi
	else
		echo "Running as non root user $CURR_USER ! Assume using -user on docker, skipping setup of user..." >> ${HDHR_LOG}
	fi
}


############################################################################################################
# Creates the initial config file for the engine in /HDHomeRunDVR/data
# Sets Following defaults
#   RecordPath =  /HDHomeRunDVR/recordings  # Should always be this
#   Port = 59090                            # must match the Dockerfile
#   RecordStreamsMax=16                     # Enable max recordings
#   BetaEngine=1                            # Used by this script
#
create_initial_config()
{
	echo "** Creating Initial Config File" >> ${HDHR_LOG}
	touch  ${DVRData}/${DVRConf}
	echo "RecordPath=${DVRRec}" >> ${DVRData}/${DVRConf}
	echo "Port=${DefaultPort}" >> ${DVRData}/${DVRConf}
	echo "RecordStreamsMax=16" >>  ${DVRData}/${DVRConf}
	echo "BetaEngine=1" >>  ${DVRData}/${DVRConf}
}

############################################################################################################
# Verifies the config file dvr.conf exists in /HDHomeRunDVR/data and ensure
# is writable so Engine can update the StorageID
# If the file doesnt exist, create one.
#
validate_config_file()
{
	echo "** Validating the Config File is available and set up correctly" >> ${HDHR_LOG}
	if [ -e ${DVRData}/${DVRConf} ] ; then
		echo "Config File exists and is writable - is record path and port correct"  >> ${HDHR_LOG}
		.  ${DVRData}/${DVRConf}
		# TODO: Validate RecordPath
		# TODO: Validate Port
	else
		# config file is missing
		echo "Config is missing - creating initial version" >> ${HDHR_LOG}
		create_initial_config
	fi
}

############################################################################################################
# Get latest Record Engine(s) from SiliconDust, delete any previous
# Get Beta (if enabled in conf) and released engine and compare dates
# Select the newest amnd make it the default
#
update_engine()
{
	echo "** Installing the HDHomeRunDVR Record Engine"  >> ${HDHR_LOG}
	if [ -f "${DVRData}/${DVRBin}" ] ; then
		echo "removing any existing engine - always going to use the latest ... " >> ${HDHR_LOG}
		echo "checking current engine file owner" >> ${HDHR_LOG}
		BinOwner="$(stat -c %U ${DVRData}/${DVRBin})"
		CurrentUser="$(id -un)"
		echo "file owner:""$BinOwner" "/ USER:""$CurrentUser" >> ${HDHR_LOG}
		if [ "${BinOwner}" = "${CurrentUser}" ] ; then
			echo "Current owner same as user:" "$BinOwner" ". Trying to remove current engine ..." >> ${HDHR_LOG}
			if rm -f  ${DVRData}/${DVRBin}; then
				echo "engine deletion successful" >> ${HDHR_LOG}
			else
				echo "attempt to force owner to current user one more time" >> ${HDHR_LOG}
				chown "$CurrentUser" "${DVRData}/${DVRBin}"
				if rm -f  ${DVRData}/${DVRBin}; then
					echo "engine deletion successful" >> ${HDHR_LOG}
				else
					echo "something went wrong during engine removal, exiting engine_update, might need to delete manually" >> ${HDHR_LOG}
					exit
				fi
			fi
		else
			echo "attempting to change engine file owner for deletion" >> ${HDHR_LOG}
			chown "$CurrentUser" "${DVRData}/${DVRBin}"
			if rm -f  ${DVRData}/${DVRBin};then
				echo "deletion successful" >> ${HDHR_LOG}
			else
				echo "engine cannot be removed. Current owner:" "${BinOwner}" "current User:""${CurrentUser}" "exiting engine_update" >> ${HDHR_LOG}
				exit
			fi
		fi
	fi
		
		# TODO: check Beta download is enabled on config file, and only download if enabled
	echo "Downloading latest release" >> ${HDHR_LOG}
	wget -qO ${DVRData}/${DVRBin}_rel ${DownloadURL}
	if [ "$BetaEngine" -eq "1" ]; then
		echo "Downloading latest beta" >> ${HDHR_LOG}
		wget -qO ${DVRData}/${DVRBin}_beta ${BetaURL}
		echo "Comparing which is newest" >>  ${HDHR_LOG}
		if [ ${DVRData}/${DVRBin}_rel -nt  ${DVRData}/${DVRBin}_beta ] ; then
			echo "Release version is newer - selecting as record engine" >> ${HDHR_LOG}
			mv ${DVRData}/${DVRBin}_rel ${DVRData}/${DVRBin}
			rm ${DVRData}/${DVRBin}_beta
			chmod u+x ${DVRData}/${DVRBin}
		elif [ ${DVRData}/${DVRBin}_rel -ot  ${DVRData}/${DVRBin}_beta ]; then
			echo "Beta version is newer - selecting as record engine" >> ${HDHR_LOG}
			mv ${DVRData}/${DVRBin}_beta ${DVRData}/${DVRBin}
			rm ${DVRData}/${DVRBin}_rel
			chmod u+x ${DVRData}/${DVRBin}
		else
			echo "Both versions are same - using the Release version" >> ${HDHR_LOG}
			mv ${DVRData}/${DVRBin}_rel ${DVRData}/${DVRBin}
			rm ${DVRData}/${DVRBin}_beta
			chmod u+x ${DVRData}/${DVRBin}
		fi
	fi

	EngineVer=$(sh ${DVRData}/${DVRBin}  version | awk 'NR==1{print $4}')
	echo "Engine Updated to... " "${EngineVer}" >>  ${HDHR_LOG}
}

############################################################################################################
# Start the engine in foreground, redirect stderr and stdout to the logfile
#
start_engine()
{
	echo "** Starting the DVR Engine as user $HDHR_USER" >> ${HDHR_LOG}
#	su ${HDHR_USER} -c"$(${DVRData}/${DVRBin} foreground --conf ${DVRData}/${DVRConf} >> ${HDHR_LOG} 2>&1)"
	${DVRData}/${DVRBin} foreground --conf ${DVRData}/${DVRConf} >> ${HDHR_LOG} 2>&1
}

############################################################################################################
# Main loop
#
validate_config_file
update_engine
create_hdhr_user
start_engine
