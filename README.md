Tasmota scripts for various applications.

In this repo:
* `.vimrc`: a simple vimrc config to force syntax to lisp for tasmota scripts
* `tasmota-scr.sh`: a shell script to upload directly a script to a module (because coding is a pain with default web ui)
* `shelly2influx/` directory: a script to get power data from shelly EM and upload it to an influxdb server
* `pool-pump/` directory: a script to manage a pool-pump reading info from a shelly EM 
* `water-heater/` directory: a simple solar inverter script for a 4 channel relay
* `other/` directory: bash/python versions of the Tasmota scripts to manage pool pump and water heater

## Get a Tasmota device

Those scripts have been tested with the following Hardware (you can check in Tasmota information webpage): ESP8266EX, ESP8285H16

But they should work on any ESP82xx devices. They should also work on ESP32, though it will require compiling Tasmota for it. TODO port the script to the new Berry scripting language.

I bought my devices on [Athom website](https://www.athom.tech). They come with Tasmota preflashed.

## Get a Shelly EM or other energy meter

Most of the scripts needs a way to monitor the power consumption of the house.

I'm using a [Shelly](https://www.shelly.com) EM (Electric Meter) with 2 power clamps: 1st on house consumption/feed-in, 2nd on solar production.

Not tested, but it's certainly possible to use another energy monitoring device, with slight code changes.

For french users, the [Denky D4 ESP32 TIC Teleinfo Reader](https://www.tindie.com/products/hallard/denky-d4-esp32-tic-teleinfo-reader/) would be a good choice as well!

## Instructions

Those Tasmota scripts require that you flash your Tasmota device with scripting enabled.

Unfortunately as of now Tasmota requires you to compile Tasmota with scripting enabled.

If you trust me you can download and use the Tasmota binary I compiled and that I'm using for my own devices.

See bellow if you want to compile Tasmota yourself.

1. get the `tasmota-scripting.bin.gz` and `tasmota-minimal.bin.gz` files from [releases](https://github.com/dooblem/tasmota-stuff/releases).

2. flash the `tasmota-scripting.bin.gz` file using Tasmota web interface. You will probably need to flash the `tasmota-minimal.bin.gz` file first, then flash the scripting version.

3. upload a script using `tasmota-scr.sh`:
```
./tasmota-scr.sh push 192.168.1.XX pool-pump/pool-pump.scr
```
It will download the current script from your device and show you the differences with the script you want to upload.
Just press enter to confirm the upload.

4. go into your device web console, and check that the script has been uploaded correctly:
```
11:51:21.002 SCR: compressed to 1166 bytes = 70 %
```
You may see a compress error if the script is too big. This is not good: the script will not work correctly, or may be truncated at next restart.

## If you want to compile Tasmota yourself

Otherwise you must compile Tasmota. The only changes I made are in the `user_config_override.h` file. 

Clone the Tasmota repo, then switch to the commit I used:
```
git clone  https://github.com/arendst/Tasmota
cd Tasmota
git checkout 27d2a0a2d52d4430795812439952338fae177c89
cp user_config_override.h tasmota/
```

I used platformio to compile under Ubuntu Linux, in cli: [Create your own firmware build without IDE](https://tasmota.github.io/docs/Create-your-own-Firmware-Build-without-IDE/)

* [Install pythn and tools](https://tasmota.github.io/docs/Create-your-own-Firmware-Build-without-IDE/#install-python-and-tools)
* [Prepare platformio in a virtualenv](https://tasmota.github.io/docs/Create-your-own-Firmware-Build-without-IDE/#prepare-a-platformio-core-environment-contained-in-a-folder)
* [Configure the sources](https://tasmota.github.io/docs/Create-your-own-Firmware-Build-without-IDE/#configure-the-sources) (put the `user_config_override.h` file)

Then use the following command to build only standard tasmota and not all the variations:
```
~/.platformio/penv/bin/platformio run -e tasmota
```