#!/bin/bash
###############################################################################
#
# exciss_increment_cycle.sh
#
#
# Increment EXCISS cycle counter and reconfigure symlinks in EXCISS_HOME
#
# Usage: exciss_increment_cycle.sh
#
# Parameters:
#   <none>
#
# Default location: /opt/exciss/mission/bin/exciss_increment_cycle.sh
#
# Requires files/binaries:
#   $EXCISS_HOME/etc/exciss_env
#   $EXCISS_HOME/var/exciss_cycle_number.cf
#
# Requires gloval variables:
#   $EXCISS_HOME
#
# Returns:
#   {true|false}
#
# If not started as root user requires sudo permissions for:
#   chown, rm
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

LOG_DATE_FORMAT="%Y%m%d_%H%M%S" # date/time stamp format for log file
LOG_DIR="${EXCISS_HOME}/log"
LOG_FILE_NAME="$(date -u +${LOG_DATE_FORMAT})_${MY_BASE_NAME}.log" # log file
LOG_FILE="${LOG_DIR}/${LOG_FILE_NAME}" # File name and absolute path of log file
TIME_STAMP_FORMAT="%Y-%m-%d_%H:%M:%S" # Date/time stamp format for log entries

typeset -i EXCISS_CYCLE_COUNT_NOW=0 # current cycle number

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

if [[ -z "${LOG_DATE_FORMAT}" ]]; then
	export LOG_DATE_FORMAT="%Y%m%d_%H%M%S"
	echo "Exported LOG_DATE_FORMAT=${LOG_DATE_FORMAT}" >&2
fi

if [[ -z "${LOG_DIR}" ]]; then
	export LOG_DIR="${EXCISS_HOME}/log"
	echo "Exported LOG_DIR=${LOG_DIR}" >&2
fi

if [[ -z "${LOG_FILE_NAME}" ]]; then
	LOG_FILE_NAME="$(date -u" \
		"+${LOG_DATE_FORMAT})_$(basename ${EXCISS_LAUNCH} .sh).log"
	echo "Set (locally) LOG_FILE_NAME=${LOG_FILE_NAME}" >&2
fi

if [[ -z "${LOG_FILE}" ]]; then
	export LOG_FILE="${LOG_DIR}/${LOG_FILE_NAME}"
	echo "Exported LOG_FILE=${LOG_FILE}" >&2
fi

if [[ -z "${TIME_STAMP_FORMAT}" ]]; then
	export TIME_STAMP_FORMAT="%Y-%m-%d_%H:%M:%S"
	echo "Exported TIME_STAMP_FORMAT=${TIME_STAMP_FORMAT}" >&2
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

###############################################################################
#
# Start main script
#
###############################################################################

typeset -i CYCLE_INCREMENT=1 # add number of days to current cycle number

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
# Read EXCISS_CYCLE_COUNT from $EXCISS_HOME/var/exciss_cycle_number.cf
#

if [[ ! -d "${EXCISS_HOME}/var" ]]; then
	echo "ERROR - Directory ${EXCISS_HOME}/var does not exist" \
		>>${LOG_FILE}
	mkdir "${EXCISS_HOME}/var" >>${LOG_FILE} 2>&1
fi

chown "${EXCISS_UID}:${EXCISS_GID}" "${EXCISS_HOME}/var" >>${LOG_FILE} 2>&1

if [[ ! -r "${EXCISS_CYCLE_VAR_FILE}" ]]; then
	if [[ -r "${EXCISS_CYCLE_VAR_FILE}.OLD" ]]; then
		echo "ERROR - Cycle file unavailable, trying to use" \
			"${EXCISS_CYCLE_VAR_FILE}.OLD instead" >>${LOG_FILE}
		cp -p "${EXCISS_CYCLE_VAR_FILE}.OLD" "${EXCISS_CYCLE_VAR_FILE}" \
			>>${LOG_FILE} 2>&1
		CYCLE_INCREMENT=${CYCLE_INCREMENT}+1 # add 1 to offset read from cycle file
	fi
fi

sudo chown "${EXCISS_UID}:${EXCISS_GID}" "${EXCISS_CYCLE_VAR_FILE}" \
	>>${LOG_FILE} 2>&1

