    PAGE 0          ;suppress page headings in ASW listing file
    
;------------------- Serial Port = 110 bits/second ------------------------------------------------
    
;--------------------------------------------------------------------------------------------------
; Demo
;
; Use the rotary option switch to select the demo program...
;
; Switch position 1 - flash the red, amber and green LEDs to mimic the operation of a traffic signal
;        position 2 - 16 digit addition demo.
;        position 3 - echo characters received through the serial port.
;        position 4 - turn on the red, amber, green and blue LEDs to match the position of the rotary switch.
;        position 5 - flash the LEDs from right to left and then from left to right in a "Knight Rider" or "Cylon" type pattern.
;        position 6 - flash the LEDs from right to left in a "chaser" type pattern
;        position 7 - display the position of the rotary switch through the serial port
; 
; Any other switch position defaults to option 1.
;
; Positions 2, 3 and 7 require the use of a serial terminal for communications.
; Set up terminal to emulate a TTY: 110 bps, no parity, 7 data bits, 1 stop bit
;----------------------------------------------------------------------------------------------------
; Tell ASW this is for the Intel 4004.
            cpu 4004

; Conditional jumps that ASW recognizes:
; jcn t     jump if test=0
; jcn tn    jump if test=1
; jcn c     jump if cy=1
; jcn cn    jump if cy=0
; jcn z     jump if accumulator=0
; jcn zn    jump if accumulator!=0

;Include bit functions so that fin can be loaded from a label (upper 4 bits of address are loped off).
            include "bitfuncs.inc"		

;include 4004 register definitions            
            include "reg4004.inc"
    
CR          equ 0DH
LF          equ 0AH
ESC         equ 1BH
EOM         equ 0FFH    ;used to indicate end of message string

MARK        equ 0001B

;I/O port addresses
SERIALPORT  equ 00H     ;address of the serial port. the least significant bit of port 00 is used for both serial input and output
LEDPORT     equ 40H     ;address of the port used to control the LEDs. "1" turns the LEDs on
SWITCHPORT  equ 10H     ;address of the input port for the rotary switch. switch contacts pull the bits low, i.e. switch position "2" gives "1101".

;data memory addresses
CHIP0REG0   equ 00H     ;4002 data ram chip 0, register 0 16 main memory characters plus 4 status characters
CHIP0REG1   equ 10H     ;4002 data ram chip 0, register 1  "   "    "         "       "  "    "       "
CHIP0REG2   equ 20H     ;4002 data ram chip 0, register 2  "   "    "         "       "  "    "       "
CHIP0REG3   equ 30H     ;4002 data ram chip 0, register 3  "   "    "         "       "  "    "       "
CHIP1REG0   equ 40H     ;4002 data ram chip 1, register 0  "   "    "         "       "  "    "       "
CHIP1REG1   equ 50H     ;4002 data ram chip 1, register 1  "   "    "         "       "  "    "       "
CHIP1REG2   equ 60H     ;4002 data ram chip 1, register 2  "   "    "         "       "  "    "       "
CHIP1REG3   equ 70H     ;4002 data ram chip 1, register 3  "   "    "         "       "  "    "       "
            
GREENLED    equ 0001B   ;bit pattern to turn the green LED on, all others off
AMBERLED    equ 0010B   ;bit pattern to turn the amber LED on, all others off
REDLED      equ 0100B   ;bit pattern to turn the red   LED on, all others off
BLUELED     equ 1000B   ;bit pattern to turn the blue  LED on, all others off

;--------------------------------------------------------------------------------------------------
;Power on Reset Entry
;--------------------------------------------------------------------------------------------------
            org 0

reset:      nop
            ldm 0
            fim P0,LEDPORT
            src P0 
            wmp                 ;write data to RAM port 40H, set all 4 outputs low to turn off all four LEDs
            
            ldm MARK
            fim P0,SERIALPORT
            src P0 
            wmp                 ;set serial port output high (MARK) 

            jms hundredmsec     ;100 millisecond delay to clear the receiving serial port

            fim P0,SWITCHPORT
            src P0
            rdr                 ;read ROM port 10H (switches)
            cma                 ;complement the accumulator since the switch contacts pull the bits low
            xch R3              ;put switch setting into R3
            
test7:      ldm 7               ;is the switch in position 7?
            clc
            sub R3
            jcn nz,test6        ;jump to next test if no match
            jun option7         ;jump to option 7 for switch position 7 (display switch position)                    
            
test6:      ldm 6               ;is the switch in position 6?
            clc
            sub R3
            jcn nz,test5        ;jump to next test if no match
            jun option6         ;jump to option 6 for switch position 6 (flashing LEDs)            

test5:      ldm 5               ;is the switch in position 5?
            clc
            sub R3
            jcn nz,test4        ;jump to next test if no match
            jun option5         ;jump to option 5 for switch position 5 (flashing LEDs)
            
