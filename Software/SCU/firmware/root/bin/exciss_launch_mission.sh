#!/bin/bash
###############################################################################
#
# exciss_launch_mission.sh
#
#
# Launcher for the main EXCISS script exciss_mission_main.sh
#
# Usage: exciss_launch_mission.sh
#
# Parameters:
#   <none>
#
# Default location: /opt/exciss/mission/bin/exciss_launch_mission.sh
#
# Requires files/binaries:
#   $EXCISS_HOME/etc/exciss_env
#   $EXCISS_HOME/bin/exciss_mission_pre.sh
#   $EXCISS_HOME/bin/exciss_mission_main.sh
#   $EXCISS_HOME/bin/exciss_mission_post.sh
#   /usr/bin/openssl
#
# Requires gloval variables:
#   $EXCISS_HOME
#
# Returns:
#   {true|false}
#
# Recommended (optional) entries in /etc/fstab (UUIDs ):
#   UUID=207ab9d2-6021-4de8-b565-22a15edb4965 /opt/exciss/mission/USB_A ext4 rw,defaults,suid,dev,exec,relatime,noatime,owner,user,users,nofail,noauto,data=journal,nodelalloc 0 0
#   UUID=1bedf96f-5f16-4955-966a-f115b4589f39 /opt/exciss/mission/USB_B ext4 rw,defaults,suid,dev,exec,relatime,noatime,owner,user,users,nofail,noauto,data=journal,nodelalloc 0 0
#   UUID=A273-4441 /opt/exciss/mission/USB_X vfat rw,defaults,suid,dev,exec,relatime,noatime,owner,user,users,nofail,noauto,uid=1000,gid=1000,user=pi 0 0
# For UUID to device translation see: # ls -l /dev/disk/by-uuid | grep "sd"
#   207ab9d2-6021-4de8-b565-22a15edb4965 -> /dev/sda1 # USB_A (512GB)
#   1bedf96f-5f16-4955-966a-f115b4589f39 -> /dev/sdb1 # USB_B (512GB)
#   A273-4441                            -> /dev/sdc1 # USB_X (64GB)
#
# If not started as root user requires sudo permissions for:
#   mount, umount, chown
#
# Invoked by: /etc/rc.local (as root)
#
###############################################################################
# set -x
unalias -a

#
# Define and load global environment variables
#

MY_DIR_NAME="$(dirname $0)" # directory where this script is located
MY_FILE_NAME="$(basename $0)" # file name of this script (without path)
MY_BASE_NAME="$(basename ${MY_FILE_NAME} .sh)" # script name without ".sh"
MY_EXEC_USER="$(whoami)" # name of user who started this script
MY_VERSION_NUMBER="0.1" # revision number of this script file

FSTAB_FILE="/etc/fstab" # name and path of fstab
OPENSSL_CMD="/usr/bin/openssl" # name and path of openssl command

EXCISS_HOME_DEFAULT="/opt/exciss/mission" # default $EXCISS_HOME

EXCISS_CYCLE_VAR_FILE_NAME="exciss_cycle_number.cf" # tracking cycle numbers
EXCISS_CYCLE_VAR_FILE="${EXCISS_HOME}/var/${EXCISS_CYCLE_VAR_FILE_NAME}"
EXCISS_CYCLE_VAR_NAME="EXCISS_CYCLE_COUNT" # variable tracking cycle number

USB_A_DEV="" # device file of USB_A file system (eg. /dev/sda) {default: ""}
USB_A_STATUS="unknown" # file system USB_A {unknown|[not]mounted|[un]available}
USB_B_DEV="" # device file of USB_B file system (eg. /dev/sdb) {default: ""}
USB_B_STATUS="unknown" # file system USB_B {unknown|[not]mounted|[un]available}
USB_X_DEV="" # device file of USB_X file system (eg. /dev/sdc) {default: ""}
USB_X_STATUS="unknown" # file system USB_X {unknown|[not]mounted|[un]available}

LOG_DATE_FORMAT="%Y%m%d_%H%M%S" # date/time stamp format for log file
LOG_DIR="${EXCISS_HOME}/log"
LOG_FILE_NAME="$(date -u +${LOG_DATE_FORMAT})_${MY_BASE_NAME}.log" # log file
LOG_FILE="${LOG_DIR}/${LOG_FILE_NAME}" # File name and absolute path of log file
TIME_STAMP_FORMAT="%Y-%m-%d_%H:%M:%S" # Date/time stamp format for log entries

