    PAGE 0                          ; suppress page headings in ASW listing file
;---------------------------------------------------------------------------------------------------------------------------------
; Copyright 2020 Jim Loos
;
; Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files
; (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge,
; publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do
; so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
; OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
; LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
; IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
;---------------------------------------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; Firmware for the Intel 4004 Single Board Computer.
; Requires the use of a terminal emulator connected to the SBC
; set for 4800 bps, 7 data bits, no parity, 1 stop bit.
; Syntax is for the Macro Assembler AS V1.42 http://john.ccac.rwth-aachen.de:8000/as/
;----------------------------------------------------------------------------------------------------

; Tell the Macro Assembler AS that this source is for the Intel 4040.
            cpu 4040

; Conditional jumps syntax for Macro Assembler AS:
; jcn t     jump if test = 0 - positive voltage or +5VDC
; jcn tn    jump if test = 1 - negative voltage or -10VDC
; jcn c     jump if cy = 1
; jcn cn    jump if cy = 0
; jcn z     jump if accumulator = 0
; jcn zn    jump if accumulator != 0

            include "bitfuncs.inc"  ; Include bit functions so that FIN can be loaded from a label (upper 4 bits of address are loped off).
            include "reg4004.inc"   ; Include 4004 register definitions.

;BAUDRATE    equ 110                 ;  110 bps, 7 data bits, no parity, 1 stop bit
;BAUDRATE    equ 300                 ;  300 bps, 7 data bits, no parity, 1 stop bit
;BAUDRATE    equ 1200                ; 1200 bps, 7 data bits, no parity, 1 stop bit
;BAUDRATE    equ 2400                ; 2400 bps, 7 data bits, no parity, 1 stop bit
BAUDRATE    equ 4800                ; 4800 bps, 7 data bits, no parity, 1 stop bit

CR          equ 0DH
LF          equ 0AH
ESCAPE      equ 1BH

; I/O port addresses
SERIALPORT  equ 00H                 ; Address of the serial port. The least significant bit of port 00 is used for serial output.
LEDPORT     equ 40H                 ; Address of the port used to control the red LEDs. "1" turns the LEDs on.
SWITCHPORT  equ 10H                 ; Address of the input port for the rotary switch. Switch contacts pull the bits low, i.e. switch position "2" gives "1101".

; each 4002 RAM chip consists of 4 registers.
; each register consists of 16 main memory characters plus 4 status characters
CHIP0REG0   equ 00H                 ; 4002 data ram chip 0, register 0
CHIP0REG1   equ 10H                 ; 4002 data ram chip 0, register 1
CHIP0REG2   equ 20H                 ; 4002 data ram chip 0, register 2
CHIP0REG3   equ 30H                 ; 4002 data ram chip 0, register 3
CHIP1REG0   equ 40H                 ; 4002 data ram chip 1, register 0
CHIP1REG1   equ 50H                 ; 4002 data ram chip 1, register 1
CHIP1REG2   equ 60H                 ; 4002 data ram chip 1, register 2
CHIP1REG3   equ 70H                 ; 4002 data ram chip 1, register 3

accumulator equ CHIP0REG0           ; multi-digit addition demo
addend      equ CHIP0REG1           ; multi-digit addition demo
minuend     equ CHIP0REG1           ; multi-digit subtraction demo
subtrahend  equ CHIP0REG2           ; multi-digit subtraction demo
multiplicand equ CHIP0REG1          ; multi-digit multiplication demo
multiplier  equ CHIP0REG2           ; multi-digit multiplication demo
product     equ CHIP0REG0           ; multi-digit multiplication demo
dividend    equ CHIP0REG0           ; multi-digit division demo
divisor     equ CHIP0REG2           ; multi-digit division demo
quotient    equ CHIP0REG3           ; multi-digit division demo
remainder   equ CHIP0REG1           ; multi-digit division demo
guess:      equ CHIP0REG2           ; number guessing game
attempts:   equ CHIP0REG3           ; number guessing game
grid        equ CHIP0REG2           ; tic-tac-toe game
calcResults equ CHIP0REG3           ; tic-tac-toe game

GPIO        equ 80H                 ; 4265 General Purpose I/O device address

; 4265 Modes:   WMP     Port:   W   X   Y   Z
GPIOMODE0   equ 0000B   ;       I   I   I   I (reset)
GPIOMODE4   equ 0100B   ;       O   O   O   O
GPIOMODE5   equ 0101B   ;       I   O   O   O
GPIOMODE6   equ 0110B   ;       I   I   O   O
GPIOMODE7   equ 0111B   ;       I   I   I   O

            org 0000H               ; beginning of 2732 EPROM

;--------------------------------------------------------------------------------------------------
; Power-on-reset Entry
;--------------------------------------------------------------------------------------------------
reset:      nop                     ; 'To avoid problems with power-on reset, the first instruction at
                                    ; program address 000 should always be an NOP.' (dont know why)
            ldm 1
            fim P0,SERIALPORT
            src P0
            wmp                     ; set RAM serial output port high to indicate MARK

            fim P6,079H             ; 250 milliseconds delay for serial port
            fim P7,06DH
reset1:     isz R12,reset1
            isz R13,reset1
            isz R14,reset1
            isz R15,reset1

            fim P0,GPIO             ; address of the 4265 GPIO device
            src P0
            ldm GPIOMODE0           ; from the table above
            wmp                     ; program the 4265 for mode 0 (all four ports are inputs)

            jms newline
            jms banner              ; print "Intel 4004 SBC" or "Intel 4040 SBC"
reset2:     jms ledsoff             ; all LEDs off
            jms menu                ; print the menu
reset3:     jms getchar             ; wait for a character from serial input, echo it, the character is returned in P1

testfor0:   fim P3,'0'
            jms compare             ; is the character '0'?
            jcn nz,testfor1         ; jump if no match
            jun reset2              ; no menu item assigned to '0' yet

testfor1:   fim P3,'1'
            jms compare             ; is the character '1'?
            jcn nz,testfor2         ; jump if no match
            jun led1demo            ; '1' selects LED demo 1

testfor2:   fim P3,'2'
            jms compare             ; is the character '2'?
            jcn nz,testfor3         ; jump if no match
            jun led2demo            ; '2' selects LED demo 2

testfor3:   fim P3,'3'
            jms compare             ; is the character '3'?
            jcn nz,testfor4         ; jump if no match
            jun adddemo             ; '3' selects decimal addition demo

testfor4:   fim P3,'4'
            jms compare             ; is the character '4'?
            jcn nz,testfor5         ; jump if no match
            jun subdemo             ; '4' selects decimal subtraction demo

testfor5:   fim P3,'5'
            jms compare             ; is the character '5'?
            jcn nz,testfor6         ; jump if no match
            jun multdemo            ; '5' selects decimal multiplication demo

testfor6:   fim P3,'6'
            jms compare             ; is the character '6'?
            jcn nz,testfor7         ; jump if no match
            jun divdemo             ; '6' selects decimal division demo

testfor7:   fim P3,'7'
            jms compare             ; is the character '7'?
            jcn nz,testfor8         ; jump if no match
            jun newGame             ; '7' selects Tic-Tac-Toe

testfor8:   fim P3,'8'
            jms compare             ; is the character '8'?
            jcn nz,testfor9         ; jump if no match
            jun game                ; '8' selects number guessing game

testfor9:   fim P3,'9'
            jms compare             ; is the character '9'?
            jcn nz,nomatch          ; jump if no match
            jun switchdemo          ; '9' selects rotary switch demo

nomatch:    ld R9                   ; "state" is kept in R9
            jcn z,state0            ; jump if state is 0

            ldm 1
            clc
            sub R9                  ; compare "state" in R9 to 1 by subtraction
            jcn z,state1            ; jump if state is 1

            ldm 2
            clc
            sub R9                  ; compare "state" in R9 to 2 by subtraction
            jcn z,state2            ; jump if state is 2

            ldm 0                   ; else reset "state" back to zero
            xch R9
            jun reset2              ; display the menu options, go back for the next character

state0:     fim P3,ESCAPE           ; state=0, we're waiting for the 1st Escape
            jms compare             ; compare the character in P1 to the "ESCAPE" in P3
            jcn nz,reset2           ; if not ESCAPE, display the menu options, go back for the next character

            ldm 1                   ; the 1st Escape has been received
            xch R9                  ; advance the state from 0 to 1
            jun reset3              ; go back for the next character

state1:     fim P3,ESCAPE           ; the 1st Escape has been received, we're waiting for the 2nd Escape
            jms compare
            jcn nz,state1a          ; jump if the character in P1 does not match the "ESCAPE" in P3
            ldm 2                   ; else advance the state from 1 to 2
            xch R9
            jun reset3              ; the 2nd ESCAPE has been received, go back for the next character

state1a:    ldm 0                   ; else reset state back to 0
            xch R9
            jun reset2              ; display the menu options, go back for the next character

state2:     ldm 0                   ; state=2, the 2nd Escape has been received, now we're waiting for the "?"
            xch R9                  ; reset state back to 0
            fim P3,"?"
            jms compare             ; was it '?'
            jcn nz,reset2           ; not '?', display the menu options, go back for the next character

            jms newline             ; ESCAPE,ESCAPE,? has been detected
            jms banner
            jms builtby             ; display the "built by" message
            jun reset2              ; display the menu options, go back for the next character

;--------------------------------------------------------------------------------------------------
; detects 4004 or 4040 CPU by using the "AN7" instruction.
; available on the 4040 but not on the 4004.
; returns 1 for 4004 CPU. returns 0 for 4040 CPU.
;--------------------------------------------------------------------------------------------------
detectCPU:  ldm 0
            xch R7                  ; R7 now contains 0000
            ldm 1111b               ; accumulator now contains 1111
            an7                     ; logical AND the contents of the accumulator (1111) with contents of R7 (0000)
                                    ; if 4040, the accumulator now contains 0000; if 4004, accumulator remains at 1111
            rar                     ; rotate the least significant bit of the accumulator into carry
            jcn c,detectCPU1        ; if carry is set, logical AND failed, must be a 4004
            bbl 0                   ; return indicating 4040
detectCPU1: bbl 1                   ; return indicating 4004

;--------------------------------------------------------------------------------------------------
; turn off all four LEDs
;--------------------------------------------------------------------------------------------------
ledsoff:    fim P0,LEDPORT
            src P0
            ldm 0
            wmp                     ; write data to RAM LED output port, set all 4 outputs low to turn off all four LEDs
            bbl 0

;--------------------------------------------------------------------------------------------------
; Compare the contents of P1 (R2,R3) with the contents of P3 (R6,R7).
; Returns 0 if P1 = P3.
; Returns 1 if P1 < P3.
; Returns 2 if P1 > P3.
; Overwrites the contents of P3.
; Adapted from code in the "MCS-4 Micro Computer Set Users Manual" on page 166:
;--------------------------------------------------------------------------------------------------
compare:    clc                     ; clear carry before "subtract with borrow" instruction
            xch R6                  ; contents of R7 (high nibble of P3) into accumulator
            sub R2                  ; compare the high nibble of P1 (R2) to the high nibble of P3 (R6) by subtraction
            jcn cn,greater          ; no carry means that R2 > R6
            jcn zn,lesser           ; jump if the accumulator is not zero (low nibbles not equal)
            clc                     ; clear carry before "subtract with borrow" instruction
            xch R7                  ; contents of R6 (low nibble of P3) into accumulator
            sub R3                  ; compare the low nibble of P1 (R3) to the low nibble of P3 (R7) by subtraction
            jcn cn,greater          ; no carry means R3 > R7
            jcn zn,lesser           ; jump if the accumulator is not zero (high nibbles not equal)
            bbl 0                   ; 0 indicates P1=P3
lesser:     bbl 1                   ; 1 indicates P1<P3
greater:    bbl 2                   ; 2 indicates P1>P3

;-----------------------------------------------------------------------------------------
; position the cursor to the start of the next line
;-----------------------------------------------------------------------------------------
newline:    fim P1,CR
            jms putchar
            fim P1,LF
            jun putchar

;-----------------------------------------------------------------------------------------
; This function is used by all the text string printing functions. If the character in P1 is zero indicating
; the end of the string, returns 0. Otherwise prints the character and increments
; P0 to point to the next character in the string then returns 1.
;-----------------------------------------------------------------------------------------
txtout:     ld R2                   ; load the most significant nibble into the accumulator
            jcn nz,txtout1          ; jump if not zero (not end of string)
            ld  R3                  ; load the least significant nibble into the accumulator
            jcn nz,txtout1          ; jump if not zero (not end of string)
            bbl 0                   ; end of text found, branch back with accumulator = 0

txtout1:    jms putchar             ; print the character in P1
            inc R1                  ; increment least significant nibble of pointer
            ld R1                   ; get the least significant nibble of the pointer into the accumulator
            jcn zn,txtout2          ; jump if zero (no overflow from the increment)
            inc R0                  ; else, increment most significant nibble of the pointer
txtout2:    bbl 1                   ; not end of text, branch back with accumulator = 1

;--------------------------------------------------------------------------------------------------
; polls the serial port during the delay. returns immediately
; with accumulator=1 is the start bit is detected.
; 907 cycles * 11.05 microseconds/cycle = 10,022 microseconds delay
;--------------------------------------------------------------------------------------------------
tenmsec:    fim P6,067H
            fim P7,0EFH
delayloop:  isz R12,delayloop
            jcn tn,delayexit        ; early exit if start bit is detected
            isz R13,delayloop
            jcn tn,delayexit        ; early exit if start bit is detected
            isz R14,delayloop
            jcn tn,delayexit        ; early exit if start bit is detected
            isz R15,delayloop
            jcn tn,delayexit        ; early exit if start bit is detected
            bbl 0                   ; return 0 if the start bit was not detected
delayexit:  bbl 1                   ; return 1 if the start bit was detected

            org 0100H

; serial I/O functions 'putchar' and 'getchar'
    SWITCH BAUDRATE
        CASE 110
            include "110bps.inc"    ; serial I/O functions for 110 bps
        CASE 300
            include "300bps.inc"    ; serial I/O functions for 300 bps
        CASE 1200
            include "1200bps.inc"   ; serial I/O functions for 1200 bps
        CASE 2400
            include "2400bps.inc"   ; serial I/O functions for 2400 bps
        CASE 4800
            include "4800bps.inc"   ; serial I/O functions for 4800 bps
        ELSECASE
            include "300bps.inc"
    ENDCASE

;-------------------------------------------------------------------------------
; Get a multi-digit decimal integer from the serial port.
; Upon entry, P2 points to RAM register for the number and R13 specifies
; the maximum number of digits to get.  Returns 1 if Control C entered.
; Adapted from code in the "MCS-4 Micro Computer Set Users Manual, Feb. 73".
;-------------------------------------------------------------------------------
getnumber:  jms getchar             ; return with a character from the serial port in P1 (most significant nibble in R2, least significant nibble in R3)
            ld R2                   ; get the most significant nibble of the character
            jcn zn,getnumber3       ; jump if it's not zero
            ldm 03H                 ; get the least significant nibble of the character
            sub R3                  ; compare the least significant nibble to 03H by subtraction
            jcn z,getnumber2a       ; jump if control C
            ldm 0DH
            sub R3                  ; compare the least significant nibble to 0DH by subtraction
            clc
            jcn zn,getnumber3       ; jump its not carriage return (0DH)
            bbl 0                   ; return to caller with fewer than 16 digits if carriage return is entered
getnumber2a:bbl 1                   ; return 1 to caller if control C

; Move digits in RAM 0EH-00H to the next higher address 0FH-01H.
; The digit at 0EH is moved to 0FH, the digit at 0DH is moved to 0EH, the digit at 0CH is moved to 0DH, and so on.
; Moving the digits makes room for the new digit from the serial port which is contained in P1 to be stored at 00H
; at the least significant digit. P3 (R6,R7) is used as a pointer to the source register for the move.
; P4 (R8,R9) is used as a pointer to the destination register.
getnumber3: ld R4                   ; get the most significant digit of the destination address from P2
            xch R6                  ; make it the most significant digit of the source address in P3
            ld R6
            xch R8                  ; make it the most significant digit of the destiation address in P4
            ldm 0EH
            xch R7                  ; make the least significant digit of source address in P3 0EH
            ldm 0FH
            xch R9                  ; make the least significant digit of destination address in P4 0FH
            ldm (16-15)
            xch R1                  ; loop counter (15 times thru the loop)
getnumber4: src P3                  ; source address
            rdm                     ; read digit from source
            src P4                  ; destination address
            wrm                     ; write digit to destination
            ld  R9
            dac                     ; decrement least significant nibble of destination address
            xch R9
            ld  R7
            dac                     ; decrement least significant nibble of source address
            xch R7
            isz R1,getnumber4       ; do all digits

            ld  R3                  ; R3 holds least significant nibble of the character received from the serial port (ignore R2 to convert ASCII to binary)
            src P2                  ; P2 now points to the destiation for the character
            wrm                     ; save the least significant nibble of the new digit (the binary value for the number) in RAM
            isz R13,getnumber       ; go back for the next digit (16 times thru the loop for 16 digits)
            bbl 0

;-------------------------------------------------------------------------------
; Print the contents of RAM register pointed to by P3 as a 16 digit decimal number. R11
; serves as a leading zero flag (1 means skip leading zeros). The digits are stored
; in RAM from right to left i.e. the most significant digit is at location 0FH,
; therefore it's the first digit printed. The least significant digit is at location
; 00H, so it's the last digit printed.
;-------------------------------------------------------------------------------
prndigits:  ldm 0
            xch R10                 ; R10 is the loop counter (0 gives 16 times thru the loop for all 16 digits)
            ldm 0FH
            xch R7                  ; make P3 0FH (point to the most significant digit)
            ldm 1
            xch R11                 ; set the leading zero flag
prndigits1: src P3
            ld R7
            jcn zn,prndigits2       ; jump if this is not the last digit
            ldm 0
            xch R11                 ; since this is the last digit, clear the leading zero flag
prndigits2: ld R11                  ; get the leading zero flag
            rar                     ; rotate the flag into carry
            rdm                     ; read the digit to be printed
            jcn zn,prndigits3       ; jump if this digit is not zero
            jcn c,prndigits4        ; this digit is zero, jump if the leading zero flag is set
prndigits3: xch R3                  ; this digit is not zero OR the leading zero flag is not set. put the digit as least significant nibble into R3
            ldm 3
            xch R2                  ; most significant nibble ("3" for ASCII characters 30H-39H)
            jms putchar             ; print the ASCII code for the digit
            src P3
            ldm 0
            xch R11                 ; reset the leading zero flag

prndigits4: ld  R7                  ; least significant nibble of the pointer to the digit
            dac                     ; next digit
            xch R7
            isz R10,prndigits1      ; loop 16 times (print all 16 digits)
            bbl 0                   ; finished with all 16 digits

;-------------------------------------------------------------------------------
; Clear RAM subroutine. P2 points to the RAM register to be cleared (zeroed).
; Adapted from code in "MCS-4 Micro Computer Set Users Manual Feb. 73" page 80.
;-------------------------------------------------------------------------------
clrram:     ldm 0
            xch R1                  ; R1 is the loop counter (0 means 16 times)
clear:      ldm 0
            src P2
            wrm                     ; write zero into RAM
            inc R5                  ; next character
            isz R1,clear            ; 16 times (zero all 16 nibbles)
            bbl 0

;-------------------------------------------------------------------------------
; this is the function that performs the multi-digit decimal subtraction
; for the subtraction demo below
;-------------------------------------------------------------------------------
subtract:   ldm 0
            xch R11                 ; R11 is the loop counter (0 gives 16 times thru the loop for 16 digits)
            stc                     ; set carry=1
subtract1:  tcs                     ; accumulator = 9 or 10
            src P2                  ; select the subtrahend
            sbm                     ; produce 9's or l0's complement
            clc                     ; set carry=0
            src P1                  ; select the minuend
            adm                     ; add minuend to accumulator
            daa                     ; adjust accumulator
            wrm                     ; write result to replace minuend
            inc R3                  ; address next digit of minuend
            inc R5                  ; address next digit of subtrahend
            isz R11,subtract1       ; loop back for all 16 digits
            jcn c,subtract2         ; carry set means no underflow from the 16th digit
            bbl 1                   ; overflow, the difference is negative
subtract2:  bbl 0                   ; no overflow, the difference is positive

            org 0200H               ; next page

;-------------------------------------------------------------------------------
; Decimal subtraction demo. 
; P1 points to the minuend stored in RAM register 10H least significant digit at 10H,
; most significant digit at 1FH.
; P2 points to the subtrahend is stored in RAM register 20H least significant digit at 20H,
; most significant digit at 2FH.
; the subtrahend is subtracted from the minuend. The difference replaces the minuend i.e. *P1=*P1-*P2
; Adapted from code in "MCS-4 Micro Computer Set Users Manual, Feb. 73" page 4-23.
;--------------------------------------------------------------------------------
subdemo:    jms subinstr
subdemo1:   fim P2,minuend          ; P2 points the memory register where the minuend digits are stored (10H-1FH)
            jms clrram              ; clear RAM 10H-1FH
            fim P2,subtrahend       ; P2 points the memory register where the subtrahend digits are stored (20H-2FH)
            jms clrram              ; clear RAM 20H-1FH

            jms newline             ; position carriage to beginning of next line
            jms newline             ; blank line
            jms firstnum            ; prompt for the first number (minuend)
            fim P2,minuend          ; destination address for minuend: 1FH down to 10H
            ldm 0                   ; up to 16 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the first number (minuend)
            jcn z,subdemo1a
            jun reset2              ; control C exits

subdemo1a:  jms newline
            jms secondnum           ; prompt for the second number (subtrahend)
            fim P2,subtrahend       ; destination address for subtrahend: 2FH down to 20H
            ldm 0                   ; up to 16 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the second number (subtrahend)
            jcn z,subdemo1b
            jun reset2              ; control C exits

subdemo1b:  jms newline
            jms prndiff             ; print "Difference:"
            fim P1,minuend          ; P1 points to the 16 digit minuend  (number from which another is to be subtracted)
            fim P2,subtrahend       ; P2 points to the 16 digit subtrahend (number to be subtracted from another)
            jms subtract            ; subtract subtrahend from minuend
            jcn z,subdemo3          ; zero means no overflow, the difference is a positive number

; the difference is a negative number, convert from 10's complement.
            fim P2,subtrahend
            jms clrram              ; zero RAM 20H-2FH
            fim P1,subtrahend       ; P1 points to the 16 digit minuend  (all zeros)
            fim P2,minuend          ; P2 points to the 16 digit subtrahend (the negative result from subtraction above)
            jms subtract            ; subtract the negative number from zero
            fim P1,'-'              ; minus sign
            fim P3,subtrahend       ; the result is in RAM at 20H-2FH
            jun subdemo4            ; go print the converted result

; the difference is a positive number
subdemo3:   fim P3,minuend          ; P3 points to the result in RAM at 10H-1FH
            fim P1,' '              ; space
subdemo4:   jms putchar             ; print a space
            jms prndigits           ; print the 16 digits of the difference
            jun subdemo1            ; go back for another pair of numbers

;-------------------------------------------------------------------------------
; Decimal addition demo.
; P1 points to the first integer (the accumulator) stored in RAM register 10H (CHIP0REG1)
; least significant digit at 10H, most significant digit at 1FH.
; P2 points to the second integer (the addend) stored in RAM register 20H (CHIP0REG2)
; least significant digit at 20H, most significant digit at 2FH.
; The 16 digit sum replaces the first integer in RAM register 10H (CHIP0REG1) least significant digit at 10H,
; most significant digit at 1FH.
; Adapted from the code in "MCS-4 Micro Computer Set Users Manual, Feb. 73" page 77.
;--------------------------------------------------------------------------------
adddemo:    jms addinstr
adddemo1:   fim P2,accumulator      ; P2 points the memory register where the first number (and sum) digits are stored (10H-1FH)
            jms clrram              ; clear RAM 10H-1FH
            fim P2,addend           ; P2 points the memory register where the second number digits are stored (20H-2FH)
            jms clrram              ; clear RAM 20H-2FH
            jms newline             ; position carriage to beginning of next line
            jms newline
            jms firstnum            ; prompt for the first number
            fim P2,accumulator      ; destination address for first number
            ldm 0                   ; up to 16 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the first number
            jcn z,adddemo1a
            jun reset2              ; control C exits

adddemo1a:  jms newline
            jms secondnum           ; prompt for the second number
            fim P2,addend           ; destination address for second number
            ldm 0                   ; up to 16 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the second number
            jcn z,adddemo1b
            jun reset2              ; control C exits

adddemo1b:  jms newline
            fim P1,accumulator      ; P1 points to the first 16 digit number (called the accumulator)
            fim P2,addend           ; P2 points to the second 16 digit number (called the addend) to be added to the first
            jms addition            ; add the two numbers
            jcn zn,adddemo2         ; jump if overflow
            jms prnsum              ; print "Sum: "
            fim P3,accumulator      ; P3 points to the sum
            jms prndigits           ; print the 16 digits of the sum
            jun adddemo1            ; go back for another pair of numbers
adddemo2:   jms prnoverflow         ; the sum of the two numbers overflows 16 digits
            jun adddemo1            ; go back for another pair of numbers

;-------------------------------------------------------------------------------
; this is the function that performs the multi-digit decimal addition
; for the addition demo above
;-------------------------------------------------------------------------------
addition    ldm 0
            xch R11                 ; R6 is the loop counter (0 gives 16 times thru the loop for all 16 digits)
addition1:  src P2                  ; P2 points to the addend digits
            rdm                     ; read the addend digit
            src P1                  ; P1 points to the "accumulator"
            adm                     ; add the digit from the "accumulator" to the addend
            daa                     ; convert the sum from binary to decimal
            wrm                     ; write the sum back to the "accumulator"
            inc R3                  ; point to next "accumlator" digit
            inc R5                  ; point to next addend digit to be added to the accumulator
            isz R11,addition1       ; loop 16 times (do all 16 digits)
            jcn cn,addition2        ; no carry means no overflow from the 16th digit addition
            bbl 1                   ; 16 digit overflow
addition2:  bbl 0                   ; no overflow

;-------------------------------------------------------------------------------
; Decimal multiplication demo.
; P1 points to the multiplicand stored in RAM register 10H (CHIP0REG1), characters 15H
; through 1CH where the digit at location 15H is the least significant digit
; and the digit at location 1CH is the most significant digit.
; P2 points to the multiplier stored in RAM register 20H (CHIP0REG2), characters 24H through 2BH
; where the digit at location 24H is the least significant digit and the digit
; at location 2BH is the most significant digit.
; P3 points to the product stored in RAM register 00H (CHIP0REG0), characters 00H through 0FH
; where the digit at location 00H is the least significant digit and the digit
; at location 0FH is the most significant digit.
; The actual multiplication is done by the "MLRT" routine taken from:
; "A Microcomputer Solution to Maneuvering Board Problems" by Kenneth Harper Kerns, June 1973
; Naval Postgraduate School Monterey, California.
;--------------------------------------------------------------------------------
multdemo:   jms multinstr
multdemo1:  fim P2,multiplicand     ; P2 points the memory register where the multiplicand is stored (10H-1FH)
            jms clrram              ; clear RAM 10H-1FH
            fim P2,multiplier       ; P2 points the memory register where the multiplier is stored (20H-2FH)
            jms clrram              ; clear RAM 20H-2FH
            jms newline             ; position carriage to beginning of next line
            jms newline
            jms firstnum            ; prompt for the multiplicand
            fim P2,multiplicand+5   ; destination address for multiplicand (15H)
            ldm 16-8                ; up to 8 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the multiplicand (8 digits max) into RAM at 15H-1CH
            jcn z,multdemo1a
            jun reset2              ; control C exits

multdemo1a: jms newline
            jms secondnum           ; prompt for the multiplier
            fim P2,multiplier+4     ; destination address for multiplier (24H)
            ldm 16-8                ; up to 8 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the multiplier (8 digits max) into RAM at 24H-2BH
            jcn z,multdemo1b
            jun reset2              ; control C exits

multdemo1b: jms newline
            fim P1,multiplicand     ; multiplicand
            fim P2,multiplier       ; multiplier
            fim P3,product          ; product goes here
            jms MLRT                ; the function that does the actual multiplication
            jms prnproduct          ; print "Product: "
            fim P3,product          ; P3 points to the product at RAM address 00H-0FH
            jms prndigits           ; print the 16 digits of the product
            jun multdemo1           ; go back for another pair of numbers

;-------------------------------------------------------------------------------
; Decimal division demo.
; P1 points to the dividend in RAM register 00H (CHIP0REG0), characters 00H through 06H
; (least significant digit at location 00H, most significant digit at location 06H).
; P3 points to the divisor in RAM register 20H (CHIP0REG2), characters 20H through 27H
; (least significant digit at location 20H, most significant digit at location 27H).
; P4 points to the quotient in RAM register 30H (CHIP0REG3) least significant digit
; at 30H, most significant digit at 3FH.
; P2 points to the remainder in RAM register 10H (CHIP0REG1) least significant digit
; at 10H, most significant digit at 1FH.
; The actual division is done by the "DVRT" routine taken from:
; "A Microcomputer Solution to Maneuvering Board Problems" by Kenneth Harper Kerns, June 1973
; Naval Postgraduate School Monterey, California.
;--------------------------------------------------------------------------------
divdemo:    jms divinstr
divdemo1:   fim P2,dividend         ; P2 points the memory register where the dividend is stored (00H-0FH)
            jms clrram              ; clear RAM 10H-1FH
            fim P2,divisor          ; P2 points the memory register where the divisor is stored (20H-2FH)
            jms clrram              ; clear RAM 20H-2FH
            jms newline
            jms newline
            jms firstnum            ; prompt for the dividend
            fim P2,dividend         ; destination address for the dividend (00H-06H)
            ldm 16-7                ; maximum of 7 digits for the dividend
            xch R13                 ; R13 is the digit counter for the getnumber function
            jms getnumber           ; get the dividend
            jcn z,divdemo1a
            jun reset2              ; control C exits

divdemo1a:  jms newline
            jms secondnum           ; prompt for the divisor
            fim P2,divisor          ; destination address for the divisor (20H-27H)
            ldm 16-8                ; maximum of 8 digits for the divisor
            xch R13                 ; R13 is the digit counter for the getnumber function (8 digits)
            jms getnumber           ; get the divisor
            jcn z,divdemo1b
            jun reset2              ; control C exits

divdemo1b:  fim P1,dividend         ; points to dividend
            fim P2,remainder        ; points to remainder
            fim P3,divisor          ; points to divisor
            fim P4,quotient         ; points to quotient
            jms DVRT                ; the function that does the actual division
            jms newline
            jms prnquotient         ; print "Quotient:"
            fim P3,quotient         ; P3 points to the quotient
            jms prnquot             ; print the 16 digits of the quotient
            jun divdemo1            ; go back for more of numbers

;-----------------------------------------------------------------------------------------
; Flashing LED demo.
; Flash the LEDs from right to left and then from left to right in a "Knight Rider"
; or "Cylon" type pattern.
;-----------------------------------------------------------------------------------------
led1demo:   ldm 0001B               ; start with the first LED
            fim P0,LEDPORT
            src P0
led1demo1:  wmp                     ; output to port to turn on LED
            xch R0                  ; the accumulator need to be saved in R0 since the 'bbl' instruction overwrites the accumulator
            jms leddelay            ; delay for 100 milliseconds. abort by jumping to reset if start bit detected
            jcn z,$+4               ; jump around  the next instruction if the start bit not detected
            jun reset2              ; a key has been pressed (start bit detected), go back to the beginning
            xch R0                  ; restore the accumulator from R0
            clc                     ; the carry bit needs to be cleared since the delay subroutine sets the carry bit
            ral                     ; rotate the accumulator left thru carry
            jcn cn,led1demo1        ; jump if cy=0
            ldm 0100B               ; change directions, start shifting right.
led1demo2:  wmp
            xch R0
            jms leddelay            ; delay for 100 milliseconds. abort by jumping to reset if start bit detected
            jcn z,$+4               ; jump around  the next instruction if the start bit not detected
            jun reset2              ; a key has been pressed (start bit detected), go back to the beginning
            xch R0
            clc
            rar
            jcn cn,led1demo2
            ldm 0010B               ; change directions, go back to shifting left
            jun led1demo1

;-----------------------------------------------------------------------------------------
; Another flashing LED demo.
; Flash the LEDs from right to left in a "chaser" pattern.
;-----------------------------------------------------------------------------------------
led2demo:   fim P0,LEDPORT          ; define the led port for port writes
            src P0
            ldm 0001B               ; one LED
            jms led2demo1
            ldm 0011B               ; two LEDs
            jms led2demo1
            ldm 0111B               ; three LEDs
            jms led2demo1
            ldm 1111b               ; all four LEDs
            jms led2demo1
            ldm 1110B               ; back to three LEDs
            jms led2demo1
            ldm 1100B               ; back to two LEDs
            jms led2demo1
            ldm 1000B               ; back to one LED
            jms led2demo1
            ldm 0000B               ; all LEDs off
            jms led2demo1
            jun led2demo            ; go back and repeat

led2demo1:  wmp                     ; output to port to turn on LEDs
            jms leddelay            ; delay for 100 milliseconds
            jcn z,$+4               ; jump around the next instruction if the start bit not detected
            jun reset2              ; a key has been pressed (start bit detected), go back to the beginning
            bbl 0

;-----------------------------------------------------------------------------------------
; 100 millisecond delay for the flashing LED demos.
; Check the 4004's TEST input for detection of the start bit every millisecond.
; Returns 1 if the start bit has been detected, otherwise returns 0.
; Uses P6 (R12,R13) and P7 (R14,R15)
;-----------------------------------------------------------------------------------------
leddelay:   ldm 15-10               ; 10 times through the outer loop
            xch R13                 ; counter for the outer loop
leddelay1:  ldm 15-10               ; 10 times through the inner loop
            xch R12                 ; counter for the inner loop
leddelay2:  jcn t,$+3               ; skip the following instruction if TEST = 0 (the start bit has not been received)
            bbl 1                   ; the start bit has been detected, return 1
            fim P7,07DH
leddelay3:  isz R14,leddelay3       ; inner loop 1 millisecond delay
            isz R15,leddelay3       ;
            isz R12,leddelay2       ; inner loop executed 10 times (10 milliseconds)
            isz R13,leddelay1       ; outer loop executed 10 times (100 milliseconds)
            bbl 0

;-----------------------------------------------------------------------------------------
; Display the position of the 16 position rotary switch using the serial port and LEDs.
; R10 holds the current switch reading. R11 holds the previous switch reading.
;-----------------------------------------------------------------------------------------
switchdemo: ldm 0
            fim P2, LEDPORT
            src P2
            wmp                     ; turn off all four LEDs
            xch R11                 ; initialize R11 to zero
            ldm 0001B
            fim P0,SERIALPORT
            src P0
            wmp                     ; set serial port output high (MARK)
readsw:     jms newline             ; position the cursor to the beginning of the next line
            fim P3,GPIO
            src P3                  ; address of the 4265 GPIO
readsw1:    rd0                     ; read port W of the 4265 GPIO
            xch R10                 ; save the current switch reading in R10
            jms tenmsec             ; ten millisecond delay for switch de-bouncing
            jcn zn,exitswdemo       ; exit if start bit is detected
            jms tenmsec             ; ten millisecond delay for switch de-bouncing
            jcn zn,exitswdemo       ; exit if start bit is detected
            jms tenmsec             ; ten millisecond delay for switch de-bouncing
            jcn zn,exitswdemo       ; exit if start bit is detected
            rd0                     ; re-read the switches
            clc
            sub R10                 ; R10 contains the switch reading from 30 milliseconds ago
            jcn nz,readsw1          ; go back if two readings 30 milliseconds apart don't match (contacts are still bouncing)
            ld R11                  ; recall the previous switch reading
            clc
            sub R10                 ; compare to the current reading by subtraction
            jcn z,readsw1           ; go back if the switch has not changed
            ld R10                  ; recall the current switch reading from R10
            xch R11                 ; save it in R11 for next time
            ld R10
            cma                     ; complement the switch reading since closed contacts pull low (i.e. position '0' = 1111, position 'F' = 0000)
            fim P2, LEDPORT
            src P2
            wmp                     ; turn on LEDs to indicate switch position
            fim P0,lo(positions)    ; lo byte of the address "positions"
            clc
            add R1
            jcn cn,nocarry          ; jump if no carry (overflow) from the addition of R1 to the accumulator
            inc R0
nocarry:    xch R1
            fin P1                  ; get the character indexed by the switch setting into P1
            jms putchar             ; print the character in P1
            jun readsw              ; go back and do it again if TEST input is 0 (the start bit has not been received)

exitswdemo  jun reset2

positions:  data    "0123456789ABCDEF"

;-------------------------------------------------------------------------------
; Returns with zero if what remains of the fractional part of the quotient part
; is all zeros and thus does not need to be printed, otherwise returns with 1.
; used by the prnquot (print quotient) function as part of the division demo.
;-------------------------------------------------------------------------------
zeros:      ld R6
            xch R2
            ld R7
            xch R3                  ; P1 now points next digit of the fractional part not yet printed
zeros1:     src P1
            rdm                     ; read the digit of the fractional part
            jcn zn,zeros2           ; exit if not zero
            ld R3
            dac
            xch R3                  ; next digit
            ldm 0FH
            clc
            sub R3                  ; have we come to the end (has R3 wrapped around to 0FH)?
            jcn zn,zeros1           ; no, go back for the next digit
            bbl 0                   ; return with zero
zeros2:     bbl 1                   ;return with non-zero

            org 0400H               ; next page

;-------------------------------------------------------------------------------
; Multi-digit multiplication function taken from:
; "A Microcomputer Solution to Maneuvering Board Problems" by Kenneth Harper Kerns, June 1973
; Naval Postgraduate School Monterey, California.
; On entry, P1 points to the multiplicand, P2 points to the multiplier, P3 points to the product.
; Sorry about the lack of comments. That's how it was done back in the day of slow teletypes.
;-------------------------------------------------------------------------------
MLRT        clb
            xch R7
            ldm 0
            xch R14
            ldm 0
ZLPM        src P3
            wrm
            isz R7,ZLPM
            wr0
            ldm 4
            xch R5
            src P1
            rd0
            rar
            jcn cn,ML4
            ld R2
            xch R0
            ldm 0
            xch R1
            jms CPLRT
            stc
            ldm 0FH
            src P1
            wr3
ML4         ral
            xch R15
            src P2
            rd0
            rar
            jcn cn,ML6
            ld R4
            xch R0
            ldm 0
            xch R1
            jms CPLRT
            stc
            ldm 0FH
            src P2
            wr3
ML6         ral
            clc
            add R15
            src P3
            wr0

ML1         src P2
            rdm
            xch R15

ML2         ld R15
            jcn z,ML3
            dac
            xch R15
            ldm 5
            xch R3
            ld R14
            xch R7
            jms MADRT
            jun ML2

ML3         inc R14
            isz R5,ML1
            src P3
            rd0
            rar
            jcn cn,ML5
            ldm 0
            wr0
            xch R1
            ld R6
            xch R0
            jms CPLRT

ML5         src P1
            rd3
            jcn z,ML8
            ld R2
            xch R0
            ldm 0
            xch R1
            jms CPLRT
            ldm 0
            src P1
            wr3

ML8         src P2
            rd3
            jcn z,ML7
            ld R4
            xch R0
            ldm 0
            xch R1
            jms CPLRT
            ldm 0
            src P2
            wr3
            nop
            nop
ML7         bbl 0

MADRT       clc
STMAD       src P1
            rdm
            src P3
            adm
            daa
            wrm
            isz R3,SKIPML
            bbl 0
SKIPML      isz R7,STMAD
            bbl 0

CPLRT       clc
COMPL       src P0
            ldm 6
            adm
            cma
            wrm
            isz R1,COMPL
            stc
TENS        ldm 0
            src P0
            adm
            daa
            wrm
            inc R1
            jcn c,TENS
            src P0
            rd0
            rar
            cmc
            ral
            wr0
            bbl 0

;-------------------------------------------------------------------------------
; Print the 16 digit quotient in RAM register pointed to by P3. The most significant
; digit is at location 0FH, therefore it's the first digit printed. The least significant
; digit is at location 00H, so it's the last digit printed. Prints the first 7 digits
; (the whole number part), then the decimal point, then the remaining 9 digits
; (the fractional part). Suppresses leading and trailing zeros. R11 serves as a
; leading zero flag (1 means skip leading zeros).
; Adapted from code in the "MCS-4 Micro Computer Set Users Manual, Feb. 73".
;-------------------------------------------------------------------------------
prnquot:    ldm 0
            xch R10                 ; R10 is the loop counter (0 gives 16 times thru the loop for all 16 digits of the register)
            ldm 0FH
            xch R7                  ; make P3 point to the most significant digit of the quotient
            ldm 1
            xch R11                 ; set the leading zero flag

prnquot1:   src P3                  ; P3 points to the digit to be printed
            ldm 9                   ; units digit (the one immediately to the left of the decimal point) is at address 9
            clc
            sub R7                  ; compare by subtraction
            jcn zn,prnquot2         ; jump if this is not the units digit
            ldm 0
            xch R11                 ; since this is the units digit, clear the leading zero flag
prnquot2:   ld R11                  ; get the leading zero flag
            rar                     ; rotate the flag into carry
            rdm                     ; read the digit to be printed
            jcn zn,prnquot3         ; jump if this digit to be printed is not zero
            jcn c,prnquot4          ; this digit is zero, jump if the leading zero flag is set

prnquot3:   xch R3                  ; this digit is not zero OR the leading zero flag is not set. put the digit as least significant nibble into R3
            ldm 3
            xch R2                  ; most significant nibble ("3" for ASCII characters 30H-39H)
            jms putchar             ; print the ASCII code for the digit
            src P3
            ldm 0
            xch R11                 ; now that a digit has been printed, reset the leading zero flag

prnquot4:   ld  R7                  ; least significant nibble of the pointer to the digit
            dac                     ; next digit
            xch R7                  ; back into R7, P3 now points to the next digit of the quotient to be printed

            ldm 8                   ; the fractional part of the quotient begins at address 8
            clc
            sub R7                  ; compare by subtraction. acc is zero if R7 equals 8. the carry flag is set if R7 less than or equal 8
            jcn zn,prnquot5         ; jump if R7 != 8 (the next digit to be printed is not the tenths digit)
            jms zeros               ; the next digit to be printed is the tenths digit. check if the fractional part of the quotient is all zeros
            jcn z,prnquot7          ; if the fractional part is all zeros, skip to the end and exit
            fim P1,'.'              ; else use a decimal point before the tenths digit to separate the whole number and fractional parts
            jms putchar             ; print the decimal point
            jun prnquot6            ; go increment counter

prnquot5:   jcn cn,prnquot6         ; jump if the next digit to be printed is not part of the fractional part
            jms zeros               ; we're printing the fractional part. is the rest of fractional part all zeros?
            jcn z,prnquot7          ; if the rest of the fractional part is all zeros, skip to the end

prnquot6:   isz R10,prnquot1        ; loop 16 times to print all 16 digits
prnquot7:   bbl 0                   ; finished with all 16 digits, return to caller

            org 0500H

;-------------------------------------------------------------------------------
; Multi-digit division routine taken from:
; "A Microcomputer Solution to Maneuvering Board Problems" by Kenneth Harper Kerns, June 1973
; Naval Postgraduate School Monterey, California.
; P1 points to the dividend, P2 points to the remainder,
; P3 points to the divisor, P4 points to the quotient
;-------------------------------------------------------------------------------
; DIVIDE ROUTINE, SETS UP TO USE DECDIV
DVRT        src P1
            rd0
            rar
            jcn cn,DV4
            ld R2
            xch R0
            ldm 0
            xch R1
            jms CPLRT
            stc
            ldm 1
            wr1
DV4         ral
            xch RF
            src P3
            rd0
            rar
            jcn cn,DV6
            ld R6
            xch R0
            ldm 0
            xch R1
            jms CPLRT
            stc
            ldm 1
            wr1
DV6         ral
            clc
            add RF
            src P4
            wr0
            jms DECDIV
CHKPT       src P1
            rd1
            jcn z,DV1
            ld R2
            xch R0
            ldm 0
            wr1
            xch R1
            jms CPLRT
DV1         src P3
            rd1
            jcn z,DV2
            ld R6
            xch R0
            ldm 0
            wr1
            xch R1
            jms CPLRT
DV2         src P4
            rd0
            rar
            jcn cn,ATLAST
            clc
            ral
            wr0
            ld R8
            xch R0
            ldm 0
            xch R1
            jms CPLRT
ATLAST      bbl 0

            org 0600H               ; next page

; DECIMAL DIVISION ROUTINE
;  WRITTEN  BY
;  G. A. KILDALL
;  ASSISTANT PROFESSOR
;  NAVAL POSTGRADUATE SCHOOL
;  MONTEREY,CALIFORNIA
DECDIV      ldm 9
            src P1
            wr2
            src P3
            wr2
            src P4
            wr2
            clb
ZEROR       src P4
            wrm
            src P2
            wrm
            inc R5
            isz R9,ZEROR
            clb
            xch RB
LZERO       ld RB
            cma
            xch R3
            src P1
            rdm
            jcn zn,FZERO
            isz RB,LZERO
            jun ENDDIV

FZERO       ld RB
            xch R5
            clb
            xch R3
COPYA       src P1
            rdm
            src P2
            wrm
            inc R3
            isz R5,COPYA
            ld RB
            xch RE
            src P1
            rd2
            add RB
            xch RB
            tcc
            xch RA
            clb
            xch RD
LZERO1      ld RD
            cma
            xch R7
            src P3
            rdm
            jcn zn,FZERO1
            isz RD,LZERO1
            bbl 1

FZERO1      ld RD
            xch RF
            rd2
            add RD
            xch RD
            tcc
            xch RC
            src P4
            rd2
            add RD
            xch RD
            ldm 0
            add RC
            xch RC
            clc
            ld RD
            sub RB
            xch R9
            cmc
            ld RC
            sub RA
            jcn c,NDERF
            bbl 0

NDERF       jcn zn,DOVRFL
            ldm 15
            xch RB
            ld R6
            xch RA
COPYC1      src P3
            rdm
            src P5
            wrm
            ld R7
            jcn z,PCPY1
            dac
            xch R7
            ld RB
            dac
            xch RB
            jun COPYC1

PCPY1       ld RB
            jcn z,DIV
            dac
            xch RB
            src P5
            ldm 0
            wrm
            jun PCPY1

DIV         ldm 10
            xch RC
SUB0        clb
            xch R3
SUB1        clb
            xch R5
            ld RB
            xch R7
            src P2
SUB2        rdm
            src P3
            sbm
            jcn c,COMPL1
            add RC
            clc
COMPL1      cmc
            src P2
            wrm
            inc R5
            src P2
            isz R7,SUB2
            ld R5
            jcn z,CHKCY
            rdm
            sub R7
            wrm
            cmc
CHKCY       jcn c,CYOUT
            inc R3
            jun SUB1
CYOUT       ld RB
            xch R7
            clb
            xch R5
ADD4        src P3
            rdm
            src P2
            adm
            daa
            wrm
            inc R5
            isz R7,ADD4
            ld R5
            jcn z,SKADD
            tcc
            src P2
            adm
            wrm
SKADD       src P4
            ld R3
            wrm
            ld R9
            jcn z,ENDDIV
            dac
            xch R9
            isz RB,SUB0
ENDDIV      clb
            xch RB
            ld RF
            xch R7
COPYC2      src P3
            rdm
            src P5
            wrm
            inc RB
            isz R7,COPYC2
            ld RB
            jcn z,PSTFIL
FILLZ       src P5
            clb
            wrm
            isz RB,FILLZ
PSTFIL      bbl 0
DOVRFL      bbl 1

            org 0700H               ; next page

;-----------------------------------------------------------------------------------------
; print the menu options
; note: this function and the text it references need to be on the same page.
;-----------------------------------------------------------------------------------------
menu:       fim P0,lo(menutxt)
            jun page7print

page7print: fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,page7print       ; go back for the next character
            bbl 0

menutxt:    data CR,LF,LF
            data "1 - LED demo 1",CR,LF
            data "2 - LED demo 2",CR,LF
            data "3 - Addition demo",CR,LF
            data "4 - Subtraction demo",CR,LF
            data "5 - Multiplication demo",CR,LF
            data "6 - Division demo",CR,LF
            data "7 - Tic-Tac-Toe game",CR,LF
            data "8 - Number guessing game",CR,LF
            data "9 - Display switch positions",CR,LF,LF
            data "Your choice (1-9): ",0

            org 0800H               ; next page

;-----------------------------------------------------------------------------------------
; print functions for the addition and subtraction demos.
; note: these functions and the text they reference need to be on the same page.
;-----------------------------------------------------------------------------------------
firstnum:   fim P0,lo(firsttxt)
            jun page8print

secondnum:  fim P0,lo(secondtxt)
            jun page8print

prnsum:     fim P0,lo(sumtxt)
            jun page8print

prnoverflow:fim P0,lo(overtxt)
            jun page8print

prndiff:    fim P0,lo(difftxt)
            jun page8print

prnproduct: fim P0,lo(producttxt)
            jun page8print

prnquotient:fim P0,lo(quottxt)
            jun page8print

page8print: fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,page8print       ; go back for the next character
            bbl 0

firsttxt:   data "First integer:  ",0
secondtxt:  data "Second integer: ",0
sumtxt:     data "Sum:            ",0
difftxt:    data "Difference:    " ,0
producttxt: data "Product:        ",0
quottxt:    data "Quotient:       ",0
overtxt     data "Overflow!",0

banner:     fim P0,lo(banner04txt)  ; assume 4004
            jms detectCPU           ; detect 4004 or 4040 cpu
            jcn zn,banner1          ; non-zero means 4004
            fim P0,lo(banner40txt)
banner1:    jun page8print

banner04txt: data CR,LF,"Intel 4004 SBC",0
banner40txt: data CR,LF,"Intel 4040 SBC",0

; inform the player that he's won the game of tic-tac-toe
printPlayerWon: fim P0,lo(playerWontxt)
                jun page8print

playerWontxt:   data    CR,LF
                data    "You Won!",0

            org 0900H

;-----------------------------------------------------------------------------------------
; print the instructions for the addition demo and Tic-Tac-Toe game.
; note: these functions and the text they reference need to be on the same page.
;-----------------------------------------------------------------------------------------
; prompt for the player's tic-tac-toe square
printPrompt:    fim P0,lo(moveprompttxt)
                jun page9print

; inform the player that the tic-tac-toe game is tied
printGameTied:  fim P0,lo(tiegametxt)
                jun page9print

; inform the player that the computer has won the tic-tac-toe game
printCompWon:   fim P0,lo(computerwontxt)
                jun page9print

; print the instructions for the decimal addition demo
addinstr:       fim P0,lo(addtxt)
page9print:     fin P1                  ; fetch the character pointed to by P0 into P1
                jms txtout              ; print the character, increment the pointer to the next character
                jcn zn,page9print       ; not yet at the end of the string, go back for the next character
                bbl 0

addtxt:         data CR,LF,LF
                data "Addition demo:",CR,LF,LF
                data "Enter two integers from 1 to 16 digits.",CR,LF
                data "The second integer is added to the first. ^C exits.",0

computerwontxt: data CR,LF
                data "The Computer Wins!",0

tiegametxt:     data CR,LF
                data "The game is a draw!",CR,LF,0

moveprompttxt:  data CR,LF
                data "Your move? (1-9) ",0

                org 0A00H

;-----------------------------------------------------------------------------------------
; print the instructions for the subtraction demo and "built by" message
; note: these functions and the text they reference need to be on the same page.
;-----------------------------------------------------------------------------------------
; print the "built by" easter egg message
builtby:    fim P0,lo(builttxt)
            jun pageAprint

; print the instructions for the decimal subtraction demo
subinstr:   fim P0,lo(subtxt)
pageAprint: fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,pageAprint       ; not yet at the end of the string, go back for the next character
            bbl 0

subtxt:     data CR,LF,LF
            data "Subtraction demo:",CR,LF,LF
            data "Enter two integers from 1 to 16 digits.",CR,LF
            data "The second integer is subtracted from the first. ^C exits.",0

builttxt:   data " built by Jim Loos.",CR,LF
            data "Firmware assembled on ",DATE," at ",TIME,".",0

            org 0B00H

;-----------------------------------------------------------------------------------------
; print the instructions for the multiplication and division demos
; note: these functions and the text they reference need to be on the same page.
;-----------------------------------------------------------------------------------------
divinstr:   fim P0,lo(dividetxt)
            jun pageBprint

multinstr:  fim P0,lo(multitxt)
pageBprint: fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,pageBprint       ; not yet at the end of the string, go back for the next character
            bbl 0

multitxt:   data CR,LF,LF
            data "Multiplication demo:",CR,LF,LF
            data "Enter two integers from 1 to 8 digits.",CR,LF
            data "The first integer is multiplied by the second. ^C exits.",0

dividetxt:  data CR,LF,LF
            data "Division demo:",CR,LF,LF
            data "Enter two integers from 1 to 7 digits.",CR,LF
            data "The first integer is divided by the second. ^C exits.",0

            org 0C00H
;-----------------------------------------------------------------------------------------
; print functions for the number guessing game
; note: these functions and the text they reference need to be on the same page.
;-----------------------------------------------------------------------------------------
gameintro:  fim P0,lo(gameintrotxt)
            jun pageCprint

gameprompt: fim P0,lo(prompttxt)
            jun pageCprint

promptguess:fim P0,lo(guesstxt)
            jun pageCprint

success1:   fim P0,lo(successtxt1)
            jun pageCprint

success2:   fim P0,lo(successtxt2)
            jun pageCprint

toolow:     fim P0,lo(toolowtxt)
            jun pageCprint

toohigh:    fim P0,lo(toohightxt)
            jun pageCprint

again:      fim P0,lo(againtxt)
pageCprint: fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,pageCprint       ; not yet at the end of the string, go back for the next character
            bbl 0

gameintrotxt:data CR,LF,LF,"Try to guess the number (0-99) that I'm thinking of.",0
prompttxt   data CR,LF,"Press the Space Bar to continue...",0
guesstxt    data CR,LF,"Your guess? (0-99) ",0
successtxt1 data CR,LF,"That's it! You guessed it in ",0
successtxt2 data " tries.",CR,LF,0
toolowtxt   data CR,LF,"Too low.",CR,LF,0
toohightxt  data CR,LF,"Too high.",CR,LF,0
againtxt    data CR,LF,"Play again? (Y/N)",0

            org 0D00H

;--------------------------------------------------------------------------------------------------
; Simple number guessing game. The player tries to guess a pseudo random number from
; 0 to 99.
;--------------------------------------------------------------------------------------------------
game:       jms gameintro           ; print "Try to guess the number..."
game1:      jms gameprompt          ; prompt "Press any key to continue..."

            fim P2,accumulator
            jms clrram
            fim P2,addend           ; P2 points the memory register where the second number digits are stored (20H-2FH)
            jms clrram              ; clear RAM 20H-2FH

            fim P2,addend
            src P2
            ldm 1
            wrm                     ; adding adden to accumulator increments by 1

            fim P1,accumulator
            fim P2,addend
game2:      jcn tn,game3            ; jump if the start bit has been detected
game2a:     src P2                  ; P2 points to the "addend" (which contains 1)
            rdm                     ; read the addend digit
            src P1                  ; P1 points to the "accumulator"
            adm                     ; add the digit from the "accumulator" to the addend (increment the accumulator)
            daa                     ; convert the sum from binary to decimal
            wrm                     ; write the sum back to the "accumulator"
            inc R3                  ; point to next "accumlator" digit
            inc R5                  ; point to next addend digit to be added to the accumulator
            isz R11,game2a          ; do both least significant digits
            jun game2               ; loop back to check for the start bit

game3:      ldm 0
            fim P1,accumulator+02H
game4:      src P1
            wrm
            isz R3,game4            ; clear the accumuultor except the two least significant digits results in a number 0-99

            ;jms newline
            ;fim P3,accumulator
            ;jms prndigits          ; for debugging, print the pseudo-random number

            fim P2,attempts
            jms clrram              ; clear number of attempts

game5:      fim P1,attempts
            fim P2,addend
            jms addition            ; increment number of attempts
            jms promptguess         ; prompt "Your guess: "
            fim P2,guess
            jms clrram
            ldm 16-2                ; maximum 2 digits
            xch R13                 ; R13 is the digit counter
            fim P2,guess
            jms getnumber           ; get the player's guess
            jcn z,game5a
            jun reset2              ; control C exits

; the subtrahend is subtracted from the minuend. The difference replaces the minuend i.e. *P1=*P1-*P2
game5a:     fim P1,guess            ; payer's guess
            fim P2,accumulator      ; random number
            jms subtract            ; subtract the random number from the guess
            jcn z,game6             ; jump if the difference is positive (the guess is GT the random number)
            jms toolow              ; the difference is negative. the guess is LT the random number. print "Too low."
            jun game5

; the difference is not negative, check to see if the difference
; is zero indicating the two numbers were equal indicating the number was guessed
game6:      fim P1,guess            ; P1 points to the difference between the two numbers
game7:      src P1
            rdm                     ; read the first digit of the difference
            jcn nz,game8            ; jump if the difference is not zero
            isz R3,game7            ; loop until all 16 data RAM character have been checked
            jms success1            ; print "That's it! You guessed it in"
            fim P3,attempts
            jms prndigits
            jms success2
            jms again               ; prompt "Play again? (Y/N)"
            jms getchar
            fim P3,'Y'              ; is it "Y"
            jms compare
            jcn z,game              ; go back for another game
            fim P3,'y'              ; is it "y"
            jms compare
            jcn z,game              ; go back for another game
            jun reset

; the difference is neither negative nor zero thus
; the guess must be greater than the random number.
game8:      jms toohigh             ; print "Too high." the guess is GT the number
            jun game5

            org 0E00H

;--------------------------------------------------------------------------------
; "Tic-Tac-Toe" (or "Naughts and Crosses" or "Xs and Os")
; inspired by the Tic-Tac-Toe game found at:
; https://www.woofys-place.uk/index.php/2021/06/13/intel-4004-50th-anniversary-computer/
;--------------------------------------------------------------------------------

;       |     |
;   20H | 21H | 22H
;       |     |
;  -----------------
;       |     |
;   23H | 24H | 25H
;       |     |
;  -----------------
;       |     |
;   26H | 27H | 28H
;       |     |
;
; RAM 0 register 2 - stores the OXO board in locations 20H-28H, 0=empty square, 1=player's 'X', -1=computer's 'O'
; RAM 0 register 3 - stores the calculation results for checking the OXO board
; RAM 0,register 2, Status 0 - holds a counter used to generate random computer moves

; start a new game
newGame:        jms clearBoard          ; clear the board for a new game
                jms printSquares        ; show the player the squares
newGame1:       jms printPrompt         ; prompt for player's selection
                jms playerMove          ; get the player's selection
                jcn z,newGame1          ; zero means an illegal square selected, try again
                jms makePlayerMove      ; else, make the player's move
                jms newline
                jms hasPlayerWon        ; has the player entered a winning move?
                jcn z,newGame2          ; no, continue below
                jms printBoard          ; display the updated board with the player's win
                jms printPlayerWon      ; yes, print "You Won!"
                jun newGame             ; go back to start a new game

newGame2:       jms winningMove         ; is there a move the computer can make to win?
                jcn z,newGame3          ; no, continue below
                jms makeCompMove        ; yes, make the computer's winning move
                jms printBoard          ; print the updated board with the computer's winning move
                jms printCompWon        ; inform the player that the computer won
                jun newGame             ; go back to start a new game

newGame3:       jms blockingMove        ; must the computer move to block the player?
                jcn z,newGame4          ; no, continue below
                jms makeCompMove        ; yes, make the computer's blocking move
                jms printBoard          ; print the updated board with the computer's blocking move
                jun newGame1            ; go back for the player's next move

newGame4:       jms randomMove          ; computer selects a random square
                jcn z,newGame5          ; jump if all the squares are filled; game drawn
                jms makeCompMove        ; else, make the computer's random move
                jms printBoard          ; print the updated board with the computer's random move
                jms randomMove          ; call this function to detect if all squares filled
                jcn z,newGame5          ; zero means all squares filled; game drawn
                jun newGame1            ; else, go back for the player's next move

newGame5:       jms printBoard          ; print the updated board showing the draw
                jms printGameTied       ; inform the player the game is a draw
                jun newGame             ; go back to start a new game

;clear the grid (data RAM characters 20H-28H) in preparation for a new game.
clearBoard:     ldm 16-9                ; 9 data RAM characters
                xch R7                  ; R7 is the counter
                ldm 0
                fim P5,grid             ; P5 points to data RAM chip 0, register 2
clearBoard1:    src P5
                wrm                     ; clear the data RAM character
                inc R11                 ; next data RAM location
                isz R7,clearBoard1      ; loop back until all 9 characters are cleared
                bbl 0

; prints the OXO grid
; prints 'X' for the player's squares.
; prints 'O' for the computer's squares.
; prints '-' for empty squares.
printBoard:     jms newline
                fim P5,grid             ; P5 points to data RAM chip 0, register 2
                ldm 16-3
                xch R7                  ; R7 is the counter for the 3 columns
printBoard0:    ldm 16-3
                xch R8                  ; R8 is the counter for the 3 rows
printBoard1:    src P5                  ; P5 points to the square in the grid
                rdm                     ; read the square
                fim P1,'-'              ; '-' to indicate that the square is empty
                jcn z,printBoard2       ; go print '-' if the square contains 0
                xch R9                  ; else, store the square's value in R9
                ldm 16-1                ; -1 indicates square is occupied by computer's 'O'
                clc
                sub R9                  ; compare the square's value in R9 to -1 by subtraction
                fim P1,'O'              ; 'O' to indicate computer's square
                jcn z,printBoard2       ; go print 'O' if the square contains -1
                fim P1,'X'              ; else, print 'X' to indicate player's square
printBoard2:    jms putchar             ; print the character
                fim P1,' '              ; print ' ' after each square for formatting
                jms putchar             ; print the space
                inc R11                 ; increment least significant nibble of P5 to point to next square
                isz R8,printBoard1      ; loop back for all three columns
                jms newline             ; start on the next line
                isz R7,printBoard0      ; loop back for all three rows
                bbl 0

; player selects a square in the grid for their move.
; increments status character 0 of register 'grid' while waiting for the start bit
; producing a pseudo-random number for the computer's 'randomMove' function.
; returns 1 if legal empty square selected. P7 points to the legal empty square selected.
; returns 0 if an illegal square selected.
; Control C exits the game, returns to the menu.
playerMove:     fim P7,grid             ; RAM 0 register 2
                src P7 
                rd0                     ; read RAM 0 register 2 (grid) status character 0 into A
playerMove00:   iac                     ; increment A
                wr0                     ; write A to the the status character 0
                jcn t,PlayerMove00      ; loop back until the start bit is detected
                jms getchar4            ; get the player's input
                ld R2                   ; get the most significant nibble of the character
                jcn zn,playerMove0      ; jump if it's not zero
                ldm 03H                 ; get the least significant nibble of the character
                sub R3                  ; compare the least significant nibble to 03H by subtraction
                jcn zn,playerMove0      ; jump if it's not control C (03H)
                jun reset2              ; control C cancels, return to the menu

playerMove0:    ldm 3
                sub R2
                jcn zn,playerMove1      ; jump if the most significant nibble of the character input is not 3 (not a number 0-9)
                ld R3                   ; least significant nibble square number now in A
                dac                     ; decrement A (1-9 now becomes 0-8)
                xch R3                  ; save the square number in R3
                ldm 9
                xch R4                  ; R4 contains 9
                ld R3                   ; A contains the square number
                clc
                sub R4                  ; subtract 9 from the square number
                jcn c,playerMove1       ; jump if the square number is greater than 8
                ld R3                   ; load the square number into A
                fim P7,grid             ; address of squares register
                xch R15                 ; address of selected square in P7
                src P7                  ; P7 points to the square selected by the player
                rdm                     ; retrieve the value stored in the square
                jcn nz,playerMove1      ; jump if the selected square is already used
                bbl 1                   ; return 1 if legal square
playerMove1:    bbl 0                   ; return 0 if illegal square

; store 1 to indicate player's 'X' in the square pointed to by P7.
makePlayerMove: ldm 1
                src P7
                wrm                     ; store 1
                bbl 0

; store -1 to indicate computer's 'O' in the square pointed to by P7.
makeCompMove:   ldm 16-1
                src P7
                wrm                     ; store -1
                bbl 0

; computer randomly selects a square in the grid for its move.
; returns 1 if a random empty square found.
; else, returns 0 if there are no empty squares to move to (game tied).
; P7 points to the random empty square selected.
randomMove:     fim P7,grid             ; P7 points to the start of the OXO grid
                src P7
                rd0                     ; fetch pseudo-random number for search start position
                clc
                rar                     ; divide 0-15 by 2 to make it 0-7
                xch R15                 ; store random number as least significant nibble of P7
                ldm 16-9                ; -9, loop counter
                xch R2                  ; store loop counter in R2
randomMove3:    src P7
                rdm                     ; read the data RAM character
                jcn z,randomMove1       ; found empty square
                inc R15                 ; else, increment R15 to point to the next data RAM location
                ldm 9
                clc
                sub R15                 ; has R15 reached the end of the grid?
                jcn nz,randomMove2      ; no, continue
                fim P7,grid             ; yes, start back at the beginning of the grid
randomMove2:    isz R2,randomMove3      ; loop until all the squares in the grid have been checked
                bbl 0                   ; return zero if no empty squares found
randomMove1:    bbl 1                   ; return 1 if an empty square found, P7 points to the empty square square

; returns 1 if the player has won, else returns 0
hasPlayerWon:   jms calcWinLose         ; sum all 8 rows
                fim P0,calcResults      ; point to results of calculations
hasPlayerWon2:  src P0
                rdm                     ; read the result calculated earlier
                dac
                dac
                dac
                jcn nz,hasPlayerWon1    ; if the result is zero, this row added up to 3, thus the player has won
                bbl 1
hasPlayerWon1:  inc R1                  ; point to the next data RAM location
                isz R1,hasPlayerWon2    ; loop through all 16 data RAM characters
                bbl 0

; checks if the computer can win this move.
; returns 1 if the game can be won this move.
; else, returns 0 if no win is possible this move.
; P7 points to the winning square.
winningMove:    fim P7,calcResults      ; point to results of calculations
winningMove2:   src P7
                rdm                     ; read the sum of the row
                iac
                iac
                jcn nz,winningMove1     ; continue below if the sum did not add up to -2
                ld  R15                 ; else, load the least significant nibble
                inc R15                 ; make it point to the empty square in the winning row
                src P7
                rdm                     ; read the empty square in the winning row
                fim P7,grid
                xch R15                 ; P7 now points to the empty square in the winning row
                bbl 1                   ; return with P7 pointing to the empty square in the winning row
winningMove1:   inc R15                 ; point P7 to the next data RAM character
                isz R15,winningMove2    ; loop through all 16 data RAM characters
                bbl 0                   ; no win possible this turn

; checks if the computer needs to block a potential player win.
; returns 1 if a blocking move is required to prevent a player win.
; else, returns 0 if a blocking move is not required.
; P7 points to the square for the blocking move.
blockingMove:   fim P7,calcResults      ; point to results of calculations
blockingMove2:  src P7
                rdm
                dac
                dac
                jcn nz,blockingMove1    ; if not added up to 2
                inc R15
                src P7
                rdm
                fim P7,grid
                xch R15
                bbl 1                   ; return with P7 pointing to square
blockingMove1:  inc R15
                isz R15,blockingMove2
                bbl 0                   ; no block needed this turn

                org 0F00H               ;next page
; the 8 possible rows (3 horizontal, 3 vertical, 2 diagonal) in the grid are
; summed to find if there is a winning position (sum = -2) or losing position
; that needs blocking (sum = 2). two values are stored for each row (the sum
; and last blank square) in the 16 characters of RAM 0 register bank 3 (30H-3FH).
calcWinLose:    fim P0,grid+0           ; first row: squares 0,1,2 (horizontal)
                fim P1,grid+1
                fim P2,grid+2
                fim P3,calcResults      ; first row pointer
                jms rowCalc

                fim P0,grid+3           ; second row: squares 3,4,5 (horizontal)
                fim P1,grid+4
                fim P2,grid+5
                fim P3,calcResults+2    ; second row pointer
                jms rowCalc

                fim P0,grid+6           ; third row: squares 6,7,8 (horizontal))
                fim P1,grid+7
                fim P2,grid+8
                fim P3,calcResults+4    ; third row pointer
                jms rowCalc

                fim P0,grid+0           ; fourth row: squares 0,3,6 (vertical)
                fim P1,grid+3
                fim P2,grid+6
                fim P3,calcResults+6    ; fourth row pointer
                jms rowCalc

                fim P0,grid+1           ; fifth row: squares 1,4,7 (vertical)
                fim P1,grid+4
                fim P2,grid+7
                fim P3,calcResults+8    ; fifth row pointer
                jms rowCalc

                fim P0,grid+2           ; sixth row: squares 2,5,8 (vertical)
                fim P1,grid+5
                fim P2,grid+8
                fim P3,calcResults+10   ; sixth row pointer
                jms rowCalc

                fim P0,grid+0           ; seventh row: squares 0,4,8 (diagonal)
                fim P1,grid+4
                fim P2,grid+8
                fim P3,calcResults+12   ; seventh row pointer
                jms rowCalc

                fim P0,grid+2           ; eight row: squares 2,4,6 (diagonal)
                fim P1,grid+4
                fim P2,grid+6
                fim P3,calcResults+14   ; eight row pointer
                jms rowCalc
                bbl 0

