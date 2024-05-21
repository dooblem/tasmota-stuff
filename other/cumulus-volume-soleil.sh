#!/bin/bash

# a systemd service to adjust 3 water heater resistors. Replaced with python version bellow.
# see the associated systemd service

# requirement: an influxdb database is filled with injection data (collected from a shelly em and sent to influxdb using openhab or telegraf)

# reads from influxdb
# set/add 1 resistor on if enough injection
# set/add 1 resistor off if consumption
# act on resistors randomly to avoid overusing the first ones
# force one resistor at given time if not hot/enough sun
# send commands to a Tasmota relay via MQTT
# set flag files for the pool pump script


# mosquitto_pub -t cmnd/tasmota-cumulus/POWER -m off

log() {
	echo "$(date +'%Y-%m-%d %H:%M:%S') $1"
}

influxReq() {
	req='select min("0.power"),max("0.power"),mean("1.power") from shellyem where time > now() - 2m'
        [ "$req" = "" ] && log "influxReq empty" >&2 && return

        influxHost="www.example.com"
        influxDb="telegraf"

	OUT=$(influx -host "$influxHost" -database "$influxDb" -precision rfc3339 -format csv -execute "$req" | tail -1)

	min=$(echo "$OUT" | cut -d, -f3 | cut -d. -f1)
	max=$(echo "$OUT" | cut -d, -f4 | cut -d. -f1)
	prod=$(echo "$OUT" | cut -d, -f5 | cut -d. -f1)
	
	echo "$min,$max,$prod"
}

initResistance() {
	local -n res="res$1"
	
	state=$( mqttGetState $(( $1 + 1)) )
	
	if [ "$state" = ON ]; then
		res="off"
		rm -f "/tmp/res${1}on"
	elif [ "$state" = OFF ]; then
		res="on"
		touch -a "/tmp/res${1}on"
		nbres=$(($nbres+1))
	fi
}

initResistances() {
	nbres=0
	initResistance 1
	initResistance 2
	initResistance 3

	echo "res1:$res1 res2:$res2 res3:$res3"
}

