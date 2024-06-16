#!/bin/bash -e
# here is a simple script to upload a script to tasmota

slimit=2560

applySedFile() {
  if [ -f "$1" ]; then
    grep -v -e '^#' -e '^ *$' "$1" | while IFS= read -r line
    do
      sed -i "$line" tmp.scr
    done
  fi
}

# output: tmp.scr
sedScr() {
  local script="$1"
  local ip="$2"

  cp "$script" tmp.scr
  applySedFile "hosts/$ip.sed"
  applySedFile "$script.sed"

  size=$(stat -c '%s' tmp.scr)
  if [ "$size" -gt "$slimit" ]; then
    echo "script too big: $size > $slimit" && exit 2
  fi

  echo "Generated ./tmp.scr size: $size <= $slimit"
}

# output: remote.scr
getScr() {
  # get the remote script
  curlArgs=$(getCurlArgs "$1")
  echo "Downloading ./remote.scr"
  curl -sSf $curlArgs "$1/s10" | sed -e 's/^.*<textarea[^>]*>//' -e 's|</textarea><script.*$||' >remote.scr
}

pushScr() {
  local ip="$1"
  local script="$2"

  sedScr "$script" "$ip"

  getScr "$ip"

  if diff -u remote.scr tmp.scr; then
    echo "remote and generated scripts are identical"
  fi

  read -p "Upload script ??? Enter to continue. Ctrl+C to abort."

  curlArgs=$(getCurlArgs "$ip")

  # --trace-ascii -
  curl -v -F c1=on -F t1="<tmp.scr" -F save= $curlArgs "$ip/ta"
}

getCurlArgs() {
  if [ -f "hosts/$1.curlargs" ]; then
    cat "hosts/$1.curlargs"
  fi
}

syntax() {
  echo "Syntax:

# push a script to a device
$0 push tasmotaIp scriptFile

# get the script from a device
$0 get tasmotaIp

# apply sed to file
$0 sed scriptFile
$0 sed tasmotaIp scriptFile
" && exit 1
}

cd "$(dirname $0)"

action="$1"

if [ "$action" = get ]; then
  [ "$2" = "" ] && syntax
  getScr "$2"

elif [ "$action" = sed ]; then
  [ "$2" = "" ] && syntax
  if [ "$3" = "" ]; then
    sedScr "$2"
  else
    sedScr "$3" "$2"
  fi

elif [ "$action" = push ]; then
  [ "$2" = "" -o "$3" = "" ] && syntax
  echo pushScr "$2" "$3"
  pushScr "$2" "$3"

else
  syntax
fi
