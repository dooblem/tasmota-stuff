#!/bin/sh -e

./tasmota-scr.sh sed pool-pump/pool-pump.scr
mv tmp.scr pool-pump/pool-pump.clean.scr
