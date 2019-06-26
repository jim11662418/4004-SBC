# Home-brew Intel 4004 Single Board Computer
### Overview
I built this Intel 4004 Single Board Computer a few years back to celebrate the 40th anniversary of the Intel 4004 CPU using ICs that I purchased on eBay. This homebrew, wire-wrap single board computer features:
- Intel 4004 CPU
- Intel 4201 Clock Generator
- Intel 4002 Static RAM (2X for a total of 640 *bits* of data memory)
- Intel 4289 Standard Memory Interface
- 2732 EPROM for program storage
- 4 LEDs controlled by an output port on one of the 4002s
- 16 position rotary switch for selection of program options
- RS232 console serial port
<figure>
  <img src="/images/4004%20SBC.jpg"/>
</figure>
<p align="center">Home-brew Intel 4004 SBC<p align="center">

The firmware in the 2732 EPROM consists of 7 demo "apps" selectable by using the on-board 16 position rotary switch (see the comments in the EPROM firmware):
- position 1 - flash the red, amber and green LEDs to mimic the operation of a traffic signal
- position 2 - 16 digit addition demo from the "MCS-4 Micro Computer Set User's Manual"
- position 3 - echo characters received through the serial port
- position 4 - turn on the red, amber, green and blue LEDs to match the position of the rotary switch
- position 5 - flash the LEDs from right to left and then from left to right in a "Knight Rider" or "Cylon" type pattern
- position 6 - flash the LEDs from right to left in a "chaser" type pattern
- position 7 - display the position of the rotary switch through the serial port

### 4004 SBC CPU and Memory
The CPU and Memory section of the Single Board Computer consists of an Intel 4004 CPU, a 4201 Clock Generator, two 4002 RAM chips with output ports (for a total of 640 bits of RAM), a 4289 Standard Memory Interface which provides the interface to a 2732 4K EPROM for program memory.
<figure>
  <img src="/images/4004%20SBC%20CPU.png"/>
</figure>
<p align="center">4004 SBC CPU and Memory<p align="center">

### 4004 SBC I/O
The Input/Output section of the 4004 Single Board Computer consists of two 4 bit output ports and two 4 bit input ports. The two 4002 RAM chips provide the output ports. A 74LS244 octal buffer provides the two input ports.

One of the output ports (address 0x40) is used to control the four LEDs. One bit of the second output port (address 0x00) is used to provide a bit-banged RS232 serial transmit output.

One of the input ports (address 0x10) is used to read a four bit, sixteen position rotary switch. One bit of the second input port (address 0x00) is used for the RS232 serial receive input.

The 4049 CMOS Inverters are used as buffers and level converters.
<figure>
  <img src="/images/4004%20SBC%20IO.png"/>
</figure>
<p align="center">4004 SBC I/O<p align="center">

### 4004 SBC Power Supply
The 4004 single board computer's power supply shown below uses a Radio Shack transformer and a dual linear adjustable power supply module that I purchased on eBay to produce to +5VDC and -10VDC that the SBC requires. Connections between the power supply and SBC use common 5 pin DIN connectors.
<figure>
  <img src="/images/4004%20SBC%20PS.png"/>
</figure>

<figure>
  <img src="/images/Power%20Supply.jpg"/>
</figure>
<p align="center">4004 SBC Power Supply<p align="center">

### 4004 SBC Firmware
The [4004 SBC firmware](4004%20SBC%20Source.asm) was assembled with the [Macro Assembler AS](http://john.ccac.rwth-aachen.de:8000/as/).
