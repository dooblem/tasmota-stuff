#!/bin/bash -e
# here is a simple script to upload a script to tasmota

slimit=2560

script="$1"
ip="$2"
action="$3"

[ "$script" = "" -o "$ip" = "" -o \( "$action" != "" -a "$action" != get \) ] && echo "Syntax $0 scriptFile tasmotaIp|gen [get]" && exit 1

cd "$(dirname $0)"

cp "$script" tmp.scr

sedFile="$script.sed"
if [ -f "$sedFile" ]; then
	grep -v -e '^#' -e '^ *$' "$sedFile" | while IFS= read -r line
	do
		sed -i "$line" tmp.scr
	done
fi

size=$(stat -c '%s' tmp.scr)
if [ "$size" -gt "$slimit" ]; then
	echo "script too big: $size > $slimit" && exit 2
fi

echo "size: $size <= $slimit"

[ "$ip" = "gen" ] && exit

curlArgs=
if [ -f "curl/$ip.args" ]; then
	curlArgs=$(cat "curl/$ip.args")
fi

# get the remote script
curl -sSf $curlArgs "$ip/s10" | sed -e 's/^.*<textarea[^>]*>//' -e 's|</textarea><script.*$||' >remote.scr

if diff -u remote.scr tmp.scr; then
  echo "remote and generated scripts are identical"
fi

[ "$action" = get ] && exit

read -p "Upload script ??? Enter to continue. Ctrl+C to abort."

# --trace-ascii -
curl -v -F c1=on -F t1="<tmp.scr" -F save= $curlArgs "$ip/ta"