# mesure resistance à 860w..
# 2300/3 = 766,666
setOneResistanceOn() {
	log "Set one Resistance ON"

	cand=() #candidates
	[ "$res1" = off ] && cand+=(1)
	[ "$res2" = off ] && cand+=(2)
	[ "$res3" = off ] && cand+=(3)
	len=${#cand[@]}
	[ "$len" = 0 ] && echo "error len is 0" && return
	rand=$(( $RANDOM % $len ))
	choice=${cand[$rand]}

	resistanceCmd "$choice" on
}
setOneResistanceOff() {
	log "Set one Resistance OFF"

	cand=() #candidates
	[ "$res1" = on ] && cand+=(1)
	[ "$res2" = on ] && cand+=(2)
	[ "$res3" = on ] && cand+=(3)
	len=${#cand[@]}
	[ "$len" = 0 ] && echo "error len is 0" && return
	rand=$(( $RANDOM % $len ))
	choice=${cand[$rand]}

	resistanceCmd "$choice" off
}

mqttGetState() {
  relayNum="$1"
  RESULT=$(timeout 5 mosquitto_sub -t stat/tasmota-relay4ch/POWER$relayNum -C 1 &
    mosquitto_pub -t cmnd/tasmota-relay4ch/POWER$relayNum -n
  )
  [ "$RESULT" != "ON" -a "$RESULT" != "OFF" ] && log "mqtt error" >&2 && return
  echo "$RESULT"
}

mqttCmd() {
    echo mosquitto_pub -t cmnd/tasmota-relay4ch/POWER"$1" -m "$2"
    mosquitto_pub -t cmnd/tasmota-relay4ch/POWER"$1" -m "$2"
}

resistanceCmd() {
	numRes="$1"
	cmdRes="$2"
	local -n res="res$1"

	echo "Set resistance $numRes to $cmdRes..."

	if [ "$cmdRes" = "on" ]; then
		res=on
		nbres=$(($nbres+1))
		touch -a "/tmp/res${numRes}on"
		cmd="OFF"
	else
		res=off
		nbres=$(($nbres-1))
		rm -f "/tmp/res${numRes}on"
		cmd="ON"
	fi

	mqttCmd $(($numRes + 1)) "$cmd" 
}

#getLinkyMaxWatt() {
#        req='select max("0.power") from shellyem where time > now() - 2m'
#        watt=$(influxReq "$req")
#        #watt=1000 # DEBUGGGGGGGGGGGGGGGGG
#        #log "watt: $watt" >&2
#        echo "$watt"
#}
#
#getLinkyMinWatt() {
#        req='select min("0.power") from shellyem where time > now() - 2m'
#        watt=$(influxReq "$req")
#        #watt=1000 # DEBUGGGGGGGGGGGGGGGGG
#        #log "watt: $watt" >&2
#        echo "$watt"
#}
#
## TODO temps ??
#getLinkyMeanWatt() {
#        req='select mean("0.power") from shellyem where time > now() - 3m'
#        watt=$(influxReq "$req")
#        #watt=1000 # DEBUGGGGGGGGGGGGGGGGG
#        #log "watt: $watt" >&2
#        echo "$watt"
#}

LOCKFILE=/tmp/$(basename "$0").lock
! mkdir "$LOCKFILE" 2>/dev/null && log "Already running so quit." && exit 1
trap "rm -rf $LOCKFILE; exit" INT TERM EXIT


# 
# conso cumulus : ~ 2300 w
# 3x 766
# 
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

(

res1=""
res2=""
res3=""
initResistances

#echo "$res1 $res2 $res3"

# while true

# injection
# if watt < -750 : nbres++ (if nbres < 3)

# conso
# if watt > 200 : nbres-- (if nbres > 0)

# soleil 21 juin : 5h45 - 22h. 6h00-21h59 . 4h00-19h59 utc
# at 12h utc : one resistance is turned on by tasmota timers. should be kept until 18h utc : 19/20h cest

prehour=0
hour=0
hasBeenHot=false
rm -f /tmp/cumulusHasBeenHot

while true
do
	# skip if not sun hours (4h-20h utc)
	prehour="$hour"
	hour=$(date -u +%H)
	if ! [ "$hour" -ge 4 -a "$hour" -lt 20 ]; then
		sleep 60 && continue
	fi
	if [ "$prehour" = 03 -a "$hour" = 04 ]; then # at 4h00 utc
		log "Sun day begin"
		initResistances
		hasBeenHot=false
		rm -f /tmp/cumulusHasBeenHot
	elif [ "$prehour" = 11 -a "$hour" = 12 -a "$hasBeenHot" = false ]; then # at 12h00 utc
		log "Force ON one resistance"
		resistanceCmd 1 on
		res1=onLock # attention si on relance le script au milieu.
	elif [ "$prehour" = 17 -a "$hour" = 18 ]; then # at 18h00 utc
		log "Force ON one resistance - finish"
		initResistances
	fi

	result=$(influxReq)
	minwatt=$(echo "$result" | cut -d, -f1)
	maxwatt=$(echo "$result" | cut -d, -f2)
	prodwatt=$(echo "$result" | cut -d, -f3)
	[ "$minwatt" = "" -o "$maxwatt" = "" -o "$prodwatt" = "" ] && echo "result error" && sleep 60 && continue

	if [ "$hasBeenHot" = false ]; then
		conso=$(( $maxwatt + $prodwatt ))
		echo "hasBeenHot test if $nbres > 0 and $maxwatt+$prodwatt=$conso < 700"
		if [ "$nbres" -gt 0 -a "$conso" -lt 700 ]; then
			echo "hasBeenHot=true"
			hasBeenHot=true
			touch /tmp/cumulusHasBeenHot
			# unlock the resistance
			res1=on
		fi
	fi

	if [ "$hasBeenHot" = false ]; then
		log "TEST_NotHot $maxwatt < -700 ELIF $minwatt > 200 (n:$nbres r1:$res1 r2:$res2 r3:$res3)"

		if [ "$maxwatt" -lt -700 -a "$nbres" -le 2 ]; then
			setOneResistanceOn
		elif [ "$minwatt" -gt 200 -a "$nbres" -ge 1 ]; then
			setOneResistanceOff
		fi
	else
		theoricWatt=$(( $nbres * 766 + 50 ))
		theoricWattPlus=$(( $theoricWatt +766 ))

		log "TEST $maxwatt<-700 $theoricWattPlus<$prodwatt ELIF $minwatt>200 or $theoricWatt>$prodwatt (n:$nbres r1:$res1 r2:$res2 r3:$res3)"

		if [ "$maxwatt" -lt -700 -a "$nbres" -le 2 -a "$theoricWattPlus" -lt "$prodwatt" ]; then # et à condition que ça n'aille pas trop haut sur la conso theorique
			setOneResistanceOn
		elif [ \( "$minwatt" -gt 200 -o "$theoricWatt" -gt "$prodwatt" \) -a "$nbres" -ge 1 ]; then # ou que par rapport au nombre de res la conso theorique est trop haute
			setOneResistanceOff
		fi
	fi
	
	sleep 60
done

) 2>&1 | tee /tmp/cumulus-volume-soleil.log
