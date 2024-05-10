#!/bin/sh
# here is a simple script to upload a script to tasmota

script="$1"
ip="$2"

[ "$script" = "" -o "$ip" = "" ] && echo "Syntax $0 scriptFile tasmotaIp" && exit 1


grep -v '^ *;' "$script" >/tmp/$0.tmp

# --trace-ascii -
curl -v -F c1=on -F t1="</tmp/$0.tmp" -F save= "$ip/ta"