; on entry, P0 points to the first square in the row, P1 points to the second square,
; P2 points to the third square. P3 points to the data RAM where the sum of the row is stored.
rowCalc:        src P0                  ; calculate sum of this row (P0+P1+P2) and store at P3
                clb                     ; the accumulator is set to 0 and the carry bit is reset
                adm                     ; add the value in the first square of this row to the accumulator
                src P1
                clc
                adm                     ; add the value in the second square of this row to the accumulator
                src P2
                clc
                adm                     ; add the value in the third square of this row to the accumulator
                src P3
                wrm                     ; store the sum of this row in data RAM pointed to by P3

; find the first empty square in this row and store it in data RAM at P3+1
                ldm 16-1
                xch R8                  ; -1 to indicate no empty squares in this row
                src P0
                rdm                     ; read the grid square pointed to by P0
                jcn nz,rowCalc1         ; jump if it's not empty
                ld  R1                  ; load the low nibble of the empty square into A
                xch R8                  ; store it in R8
                jun rowCalc3            ; go store it in data RAM

rowCalc1:       src P1
                rdm                     ; read the grid square pointed to by P1
                jcn nz,rowCalc2         ; jump if it's not empty
                ld  R3                  ; load the low nibble of the empty square into A
                xch R8                  ; store it in R8
                jun rowCalc3            ; go store it in data RAM

