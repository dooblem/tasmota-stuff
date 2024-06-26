# Pool Pump Sun Manager

## Screenshot

<img src="/img/tasmota_pool-pump.png" width="40%" alt="Pool Pump Sun Manager witch Tasmota - Screenshot" />

## Features

* Start the pump when you export enough power (during X minutes)
* Stop the pump when you consume too much power from the grid (during X minutes)
* For each month of the year, define a daily target (maximum number of hours for the pump to run)
* The pump can then be forced at a fixed hour if the target is not reached (today+yesterday, but feel free to change the formula).
* You can disable "Sun Auto Mode" to switch manually the pump
* You can enable "Sun Unlimited" to ignore the daily maximum and always start the pump when energy is available.
* Double click on the physical button will toggle "Auto Mode"
* If configured properly the Led will show if "Auto Mode" is enabled
* (optional) send plug power data to an influxdb database, or other http endpoint

## Requirements

A Tasmota device and an energy meter. See the [main README](../).

Hardware suggestions:
* [Athom Tasmota Plug V2](https://www.athom.tech/blank-1/EU-plug)
* [Athom Relay Switch](https://www.athom.tech/blank-1/sensor)

## Setup

See the [main README](../)

1. Flash Tasmota with scripting enabled.
1. Get the `pool-pump.clean.scr` script.
1. Edit the script file, adjust the configuration to your needs (see bellow).
1. Upload the script to your device.

## pool-pump.scr important configuration

### shelly energy meter

Set IP address at the top of the script.

It expects the house general power to be on the 1st shelly clamp.

If it's different, say on the 2nd clamp, change this line in the script:

`http(ip "/emeter/0")` --> `http(ip "/emeter/1")`

### threshold values

Bellow `lkyON` (you are feeding energy to the grid), the pump is switched ON.

Above `lkyOFF` (you are consumming grid energy), the pump is switched OFF.

Be sure that `lkyON + your pump power` stays bellow `lkyOFF`, otherwise if the power stays the same it will flap (on, off, on, off and so on...).

```
; sensible values for a 300w pump:
lkyON=-250
lkyOFF=100
```

### Force hour

Hour of the day at which pump is forced if target is not reached (running time of pump today + yesterday has not reached target).

```
; set high to disable (fh=99)
fh=11
```

Feel free to change the formula to your needs in the code: `pm+pmy<pmt`

## Target runtime daily hours for each Month

In the `>B` section of the script, you can define the target runtime daily hours for each Month.

```
mo[4]=3.5
mo[5]=5
```

Means that the pump will run a maximum of 3h30 in april, and 5h in may.

## Important Tasmota configuration

In Tasmota Web User Interface, go to Tools > Console and configure the following.

```
; Relay 2 controls "Sun Auto Mode". Set it to ON for the script to run, otherwise your are in manual mode.
Power2 on

; Customise the text of the toggle buttons
WebButton1 Pool Pump
WebButton2 Sun Auto Mode
WebButton3 Sun Unlimited

; Be sure to reset Led config to default (LED on when power on)
LedState 1

; Disable power state scanning at restart. otherwise relay2 state is not kept
SetOption63 1
```

For more info see [Tasmota Commands documentation](https://tasmota.github.io/docs/Commands/).

## pool-pump.scr other configuration

### Check interval

The check interval is every 60s. Changing it requires also changing the incrementation of recorded minutes, and testing.

### Save interval

Pump runtime minutes for today and yesterday are recorded and saved on flash only every hour. This is to avoid too many writes on flash memory, and breaking the flash.

It means that if your device loose power, you may loose at most 1 hour of recorded minutes (so your pump may run 1h longer that day).

You may decrease it a bit if you want, but keep it a multiple of 60s or the save will not work.

```
 if upsecs%3600==0 {
  svars
 }
```