test4:      ldm 4               ;is the switch in position 4?
            clc
            sub R3
            jcn nz,test3        ;jump to next test if no match
            jun option4         ;jump to option 4 for switch position 4 (LEDs controlled with switch)

test3:      ldm 3               ;is the switch in position 3?
            clc
            sub R3
            jcn nz,test2        ;jump to next test if no match
            jun option3         ;jump to option 3 for switch position 3 (serial port demo)

test2:      ldm 2               ;is the switch in position 2?
            clc
            sub R3
            jcn nz,default      ;default to option 1 if no match
            jun option2         ;jump to option 2 for switch position 2 (16 digit addition demo)

default:    jun option1         ;if no matches, use option 1 as default (LEDs flash like traffic signal)

;use the remaining space in page 0 for utility subroutines

;--------------------------------------------------------------------------------------------------            
;From the the "MCS-4 Micro Computer Set Users Manual" page 166:
;8 bit compare
;Compare the contents of P1 with P3. Returns with acc = 0 if the register
;pair contents are equal. Returns with acc = 1 if the comparison fails.
;--------------------------------------------------------------------------------------------------            
compare:    clc
            xch R7
            sub R3              ;compare the low nibbles (by subtraction)
            jcn zn,notequal     ;jump if the accumulator is not zero (low nibbles not equal)
            clc
            xch R6
            sub R2              ;compare the high nibbles (by subtraction)
            jcn zn,notequal     ;jump if the accumulator is not zero (high nibbles not equal)
            bbl 0               ;both register pairs are equal
notequal:   bbl 1               ;register pairs are not equal        

;--------------------------------------------------------------------------------------------------
;From the MCS-4 Assembly Language Programming Manual Dec.73 pages 4-8 through 4-12.

;The following subroutine produces the AND, bit by bit, of the two 4-bit quantities
;held in index registers R0 and R1. The result is placed in register R0, while register
;R1 is set to 0. Index registers R2 and R3 are also used.

;For example, if register R0 = 1110B and register R1 = 0011B, register R0 will be
;replaced with 0010B.

;The subroutine produces the AND of two bits by placing the bits in the leftmost
;position of the accumulator and register R2, respectively, and zeroing the rightmost
;three bits of the accumulator and register R2. Register R2 is then added to the
;accumulator, and the resulting carry is equal to the AND of the two bits.
;--------------------------------------------------------------------------------------------------            
_and:	    ldm 0 		        ;acc = 0
            xch R0 		        ;acc = R0, R0 = acc (zero)
            ral 		        ;1st "and" bit to carry
            xch R0 		        ;save shifted data in R0; acc = 0
            inc R3 		        ;done if R3 = 0
            xch R3 		        ;R3 to acc
            jcn z,and1	        ;return if acc = 0
            xch R3 		        ;otherwise restore acc and R3
            rar 		        ;bit of R0 is alone in acc
            xch R2 		        ;save 1st 'and' bit in R2
            xch R1 		        ;get bit of R1
            ral 		        ;left bit to carry
            xch R1 		        ;save shifted data in R1
            rar 		        ;2nd 'and' bit to acc
            add R2 		        ;'add' gives 'and' of the 2 bits in carry
            jun _and 	
and1:   	bbl 0 		        ;return to main program		

;--------------------------------------------------------------------------------------------------
;The following subroutine produces the logical OR, bit by bit, of the two 4 bit quantities
;held in index registers R0 and R1. The result is placed in register R0, while register
;R1 is set to 0. Index registers R2 and R3 are also used.

;For example, if register R0 = 0100B and register Rl = 0011B, register R0 will be
;replaced with 0111B.

;The subroutine produces the OR of two bits by placing the bits in the leftmost
;position of the accumulator and register R2, respectively, and zeroing the rightmost
;three bits of the accumulator and register R2. Register R2 is then added to the
;accumulator. If the resulting carry = 1, the OR of the two bits = 1. If the resulting
;carry = 0, the OR of the two bits is equal to the leftmost bit of the accumulator.
;--------------------------------------------------------------------------------------------------            
_or: 		ldm 0 		        ;acc = 0
            xch R0 		        ;acc = R0, R0 = acc (zero)
            ral 		        ;1st 'or' bit to carry
            xch R0 		        ;save shifted data in R0; acc = 0
            inc R3 		        ;done if R3 = 0
            xch R3 		        ;R3 to acc
            jcn z,or1 	        ;return if acc = 0
            xch R3 		        ;otherwise restore acc and R3
            rar 		        ;bit of R0 is alone in acc
            xch R2 		        ;save 1st 'or' bit in R2
            ldm 0 		        ;get bit in R1;set acc = 0
            xch R1
            ral 		        ;left bit to garry
            xch R1 		        ;save shifted data in R1
            rar 		        ;2nd 'or' 'bit to acc
            add R2 		        ;produce the or of the bits.
            jcn c,_or 	        ;jump if carry = 1 because 'or' = l
            ral 		        ;otherwise 'or' = left bit of accumulator, transmit to carry by ral
            jun _or 	