function Load_Environment_Vars {
###############################################################################
#
# Load_Environment_Vars
#
#
# Loads the global environment variables for this shell script
#
# Usage: Load_Environment_Vars
#
# Parameters:
#   <none>
#
# Requires files/binaries:
#   $EXCISS_HOME/etc/exciss_env
#
# Requires gloval variables:
#   <none>
#
# Returns:
#   {true|false}
#
# Loads environment variables from $EXCISS_HOME/etc/exciss_env
#
###############################################################################

ENV_FILE_NAME="exciss_env" # name of environment file (without path)
EXCISS_ENV_FILE="" # name and path of environment file (default: unknown)
EXCISS_ENV_LOADED="false" # EXCISS environment has not been loaded yet

if [[ -n "${EXCISS_HOME}" ]]; then
	# Look for /opt/exciss/mission/etc/exciss_env
	EXCISS_ENV_TEST="${EXCISS_HOME}/etc/${ENV_FILE_NAME}" # env file candidate
	if [[ -r "${EXCISS_ENV_TEST}" ]]; then
		EXCISS_ENV_FILE="${EXCISS_ENV_TEST}" # environment file found
	else
		echo "Warning - Environment file ${EXCISS_ENV_TEST} not found" >&2
	fi
else
	# EXCISS_HOME environment variable not set
	echo "Using default EXCISS_HOME=${EXCISS_HOME_DEFAULT}" >&2
	export EXCISS_HOME="${EXCISS_HOME_DEFAULT}"
fi

if [[ -z "${EXCISS_ENV_FILE}" ]]; then
	# Look for ../etc/exciss_env
	EXCISS_ENV_TEST="${MY_DIR_NAME}/../etc/${ENV_FILE_NAME}" # env candidate
	if [[ -r "${EXCISS_ENV_TEST}" ]]; then
		EXCISS_ENV_FILE="${EXCISS_ENV_TEST}"
	else
		echo "Warning - Environment file ${EXCISS_ENV_TEST} not found" >&2
	fi
fi

if [[ -z "${EXCISS_ENV_FILE}" ]]; then
	# Search for ./etc/exciss_env starting in /
	echo "Searching / for environment file ./etc/${ENV_FILE_NAME}" >&2
	EXCISS_ENV_TEST="$(find / -name ${ENV_FILE_NAME} 2>&- \
		| egrep "/etc/${ENV_FILE_NAME}$" | head -1)" # env file candidate
	if [[ -r "${EXCISS_ENV_TEST}" ]]; then
		EXCISS_ENV_FILE="${EXCISS_ENV_TEST}"
	else
		echo "Warning - Environment file etc/${ENV_FILE_NAME} not found" \
			"anywhere in /" >&2
	fi
fi

echo
if [[ -n "${EXCISS_ENV_FILE}" ]]; then
	echo "Using environment file ${EXCISS_ENV_FILE}"
	. "${EXCISS_ENV_FILE}" # source in environment file
	if ${EXCISS_ENV_LOADED}; then
		echo "Successfully loaded EXCISS environment"
	else
		echo "ERROR - Failed to load EXCISS environment" >&2
	fi
else
	echo "ERROR - Failed to find environment file ${ENV_FILE_NAME}" >&2
fi

#
# Set default environment variables if exciss_env failed to load
#

if [[ -z "${EXCISS_UID}" ]]; then
	export EXCISS_UID="pi"
	echo "Exported EXCISS_UID=${EXCISS_UID}" >&2
fi

if [[ -z "${EXCISS_GID}" ]]; then
	export EXCISS_GID="pi"
	echo "Exported EXCISS_GID=${EXCISS_GID}" >&2
fi

if [[ -z "${USB_A_PATH}" ]]; then
	export USB_A_PATH="${EXCISS_HOME}/USB_A"
	echo "Exported USB_A_PATH=${USB_A_PATH}" >&2
fi

if [[ -z "${USB_A_SIZE}" ]]; then
	export USB_A_SIZE="512"
	echo "Exported USB_A_SIZE=${USB_A_SIZE}" >&2
fi

if [[ -z "${USB_A_FILESYSTEM}" ]]; then
	export USB_A_FILESYSTEM="ext4"
	echo "Exported USB_A_FILESYSTEM=${USB_A_FILESYSTEM}" >&2
fi

if [[ -z "${USB_B_PATH}" ]]; then
	export USB_B_PATH="${EXCISS_HOME}/USB_B"
	echo "Exported USB_B_PATH=${USB_B_PATH}" >&2
fi

if [[ -z "${USB_B_SIZE}" ]]; then
	export USB_B_SIZE="512"
	echo "Exported USB_B_SIZE=${USB_B_SIZE}" >&2
fi

if [[ -z "${USB_B_FILESYSTEM}" ]]; then
	export USB_B_FILESYSTEM="ext4"
	echo "Exported USB_B_FILESYSTEM=${USB_B_FILESYSTEM}" >&2
fi

if [[ -z "${USB_X_PATH}" ]]; then
	export USB_X_PATH="${EXCISS_HOME}/USB_X"
	echo "Exported USB_X_PATH=${USB_X_PATH}" >&2
fi

if [[ -z "${USB_X_SIZE}" ]]; then
	export USB_X_SIZE="32"
	echo "Exported USB_X_SIZE=${USB_X_SIZE}" >&2
fi

if [[ -z "${USB_X_FILESYSTEM}" ]]; then
	export USB_X_FILESYSTEM="vfat"
	echo "Exported USB_X_FILESYSTEM=${USB_X_FILESYSTEM}" >&2
fi

if ${EXCISS_ENV_LOADED}; then
	return $(true)
else
	return $(false)
fi

}
###############################################################################

