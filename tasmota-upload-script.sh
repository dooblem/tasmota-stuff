#!/bin/bash -e
# here is a simple script to upload a script to tasmota

slimit=2560

script="$1"
ip="$2"

[ "$script" = "" -o "$ip" = "" ] && echo "Syntax $0 scriptFile tasmotaIp" && exit 1

cd "$(dirname $0)"

# comments to remove: line start, spaces, ';', but no 'k' otherwise we keep the comment
#grep -v '^ *;[^k]' "$script" >/tmp/$0.tmp
grep -v -e '^ *;' -e '^ *$' "$script" >tmp.scr
#sed -i '/^ *;k/s/;k;/;/' /tmp/$0.tmp

sedFile=sed.cnf
if [ -f "$sedFile" ]; then
	while IFS= read -r line
	do
		sed -i "$line" tmp.scr
	done < "$sedFile"
fi

size=$(stat -c '%s' tmp.scr)
if [ "$size" -gt "$slimit" ]; then
	echo "script too big: $size > $slimit" && exit 2
fi

echo=""
if [ "$ip" = "test" ]; then
	echo="echo"
	cat tmp.scr
fi

# --trace-ascii -
$echo curl -v -F c1=on -F t1="<tmp.scr" -F save= "$ip/ta"

echo "size: $size <= $slimit"
