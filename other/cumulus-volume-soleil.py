#!/usr/bin/env python3

# a systemd service to adjust 3 water heater resistors. no influxdb required. reads directly from shelly em.
# see the associated systemd service and wrapper

# reads directly from shelly em
# set/add 1 resistor on if enough injection
# set/add 1 resistor off if consumption
# act on resistors randomly to avoid overusing the first ones
# force one resistor at given time if not hot/enough sun
# send commands to a Tasmota relay via HTTP
# set flag files for the pool pump script


SLEEP_INTERVAL = 20
# the history time window is SLEEP_INTERVAL*METRICS_HISTORY
# 20*6=120=2min
METRICS_HISTORY = 6
# how much time to wait after actionning the relay
RELAY_LOCK_TIME = 60
# tasmota command url
RELAY_CMD_URL = "http://192.168.1.XX/cm?cmnd="
# shelly power status url
POWER_STATUS_URL = "http://192.168.1.XX/status"

# power in watt to trigger on one resistance. when maxwatt is bellow
WATT_UP = -700
# power in watt to trigger off one resistance. when lastwatt is above
WATT_DOWN = 200

# when conso bellow this limit and resistance on. cumulus is HOT
WATT_HOT_DETECT = 700

# average load of a single resistance
WATT_RES_LOAD = 766
# average residual load of the house when nothing is plugged
WATT_MIN_LOAD = 50

#####
import requests,collections,pathlib,time,random,statistics,os
from time import sleep
from datetime import datetime,timezone

dryrun = 'DRYRUN' in os.environ

def logDate(msg=""):
    print(datetime.now().strftime("%Y-%m-%d %H:%M:%S")+" "+msg)

def log(msg):
    print("  "+msg)

class CumulusRelay:
    def __init__(self):
        self.res = ["", "", ""]
        self.lastChangeTimestamp = 0
        self.hasBeenHot = False
        # this flag file mark if the cumulus has reach hot state in the current day
        # used by external scripts. once hot, the cumulus has not priority anymore
        self.hotFile = pathlib.Path("/tmp/cumulusHasBeenHot")
        self.resetNotHot()

    def __str__(self):
        resStr = str(self.res).replace("'", "")
        return f"n:{self.nbRes()} {resStr}"

    def initResistances(self):
        resp = requests.get(RELAY_CMD_URL+"state")
        data = resp.json()

        # we do not use first relay which is glithing at tasmota boot
        if   data["POWER2"] == "ON":   self.res[0] = "off"
        elif data["POWER2"] == "OFF":  self.res[0] = "on"
        if   data["POWER3"] == "ON":   self.res[1] = "off"
        elif data["POWER3"] == "OFF":  self.res[1] = "on"
        if   data["POWER4"] == "ON":   self.res[2] = "off"
        elif data["POWER4"] == "OFF":  self.res[2] = "on"

        self.setNbResFile()
        log(f"initResistances {self}")

    def nbRes(self):
        return self.res.count("on") + self.res.count("onLock")

    def setNbResFile(self):
        # used by piscine-pompe-soleil.sh
        with open("/tmp/cumulus-volume-soleil.nbres", "w") as f:
            f.write(str(self.nbRes()))

    def resetNotHot(self):
        self.hasBeenHot = False
        if self.hotFile.exists():
            self.hotFile.unlink()

    def setIfHot(self, conso):
        log(f"hasBeenHot test if {self.nbRes()} > 0 and {conso} < 700")
        if self.nbRes() > 0 and conso < WATT_HOT_DETECT:
            log("hasBeenHot=true")
            self.hasBeenHot = True
            self.hotFile.touch()
            self.unlockResistance()

    def setOneResistance(self, state):
        timest = int(time.time())
        if timest < self.lastChangeTimestamp + RELAY_LOCK_TIME:
            log(f"SKIP setOneResistance lastChangeTimestamp={self.lastChangeTimestamp}")
            return

        log("Set one Resistance "+state.upper())
        self.lastChangeTimestamp = timest

        invState = "off" if state == "on" else "on"

        cand=[] #candidates
        if self.res[0] == invState: cand.append(0)
        if self.res[1] == invState: cand.append(1)
        if self.res[2] == invState: cand.append(2)
        if len(cand) == 0: print("error len is 0"); return

        choice = random.choice(cand)
        
        self.resistanceCmd(choice, state)

    def resistanceCmd(self, numRes, cmd):
        log(f"Set resistance {numRes} to {cmd}...")

        realCmd = "OFF" if cmd == "on" else "ON"
        # we do not use first relay which is glithing at tasmota boot
        self.sendRelayCmd(numRes+2, realCmd)

        self.res[numRes] = cmd
        self.setNbResFile()

    def sendRelayCmd(self, numRes, cmd):
        if dryrun:
            log(f"DRYRUN: {RELAY_CMD_URL}Power{numRes}%20{cmd}")
            return
        resp = requests.get(f"{RELAY_CMD_URL}Power{numRes}%20{cmd}")
        resp.raise_for_status()

    def lockOneResistance(self):
        # if one resistance is on, mark it locked
        if   self.res[0] == "on": self.res[0] = "onLock"
        elif self.res[1] == "on": self.res[1] = "onLock"
        elif self.res[2] == "on": self.res[2] = "onLock"
        else:
            # else set it on and mark it
            self.resistanceCmd(0, "on")
            self.res[0] = "onLock"

    def unlockResistance(self):
        if   self.res[0] == "onLock": self.res[0] = "on"
        elif self.res[1] == "onLock": self.res[1] = "on"
        elif self.res[2] == "onLock": self.res[2] = "on"

