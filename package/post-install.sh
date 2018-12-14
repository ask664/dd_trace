#!/bin/bash --login

EXTENSION_BASE_DIR=/opt/datadog-php
EXTENSION_DIR=${EXTENSION_BASE_DIR}/extensions
EXTENSION_CFG_DIR=${EXTENSION_BASE_DIR}/etc
EXTENSION_LOGS_DIR=${EXTENSION_BASE_DIR}/log
INI_FILE_NAME='99-ddtrace.ini'

PATH="${PATH}:/usr/local/bin"

function println(){
    echo -e '###' "$@"
}

function append_configuration_to_file() {
    tee -a "$@" <<EOF
## Autogenerated by the DataDog post-install.sh script

[datadog]
extension=${EXTENSION_FILE_PATH}

## end of autogenerated part
EOF
}

function install_conf_d_file() {
    INI_FILE_PATH="${EXTENSION_CFG_DIR}/$INI_FILE_NAME"

    println "Creating ddtrace.ini"
    println "\n"

    append_configuration_to_file "${INI_FILE_PATH}"

    println "ddtrace.ini created"
    println

    PHP_DDTRACE_INI="$PHP_CFG_DIR/$INI_FILE_NAME"

    println "Linking ddtrace.ini to ${PHP_DDTRACE_INI}"
    test -f "${PHP_DDTRACE_INI}" && rm "${PHP_DDTRACE_INI}"
    ln -s "$INI_FILE_PATH" "${PHP_DDTRACE_INI}"
}

function fail_print_and_exit() {
    println 'Failed enabling ddtrace extension'
    println
    println "The extension has been installed and couldn't be enabled"
    println "Try adding the extension manually to your PHP - php.ini - configuration file"
    println "e.g. by adding following line: "
    println
    println "    extension=${EXTENSION_FILE_PATH}"
    println
    println "Note that your PHP API version must match the extension's API version"
    println "PHP API version can be found using following command"
    println
    println "    php -i | grep 'PHP API'"
    println

    exit 0 # exit - but do not fail the installtion
}

function verify_installation() {
    ENABLED_VERSION="$(php -r "echo phpversion('ddtrace');")"

    if [[ -n ${ENABLED_VERSION} ]]; then
        println "Extension ${ENABLED_VERSION} enabled successfully"
    else
        fail_print_and_exit
    fi
}

mkdir -p $EXTENSION_DIR
mkdir -p $EXTENSION_CFG_DIR
mkdir -p $EXTENSION_LOGS_DIR

println 'Installing DataDog PHP tracing extension (ddtrace)'
println
println 'Logging php -i to a file'
println

php -i > "$EXTENSION_LOGS_DIR/php-info.log"

PHP_VERSION=$(php -i | grep 'PHP API' | awk '{print $NF}')
PHP_CFG_DIR=$(php --ini | grep 'Scan for additional .ini files in:' | sed -e 's/Scan for additional .ini files in://g' | head -n 1 | awk '{print $1}')

PHP_THREAD_SAFETY=$(php -i | grep 'Thread Safety' | awk '{print $NF}' | grep -i enabled)

VERSION_SUFFIX=""
if [[ -n $PHP_THREAD_SAFETY ]]; then
    VERSION_SUFFIX="-zts"
fi

EXTENSION_NAME="ddtrace-${PHP_VERSION}${VERSION_SUFFIX}.so"
EXTENSION_FILE_PATH="${EXTENSION_DIR}/${EXTENSION_NAME}"

if [[ ! -e $PHP_CFG_DIR ]]; then
    println
    println 'conf.d folder not found falling back to appending extension config to main "php.ini"'
    PHP_CFG_FILE_PATH=$(php --ini | grep 'Configuration File (php.ini) Path:' | sed -e 's/Configuration File (php.ini) Path://g' | head -n 1 | awk '{print $1}')
    PHP_CFG_FILE="${PHP_CFG_FILE_PATH}/php.ini"
    if [[ ! -e $PHP_CFG_FILE_PATH ]]; then
        fail_print_and_exit
    fi

    if grep -q "${EXTENSION_FILE_PATH}" "${PHP_CFG_FILE}"; then
        println
        println '    extension configuration already exists skipping'
    else
        append_configuration_to_file "${PHP_CFG_FILE}"
    fi
else
    install_conf_d_file
fi

verify_installation