function Initialize_Log_File {
###############################################################################
#
# Initialize_Log_File
#
#
# Initialize new log file in $EXCISS_HOME/log/
#
# Usage: Initialize_Log_File
#
# Parameters:
#   <none>
#
# Requires files/binaries:
#   <none>
#
# Requires gloval variables:
#   $LOG_DIR
#   $LOG_FILE
#   $EXCISS_UID
#   $EXCISS_GID
#   $TIME_STAMP_FORMAT
#   $MY_FILE_NAME
#   $EXCISS_ENV_FILE
#   $EXCISS_HOME
#   $MY_EXEC_USER
#
# Returns:
#   {true|false}
#
# Creates a new log file in $EXCISS_HOME/log/
#
###############################################################################

# Create log directory and current log file with permissions for user "pi"
if [ ! -d "${LOG_DIR}" ]; then
        mkdir "${LOG_DIR}" # create log dir if it doesn't exist yet
fi

# If log file already exists, keep 1 version
if [[ -f "${LOG_FILE}" ]]; then
	cp "${LOG_FILE}" "${LOG_FILE}.OLD"
fi

chown "${EXCISS_UID}:${EXCISS_GID}" "${LOG_DIR}" # chown pi:pi $LOG_DIR
touch "${LOG_FILE}" # create empty $LOG_FILE
chown "${EXCISS_UID}:${EXCISS_GID}" "${LOG_FILE}" # chown pi:pi $LOG_FILE

echo "--------------------------------------------------" >>${LOG_FILE}
echo "$(date +${TIME_STAMP_FORMAT}) ${MY_FILE_NAME} Starting" >>${LOG_FILE}
echo "--------------------------------------------------" >>${LOG_FILE}
echo "Command line: $0 $*" >>${LOG_FILE}
echo "Environment file: ${EXCISS_ENV_FILE}" >>${LOG_FILE}
echo "ENV: EXCISS_HOME=${EXCISS_HOME}" >>${LOG_FILE}
echo "Current directory: $(pwd)" >>${LOG_FILE}
echo "Executing user: ${MY_EXEC_USER}" >>${LOG_FILE}
echo "--------------------------------------------------" >>${LOG_FILE}

if [[ -f "${LOG_FILE}" ]]; then
	return $(true)
else
	return $(false)
fi

}
###############################################################################

function Mount_USB_Stick {
###############################################################################
#
# Mount_USB_Stick
#
#
# Mounts a USB stick file system
#
# Usage: Mount_USB_Stick USB_stick
#
# Parameters:
#   $1 (USB_Stick) = {"USB_A"|"USB_B"|"USB_X"}
#
# Requires files/binaries:
#   <none>
#
# Requires gloval variables:
#   {$USB_A_PATH|$USB_B_PATH|$USB_X_PATH}
#   {$USB_A_UUID|$USB_B_UUID|$USB_X_UUID}
#   {$USB_A_SIZE|$USB_B_SIZE|$USB_X_SIZE}
#   {$USB_A_FILESYSTEM|$USB_B_FILESYSTEM|$USB_X_FILESYSTEM}
#   {$USB_A_DEV|$USB_B_DEV|$USB_X_DEV}
#   {$USB_A_STATUS|$USB_B_STATUS|$USB_X_STATUS}
#
# Returns:
#   {true|false}
#
# Mounts the USB stick passed as parameter $1 as $EXCISS_HOME/USB_?
# Error recovery assumes partition 1 on USB stick as default file system
#
###############################################################################

USB_STICK="$1" # {"USB_A"|"USB_B"|"USB_X"}

case "${USB_STICK}" in
	"USB_A")
		USB_STICK_PATH="${USB_A_PATH}"
		USB_STICK_UUID="${USB_A_UUID}"
		USB_STICK_SIZE="${USB_A_SIZE}"
		USB_STICK_FILESYSTEM="${USB_A_FILESYSTEM}"
		;;
	"USB_B")
		USB_STICK_PATH="${USB_B_PATH}"
		USB_STICK_UUID="${USB_B_UUID}"
		USB_STICK_SIZE="${USB_B_SIZE}"
		USB_STICK_FILESYSTEM="${USB_B_FILESYSTEM}"
		;;
	"USB_X")
		USB_STICK_PATH="${USB_X_PATH}"
		USB_STICK_UUID="${USB_X_UUID}"
		USB_STICK_SIZE="${USB_X_SIZE}"
		USB_STICK_FILESYSTEM="${USB_X_FILESYSTEM}"
		;;
	*)
		echo "ERROR: Function $0 requires a parameter" >>${LOG_FILE}
		echo "	Usage: Mount_USB_Stick" \
			"{\"USB_A\"|\"USB_B\"|\"USB_X\"}" >>${LOG_FILE}
		exit 1
		;;
esac

echo | tee -a ${LOG_FILE} >&2
echo "Verifying ${USB_STICK} file system" >>${LOG_FILE}

echo >>${LOG_FILE}
USB_STICK_DEV=""
if [[ -n "${USB_STICK_UUID}" ]]; then
	# Find USB stick by UUID from exciss_env
	if [[ -e "/dev/disk/by-uuid/${USB_STICK_UUID}" ]]; then
		USB_STICK_DEV="/dev/$(basename $(ls -l \
			/dev/disk/by-uuid/${USB_STICK_UUID} | awk '{print $NF}' \
			2>>${LOG_FILE}) 2>>${LOG_FILE})" >>${LOG_FILE} 2>&1
	fi
fi
if [[ -n "${USB_STICK_DEV}" && -b "${USB_STICK_DEV}" ]]; then
	echo "${USB_STICK}: ${USB_STICK_DEV} assigned to ${USB_STICK_UUID}" \
		| tee -a ${LOG_FILE} >&2