or1:    	bbl 0 		        ;return to main program

;--------------------------------------------------------------------------------------------------
;The following subroutine produces the exclusive OR of the two 4-bit quantities
;held in index registers R0 and R1. The result is placed in register R0, while register
;R1 is set to 0. Index registers R2 and R3 are also used.

;For example if register R0 = 0011B and register R1 = 0010B, register R0 will be
;replaced with 0001B.

;The subroutine produces the XOR of two bits by placing the bits in the leftmost
;position of the accumulator and register R2, respectively, and zeroing the rightmost
;three bits of the accumulator and register R2. Register R2 is then added to the
;accumulator. The XOR of the two bits is then equal to the leftmost bit of the
;accumulator.
;--------------------------------------------------------------------------------------------------            
_xor:	    ldm 0 		        ;acc = 0
            xch R0 		        ;acc = R0, R0 = acc (zero)
            ral 		        ;1st 'xor' bit to carry
            xch R0 		        ;save shifted data in R0; acc = 0
            inc R3 		        ;done if R3 = 0
            xch R3 		        ;R3 to acc
            jcn z,xor1      	;return if acc = 0.
            xch R3 		        ;otherwise restore acc & R3
            rar 		        ;bit of R0 is alone in acc
            xch R2 		        ;save 1st xor bit in R2
            ldm 0 		        ;get bit in R1;set acc = 0
            xch R1
            ral 		        ;left bit to carry
            xch R1 		        ;save shifted data in R1
            rar 		        ;2nd 'xor' bit to acc
            add R2 		        ;produce the xor of the bits
            ral 		        ;xor = left bit of accumulator, transmit to carry by ral.
            jun _xor	
xor1:   	bbl 0		        ;return to main program

;--------------------------------------------------------------------------------------------------            
; The following delays assume a 5.068 MHz crystal/7 = 724 KHz clock which yields 1.38121 microsecond clock period.
; Each instruction cycle is 8 clock periods so: 1.38121 microseconds * 8 = 11.04968 microseconds/instruction cycle.
; Uses P6 and P7 (R12, R13, R14, R15).
;--------------------------------------------------------------------------------------------------
;90501 cycles * 11.04968 microseconds/cycle = 1,000,007.08 microseconds    
onesecond:  fim P6,0E4H         ;R12 = 14, R13 =  4
            fim P7,0A5H         ;R14 = 10, R15 =  5
            jun delayloop

;45251 cycles * 11.04968 microseconds/cycle = 500,009.06 microseconds    
halfsecond: fim P6,092H         ;R12 =  9, R13 =  2
            fim P7,0DAH         ;R14 = 13, R15 = 10
            jun delayloop

;22625 cycles * 11.04968 microseconds/cycle = 249999.01 microseconds    
quartersec: fim P6,079H         ;R12 = 7, R13 =  9
            fim P7,06DH         ;R14 = 6, R15 =  13
            jun delayloop
            
;9051 cycles * 11.04968 microseconds/cycle = 100,010.65 microseconds    
hundredmsec:fim P6,027H         ;R12 =  2, R13 =   7
            fim P7,0FEH         ;R14 = 15, R15 =  14
            jun delayloop
            
;905 cycles * 11.04968 microseconds/cycle = 9,999.96 microseconds    
tenmsec:    fim P6,0D5H         ;R12 = 13, R13 =  5
            fim P7,0EFH         ;R14 = 14, R15 = 15
            jun delayloop

;91 cycles * 11.04968 microseconds/cycle = 1,005.52 microseconds    
onemsec:    fim P6,0ADH         ;R12 = 10, R13 = 13
            fim P7,0FFH         ;R13 = 15, R15 = 15
            
delayloop:  isz R12,delayloop
            isz R13,delayloop
            isz R14,delayloop
            isz R15,delayloop
            bbl 0       
            
;--------------------------------------------------------------------------------------------------            
;send the character in P1 (R2 and R3) to the serial port
;in addition to P1 (R2 and R3) also uses P5 (R10 and R11), P6 (R12 and R13) and P7 (R14 and R15)
;NOTE: destroys P1, make sure that the character in P1 is saved elsewhere!
;--------------------------------------------------------------------------------------------------            

putc:       clc
            jms sendbit     ;send the start bit
            nop
            
            ld R2           ;get the most significant nibble of the character from R2
            ral
            stc
            rar             ;set the most significant bit (the stop bit)
            xch R2          ;save the most significant nibble of the character in R2            

            ldm 16-8        ;7 data bits and 1 stop bit to send
            xch R10         ;R10 is used as the bit counter
            
