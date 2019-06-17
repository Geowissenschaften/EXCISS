#!/bin/bash
###############################################################################
#
# EXCISS_HOME/bin/exciss_boot.sh
#
###############################################################################

MY_FILE_NAME="$(basename $0)" # Name of this script without path
EXCISS_HOME="/opt/exciss/mission" # Home directory of EXCISS environment
EXCISS_INC_CYCLE_SCRIPT="${EXCISS_HOME}/bin/exciss_increment_cycle.sh"
EXCISS_LAUNCH_MISSION_SCRIPT="${EXCISS_HOME}/bin/exciss_launch_mission.sh"
GPIO_SHUTDOWN_PI_SCRIPT="${EXCISS_HOME}/bin/pi_shutdown_gpio.py"

LOG_FILE_NAME="$(basename ${MY_FILE_NAME} .sh).log"
LOG_FILE="${EXCISS_HOME}/log/${LOG_FILE_NAME}"

export EXCISS_HOME

echo "${MY_FILE_NAME}: Running ${GPIO_SHUTDOWN_PI_SCRIPT}" | \
	tee -a ${LOG_FILE}
sudo "${GPIO_SHUTDOWN_PI_SCRIPT} &" | tee -a ${LOG_FILE} 2>&1

echo "${MY_FILE_NAME}: Running ${EXCISS_INC_CYCLE_SCRIPT}" | \
	tee -a ${LOG_FILE}
sudo "${EXCISS_INC_CYCLE_SCRIPT}" | tee -a ${LOG_FILE} 2>&1

echo "${MY_FILE_NAME}: Running ${EXCISS_LAUNCH_MISSION_SCRIPT}" | \
	tee -a ${LOG_FILE}
sudo "${EXCISS_LAUNCH_MISSION_SCRIPT}" | tee -a ${LOG_FILE} 2>&1

exit 0

###############################################################################
# EOF
###############################################################################

