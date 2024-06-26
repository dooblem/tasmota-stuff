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
* Double click on the physical button will toggle "Sun Auto Mode"
* If configured properly the Led will show if "Sun Auto Mode" is enabled
* (optional) send plug power data to an influxdb database, or other http endpoint

## Requirements

A Tasmota device and an energy meter. See the [main README](../).

Hardware suggestions:
* [Athom Tasmota Plug V2](https://www.athom.tech/blank-1/EU-plug)
* [Athom Relay Switch](https://www.athom.tech/blank-1/sensor)

## Setup

See the [main README](../)

1. Flash Tasmota with scripting enabled.
1. Setup Important Tasmota configuration bellow
1. Get the `pool-pump.clean.scr` script.
1. Edit the script file, adjust the configuration to your needs (see bellow).
1. Upload the script to your device.

## Important Tasmota configuration

### Tasmota Template

In Tasmota Web User Interface, go to Configuration > Configure Template.

Take any free GPIO, and set it from `None` to `Relay` `2`: this will add a toggle button in the main web page, allowing to control "Sun Auto Mode". It can also be toggled with a double click on the physical button.

(optional) Take any other free GPIO, and set it from `None` to `Relay` `3`: this will add another button, allowing to control "Sun Unlimited Mode".

Those changes are shown on image bellow:  
<img src="/img/gpio_changes_relay.png" width="40%" alt="Tasmota Template Gpio changes - relays " />

Note: feel free to change the name of your device as well. Like "Pool Pump Sun Manager". It's displayed as main title of the Web UI.

Note 2: see led management bellow if your device has an extra led and you want to show the "Sun Auto Mode" status on it.

### Tasmota Console

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

## pool-pump.scr other configuration (optional)

### Check interval

The check interval is every 60s. Changing it requires also changing the incrementation of recorded minutes, and testing. Do not change it unless you know what you are doing.

### Save interval

Pump runtime minutes for today and yesterday are recorded and saved on flash only every hour. This is to avoid too many writes on flash memory, and breaking the flash.

It means that if your device loose power, you may loose at most 1 hour of recorded minutes (so your pump may run 1h longer that day).

You may decrease it a bit if you want, but keep it a multiple of 60s or the save will not work.

```
 if upsecs%3600==0 {
  svars
 }
```

### Power change sensitivity

You may not want to turn off the pump if a small cloud passes. And the opposite.

The defaults are set to 5 minutes. Feel free to change that:
```
if (pwr[1]==0 and pm<pmt and cnt<=-5 and cuOk==1)
```
Pump will be set ON if power is recorded bellow the threshold (`lkyON`) for 5 times (= 5 minutes).
```
if (pwr[1]==1 and ((pm>pmt and pwr[3]==0) or cnt>=5 or cuOk==0))
```
Pump will be set OFF if power is recorded above the threshold (`lkyOFF`) for 5 times (= 5minutes).

## LED Management for Sun Auto Mode (optional)

This extra configuration allows to show the "Sun Auto Mode" status on a LED. It's handy if you use the double click to switch the mode.

Requirement: a LED plugged on a GPIO. This is the case on Athom Monitoring Smart Plug.

In Tasmota Web User Interface, go to Configuration > Configure Template.

Note: on devices like the Athom Monitoring Smart Plug, there is 2 leds:
* a red led is hard wired to the relay power status. you cannot configure it.
* a blue led is on a GPIO and configurable: we will use it to show the "Sun Auto Mode" status
* the led colors blend behind the button: pink means that both leds are ON

Identify which GPIO is controlling your LED. On Athom Smart Plug it's GPIO13 which is configured as `LedLink` by default. This is your LED. Configure it as `Led_i` `2` so that it will show the status of `Relay` `2` (our "Sun Auto Mode" relay).

Additionnaly, you must:
* assign `LedLink` to any other free GPIO, in order to ignore any link status (as explained in Tasmota doc)
* assign `Led_i` `1` to any other free GPIO, in order to ignore relay 1 power led. Anyway it's already hardwired on the red led. Without that Tasmota will ignore led 2 and it's not working.

Those changes are shown on image bellow:  
<img src="/img/gpio_changes_led.png" width="40%" alt="Tasmota Template Gpio changes - Leds " />

Notes:
* the `_i` in `Led_i` stands for "inverted". Without that the LED is reversed.
* See also: [Tasmota Status LEDs Documentation](https://tasmota.github.io/docs/Lights/#status-leds)
