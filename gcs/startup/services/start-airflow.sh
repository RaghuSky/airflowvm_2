#!/bin/bash

##########
# Errors #
##########

# Exit upon any error
set -e

# Keep track of the last commmand
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG

# Echo an error message before exiting
trap 'echo "\"${last_command}\" command failed with return code $?."' EXIT

##########
# Inputs #
##########

[ -z "${LINUX_USER}" ] && LINUX_USER=root;
[ -z "${APP_HOME}" ] && APP_HOME=/${LINUX_USER}/;
[ -z "${AIRFLOW_HOME}" ] && AIRFLOW_HOME=${APP_HOME}airflow;
[ -z "${AIRFLOW_PORT}" ] && AIRFLOW_PORT=8080;
[ -z "${VENV_NAME}" ] && VENV_NAME=venv;

# Activate your virtual environment
source ${APP_HOME}${VENV_NAME}/bin/activate

# Look-up the version from the instance metadata and echo the Jupyter Notebook URL
getInstanceDefaultMetadata() {
  curl -fs http://metadata.google.internal/computeMetadata/v1/instance/$1 -H "Metadata-Flavor: Google"
}

# Cleanup Airflow pid files, in case it crashed last time and now needs to restart properly.
rm -f ${AIRFLOW_HOME}/*.pid

# Start the Airflow webserver and scheduler as background processes, and detach them from the terminal
# Note: it is important to run 2 separate processes as Airflow uses a SequentialExecutor with SQLite.
airflow webserver -p ${AIRFLOW_PORT} --error_logfile ${AIRFLOW_HOME}/logs/webserver-stderr.txt --daemon
airflow scheduler --stderr ${AIRFLOW_HOME}/logs/scheduler-stderr.txt --daemon

# Return Airflow's webserver URL
EXTERNAL_IP=`getInstanceDefaultMetadata network-interfaces/0/access-configs/0/external-ip`
printf "\nAirflow GUI available here: http://${EXTERNAL_IP}:${AIRFLOW_PORT}\n"
