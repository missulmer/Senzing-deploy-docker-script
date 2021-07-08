#!/bin/bash
# vim: ai:sw=4:ts=4:sta:et:fo=croql
# Author: Gustavo Kuhn Andriotti
#
# Tested on 2021-07-06 for:
# - macOS Big Sur (11.4)
# - Ubuntu 21.04
#

# must be the first thing
CLI_ARGS=${@}

# Default CLI args
GIT_REPOSITORY_URL="https://github.com/senzing/docker-compose-demo.git"
GIT_CLONE_DIR="${HOME}/senzing-docker"
SENZING_VOLUME_DIR="${HOME}/senzing-volume"
FORCE_GIT_OVERWRITE=0
STOP_ALL_CONTAINERS=0
SZ_EULA_VALUE=""


# Exports and corresponding subdirs for docker compose
SENZING_VOLUME_VAR_NAME="SENZING_VOLUME"
set -a SENZING_VOLUME_DIR_VARNAME_SUBDIRS
SENZING_VOLUME_DIR_VARNAME_SUBDIRS+=( "SENZING_DATA_DIR data" )
SENZING_VOLUME_DIR_VARNAME_SUBDIRS+=( "SENZING_DATA_VERSION_DIR data/2.0.0" )
SENZING_VOLUME_DIR_VARNAME_SUBDIRS+=( "SENZING_ETC_DIR etc" )
SENZING_VOLUME_DIR_VARNAME_SUBDIRS+=( "SENZING_G2_DIR g2" )
SENZING_VOLUME_DIR_VARNAME_SUBDIRS+=( "SENZING_VAR_DIR var" )
SENZING_VOLUME_DIR_VARNAME_SUBDIRS+=( "POSTGRES_DIR var/postgres" )
SENZING_VOLUME_DIR_VARNAME_SUBDIRS+=( "RABBITMQ_DIR var/rabbitmq" )

# Will be set according to CLI args
SZ_EULA_VAR_NAME="SENZING_ACCEPT_EULA"


# Required free ports
# Source: https://github.com/Senzing/docker-compose-demo/blob/master/resources/postgresql/docker-compose-rabbitmq-postgresql.yaml
set -a SZ_DOCKER_PORTS
SZ_DOCKER_PORTS+=( 5432 ) # PostgreSQL
SZ_DOCKER_PORTS+=( 5672 ) # RabbitMQ
SZ_DOCKER_PORTS+=( 8250 ) # Senzing API
SZ_DOCKER_PORTS+=( 8251 ) # Senzing Webapp
SZ_DOCKER_PORTS+=( 8254 ) # Senzing xterm
SZ_DOCKER_PORTS+=( 9171 ) # PHP PGAdmin HTTP
SZ_DOCKER_PORTS+=( 9172 ) # PHP PGAdmin HTTPS
SZ_DOCKER_PORTS+=( 9178 ) # Jupyter HTTP
SZ_DOCKER_PORTS+=( 9180 ) # Swagger UI
SZ_DOCKER_PORTS+=( 9181 ) # SSH container
SZ_DOCKER_PORTS+=( 15672 ) # RabbitMQ

# Path within the GitHub repo
set -a SZ_DOCKER_YAML_FILES
SZ_DOCKER_YAML_FILES+=( "resources/senzing/docker-compose-senzing-installation.yaml" )
SZ_DOCKER_YAML_FILES+=( "resources/postgresql/docker-compose-rabbitmq-postgresql.yaml" )

# Linux/macOS differences
MACOS_DOCKER_COMPOSE_CMD="docker compose"
LINUX_DOCKER_COMPOSE_CMD="docker-compose"


function help()
{
    echo
    echo "Usage:"
    echo "${0} \\"
    echo "  [--git-repo GIT_REPO_URL] \\"
    echo "  [--git-local-dir GIT_CLONE_LOCAL_DIR] \\"
    echo "  [--sz-volume-dir SENZING_LOCAL_VOLUME_DIR] \\"
    echo "  [--force] \\"
    echo "  [--stop-all] \\"
    echo "  [--I-accept-senzing-eula]"
    echo
    echo "Example:"
    echo "${0} \\"
    echo "  --force \\"
    echo "  --stop-all \\"
    echo "  --I-accept-senzing-eula"
    echo
    echo "${0} \\"
    echo "  --git-repo ${GIT_REPOSITORY_URL} \\"
    echo "  --git-local-dir ${GIT_CLONE_DIR} \\"
    echo "  --sz-volume-dir ${SENZING_VOLUME_DIR} \\"
    echo "  --force \\"
    echo "  --stop-all \\"
    echo "  --I-accept-senzing-eula"
    echo
}