;each bit takes 823 cycles * 11.04968 microseconds/cycle = 9.093 milliseconds/bit
shftbit:    ld R2           ;get the most significant nibble of the character from R2
            rar             ;shift the least significant bit into carry
            xch R2          ;save the result in R2 for next time
            ld R3           ;get the least significant nibble of the character from R3
            rar             ;shift the least significant bit into carry 
            xch R3          ;save the result in R3 for next time
            jms sendbit     ;send the carry bit
            nop
            isz R10,shftbit ;do it for all 8 bits in R2,R3
            
            bbl 0
          
;812 cycles       
sendbit:    tcc             ;transfer the carry bit to the least significant bit of the accumulator
            fim P6,SERIALPORT
            src P6          ;address of serial port for I/O writes
            wmp             ;write the least significant bit of the accumulator to the serial output port
            fim P6,0A8H
            fim P7,0EFH
bittimer:   isz R12,bittimer
            isz R13,bittimer
            isz R14,bittimer
            isz R15,bittimer
            bbl 0       
            
            
;----------------------------------------------------------------------------
; Traffic Signal
; Turn red, amber and green LEDs on and off to simulate the operation of a traffic signal.
; Switch position #1 jumps here.
;----------------------------------------------------------------------------
            org 0100h

GREENTIME   equ 6               ;green LED on for 6 seconds
AMBERTIME   equ GREENTIME/3     ;amber LED on for one third as long as the green LED
REDTIME     equ GREENTIME       ;red LED on for as long as green LED

option1:    ldm GREENLED
            fim P0,LEDPORT
            src P0
            wmp                 ;write data to LEDPORT, turn on green LED (high turns the LED on)
            ldm 16-GREENTIME
            xch R10
greendelay: jms onesecond       ;delay for GREENTIME seconds
            isz R10,greendelay
            
            ldm AMBERLED
            fim P0,LEDPORT
            src P0
            wmp                 ;write data to LEDPORT, turn on amber LED (high turns the LED on)
            ldm 16-AMBERTIME
            xch R10
amberdelay: jms onesecond       ;delay for AMBERTIME seconds
            isz R10,amberdelay
            
            ldm REDLED
            fim P0,LEDPORT
            src P0
            wmp                 ;write data to LEDPORT, turn on red LED (high turns the LED on)
            ldm 16-REDTIME
            xch R10
reddelay:   jms onesecond       ;delay for REDTIME seconds
            isz R10,reddelay

            jun option1
  
;-------------------------------------------------------------------------------
; Sixteen digit decimal addition program.
; Switch position #2 jumps here.

; from page 77 of the "MCS-4 Micro Computer Set Users Manual" Feb. 73:

;  "An MCS-4 program has been developed to demonstrate both the control
;   and arithmetic features of this microcomputer system.  This
;   program adds a sixteen digit integer to the content of the accumulator
;   and prints the new content of the accumulator."

;  "Input and output capability is provided by an ASR 33 teletype."
;   The TTY, keyboard interrogation, arithmetic operation, and TTY
;   printer output are all controlled by the CPU (4004) using this
;   special decimal addition program."

;  "Enter from one to sixteen integers from the tty keyboard.
;   If fewer than sixteen digits are entered, press the '+' key."

;  "The number entered is added to the contents of the accumulator."

