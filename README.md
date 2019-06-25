# 4004-SBC
## Overview
I built this Intel 4004 Single Board Computer a few years back to celebrate the 40th anniversary of the Intel 4004 CPU using ICs that I purchased on eBay. This homebrew, wire-wrap single board computer features:
- Intel 4004 CPU
- Intel 4201 Clock Generator
- Intel 4002 Static RAM (2X for a total of 640 bits of data memory)
- Intel 4289 Standard Memory Interface
- 2732 EPROM for program storage
- 4 LEDs controlled by an output port on one of the 4002s
- 16 position rotary switch for selection of program options
- RS232 console serial port

The firmware in the 2732 EPROM consists of 7 demo "apps" selectable by using the on-board 16 position rotary switch (see the comments in the EPROM firmware):
- position 1 - flash the red, amber and green LEDs to mimic the operation of a traffic signal
- position 2 - 16 digit addition demo from the "MCS-4 Micro Computer Set User's Manual"
- position 3 - echo characters received through the serial port
- position 4 - turn on the red, amber, green and blue LEDs to match the position of the rotary switch
- position 5 - flash the LEDs from right to left and then from left to right in a "Knight Rider" or "Cylon" type pattern
- position 6 - flash the LEDs from right to left in a "chaser" type pattern
- position 7 - display the position of the rotary switch through the serial port
