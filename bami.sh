#!/bin/bash

user=admin
pass=secret
log=/tmp/bami.log

# Generic function for logging
function log() {
    echo `date "+%D %T - "` "${@}" >> ${log}
}

# Will call log() with a INFO prefix
function info() {
    log "INFO - ${@}"
}

# Will call log() with a DEBUG prefix
function debug() {
    log "DEBUG - ${@}"
}

# Will call log() with a ERROR prefix
function error() {
    log "ERROR - ${@}"
}

# Reads a line from AMI (stdin), will strip \r
function readLine() {
    local line=""
    read line
    line=`echo ${line} | tr -d "\r"`
    echo ${line}
}

# Reads a full PDU from asterisk. Since Asterisk messages
# ends with a \r\n\r\n, and we use "read" to read line by
# line, this will translate to an empty line delimiting
# PDUs. So read up to an empty line, and return whatever
# read.
function readPdu() {
    local pdu=""
    local complete=0
    while [ ${complete} -eq "0" ]; do
        line=`readLine`
        # End Of Message detected
        if [ -z ${line} ]; then
            complete=1
        else
            # Concat line read
            pdu=`printf "${pdu}\\\n${line}"`
        fi
    done
    echo ${pdu}
}

# Performs a Login action. Will terminate with error code 255 if 
# the asterisk ami welcome message is not found.
function login() {
    local welcome=`readLine`
    if [ ${welcome} != "Asterisk Call Manager/1.1" ]; then
        error "Invalid peer. Not AMI."
        exit 255
    fi
    printf "Action: Login\r\nUsername: ${user}\r\nSecret: ${pass}\r\n\r\n"
    local response=`readPdu`
    if [[ ! ${response} =~ Success ]]; then
        error "Could not login: ${response}"
        exit 254
    fi
}

# Do login.
login

# Main reading loop.
while [ true ]; do
    pdu=`readPdu`
    debug "${pdu}"
    $regex="Event: *"
    if [[ $pdu =~ $regex ]]; then
        eventName=`echo ${pdu} | cut -d' ' -f2`
        case ${eventName} in
            DTMF)
                info DTMF
            ;;
            VarSet)
            ;;
            Hangup)
            ;;
            Dial)
                info Dial
            ;;
            *)
                info "=== Unhandled event: ${eventName} ==="
            ;;
        esac
    else
        info "Response: ${pdu}"
    fi
done