;  "This procedure may be repeated until the contents of the sixteen
;   digit accumulator overflows (X's will be printed). This overflow
;   will automatically reset the system."

; Notes:
; The source code from the users manual was modified slightly to match the ASW cross-assembler syntax.
; Some examples: FIM 0<;0  changed to: fim P0,0
;                SRC 0<       "     "  src P0
;                INC 4        "     "  inc R4
;                ISZ 7,REP    "     "  isz R7,rep

; The source code has also been altered to use bit 0 of port 0 as the serial input instead of the 4004 CPU test input.
; Since the bit timing is not exactly right for 110 bps using a 5.068 MHz crystal instead of the expected 5.180 MHz crystal, 
; the timing has been tweaked a bit to make it work.

; Set up the terminal emulator to emulate a TTY (110 bps, 7 bits 1 stop bit, no parity).
;--------------------------------------------------------------------------------
            
            org 0200h

option2:    jun instruct    ;jump to page 0F00H to display abbreviated instructions for the 16 digit addition program
       
decimal:    ldm 15          ;set RAM port 0 to 1111
            fim P0,00
            src P0
            wmp
            ldm 0
            
            fim P2,0        ;R3 = 0, R4 = 0
            
            fim P3,10       ;R6 = 0, R7 = 10
rp:         src P2
            wrr
            inc R4
            isz R7,rp
            
next:       ldm 0           ;set digit counter (16)
            xch R13         ;R13 = 0
            
            fim P2,48       ;R4 = 3, R5 = 0
            jms clrram      ;clear RAM
            
            jms crlf        ;position carriage
            clc

            ;test tty/kbd inputs
st:         fim P0,0
            src P0
            rdr   
            rar   
            jcn c,st

            jms sbr1
            
            fim P0,13       ;R0 = 0, R1 =13
            src P0
            rdr
            wmp
            jms sbr2
            fim P0,0        ;R0 = 0, R1 = 0
            ldm 0
            xch R2          ;R2 = 0
            ldm 0
            xch R3          ;R3 = 0
            ldm 8
            xch R4          ;R4 = 8
            
st1:        jms sbr1
            clc
            src P0
            rdr             ;read data input
            wmp
            rar             ;store data in carry
            ld R2           ;acc = R2
            rar             ;transfer bit
            xch R2          ;restore new data word
            ld  R3
            rar
            xch R3          ;extend R2-R3 to make 8 bits
            jms sbr2
            isz R4,st1

            ldm 15
            fim P0,0
            src P0
            wmp
comadd:     ldm 11
            sub R3
            clc
            
            jcn z,additn    ;if ac = 0; jump
            
write:      fim P4,64       ;R8 = 8; R9 = 0
            ld R3
            src P4
            wrr
            inc R8
            ld  R2
            src P4
            wrr
            
store:      fim P0,1        ;R0 = 0; R1 = 1

            fim P2,63       ;R4 = 3; R5 = 15
            
            fim P3,62       ;R6 = 3; R7 = 14
rep1:       src P3
            rdm
            src P2
            wrm
            ld  R5
            dac
            xch R5
            clc
            ld  R7
            dac    
            xch R7
            clc
            
            isz R1,rep1
            ld  R3
            src P2
            wrm
            
            isz R13,st
            
additn:     jms crlf        ;position carriage
            
            fim P0,0        ;R0 = 0; R1 = 0
            
            fim P2,48       ;R4 = 3; R5 = 0
            ldm 0
            xch R6
            clc
ad1:        src P2
            rdm
            src P0
            adm
            daa
            wrm
            inc R1
            inc R5
            
            isz R6,ad1
            
overfl:     jcn c,xxx       ;test for carry

            fim P6,15       ;R12 = 0; R13 = 15
            ldm 0
            xch R10
            
            fim P2,10
            ldm 1
            src P2
            wr0
ad2:        src P2
            rd0
            rar
            src P6
            rdm
            
            jcn zn,skp1     ;test for ac != 0
            
            jcn c,skip      ;test for cy=1
skp1:       xch R3
            ldm 11
            xch R2
            ldm 0            
            src P0
            wr0
            
            jms print
skip:       ld  R13
            dac
            xch R13
            isz R10,ad2
            
            jun next
xxx:        ldm 0
            xch R10
            
ovfl1:      fim P1,216      ;R1 = 8; R2 = 13

            jms print
            
            isz R10,ovfl1
            
            fim P2,0
            
            jms clrram
            jun next

;clear ram subroutine from page 80 of the "MCS-4 Micro Computer Set Users Manual" Feb.73 
clrram:     ldm 0
            xch R1
clear:      ldm 0
            src P2 
            wrm    
            inc R5 
            isz R1,clear
            bbl 0

;timing subroutines from page 80 of the "MCS-4 Micro Computer Set Users Manual" Feb.73 
;changed from 547 cycles delay to 537 cycles delay for 5.068 MHz crystal.
sbr1:       fim P0,50h
l1:         isz R0,l1
            isz R1,l1
            bbl 0

;timing subroutines from page 80 of the "MCS-4 Micro Computer Set Users Manual" Feb.73
;changed from 275 cycles delay to 269 cycles delay for 5.068 MHz crystal.
sbr2:       fim P0,38h
l2:         isz R0,l2
            isz R1,l2
            bbl 0

;print subroutine from page 81 of the "MCS-4 Micro Computer Set Users Manual" Feb.73
print:      fim P0,16
            ldm 7
            src P0
            wrm
            inc R1
            xch R3
            src P0
            wrm   
            inc R1
            xch R2
            src P0
            wrm   
            
            fim P4,16           ;R8 = 1, R9 = 0
            fim P1,208          ;R2 = 13,R3 = 0
st7:        fim P2,12           ;R4 = 0, R5 = 12
            src P4
            rdm
st8:        wmp
            xch R4
            jms sbr1            ;537 cycles
            jms sbr2            ;269 cycles
            xch R4              ;save C (AC) in R4
            isz R5,st12         ;number of rotations
            inc R9              ;number of digits
            isz R2,st7          ;number of 4 bit words
            ldm 15
            wmp
            bbl 0

st9:        fim P3,12           ;R6 = 0, R7 = 12

st12:       isz R7,st12
            rar
            jun st8

;Newline subroutine from page 81 of the the "MCS-4 Micro Computer Set Users Manual":
crlf:       fim P1,141          ;R2 = 8, R3 = 13 (CR)
            jms print
            fim P1,138          ;R2 = 8; R3 = 10 (LF)
            jms print
            bbl 0            
            
;-----------------------------------------------------------------------------------------
; Serial port demo...
; Display the sign-on banner. Wait for a character, echo it.
; Set up terminal to emulate a TTY: 110 bps (9.09ms/bit), no parity, 7 data bits, 1 stop bits
; Pressing ESC, ESC, followed by "?" prints the "built by" message.
; Switch position #3 jumps here.
;-----------------------------------------------------------------------------------------
            org 0300h
            
option3:    ldm MARK
            fim P0,SERIALPORT
            src P0                  ;define RAM address 00
            wmp                     ;set serial port output high (MARK)
            fim P0,CHIP0REG0
            src P0
            ldm 0
            wr0                     ;clear data ram status character 0
            
            fim P0,lo(banner)       ;lo byte of the address of the label "banner"
opt1:       fin P1                  ;get the character into P1 (most significant nibble into R2, least significant nibble into R3)
            ld R2                   ;get the most significant nibble into acc
            ral                     ;rotate msb into cy
            jcn c,opt2              ;jump if cy=1 (end of message)
            jms putc                ;print the character in P1
            inc R1                  ;increment least significant nibble of pointer
            ld R1                   ;get the least significant nibble of the pointer into the accumulator
            jcn zn,opt1             ;jump if not zero (no overflow from the increment)
            inc R0                  ;else, increment most significant nibble of the pointer
            jun opt1            

opt2:       jms getc                ;get a character from the serial port into P1 (R2,R3) and echo it

            fim P3,CHIP0REG0
            src P3
            rd0                     ;recall the "state" from status character
            xch R15                 ;put the "state" into R15
            
            ldm 0
            clc
            sub R15
            jcn z,state0            ;jump if state "0"
            
            ldm 1
            clc
            sub R15
            jcn z,state1            ;jump if state "1"
            
            ldm 2
            clc
            sub R15
            jcn z,state2            ;jump if state "2"
            
            ldm 0                   ;else reset "state" back to zero
            wr0
            jun opt2                ;go back for the next character
            
state0:     fim P3,ESC
            jms compare             ;compare the character in P1 to the "ESC" in P3
            jcn nz,opt2             ;jump back for the next character if not equal
            
            ldm 1
            fim P3,CHIP0REG0
            src P3
            wr0                     ;advance to state "1"
            jun opt2                ;go back for the next character
            
state1:     fim P3,ESC
            jms compare
            fim P3,CHIP0REG0
            src P3
            jcn nz,state11          ;jump if the character in P1 does not match the "ESC" in P3
            
            ldm 2                   ;else advance to state "2"
            jun state12
state11:    ldm 0
state12:    wr0 
            jun opt2                ;go back for the next character
            
state2:     fim P3,"?"
            jms compare
            xch R15                 ;save the result of the comparison in R15

            ldm 0
            fim P3,CHIP0REG0
            src P3
            wr0                     ;reset "state" back to zero
            
            ld R15                  ;recall the result of the comparison from R15
            jcn nz,opt2             ;go back for the next character if no match
            
            jms hundredmsec         ;100 millisecond delay
            fim P0,lo(builtby)      ;lo byte of the address of "builtby"
            jun opt1                ;display the "Built by..." message

;Wait for a character from the serial input port (bit 0 of port 0). Echo the character to 
;bit 0 of the serial output port (bit 0 of port 0).
;Returns the 7 bit character in P1 (R2,R3).
;In addition to P1, also uses P0 and P2. 
       
getc:       fim P0,SERIALPORT
            src P0                  ;define the serial port for I/O reads and writes
start:      rdr                     ;read ROM port 00 (serial input is bit 0)
            rar                     ;rotate lsb of accumulator into cy
            jcn c,start             ;wait for input to go low for start bit

;start bit has been received...
            jms bitdelay            ;wait for 1/2 bit time (403 cycles = 4.45 msec delay)
            fim P0,SERIALPORT
            src P0                  ;define the serial port for I/O reads and writes
            rdr                     ;read the start bit from SERIALPORT
            wmp                     ;echo the start bit to SERIALPORT
            jms bitdelay            ;wait for the second half of the start bit (403 cycles = 4.45 msec delay)
            nop                     ;timing adjustment
            nop                     ;  "       "
            ldm 0
            xch R2                  ;R2 = 0 (high nibble of the received character)
            ldm 0
            xch R3                  ;R3 = 0 (low nibble of the received character)
            ldm 8
            xch R4                  ;R4 = 8 (7 data bits and 1 stop bit to receive);
;the start bit takes 823 cycles at 11.04968 usec/cycle = 9.093 msec/bit

;each bit requires 823 cycles at 11.04968 usec/cycle = 9.093 msec/bit
nxtbit:     jms bitdelay            ;wait for 1/2 bit time (403 cycles = 4.45 msec delay)
            nop                     ;timing adjustment
            clc
            rdr                     ;read the data from the least significant bit of the serial input port
            wmp                     ;echo the data back to the least significant bit of the serial output port
            rar                     ;rotate the received bit into carry
            ld R2                   ;get the high nibble of the received character from R2
            rar                     ;rotate received bit from carry into most significant bit of R2, least significant bit of R2 into carry
            xch R2                  ;save the high nibble
            ld R3                   ;get the low nibble of the character from R3
            rar                     ;rotate the least significant bit of R2 into the most significant bit of R3
            xch R3                  ;extend register pair to make 8 bits
            jms bitdelay            ;403 cycles = 4.45 msec delay
            isz R4,nxtbit           ;loop back until all 8 bits are read
        
;8 bits (7 data bits and 1 stop bit) have been received, clear the the most significant bit of the most significant nibble (the stop bit)
            ld R2                   ;get the most significant nibble from R2
            ral
            clc
            rar                     ;shift the cleared carry bit back into the most significant bit of the most significant nibble
            xch R2                  ;save it back into R2

            ldm MARK
            wmp                     ;set serial port high (mark)
            bbl 0                   ;return to caller

;403 cycles at 11.04 usec/cycle = 4.45 millisecond delay (nearly one half bit time)
bitdelay:  fim P0,044H              ;R0 = 4, R1 = 4
bitdelay1: isz R0,bitdelay1
           isz R1,bitdelay1
           bbl 0

;sign-on banner
banner:     data "Intel 4004 SBC",CR,LF
            data ">"
            data EOM

builtby:    data CR,LF
            data "Intel 4004 SBC built by Jim Loos.",CR,LF
            data "Firmware assembled: ",DATE," at ",TIME,".",CR,LF,EOM
            
;-----------------------------------------------------------------------------------------
; Switch Input demo...
; Use the switches to control the red, amber, green and blue LEDs.
; Switch position #4 jumps here.
;-----------------------------------------------------------------------------------------
            org 0400h
            
option4:    fim P0,SWITCHPORT
            fim P1,LEDPORT
            
readswitch: src P0                  ;ROM port 10H is the switch input port
            rdr                     ;read the option switch
            xch R6                  ;save the switch setting in R6
            
            jms tenmsec             ;ten millisecond delay
            
            rdr                     ;re-read the switches
            clc
            sub R6                  ;R6 contains the previous switch reading
            jcn nz,readswitch       ;go back if the two readings don't match (contacts still bouncing)
            
            xch R6                  ;restore the original switch reading to the accumulator
            cma                     ;complement accumulator since "0" indicates switch closed and "1" turns the LEDs on                        
            src P1                  ;define RAM port address 40, RAM port 40H is the LED output port
            wmp                     ;write complement of switch setting in accumulator to LEDPORT

            jun option4             ;go back and do it again
            
;-----------------------------------------------------------------------------------------
; Flashing LED demo...
; Flash the LEDs from right to left and then from left to right in a "Knight Rider" or "Cylon" 
; type pattern. The switch setting varies the rate. Switch position "0" gives the minimum delay
; (57,054 microseconds). Switch position "F" gives the maximum delay (1,504,067 microseconds).
; Switch position #5 jumps here.
;-----------------------------------------------------------------------------------------
            org 0500h
            
option5:    ldm GREENLED            ;start with the green LED
led1:       fim P0,LEDPORT
            src P0
            wmp                     ;output to port to turn on LED
            xch R10                 ;the accumulator need to be saved in R10 since the 'bbl' instruction overwrites the accumulator
            jms leddelay            ;delay for one half second
            xch R10                 ;restore the accumulator from R10
            clc                     ;the carry bit needs to be cleared since the delay subroutine sets the carry bit
            ral                     ;rotate the accumulator left thru carry
            jcn cn,led1             ;jump if cy=0
            ldm 0100B               ;change directions, start shifting right. turn on the red LED
led2:       fim P0,LEDPORT
            src P0
            wmp
            xch R10
            jms leddelay
            xch R10
            clc
            rar
            jcn cn,led2
            ldm 0010B               ;change directions, go back to shifting left, turn on the amber LED
            jun led1        
            
leddelay:   fim P0,SWITCHPORT
            src P0
            rdr                     ;read the switches (position '0' = 1111, position 'F' = 0000)
            fim P0, 081h            ;R0 = 8,  R1 = 1
            fim P1, 0DAh            ;R2 = 13, R3 = 10 (10 = switch setting 1010 when in position 5) these values give a delay of 500 milliseconds
            xch R3                  ;put the switch setting from acc into R3 to vary the delay
shiftdelay: isz R0,shiftdelay
            isz R1,shiftdelay
            isz R2,shiftdelay
            isz R3,shiftdelay
            bbl 0
            
;-----------------------------------------------------------------------------------------
; Another LED demo...
; Flash the LEDs from right to left in a "chaser" pattern. First the green LED, then the green 
; and amber, then the green, amber and red, and finally green, amber, red and blue. Again, 
; the switch setting varies the rate. Switch position "0" gives the minimum delay (57,054 
; microseconds). Switch position "F" ; gives the maximum delay (1,504,067 microseconds).
; Switch position #6 jumps here.
;-----------------------------------------------------------------------------------------            
            org 0600h
            
option6:    ldm 0001B               ;start with the green LED
            jms flashleds
            
            ldm 0011B               ;green and amber LEDs
            jms flashleds
            
            ldm 0111B               ;green, amber and red LEDs
            jms flashleds
            
            ldm 1111b               ;green, amber, red and blue LEDs
            jms flashleds
            
            ldm 1110B               ;amber, red and blue LEDs
            jms flashleds
            
            ldm 1100B               ;red and blue LEDs
            jms flashleds
            
            ldm 1000B               ;blue LED
            jms flashleds
            
            ldm 0000B               ;all LEDs off
            jms flashleds
            
            jun option6             ;go back and repeat

flashleds:  fim P0,LEDPORT          ;define the led port for port writes
            src P0
            wmp                     ;output to port to turn on LEDs
            jms leddelay            ;delay for one half second   
            bbl 0
            

;-----------------------------------------------------------------------------------------
; Display the position of the switch using the serial port.
; R6 holds the current switch reading, R11 holds the previous switch reading.
; Switch position #7 jumps here.
;-----------------------------------------------------------------------------------------             
            org 0700h
            
option7:    fim P1,CHIP1REG0
            src P1
            ldm 0
            wr0                     ;initialize previous switch setting to "0"
            ldm MARK
            fim P0,SERIALPORT
            src P0
            wmp                     ;set serial port output high (MARK)            
            
readsw:     jms crlf                ;newline
readsw1:    fim P0,SWITCHPORT
            src P0                  ;ROM port 10H is the switch input port
readsw2:    rdr                     ;read the option switch
            xch R6                  ;R6 = switch reading
            jms tenmsec             ;ten millisecond delay for switch de-bouncing
            jms tenmsec             ;another ten milliseconds
            rdr                     ;re-read the switches
            clc
            sub R6                  ;R6 contains the previous switch reading
            jcn nz,readsw2          ;go back if two readings 20 milliseconds apart don't match (contacts still bouncing)
                        
            rdr                     ;re-read the switch
            xch R6                  ;put switch setting in R6
            fim P1,CHIP1REG0
            src P1
            rd0                     ;recall the previous switch setting
            clc
            sub R6
            jcn z,readsw1           ;go back if the switch setting has not changed

            ld R6                   ;recall the current setting from R6
            wr0                     ;save the current switch setting for next time
            cma                     ;complement the switch reading since closed contacts pull low (i.e. position '0' = 1111, position 'F' = 0000)
            fim P0,lo(positions)    ;lo byte of the address "positions"
            clc
            add R1
            jcn cn,nc               ;jump if no carry (overflow) from the addition of R1 to the accumulator
            inc R0
nc:         xch R1
            fin P1                  ;get the character indexed by the switch setting into P1
            jms putc                ;print the character in P1
            jun readsw

positions:  data    "0123456789ABCDEF"

            
;-----------------------------------------------------------------------------------------
; Display the instructions for the 16 digit addition program...
; Switch position 2 jumps here. When finished jumps back to page 0200H.
;-----------------------------------------------------------------------------------------             

            org 0F00H
            
instruct:   ldm MARK
            fim P0,SERIALPORT
            src P0
            wmp                     ;set serial port output high (MARK) 

            fim P0,lo(instruct3)    ;lo byte of the address of the "instructions"
instruct1:  fin P1                  ;get the character into P1 (most significant nibble into R2, least significant nibble into R3)
            ld R2                   ;get the most significant nibble into accumulator
            ral                     ;rotate msb into carry
            jcn c,instruct2         ;jump if carry=1 (end of message)
            jms putc                ;print the character in P1
            inc R1                  ;increment least significant nibble of the pointer
            ld R1                   ;get the least significant nibble into accumulator
            jcn zn,instruct1        ;loop back for the next character if no overflow from the increment
            inc R0                  ;else, increment most significant nibble of pointer
            jun instruct1           ;loop back for the next character
            
instruct2:  jun decimal             ;jump to the 16 digit addition demo...
      
instruct3:  data CR,LF            
            data "Enter from one to sixteen digits from the tty keyboard.",CR,LF
            data "If fewer than sixteen digits are entered, press the '+' key.",CR,LF            
            data "The number entered is added to the contents of the accumulator.",CR,LF,EOM 
