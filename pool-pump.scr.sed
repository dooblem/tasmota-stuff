s/__SHELLY_IP__/192.168.1.X/
# remove comments except ;k comments
/^;$/d
/^ *;[^k]/d
# replace ;k; with ; in ;k comments
/^ *;k/s/;k;/;/
# remove empty lines
/^ *$/d