else
	echo "ERROR - ${USB_STICK} device UUID=${USB_STICK_UUID} not found" | \
		tee -a ${LOG_FILE} >&2
	# Try to identify USB stick by size (partition=1)
	echo "Searching for storage device with matching size" >>${LOG_FILE}
	# Only partition 1 of USB stick is evaluated by awk (...print $2"1 ...)
	USB_STICK_DEV=$(sudo fdisk -l 2>/dev/null | awk -v \
		USB_SIZE=${USB_STICK_SIZE} '$1 == "Disk" && $2 !~ /mmcblk/ && \
		$4 ~ /^GiB[,]+$/ && $3>(USB_SIZE*0.85) && $3<(USB_SIZE*1.15) \
		{gsub(":$", "", $2); \
		print $2"1 ("USB_SIZE*0.85"GB<"$3"GB<"USB_SIZE*1.15"GB)"}' | sort | \
		while read USB_DEV_TEST USB_SIZE_TEST REST; do
			DEV_IN_USE=0
			for DEV_MOUNTED in $(mount | awk '{print $1}'); do
				if [[ ${USB_DEV_TEST} == ${DEV_MOUNTED} ]]; then
					DEV_IN_USE=1
				fi
			done
			if [[ ${DEV_IN_USE} -eq 0 && -z ${DEV_AVAILABLE} ]]; then
				echo "Available ${USB_DEV_TEST} ${USB_SIZE_TEST}" >>${LOG_FILE}
				echo "${USB_DEV_TEST}"
				break
			fi
		done | head -1)

	if [[ -n "${USB_STICK_DEV}" ]]; then
		echo "${USB_STICK}: ${USB_STICK_DEV} assumed by size" \
			"(${USB_STICK_SIZE}GB)" | tee -a ${LOG_FILE}
	else
		echo "ERROR - ${USB_STICK} not found by size (${USB_STICK_SIZE}GB)" | \
			tee -a ${LOG_FILE} >&2
		# Try to find first matching entry in /etc/fstab
		echo "Searching for storage device in ${FSTAB_FILE}" >>${LOG_FILE}
		USB_STICK_DEV="$(awk -v DIR="${USB_STICK_PATH}" '$2==DIR {print $1}' \
			${FSTAB_FILE} | head -1)" >>${LOG_FILE} 2>&1
		if [[ -n "${USB_STICK_DEV}" && -e "${USB_STICK_DEV}" ]]; then
			echo "${USB_STICK}: ${USB_STICK_DEV} found in ${FSTAB_FILE}" | \
				tee -a ${LOG_FILE}
		else
			echo "ERROR - ${USB_STICK} not found in ${FSTAB_FILE}" | \
				tee -a ${LOG_FILE} >&2
		fi
	fi
fi

if [[ $(df 2>/dev/null | awk -v DIR="${USB_STICK_PATH}" \
	'$NF==DIR {print $NF}' | head -1) == "${USB_STICK_PATH}" ]]; then
	sudo chown "${EXCISS_UID}:${EXCISS_GID}" ${USB_STICK_PATH} \
		>>${LOG_FILE} 2>&1
	echo "${USB_STICK} is already mounted on ${USB_STICK_PATH}" >>${LOG_FILE}
	USB_STICK_STATUS="mounted"
else
	echo "${USB_STICK} currently not mounted on ${USB_STICK_PATH}" \
		>>${LOG_FILE}
	if [[ "${USB_STICK_FILESYSTEM}" == "vfat" ]]; then
		sudo mount -t ${USB_STICK_FILESYSTEM} \
			-o "rw,defaults,suid,dev,exec,relatime,noatime,owner,user,users" \
			-o "nofail,noauto" \
			-o "uid=$(id -u ${EXCISS_UID}),gid=$(id	-g ${EXCISS_GID})" \
			${USB_STICK_DEV} ${USB_STICK_PATH} \
			>>${LOG_FILE} 2>&1
	elif [[ "${USB_STICK_FILESYSTEM}" == "ext4" ]]; then
		sudo mount -t ${USB_STICK_FILESYSTEM} \
			-o "rw,defaults,suid,dev,exec,relatime,noatime,owner,user,users" \
			-o "nofail,noauto,data=journal,nodelalloc" \
			${USB_STICK_DEV} ${USB_STICK_PATH} \
			>>${LOG_FILE} 2>&1
	else
		sudo mount -t ${USB_STICK_FILESYSTEM} -o \
			"rw,defaults,noatime" ${USB_STICK_DEV} ${USB_STICK_PATH} \
			>>${LOG_FILE} 2>&1
	fi
	if [[ $(df 2>/dev/null | awk -v DIR="${USB_STICK_PATH}" \
		'$NF==DIR {print $NF}' | head -1) == "${USB_STICK_PATH}" ]]; then
		sudo chown "${EXCISS_UID}:${EXCISS_GID}" ${USB_STICK_PATH} \
			>>${LOG_FILE} 2>&1
		echo "${USB_STICK} was mounted on ${USB_STICK_PATH}" >>${LOG_FILE}
		USB_STICK_STATUS="mounted"
	else
		echo "ERROR - Failed to mount ${USB_STICK} on ${USB_STICK_PATH}" \
			>>${LOG_FILE} >&2
		USB_STICK_STATUS="notmounted"
	fi
