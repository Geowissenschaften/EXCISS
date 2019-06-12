# MCU firmware

It is the flight ready source code, but it requires some cleanup.

The firmware is tailored to meet the requirements for the EXCISS mission.
For other type of missions, it is required to change mission specific part of the source code.

Some library's are fork of existing library's. Mainly the i2c and onewire library's are heavily modified to prevent any blocking caused by faulty components.

The battery management library requires some additional work to be able to use for other applications.
