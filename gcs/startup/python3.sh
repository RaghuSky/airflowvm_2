Skip to content
Search or jump to…

Pull requests
Issues
Marketplace
Explore
 
@RaghuSky 
Learn Git and GitHub without any code!
Using the Hello World guide, you’ll start a branch, write comments, and open a pull request.


sky-uk
/
decisioning-gcp-marts
Private
0
0
0
Code
Issues
Pull requests
Projects
Wiki
Security
Insights
decisioning-gcp-marts/gcs/startup/python3.sh
@cmacartney
cmacartney correction to git account reference
Latest commit b33bbfa 25 days ago
 History
 1 contributor
248 lines (188 sloc)  7.33 KB
  
#!/bin/bash
# On a GCP Debian VM, startup-script-url logs are written to: /var/log/daemon.log

START_TIME=`date +%s`

##########
# Errors #
##########

# Exit upon any error
set -e

# Keep track of the last commmand
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG

# Echo an error message before exiting
trap 'echo "\"${last_command}\" command failed with return code $?."' EXIT

#############
# Functions #
#############

getProjectMetadata() {
  curl -fs http://metadata.google.internal/computeMetadata/v1/project/$1 -H "Metadata-Flavor: Google"
}

getInstanceMetadata() {
  curl -fs http://metadata.google.internal/computeMetadata/v1/instance/$1 -H "Metadata-Flavor: Google"
}

##########
# Inputs #
##########

export ENVIRONMENT=`getInstanceMetadata attributes/environment`
export SECRETS_BUCKET=`getInstanceMetadata attributes/secrets-bucket`
export STARTUP_BUCKET=`getInstanceMetadata attributes/startup-bucket`

# Git credentials
export GIT_USERNAME=$(gsutil cat gs://${SECRETS_BUCKET}/git.txt)
export GIT_TOKEN=""

if [[ ${GIT_USERNAME} == "" ]]; then
    printf "[ERROR] - Failed to get Github credentials\n"
    exit 17
fi

# Linux user name and password
# Start-up script runs as root
export LINUX_USER=root
export APP_HOME=/${LINUX_USER}/

# Airflow config
export AIRFLOW_HOME=${APP_HOME}airflow
export AIRFLOW_PORT=8080

# Postgresql config
export DB_USER=airflow
export DB_PASSWORD=airflow
export DB_NAME=airflow

# Application code home
export CODE_HOME=${APP_HOME}repo/

# Python virtual environment
export VENV_NAME=venv

##################
# Linux packages #
##################

# jq: JSON parser at the command line
printf "\nInstalling Linux packages\n"
apt-get update
# apt-get install python3.6
apt-get install -y \
    git \
    jq \
    python3-pip \
    python3-venv \
    less \
    dos2unix \
    curl
# apt-get install python3.6
# apt-get upgrade python3.6

###########
# Airflow #
###########

# Creating a virtual environment for Airflow
printf "\nCreating and activating a Python 3 virtual environment\n"
cd ${APP_HOME}
python3 -m venv ${VENV_NAME}
source ${APP_HOME}${VENV_NAME}/bin/activate

# Set this to avoid the GPL version; no functionality difference either way
printf "\nPreparing environment for Airflow\n"
export SLUGIFY_USES_TEXT_UNIDECODE=yes

printf "\nInstalling Airflow\n"
pip3 install wheel
pip3 install apache-airflow

printf "\nInstall requests package (for custom Airflow operators)\n"
pip3 install requests

# Reverting to an earlier version of this package to prevent a SyntaxError
pip3 uninstall -y marshmallow-sqlalchemy
pip3 install marshmallow-sqlalchemy==0.17.1
# pip3 install marshmallow-sqlalchemy==0.22.3
# pip3 install -U marshmallow-sqlalchemy

pip3 uninstall -y WTForms
pip3 install WTForms==2.2.1

printf "Initializing Airflow SQLite database\n"
airflow initdb

printf "\nAdjusting Airflow's settings (note: up to 100 BigQuery concurrent queries)\n"
sed -i'.orig' 's|dag_dir_list_interval = 300|dag_dir_list_interval = 1|g' ${AIRFLOW_HOME}/airflow.cfg
sed -i'.orig' 's|job_heartbeat_sec = 5|job_heartbeat_sec = 5|g' ${AIRFLOW_HOME}/airflow.cfg
sed -i'.orig' 's|scheduler_heartbeat_sec = 5|scheduler_heartbeat_sec = 5|g' ${AIRFLOW_HOME}/airflow.cfg
sed -i'.orig' 's|parallelism = 32|parallelism = 100|g' ${AIRFLOW_HOME}/airflow.cfg
sed -i'.orig' 's|dag_concurrency = 16|dag_concurrency = 100|g' ${AIRFLOW_HOME}/airflow.cfg
sed -i'.orig' 's|max_active_runs_per_dag = 16|max_active_runs_per_dag = 52|g' ${AIRFLOW_HOME}/airflow.cfg
sed -i'.orig' 's|dag_default_view = tree|dag_default_view = graph|g' ${AIRFLOW_HOME}/airflow.cfg
sed -i'.orig' 's|load_examples = True|load_examples = False|g' ${AIRFLOW_HOME}/airflow.cfg
sed -i'.orig' 's|dag_run_conf_overrides_params = False|dag_run_conf_overrides_params = True|g' ${AIRFLOW_HOME}/airflow.cfg

############
# Codebase #
############

GIT_REPO=`getInstanceMetadata attributes/repo`
GIT_TAG=`getInstanceMetadata attributes/tag` || true
GIT_BRANCH=`getInstanceMetadata attributes/branch` || true

if [ ! -d "${CODE_HOME}" ]; then

    printf "\nCloning the ${GIT_REPO} repo\n"
    git clone https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/sky-uk/${GIT_REPO}.git ${CODE_HOME}
    #git clone https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/cmacartney/${GIT_REPO}.git ${CODE_HOME} #CMedit

fi

# Checkout a tag or branch (in that order), if available
if [[ -n "${GIT_TAG}" ]]; then
  GIT_ID=${GIT_TAG}
else
  if [[ -n "${GIT_BRANCH}" ]]; then
    GIT_ID=${GIT_BRANCH}
  fi
fi

if [[ -n "${GIT_ID}" ]]; then
  cd ${CODE_HOME}
  git fetch
  git checkout ${GIT_ID}
  printf "\ngit checkout ${GIT_ID}\n"
  cd ${APP_HOME}
fi


# Point to the DAGs folder
sed -i'.orig' "s|dags_folder = ${AIRFLOW_HOME}/dags|dags_folder = ${CODE_HOME}dags|g" ${AIRFLOW_HOME}/airflow.cfg

##############
# Postgresql #
##############

printf "\nInstalling Postgres packages\n"
apt-get install -y postgresql-9.6 postgresql-client postgresql-contrib libpq-dev

printf "\nPostgres cluster status:\n"
pg_lsclusters

printf "\nStarting Postgres cluster:\n"
pg_ctlcluster 9.6 main start
netstat -nlp

# Check whether the Airflow database exists
db_exists=$(sudo -u postgres psql -lqt | awk '{print $1}' | grep ${DB_NAME} | wc -l)

if [ $db_exists -eq 0 ]; then

    printf "\nCreating Postgres Airflow database and user\n"
    sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME}"
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH ENCRYPTED PASSWORD '${DB_PASSWORD}'"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER}"

    printf "\nCustomising Postgres config\n"
    sudo -u postgres sed -i'.orig' "s|#listen_addresses = 'localhost'|listen_addresses = '127.0.0.1'|g" /etc/postgresql/9.6/main/postgresql.conf
    sudo -u postgres sed -i'.orig' "s|host    all             all             127.0.0.1/32            md5|host    all             all             127.0.0.1/32            trust|g" /etc/postgresql/9.6/main/pg_hba.conf
    service postgresql restart

