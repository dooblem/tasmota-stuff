# Pool Pump Sun Manager

## Screenshot

<img src="/img/tasmota_pool-pump.png" width="50%" alt="Pool Pump Sun Manager witch Tasmota - Screenshot" />

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

## Setup

Follow the [main README](../README.md) to flash Tasmota and upload the `pool-pump.scr` script.