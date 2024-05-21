#!/bin/sh -e

# a simple script to start/stop water heater with the sun

# requirement: an influxdb database is filled with injection data (collected from a shelly em and sent to influxdb using openhab or telegraf)

# we read injection from influxdb
# and control a relay running tasmota, with a MQTT request

# if there is enough injection, start the heater, wait 15m
# if consumption, stop the heater, wait 15m


# works using the following cronjobs

# toutes les minutes avant midi (moins 15min) on verifie si on lance le cumulus ou on le stop en fonction du soleil
#*  6-11   * * * sleep 5; bin/cumulus-onoff-soleil.sh >>/tmp/cumulus-onoff-soleil.log 2>&1
#0-45 12   * * * sleep 5; bin/cumulus-onoff-soleil.sh >>/tmp/cumulus-onoff-soleil.log 2>&1

# mosquitto_pub -t cmnd/tasmota-cumulus/POWER -m off

log() {
	echo "$(date +'%Y-%m-%d %H:%M:%S') $1"
}

influxReq() {
        influxReq="$1"
        [ "$influxReq" = "" ] && log "influxReq empty" >&2 && exit 1

        influxHost="www.example.com"
        influxDb="openhab"

        influx -host "$influxHost" -database "$influxDb" -precision rfc3339 -format csv -execute "$influxReq" | tail -1 | cut -d, -f3 | cut -d. -f1
}

mqttGetState() {
  RESULT=$(timeout 5 mosquitto_sub -t stat/tasmota-cumulus/POWER -C 1 &
    mosquitto_pub -t cmnd/tasmota-cumulus/POWER -n
  )
  [ "$RESULT" != "ON" -a "$RESULT" != "OFF" ] && log "mqtt error" >&2 && exit 1
  echo "$RESULT"
}

mqttCmd() {
    mosquitto_pub -t cmnd/tasmota-cumulus/POWER -m "$1"
}

getLinkyMaxWatt() {
        influxReqMaxWatt="select max(value) from ShellyEM_meter1_watts where time > now() - 5m"
        maxwatt=$(influxReq "$influxReqMaxWatt")
        #maxwatt=-10 # DEBUGGGGGGGGGGGGGGGGG
        #log "maxwatt: $maxwatt" >&2
        echo "$maxwatt"
}

getLinkyMinWatt() {
        influxReqMinWatt="select min(value) from ShellyEM_meter1_watts where time > now() - 5m"
        minwatt=$(influxReq "$influxReqMinWatt")
        #minwatt=1000 # DEBUGGGGGGGGGGGGGGGGG
        #log "minwatt: $minwatt" >&2
        echo "$minwatt"
}

LOCKFILE=/tmp/$(basename "$0").lock
! mkdir "$LOCKFILE" 2>/dev/null && log "Already running so quit." && exit 1
trap "rm -rf $LOCKFILE; exit" INT TERM EXIT


# 
# conso cumulus : ~ 2300 w
# 
# 
# de 7h à 11h30 (heure de forcage du cumulus)
# 
# si off
#   si maxwatt/linky < -2000 (5min)
#     on
#     sleep 15m
# 
# si on
#   si linky > 1500 (5min)
#     off
#     sleep 15m

state=$(mqttGetState)
log "state: $state"

###########
if [ "$state" = "OFF" ]; then

	watt=$(getLinkyMaxWatt)
	log "test if $watt < -2000"

	if [ "$watt" -lt -2000 ]; then
		log "Set Cumulus ON. Waiting 15m..."
		mqttCmd on
		sleep 15m
	fi

###########
elif [ "$state" = "ON" ]; then

	watt=$(getLinkyMinWatt)
	log "test if $watt > 1500"

	if [ "$watt" -gt 1500 ]; then
		log "Set Cumulus OFF. Waiting 15m..."
		mqttCmd off
		sleep 15m
	fi

###########
else
	log "state error"; exit 2
fi