else
    printf "\nSkipping Postgres Airflow database setup\n"
fi

printf "\nInstalling Python packages\n"
pip3 install psycopg2
pip3 install 'apache-airflow[postgres]'
pip3 install 'apache-airflow[google_auth]'
pip3 install 'apache-airflow[gcp_api]'

# Airflow config #
printf "\nUpdating Airflow's configuration for Postgres\n"
SQL_ALCHEMY_CONN_AIRFLOW=postgresql+psycopg2://${DB_USER}:${DB_PASSWORD}@127.0.0.1:5432/${DB_NAME}
sed -i'.orig' "s|sql_alchemy_conn = sqlite:////root/airflow/airflow.db|sql_alchemy_conn = $SQL_ALCHEMY_CONN_AIRFLOW|g" ${AIRFLOW_HOME}/airflow.cfg
sed -i'.orig' 's|executor = SequentialExecutor|executor = LocalExecutor|g' ${AIRFLOW_HOME}/airflow.cfg

printf "\nRefreshing Airflow to pick up new config\n"
airflow resetdb --yes

############
# Services #
############

mkdir -p ${APP_HOME}services

gsutil cp gs://${STARTUP_BUCKET}/services/* ${APP_HOME}services/
dos2unix ${APP_HOME}services/*.sh
chmod +x ${APP_HOME}services/*.sh

###########
# Airflow #
###########

# Start Airflow
source ${APP_HOME}services/start-airflow.sh

# Airflow variables: generic variables
GCP_PROJECT_ID=`getProjectMetadata project-id`
ETL_API_VM=`getInstanceMetadata attributes/etl-api-vm`

airflow variables --set gcp_project_id ${GCP_PROJECT_ID}
airflow variables --set api_endpoint http://${ETL_API_VM}:5000

# Unpause the clean-up DAG
airflow unpause prune_logs

# Wrap-up
END_TIME=`date +%s`

RUN_TIME=$((END_TIME-START_TIME))

printf "\nEnvironment setup in ${RUN_TIME} seconds\n"
© 2020 GitHub, Inc.
Terms
Privacy
Security
Status
Help
Contact GitHub
Pricing
API
Training
Blog
About