if [[ -r "${EXCISS_CYCLE_VAR_FILE}" ]]; then
	# Read last cycle number from cycle file
	EXCISS_CYCLE_COUNT_LAST="$(awk -F "=" -v VAR="${EXCISS_CYCLE_VAR_NAME}" \
		'$1 ~ "^[ \t]*"VAR"[ \t]*$" {gsub("^[ \t]*", "", $2); print \
		substr($2, 1, match($2, "[ \t]*#")-1)}' ${EXCISS_CYCLE_VAR_FILE})"

	EXCISS_CYCLE_COUNT_COMMENT="$(awk -F "#" -v \
		VAR="${EXCISS_CYCLE_VAR_NAME}" '$1 ~ "^[ \t]*"VAR"[ \t]*=" \
		{gsub("^([ \t]+)", "", $2); gsub("([ \t]+)", " ", $2); print $2}' \
		${EXCISS_CYCLE_VAR_FILE})"
else
	# Try to find cycle number from data and log directories
	echo "VOID - Trying to find cycle number from data and log directories"
	# else EXCISS_CYCLE_COUNT_NOW=0
fi

if [[ "${EXCISS_CYCLE_COUNT_LAST}" == "" ]]; then
	EXCISS_CYCLE_COUNT_LAST="0"
fi

EXCISS_CYCLE_COUNT_NOW=${EXCISS_CYCLE_COUNT_LAST}+${CYCLE_INCREMENT}
EXCISS_CYCLE_VAR_NEW="${EXCISS_CYCLE_VAR_NAME}=${EXCISS_CYCLE_COUNT_NOW}" \
EXCISS_CYCLE_VAR_NEW="${EXCISS_CYCLE_VAR_NEW} # ${EXCISS_CYCLE_COUNT_COMMENT}"

echo | tee -a ${LOG_FILE}
echo "Advancing from cycle ${EXCISS_CYCLE_COUNT_LAST} to" \
	"${EXCISS_CYCLE_COUNT_NOW}" | tee -a ${LOG_FILE}

#
# Update cycle file with new cycle number
#
awk -F "=" -v VAR="${EXCISS_CYCLE_VAR_NAME}" \
	-v NEW_LINE="${EXCISS_CYCLE_VAR_NEW}" \
	'$1 ~ "^[ \t]*"VAR"[ \t]*$" {$0=NEW_LINE} {print}' \
	"${EXCISS_CYCLE_VAR_FILE}" >"${EXCISS_CYCLE_VAR_FILE}.tmp"

if [[ -r "${EXCISS_CYCLE_VAR_FILE}.tmp" ]]; then
	cp "${EXCISS_CYCLE_VAR_FILE}" "${EXCISS_CYCLE_VAR_FILE}.OLD" \
		>>${LOG_FILE} 2>&1
	sudo chown "${EXCISS_UID}:${EXCISS_GID}" "${EXCISS_CYCLE_VAR_FILE}.OLD" \
		>>${LOG_FILE} 2>&1
	mv "${EXCISS_CYCLE_VAR_FILE}.tmp" "${EXCISS_CYCLE_VAR_FILE}" \
		>>${LOG_FILE} 2>&1
	sudo chown "${EXCISS_UID}:${EXCISS_GID}" "${EXCISS_CYCLE_VAR_FILE}" \
		>>${LOG_FILE} 2>&1
fi

#
# Advance /opt/exciss/mission/data
#
mkdir "${EXCISS_HOME}/data/${EXCISS_CYCLE_COUNT_NOW}"
chown "${EXCISS_UID}:${EXCISS_GID}" \
	"${EXCISS_HOME}/data/${EXCISS_CYCLE_COUNT_NOW}"
#sudo rm -rf "${EXCISS_HOME}/data/current"
#ln -sf "${EXCISS_HOME}/data/${EXCISS_CYCLE_COUNT_NOW}" \
#	"${EXCISS_HOME}/data/current"
#chown "${EXCISS_UID}:${EXCISS_GID}" \
#	"${EXCISS_HOME}/data/current"

#
# Advance /opt/exciss/mission/log/cycle
#
#mkdir "${EXCISS_HOME}/log/cycle/${EXCISS_CYCLE_COUNT_NOW}"
#chown "${EXCISS_UID}:${EXCISS_GID}" \
#	"${EXCISS_HOME}/log/cycle/${EXCISS_CYCLE_COUNT_NOW}"
#sudo rm -rf "${EXCISS_HOME}/log/cycle/current"
#ln -sf "${EXCISS_HOME}/log/cycle/${EXCISS_CYCLE_COUNT_NOW}" \
#	"${EXCISS_HOME}/log/cycle/current"
#chown "${EXCISS_UID}:${EXCISS_GID}" \
#	"${EXCISS_HOME}/log/cycle/current"

exit 0

###############################################################################
# EOF
###############################################################################