rowCalc2:       src P2
                rdm                     ; read the grid square pointed to by P2
                jcn nz,rowCalc3         ; jump if it's not empty
                ld  R5                  ; load the low nibble of the empty square into A
                xch R8                  ; store it in R8
rowCalc3:       inc R7                  ; increment P3 to point to the next data RAM character
                src P3
                xch R8                  ; get the low nibble of the empty cell from R8 into A
                wrm                     ; store the low nibble of the empty cell in the data RAM pointed to by P3
                bbl 0

;-----------------------------------------------------------------------------------------
; print info for the Tic-Tac-Toe game.
; this function and the text to be printed must all be on the same page.
;-----------------------------------------------------------------------------------------
printSquares:   fim P0,lo(squarestxt)
                jun pageFprint

pageFprint:     fin P1                  ; fetch the character pointed to by P0 into P1
                jms txtout              ; print the character, increment the pointer to the next character
                jcn zn,pageFprint        ; go back for the next character
                bbl 0

squarestxt:     data    CR,LF,LF,"TIC-TAC-TOE",CR,LF,LF
                data    "You will be 'X', the computer will be 'O'",CR,LF
                data    "The move positions are:",CR,LF
                data    "1 2 3",CR,LF
                data    "4 5 6",CR,LF
                data    "7 8 9",CR,LF,0


