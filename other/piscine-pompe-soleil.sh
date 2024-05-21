#!/bin/sh -e

# every min cronjob to start/stop pool pum with the sun

# requirement: reads injection from influxdb database
# in a defined sliding window (16h) the pump should run between min and max minutes
# start only if water heater hot, or water heating but extra energy
# flag file to force pump if sun available

# works using the following cronjobs

# reset flag files for piscine-pompe-soleil.sh
#0 5 * * * rm -f /var/www/websend/tmp/*

# toutes les minutes on verifie si on lance la pompe ou la stoppe en fonction du soleil
#* 6-22 * * * sleep 13; ~/bin/piscine-pompe-soleil.sh >>/tmp/piscine-pompe-soleil.log 2>&1



log() {
        echo "$(date +'%Y-%m-%d %H:%M:%S') $1" >&2
}

influxReq() {
	influxReq="$1"
	[ "$influxReq" = "" ] && echo "influxReq empty" >&2 && exit 1

	influxHost="www.example.com"
	influxDb="openhab"

	influx -host "$influxHost" -database "$influxDb" -precision rfc3339 -format csv -execute "$influxReq" | tail -1 | cut -d, -f3 | cut -d. -f1
}

mqttGetState() {
  RESULT=$(timeout 5 mosquitto_sub -t stat/tasmota-piscine/POWER -C 1 &
    mosquitto_pub -t cmnd/tasmota-piscine/POWER -n
  )
  [ "$RESULT" != "ON" -a "$RESULT" != "OFF" ] && log "mqtt error" >&2 && exit 1
  echo "$RESULT"
}

mqttCmd() {
    mosquitto_pub -t cmnd/tasmota-piscine/POWER -m "$1"
}

getPompeMinutes() {
	influxReqPompe="select count(*) from TasmotaRelaiPiscine where time > now() - 16h and value = 1"
  	pompeMinutes=$(influxReq "$influxReqPompe")
  	#pompeMinutes=182 #DEBUGGGGGGGGGGGG
	if [ "$pompeMinutes" = "" ]; then
  		pompeMinutes="0"
	fi
	log "pompeMinutes: $pompeMinutes"
	echo "$pompeMinutes"
}

# 7 minutes so should start after the cumulus

getLinkyMaxWatt() {
        influxReqMaxWatt="select max(value) from ShellyEM_meter1_watts where time > now() - 7m"
        maxwatt=$(influxReq "$influxReqMaxWatt")
        #maxwatt=-10 # DEBUGGGGGGGGGGGGGGGGG
        log "maxwatt: $maxwatt"
        echo "$maxwatt"
}

getLinkyMinWatt() {
        influxReqMinWatt="select min(value) from ShellyEM_meter1_watts where time > now() - 7m"
        minwatt=$(influxReq "$influxReqMinWatt")
        #minwatt=1000 # DEBUGGGGGGGGGGGGGGGGG
        log "minwatt: $minwatt"
        echo "$minwatt"
}

# wait 10min after a change of cumulus state
cumulusHotOrFullPower() {
	dir=/var/www/websend/tmp
	if [ -f $dir/cumulusHasBeenHot -o \( "$(cat $dir/cumulus-volume-soleil.nbres)" = 3 -a "$(find $dir/cumulus-volume-soleil.nbres -mmin -10)" = "" \) ]; then
		return 0
	else
		return 1
	fi
}

LOCKFILE=/tmp/$(basename "$0").lock
! mkdir "$LOCKFILE" 2>/dev/null && log "Already running so quit." && exit 1
trap "rm -rf $LOCKFILE; exit" INT TERM EXIT


state=$(mqttGetState)
#log "state: $state"

if [ -f ~/.state/forcePumpOnIfSun ]; then
	POMPEMIN=1000000
	POMPEMAX=1000000
else
	# entre 2h et 3h
	POMPEMIN=120
	POMPEMAX=180
	# entre 3h et 4h
	POMPEMIN=180
	POMPEMAX=240
fi

if cumulusHotOrFullPower; then
    cumulusOK=true
else
    cumulusOK=false
fi

###########
if [ "$state" = "OFF" ]; then

	# si ça fait qq min qu'on injecte, et que la pompe doit encore tourner, on la lance
	# -lt -3 : mode zero injection
	# -lt -250 : mode full injection
	# 2h in 2 days : 2x60 = 120 min

	log "(OFF) cumulusOK:$cumulusOK test if pompeMinutes < $POMPEMIN AND watt < -250"
	if [ "$cumulusOK" = true -a "$(getPompeMinutes)" -lt "$POMPEMIN" -a "$(getLinkyMaxWatt)" -lt -250 ]; then
            log "Set pump ON. Waiting 10m..."
            mqttCmd on
            sleep 10m
        fi

###########
elif [ "$state" = "ON" ]; then

	# si ça fait qq min qu'on consomme chez edf, ou que la pompe a assez tourné, on stoppe
	# 150min : 2h30
	# 480min : 8h
	# 10000000 : forcé dès qu'il y a du soleil

	log "(ON) cumulusOK:$cumulusOK test if pompeMinutes > $POMPEMAX OR watt > 100"
	if [ "$cumulusOK" = false -o "$(getPompeMinutes)" -gt "$POMPEMAX" -o "$(getLinkyMinWatt)" -gt 100 ]; then
                log "Set pump OFF. Waiting 10m..."
                mqttCmd off
                sleep 10m
	fi

###########
else
        log "state error"; exit 2
fi