fi

if [[ "${USB_STICK_STATUS}" == "mounted" ]]; then
	if [[ -w "${USB_STICK_PATH}" ]]; then
		TEST_FILE_NAME=".$(date +${LOG_DATE_FORMAT}).dirtest.tmp"
		echo "Testing write access with ${USB_STICK_PATH}/${TEST_FILE_NAME}" \
			>>${LOG_FILE}
		echo "Test file from ${MY_FILE_NAME}" > \
			"${USB_STICK_PATH}/${TEST_FILE_NAME}" 2>>${LOG_FILE}
		cat "${USB_STICK_PATH}/${TEST_FILE_NAME}" >/dev/null 2>>${LOG_FILE}
		CMD_RETURN="$?"
		rm -f "${USB_STICK_PATH}/${TEST_FILE_NAME}" >>${LOG_FILE} 2>&1
		if [[ "${CMD_RETURN}" -eq 0 ]]; then
			echo "${USB_STICK} is available on ${USB_STICK_PATH}" | \
				tee -a ${LOG_FILE}
			USB_STICK_STATUS="available"
		else
			echo "ERROR - ${USB_STICK} failed write test on" \
				"${USB_STICK_PATH}" | tee -a ${LOG_FILE} 2>&1
			USB_STICK_STATUS="unavailable"
		fi
	else
		echo "ERROR - ${USB_STICK} not writable on ${USB_STICK_PATH}" | \
			tee -a ${LOG_FILE} 2>&1
		USB_STICK_STATUS="unavailable"
	fi
else
	echo "ERROR - ${USB_STICK} unavailable on ${USB_STICK_PATH}" | \
		tee -a ${LOG_FILE} >&2
	USB_STICK_STATUS="unavailable"
fi

case "${USB_STICK}" in
	"USB_A")
		USB_A_DEV="${USB_STICK_DEV}"
		USB_A_STATUS="${USB_STICK_STATUS}"
		;;
	"USB_B")
		USB_B_DEV="${USB_STICK_DEV}"
		USB_B_STATUS="${USB_STICK_STATUS}"
		;;
	"USB_X")
		USB_X_DEV="${USB_STICK_DEV}"
		USB_X_STATUS="${USB_STICK_STATUS}"
		;;
esac

if [[ "${USB_STICK_STATUS}" == "available" ]]; then
	return $(true)
else
	return $(false)
fi

}
###############################################################################

