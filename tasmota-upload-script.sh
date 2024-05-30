#!/bin/bash
# here is a simple script to upload a script to tasmota

slimit=2560

script="$1"
ip="$2"

[ "$script" = "" -o "$ip" = "" ] && echo "Syntax $0 scriptFile tasmotaIp" && exit 1

# comments to remove: line start, spaces, ';', but no 'k' otherwise we keep the comment
grep -v '^ *;[^k]' "$script" >/tmp/$0.tmp

sedFile=$(dirname $0)/sed.cnf
if [ -f "$sedFile" ]; then
	while IFS= read -r line
	do
		sed -i "$line" /tmp/$0.tmp
	done < "$sedFile"
fi

size=$(stat -c '%s' "/tmp/$0.tmp")
if [ "$size" -gt "$slimit" ]; then
	echo "script too big: $size > $slimit" && exit 2
fi

echo=""
if [ "$ip" = "test" ]; then
	echo="echo"
	cat /tmp/$0.tmp
fi

# --trace-ascii -
$echo curl -v -F c1=on -F t1="</tmp/$0.tmp" -F save= "$ip/ta"

echo "size: $size <= $slimit"