function log_msg()
{
    local MSG="${1}"

    echo "[INFO] ${MSG}" >&2
}


function error_msg_exit()
{
    local MSG="${1}"

    echo
    echo "[ERROR] ${MSG}" >&2
    exit 1
}


function error_msg_help()
{
    local MSG="${1}"

    help >&2
    error_msg_exit "${MSG}"
}


function error_msg_missing_arg()
{
    local ARG="${1}"

    error_msg_help "Argument for [${ARG}] is missing"
}


function has_requirement()
{
    local REQ_CMD="${1}"
    local REQ_SOURCE="${2}"

    if [[ -z $(which ${REQ_CMD}) ]]
    then
        error_msg_exit "Could not find [${REQ_CMD}]. Visit: ${REQ_SOURCE}"
        exit 1
    else
        log_msg "Using ${REQ_CMD} found in $(which ${REQ_CMD})"
    fi
}


function is_linux()
{
    local KERNEL=$(uname -s)
    if [[ "${KERNEL}" == "Linux" ]]
    then
        echo 1
    else
        echo 0
    fi
}


function has_all_requirements()
{
    log_msg "Checking requirements"
    has_requirement "docker" "https://www.docker.com/"
    if [[ "$(is_linux)" == "1" ]]
    then
        has_requirement "docker-compose" "https://www.docker.com/"
    fi
    has_requirement "git" "https://git-scm.com/"
    has_requirement "lsof" "https://en.wikipedia.org/wiki/Lsof"
}


function parse_cli_args()
{
    while (( "${#}" )); do
        case "${1}" in
            -g|--git-repo)
                if [ -n "${2}" ] && [ "${2:0:1}" != "-" ]; then
                    GIT_REPOSITORY_URL="${2}"
                    shift 2
                else
                    error_msg_missing_arg "${1}"
                fi
                ;;
            -d|--git-local-dir)
                if [ -n "${2}" ] && [ "${2:0:1}" != "-" ]; then
                    GIT_CLONE_DIR="${2}"
                    shift 2
                else
                    error_msg_missing_arg "${1}"
                fi
                ;;
            -v|--sz-volume-dir)
                if [ -n "${2}" ] && [ "${2:0:1}" != "-" ]; then
                    SENZING_VOLUME_DIR="${2}"
                    shift 2
                else
                    error_msg_missing_arg "${1}"
                fi
                ;;
            -f|--force)
                FORCE_GIT_OVERWRITE=1
                shift 1
                ;;
            -s|--stop-all)
                STOP_ALL_CONTAINERS=1
                shift 1
                ;;
            --I-accept-senzing-eula)
                SZ_EULA_VALUE="I_ACCEPT_THE_SENZING_EULA"
                shift 1
                ;;
            -h|--help)
                help
                exit 0
                ;;
            *) # unsupported flags
                error_msg_help "Unsupported flag [$1]"
                ;;
        esac
    done

    if [[ -z ${SZ_EULA_VALUE} ]]
    then
        error_msg_help "EULA has not been accepted, without it Senzing does not work"
    fi
}