function Apply_TGZ_Updates {
###############################################################################
#
# Apply_TGZ_Updates
#
#
# Install updates from $EXCISS_HOME/USB_X/TO_ISS directory
#
# Usage: Apply_TGZ_Updates
#
# Parameters:
#   <none>
#
# Requires files/binaries:
#   <none>
#
# Requires gloval variables:
#   $LOG_FILE
#   $OPENSSL_CMD
#
# Returns:
#   {true|false}
#
# Installs new TGZ updates found in $EXCISS_HOME/etc/exciss_env
#
###############################################################################

UPDATE_SUCCESS="false" # status of update process to return

echo | tee -a ${LOG_FILE}
echo "Checking for updates in \$USB_X/TO_ISS" | tee -a ${LOG_FILE}

if [[ ! -d "${EXCISS_HOME}/update" ]]; then
	mkdir "${EXCISS_HOME}/update" >>${LOG_FILE} 2>&1
	sudo chown "${EXCISS_UID}:${EXCISS_GID}" "${EXCISS_HOME}/update" \
		>>${LOG_FILE} 2>&1
	mkdir "${EXCISS_HOME}/update/done" >>${LOG_FILE} 2>&1
	sudo chown "${EXCISS_UID}:${EXCISS_GID}" "${EXCISS_HOME}/update/done" \
		>>${LOG_FILE} 2>&1
fi

echo >>${LOG_FILE}
echo "Files in ${USB_X_PATH}/TO_ISS" >>${LOG_FILE}
echo >>${LOG_FILE}
ls -l "${USB_X_PATH}/TO_ISS" >>${LOG_FILE}

if [[ -d "${USB_X_PATH}/TO_ISS" ]]; then
	UPDATE_COUNT="$(ls ${USB_X_PATH}/TO_ISS/*.tgz 2>/dev/null | wc -l)"
else
	UPDATE_COUNT=0
fi

if [[ "${UPDATE_COUNT}" -gt 0 ]]; then
	echo >>${LOG_FILE}
	echo "Found ${UPDATE_COUNT} (tgz) update(s) in ${USB_X_PATH}/TO_ISS" | \
		tee -a ${LOG_FILE}
	ls "${USB_X_PATH}/TO_ISS/"*.tgz | while read TGZ_FILE; do
		echo | tee -a ${LOG_FILE}
		MD5_FILE="${USB_X_PATH}/TO_ISS/$(basename ${TGZ_FILE} .tgz \
			2>>${LOG_FILE}).md5"
		echo "Update $(basename ${TGZ_FILE}) + $(basename ${MD5_FILE})" \
			"found" | tee -a ${LOG_FILE}
		# Verify MD5 hash before moving the file pair
		MD5_HASH_EXPECTED="$(cat ${MD5_FILE} 2>>${LOG_FILE} | \
			awk '{print $NF}')"
		MD5_HASH_REAL="$(${OPENSSL_CMD} dgst -md5 ${TGZ_FILE} \
			2>>${LOG_FILE} | awk '{print $NF}')"
		if [[ "${MD5_HASH_EXPECTED}" == "${MD5_HASH_REAL}" ]]; then
			# Hash verified, move file pair to $EXCISS_HOME/update
			UPDATE_TGZ_FILE="${EXCISS_HOME}/update/$(basename ${TGZ_FILE})"
			mv "${TGZ_FILE}" "${UPDATE_TGZ_FILE}" 2>>${LOG_FILE}
			if [[ -f "${UPDATE_TGZ_FILE}" ]]; then
				echo "Moved ${TGZ_FILE} to ${UPDATE_TGZ_FILE}" >>${LOG_FILE}
			else
				echo "ERROR - Failed to move update file ${TGZ_FILE}" \
					"to ${EXCISS_HOME}/update" | tee -a ${LOG_FILE} >&2
			fi
			UPDATE_MD5_FILE="${EXCISS_HOME}/update/$(basename ${MD5_FILE})"
			mv "${MD5_FILE}" "${UPDATE_MD5_FILE}" 2>>${LOG_FILE}
			if [[ -f "${UPDATE_MD5_FILE}" ]]; then
				echo "Moved ${MD5_FILE} to ${UPDATE_MD5_FILE}" >>${LOG_FILE}
			else
				echo "ERROR - Failed to move update file ${MD5_FILE}" \
					"to ${EXCISS_HOME}/update" | tee -a ${LOG_FILE} >&2
			fi
			# Unpack and install TGZ update
			if gzip -t "${UPDATE_TGZ_FILE}"; then
				echo >>${LOG_FILE}
				echo "Contents of ${UPDATE_TGZ_FILE}" >>${LOG_FILE}
				gzip -tv "${UPDATE_TGZ_FILE}" >>${LOG_FILE} 2>&1

				echo >>${LOG_FILE}
				echo "Files contained in ${UPDATE_TGZ_FILE}" >>${LOG_FILE}
				gzip -d < "${UPDATE_TGZ_FILE}" | tar tvPf - >>${LOG_FILE} 2>&1

				echo >>${LOG_FILE}
				echo "Installing ${UPDATE_TGZ_FILE}" >>${LOG_FILE}
				gzip -d < "${UPDATE_TGZ_FILE}" | tar xvPf - >>${LOG_FILE} 2>&1
				CMD_RETURN="$?"

				echo >>${LOG_FILE}
				if [[ "${CMD_RETURN}" -eq 0 ]]; then
					echo "Successfully installed ${UPDATE_TGZ_FILE}" | \
						tee -a ${LOG_FILE}
					mv "${UPDATE_TGZ_FILE}" "${UPDATE_TGZ_FILE}.APPLIED" \
						>>${LOG_FILE} 2>&1
					mv "${UPDATE_TGZ_FILE}.APPLIED" \
						"${EXCISS_HOME}/update/done/." >>${LOG_FILE} 2>&1
				else
					echo "ERROR - Failed to install ${UPDATE_TGZ_FILE}" | \
						tee -a ${LOG_FILE} >&2
					mv "${UPDATE_TGZ_FILE}" "${UPDATE_TGZ_FILE}.FAILED" \
						>>${LOG_FILE} 2>&1
					mv "${UPDATE_TGZ_FILE}.FAILED" \
						"${EXCISS_HOME}/update/done/." >>${LOG_FILE} 2>&1
				fi
				mv "${UPDATE_MD5_FILE}" "${EXCISS_HOME}/update/done/." \
					>>${LOG_FILE} 2>&1
			else
				echo "ERROR - TGZ archive ${UPDATE_TGZ_FILE} can not be" \
					"opened" | tee -a ${LOG_FILE} >&2
				mv "${UPDATE_TGZ_FILE}" "${UPDATE_TGZ_FILE}.ERROR" \
					>>${LOG_FILE} 2>&1
				mv "${UPDATE_TGZ_FILE}.ERROR" \
					"${EXCISS_HOME}/update/done/." >>${LOG_FILE} 2>&1
				mv "${UPDATE_MD5_FILE}" "${EXCISS_HOME}/update/done/." \
					>>${LOG_FILE} 2>&1
			fi
		else
			# Reject update as MD5 hash failed to verify
			echo "ERROR - MD5 hashes of TGZ and MD5 file do not match" | \
				tee -a ${LOG_FILE} >&2
			echo "TGZ: ${MD5_HASH_REAL} MD5: ${MD5_HASH_EXPECTED}"
			mv "${TGZ_FILE}" "${TGZ_FILE}.REJECTED" 2>>${LOG_FILE}
			if [[ ! -f "${TGZ_FILE}.REJECTED" ]]; then
				echo "ERROR - Failed to reject update file ${TGZ_FILE}" | \
					tee -a ${LOG_FILE} >&2
			fi
			mv "${MD5_FILE}" "${MD5_FILE}.REJECTED" 2>>${LOG_FILE}
			if [[ ! -f "${MD5_FILE}.REJECTED" ]]; then
				echo "ERROR - Failed to reject hash file ${MD5_FILE}" | \
					tee -a ${LOG_FILE} >&2
			fi
		fi
	done
fi

#
# Execute $USB_X_PATH/TO_ISS/update_commands.sh if present
#
if [[ -r "${USB_X_PATH}/TO_ISS/update_commands.sh" ]]; then
	echo | tee -a ${LOG_FILE}
	echo "Executing update_commands.sh script" | tee -a ${LOG_FILE}
	UPDATE_DATE="$(date -u +${LOG_DATE_FORMAT})"
	NEW_UPDATE_COMMANDS="${EXCISS_HOME}/update/${UPDATE_DATE}_update_commands.sh"
	mv "${USB_X_PATH}/TO_ISS/update_commands.sh" \
		"${NEW_UPDATE_COMMANDS}" >>${LOG_FILE} 2>&1
	sudo chown "${EXCISS_UID}:${EXCISS_GID}" \
		"${NEW_UPDATE_COMMANDS}" >>${LOG_FILE} 2>&1
	sudo chmod 0774 "${NEW_UPDATE_COMMANDS}" >>${LOG_FILE} 2>&1

	sudo "${NEW_UPDATE_COMMANDS}" >>${LOG_FILE} 2>&1
	CMD_RETURN="$?"

	if [[ "${CMD_RETURN}" -eq 0 ]]; then
		echo "Successfully executed update_commands.sh" | \
			tee -a ${LOG_FILE}
	else
		echo "ERROR - Failed to execute update_commands.sh" | \
			tee -a ${LOG_FILE} >&2
	fi

	mv "${NEW_UPDATE_COMMANDS}" \
		"${EXCISS_HOME}/update/done/${UPDATE_DATE}_update_commands.sh.APPLIED" \
		>>${LOG_FILE} 2>&1
	sudo chmod 0664 \
		"${EXCISS_HOME}/update/done/${UPDATE_DATE}_update_commands.sh.APPLIED" \
		>>${LOG_FILE} 2>&1

	if [[ -r "${EXCISS_HOME}/update/done/${UPDATE_DATE}_update_commands.sh.APPLIED" \
		]]; then
		echo "Archived" \
			"${EXCISS_HOME}/update/done/${UPDATE_DATE}_update_commands.sh.APPLIED" \
			>>${LOG_FILE}
	else
		echo "ERROR - Failed to acrchive" \
			"${EXCISS_HOME}/update/done/${UPDATE_DATE}_update_commands.sh.APPLIED" \
			>>${LOG_FILE} >&2
	fi
fi

return $(true)

}
###############################################################################

