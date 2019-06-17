#!/usr/bin/python
###############################################################################
#
# pi_shutdown_switch.py
#
# Script for shutting down the raspberry Pi at the press of a button.
#
# Shutdown button is pin 7 (here: GPIO 04)
#
# https://pypi.python.org/pypi/RPi.GPIO
# https://sourceforge.net/p/raspberry-gpio-python/wiki/Inputs/
#
###############################################################################

import RPi.GPIO as GPIO
import time
import os

GPIO.setmode(GPIO.BOARD) # adresses the pins by the number of the pin in the plug
GPIO.setup(7, GPIO.IN, pull_up_down = GPIO.PUD_DOWN) # pin 7 is GPIO 04

def Shutdown(channel):
	print "Shutdown"
	os.system("sync;sync")
	os.system("sudo shutdown -h now")

GPIO.add_event_detect(7, GPIO.RISING, callback = Shutdown, bouncetime = 200)

while 1:
	time.sleep(1) # sleep 1 second

###############################################################################
# EOF
###############################################################################

