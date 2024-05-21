Some script I've been using to manage water heater and pool pump with the sun:
* `telegraf_shellyem-status.conf`
  * config to read json data from shelly (2 clamps)
* `cumulus-onoff-soleil.sh`
  * every min cronjob to start/stop water heater with the sun (all or nothing)
* `cumulus-volume-soleil.sh`
  * a systemd service to adjust 3 water heater resistors. influxdb required. Replaced with python version bellow.
* `cumulus-volume-soleil.py`
  * a systemd service to adjust 3 water heater resistors. no influxdb required. reads directly from shelly em. Replaced with a Tasmota script. see `../relai4.scr`
* `piscine-pompe-soleil.sh`
  * every min cronjob to start/stop pool pum with the sun. Replaced with a Tasmota script. see `../pool-pump.scr`