class PowerInfo:
    def __init__(self):
        self.linkyMetrics = collections.deque(maxlen=METRICS_HISTORY)
        self.prodMetrics = collections.deque(maxlen=METRICS_HISTORY)

    def get(self):
        # get from shelly. returns lastwatt,maxwatt,prodwatt,conso
        resp = requests.get(POWER_STATUS_URL)
        data = resp.json()
        linky = int(data["emeters"][0]["power"])
        prod = int(data["emeters"][1]["power"])

        self.linkyMetrics.append(linky)
        self.prodMetrics.append(prod)

        maxwatt = max(self.linkyMetrics)
        prodwatt = int(statistics.mean(self.prodMetrics))
        conso = maxwatt + prod

        return linky,maxwatt,prodwatt,conso

######
        
powerInfo = PowerInfo()

cumu = CumulusRelay()

cumu.initResistances()

prevHour = hour = 0

while True:
    try:
        prevHour = hour
        hour = datetime.now(timezone.utc).hour

        # skip if not sun hours (4h-20h utc)
        if not (hour >= 4 and hour < 20):
            sleep(60); continue

        logDate()

        if hour == 4 and prevHour == 3: #at 4h00 utc
            log("Sun day begin")
            cumu.initResistances()
            cumu.resetNotHot()
        elif hour == 11 and prevHour == 10 and not cumu.hasBeenHot: #at 11h00 utc - the relay timer as well
            log("Ensure one resistance is ON and lock it")
            sleep(10) # let some time for the relay to switch
            cumu.initResistances()
            cumu.lockOneResistance()
            sleep(30) # wait a bit to see the effect for the setIfHot test !
        elif hour == 19 and prevHour == 18: #at 19h00 utc - the relay timer as well
            log("Force ON one resistance - finish")
            sleep(10) # let some time for the relay to switch
            cumu.initResistances()

        lastwatt,maxwatt,prodwatt,conso = powerInfo.get()
        nbres = cumu.nbRes()

        if not cumu.hasBeenHot:
            cumu.setIfHot(conso)

        if not cumu.hasBeenHot:
            log(f"TEST_NotHot {maxwatt} < {WATT_UP} ELIF {lastwatt} > {WATT_DOWN} {cumu}")

            if maxwatt < WATT_UP and nbres < 3:
                cumu.setOneResistance("on")
            elif lastwatt > WATT_DOWN and nbres > 0:
                cumu.setOneResistance("off")

        else: # cumulus has been hot
            theoricWatt = nbres * WATT_RES_LOAD + WATT_MIN_LOAD
            theoricWattPlus = theoricWatt + WATT_RES_LOAD

            log(f"TEST {maxwatt}<{WATT_UP} {theoricWattPlus}<{prodwatt} ELIF {lastwatt}>{WATT_DOWN} or {theoricWatt}>{prodwatt} {cumu}")
            
            # et à condition que ça n'aille pas trop haut sur la conso theorique
            # ou que par rapport au nombre de res la conso theorique est trop haute
            if maxwatt < WATT_UP and nbres < 3 and theoricWattPlus < prodwatt:
                cumu.setOneResistance("on")
            elif ( lastwatt > WATT_DOWN or theoricWatt > prodwatt ) and nbres > 0:
                cumu.setOneResistance("off")

    except Exception as e:
        print("ERROR: "+repr(e))

    sleep(SLEEP_INTERVAL)
