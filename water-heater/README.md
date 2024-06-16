# Simple solar diverter - 3 resistor water heating

If your water heater has 3 resistors, you can modify it to be able to modulate the heating volume from 1 to 3.

<img src="/img/water_heater_3_resistors.jpg" width="50%" alt="Some water heater with 3 resistors" />

Just add a relay on each of the 3 red wires to be able to choose if you allow heating or not.

You will probably have to add 2 long wires per red wire (6 in total). Be sure to choose the right cables (1.5mm2 is just enough in my case but to be sure use 2.5mm2 cables).

I used the cheap (~20$) [Athom 4 channels relay](https://www.athom.tech/blank-1/4ch-inching-self-lock-relay). It comes pre flashed with the Tasmota firmware. But you may choose another relay.

<img src="/img/athom_relay_4_channels_tasmota.jpg" width="50%" alt="water heater 3 resistors plugged to Athom 4 channels relay" />

I used the NC (Normaly Closed) holes on the relay, so that if anything happen (hardware problem, software bug...), the resistors are wired and the water heater is (almost) at it's original state.

The switch bellow can be used to cut the power on the relay, to get hot water rapidly if any problem.

Avoid using the first relay: not a big deal, but it may flap a bit when booting. Apparently there is a hardware glitch. It's documented somewhere in a Tasmota issue.

I'm using a [Shelly](https://www.shelly.com) EM (Electric Meter) with 2 power clamps: 1st on house consumption/feed-in, 2nd on solar production.

And here is the result on a not so sunny day (2024-05-15, Toulouse, 5.5kw peak) (water heater power is in black color):
![Grafana not so sunny day](/img/grafana.png)

And on a realy bad day, one resistor is locked ON in the middle of the day (2024-04-15):
![Grafana not so sunny day](/img/grafana-bad-day.png)