###############################################################################
#
# Start main script
#
###############################################################################

echo "${MY_FILE_NAME} starting in $(pwd)" >&2

#
# Load environment variables from $EXCISS_HOME/etc/exciss_env
#

Load_Environment_Vars

#
# Initialize log file in $EXCISS_HOME/log/
#

Initialize_Log_File

#
# Mount USB sticks to $EXCISS_HOME/USB_?/
#

echo | tee -a ${LOG_FILE}
echo "Verifying USB storage devices" | tee -a ${LOG_FILE}

echo >>${LOG_FILE}
echo "Available disk devices" >>${LOG_FILE}
echo >>${LOG_FILE}
ls -l /dev/disk/by-uuid/* >>${LOG_FILE} 2>&1

echo >>${LOG_FILE}
echo "Available file systems" >>${LOG_FILE}
echo >>${LOG_FILE}
df -h >>${LOG_FILE} 2>&1

Mount_USB_Stick "USB_A"

Mount_USB_Stick "USB_B"

Mount_USB_Stick "USB_X"

echo >>${LOG_FILE}
echo "Available EXCISS file systems" >>${LOG_FILE}
echo >>${LOG_FILE}
df -h | egrep "^Filesystem|${EXCISS_HOME}" >>${LOG_FILE} 2>&1

#
# Apply_TGZ_Updates from $EXCISS_HOME/USB_X/TO_ISS
#

Apply_TGZ_Updates

#
# Initiate this cycle
#

# Read last cycle number from cycle file
EXCISS_CYCLE_COUNT_LAST="$(awk -F "=" -v VAR="${EXCISS_CYCLE_VAR_NAME}" \
	'$1 ~ "^[ \t]*"VAR"[ \t]*$" {gsub("^[ \t]*", "", $2); print \
	substr($2, 1, match($2, "[ \t]*#")-1)}' ${EXCISS_CYCLE_VAR_FILE})"

echo | tee -a ${LOG_FILE}
echo "Initiating experiment cycle ${EXCISS_CYCLE_COUNT_LAST}" | \
	tee -a ${LOG_FILE}

cd "${EXCISS_HOME}/data/${EXCISS_CYCLE_COUNT_LAST}" >>${LOG_FILE} 2>&1

#
# Call exciss_mission scripts (pre,main,post)
#

#
# PRE
#
if [[ -r "${EXCISS_HOME}/bin/exciss_mission_pre.sh" ]]; then
	echo | tee -a ${LOG_FILE}
	echo "Executing PRE mission script exciss_mission_pre.sh" | tee -a ${LOG_FILE}
	MISSION_LOG="${EXCISS_CYCLE_COUNT_LAST}_$(date -u +${LOG_DATE_FORMAT})_exciss_mission_pre.log"
	sudo chown "${EXCISS_UID}:${EXCISS_GID}" \
		"${EXCISS_HOME}/bin/exciss_mission_pre.sh" >>${LOG_FILE} 2>&1
	sudo chmod 0774 "${EXCISS_HOME}/bin/exciss_mission_pre.sh" \
		>>${LOG_FILE} 2>&1
	sudo su pi -c "${EXCISS_HOME}/bin/exciss_mission_pre.sh" >>${MISSION_LOG} 2>&1
fi

#
# MAIN
#
echo | tee -a ${LOG_FILE}
echo "Executing MAIN mission script exciss_mission_main.sh" | tee -a ${LOG_FILE}
sudo chown "${EXCISS_UID}:${EXCISS_GID}" \
	"${EXCISS_HOME}/bin/exciss_mission_main.sh" >>${LOG_FILE} 2>&1
sudo chmod 0774 "${EXCISS_HOME}/bin/exciss_mission_main.sh" \
	>>${LOG_FILE} 2>&1
MISSION_LOG="${EXCISS_CYCLE_COUNT_LAST}_$(date -u +${LOG_DATE_FORMAT})_exciss_mission_main.log"
sudo su pi -c "${EXCISS_HOME}/bin/exciss_mission_main.sh" >>${MISSION_LOG} 2>&1

#
# POST
#
if [[ -r "${EXCISS_HOME}/bin/exciss_mission_post.sh" ]]; then
	echo | tee -a ${LOG_FILE}
	echo "Executing POST mission script exciss_mission_post.sh" | tee -a ${LOG_FILE}
	MISSION_LOG="${EXCISS_CYCLE_COUNT_LAST}_$(date -u +${LOG_DATE_FORMAT})_exciss_mission_post.log"
	sudo chown "${EXCISS_UID}:${EXCISS_GID}" \
		"${EXCISS_HOME}/bin/exciss_mission_post.sh" >>${LOG_FILE} 2>&1
	sudo chmod 0774 "${EXCISS_HOME}/bin/exciss_mission_post.sh" \
		>>${LOG_FILE} 2>&1
	sudo su pi -c "${EXCISS_HOME}/bin/exciss_mission_post.sh" >>${MISSION_LOG} 2>&1
fi

cd "${EXCISS_HOME}" >>${LOG_FILE} 2>&1

#
# Copy data collected during this cylce
#

echo "Copying data collected to USB storage"

if [[ "${USB_A_STATUS}" == "available" ]]; then
	cp -pr "${EXCISS_HOME}/data/${EXCISS_CYCLE_COUNT_LAST}" \
		"${USB_A_PATH}/data/" >>${LOG_FILE} 2>&1
else
	echo "Warning - Skipped ${USB_A_PATH} as USB_A is unavailable" | \
		tee -a ${LOG_FILE} >&2
fi

if [[ "${USB_B_STATUS}" == "available" ]]; then
	cp -pr "${EXCISS_HOME}/data/${EXCISS_CYCLE_COUNT_LAST}" \
		"${USB_B_PATH}/data/" >>${LOG_FILE} 2>&1
else
	echo "Warning - Skipped ${USB_B_PATH} as USB_B is unavailable" | \
		tee -a ${LOG_FILE} >&2
fi

if [[ "${USB_X_STATUS}" == "available" ]]; then
	cp -pr "${EXCISS_HOME}/data/${EXCISS_CYCLE_COUNT_LAST}" \
		"${USB_X_PATH}/FROM_ISS/data/" >>${LOG_FILE} 2>&1
else
	echo "Warning - Skipped ${USB_X_PATH} as USB_X is unavailable" | \
		tee -a ${LOG_FILE} >&2
fi

#
# Remove cycle data after at least one successful copy
#
echo >>${LOG_FILE}
rm -r "${EXCISS_HOME}/data/${EXCISS_CYCLE_COUNT_LAST}"

#
# Copy log files to USB sticks
#
echo "Copying log files to USB sticks" | tee -a ${LOG_FILE} >&2
sync; sync >>${LOG_FILE} 2>&1


#
# Unmount USB sticks
#
echo "Unmounting USB file systems" | tee -a ${LOG_FILE} >&2
sync; sync >>${LOG_FILE} 2>&1
umount ${USB_A_PATH} >>${LOG_FILE} 2>&1
umount ${USB_B_PATH} >>${LOG_FILE} 2>&1
umount ${USB_X_PATH} >>${LOG_FILE} 2>&1

###############################################################################
##### OPEN ISSUES #####
###############################################################################
#
# exciss_launch_mission.sh: Clear data (Copy old data before new experiment)
# exciss_launch_mission.sh: Deliver data => USB_A / USB_B / USB_X
#
# $EXCISS_HOME/bin/exciss_increment_cycle.sh => $EXCISS_HOME/var/exciss_cycle_number.cf
#

# Copy incoming files from folder $USB_X/TO_ISS to local directories

# echo "$(date -u +${LOG_DATE_FORMAT}) ${MY_FILE_NAME} Preparing for" \
#         "EXCISS launch" | tee -a "${LOG_FILE}" >/dev/console

#if [ -f ${LOG} ]; then
#  rm ${LOG} >/dev/null 2>&1
#fi
#${EXCISS_HOME}/bin/mission_boot.sh >${LOG} 2>&1 &


exit 0

###############################################################################
# EOF
###############################################################################