function git_repo_subdir()
{
    local REPO_URL="${1}"

    local REPO_SUBDIR=${REPO_URL##*/}
    REPO_SUBDIR=${REPO_SUBDIR%%\.git}
    echo ${REPO_SUBDIR}
}


function git_clone()
{
    local REPO_URL="${1}"
    local PARENT_DIR="${2}"

    log_msg "Cloning repo ${REPO_URL} into ${PARENT_DIR}"
    mkdir -p ${PARENT_DIR} 1>&2
    pushd ${PARENT_DIR}
    if [[ ${FORCE_GIT_OVERWRITE} -eq 1 ]]
    then
        local REPO_SUBDIR=$(git_repo_subdir ${REPO_URL})
        echo "Removing existing repo subdir: ${REPO_SUBDIR}"
        rm -rf ${REPO_SUBDIR}
    fi
    git clone --recurse-submodules ${REPO_URL} 1>&2 \
        || error_msg_exit "Could not clone ${REPO_URL} into ${PARENT_DIR}"
    popd
}


function has_docker_access_to_sz_volume()
{
    local SZ_DIR="${1}"

    log_msg "Checking Docker access to Senzing volume: ${SZ_DIR}"
    local MOUNTING_POINT="/test-access"
    local ACCESS_TEST_FILE="${MOUNTING_POINT}/docker_has_access"
    docker run \
        -v ${SZ_DIR}:${MOUNTING_POINT} \
        -it alpine \
        touch ${ACCESS_TEST_FILE} 1>&2 \
        || error_msg_exit "Docker cannot access ${SZ_DIR} properly. If you are using macOS, check: https://docs.docker.com/docker-for-mac/#file-sharing. If on ubuntu and you got 'Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock' check: https://linuxhandbook.com/docker-permission-denied/"
}


function sz_volume()
{
    local SZ_DIR="${1}"

    log_msg "Creating Senzing volume and subdirs: ${SZ_DIR}"
    mkdir -p ${SZ_DIR}
    chmod 777 ${SZ_DIR}

    has_docker_access_to_sz_volume ${SZ_DIR}

    for NDX in $(seq 0 $(expr ${#SENZING_VOLUME_DIR_VARNAME_SUBDIRS[@]} - 1))
    do
        local VARNAME_SUBDIR="${SENZING_VOLUME_DIR_VARNAME_SUBDIRS[$NDX]}"
        local SUBDIR=${VARNAME_SUBDIR#* }
        local FQN_SUBDIR="${SZ_DIR}/${SUBDIR}"
        log_msg "Creating Senzing subdir: ${FQN_SUBDIR}"
        mkdir -p ${FQN_SUBDIR}
        chmod 777 ${FQN_SUBDIR}
    done
}


function sz_exports()
{
    local SZ_DIR="${1}"
    local EULA_VALUE="${2}"

    log_msg "Exporting senzing volume: ${SENZING_VOLUME_VAR_NAME}=\"${SZ_DIR}\""
    export ${SENZING_VOLUME_VAR_NAME}=${SZ_DIR}
    for NDX in $(seq 0 $(expr ${#SENZING_VOLUME_DIR_VARNAME_SUBDIRS[@]} - 1))
    do
        local VARNAME_SUBDIR="${SENZING_VOLUME_DIR_VARNAME_SUBDIRS[$NDX]}"
        local VAR_NAME="${VARNAME_SUBDIR%% *}"
        local SUBDIR=${VARNAME_SUBDIR#* }
        local VAR_VAL="${SZ_DIR}/${SUBDIR}"
        log_msg "Exporting ${VAR_NAME}=\"${VAR_VAL}\""
        export ${VAR_NAME}=${VAR_VAL}
    done
    log_msg "Senzing EULA: ${SZ_EULA_VAR_NAME}=\"${EULA_VALUE}\""
    export ${SZ_EULA_VAR_NAME}=${EULA_VALUE}
}


function docker_stop_all()
{
    log_msg "Stopping all docker containers"
    docker container ls --quiet \
        | while read CONTAINER_ID
            do 
                log_msg "Stopping container ID: ${CONTAINER_ID}"
                docker container stop ${CONTAINER_ID} 1>&2 \
                    || error_msg_exit "Could not stop container ID: ${CONTAINER_ID}"
            done
}


function check_port()
{
    local PORT="${1}"

    lsof -i -n -P | grep -e ":${PORT}[[:space:]]\+"
}


function has_all_ports_free()
{
    log_msg "Checking for ports: ${SZ_DOCKER_PORTS[*]}"
    for PORT in ${SZ_DOCKER_PORTS[@]}
    do
        local HAS_PORT=$(check_port ${PORT})
        if [[ -n ${HAS_PORT} ]]
        then
            error_msg_exit "Port ${PORT} is in use, please free it up:\n${HAS_PORT}"
        fi
    done
}


function docker_compose()
{
    local YAML_FILE="${1}"

    log_msg "Creating docker from ${YAML_FILE}"
    local DOCKER_COMPOSE_CMD=${MACOS_DOCKER_COMPOSE_CMD} 
    if [[ "$(is_linux)" == "1" ]]
    then
        DOCKER_COMPOSE_CMD=${LINUX_DOCKER_COMPOSE_CMD} 
    fi
    ${DOCKER_COMPOSE_CMD} --file ${YAML_FILE} up 1>&2 \
        || error_msg_exit "Could compose ${YAML_FILE}"
}


function sz_docker()
{
    local REPO_URL="${1}"
    local PARENT_DIR="${2}"

    if [[ ${STOP_ALL_CONTAINERS} -eq 1 ]]
    then
        docker_stop_all
    fi

    has_all_ports_free

    local REPO_SUBDIR=$(git_repo_subdir ${REPO_URL})
    for YAML_FILE in ${SZ_DOCKER_YAML_FILES[@]}
    do
        docker_compose "${PARENT_DIR}/${REPO_SUBDIR}/${YAML_FILE}"
    done
}


# fetch()
has_all_requirements
parse_cli_args ${CLI_ARGS[@]}
sz_volume "${SENZING_VOLUME_DIR}"
sz_exports "${SENZING_VOLUME_DIR}" "${SZ_EULA_VALUE}"
git_clone "${GIT_REPOSITORY_URL}" "${GIT_CLONE_DIR}"
sz_docker "${GIT_REPOSITORY_URL}" "${GIT_CLONE_DIR}"
