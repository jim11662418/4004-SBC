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
; set for 300 bps, no parity, 8 data bits, 1 stop bit.
; 110 bps would be more period-correct but takes forever!
; Syntax is for the Macro Assembler AS V1.42 http://john.ccac.rwth-aachen.de:8000/as/
;----------------------------------------------------------------------------------------------------

; Tell the ASW assembler that this source is for the Intel 4004.
            cpu 4040

; Conditional jumps syntax for ASW:
; jcn t     jump if test = 0 - positive voltage or +5VDC
; jcn tn    jump if test = 1 - negative voltage or -10VDC
; jcn c     jump if cy = 1
; jcn cn    jump if cy = 0
; jcn z     jump if accumulator = 0
; jcn zn    jump if accumulator != 0

            include "bitfuncs.inc"  ; Include bit functions so that FIN can be loaded from a label (upper 4 bits of address are loped off).
            include "reg4004.inc"   ; Include 4004 register definitions.

CR          equ 0DH
LF          equ 0AH
ESCAPE      equ 1BH

; I/O port addresses
SERIALPORT  equ 00H     ; Address of the serial port. The least significant bit of port 00 is used for serial output.
LEDPORT     equ 40H     ; Address of the port used to control the red LEDs. "1" turns the LEDs on.
SWITCHPORT  equ 10H     ; Address of the input port for the rotary switch. Switch contacts pull the bits low, i.e. switch position "2" gives "1101".

; RAM register addresses
CHIP0REG0   equ 00H     ; 4002 data ram chip 0, register 0 16 main memory characters plus 4 status characters
CHIP0REG1   equ 10H     ; 4002 data ram chip 0, register 1  "   "    "         "       "  "    "       "
CHIP0REG2   equ 20H     ; 4002 data ram chip 0, register 2  "   "    "         "       "  "    "       "
CHIP0REG3   equ 30H     ; 4002 data ram chip 0, register 3  "   "    "         "       "  "    "       "
CHIP1REG0   equ 40H     ; 4002 data ram chip 1, register 0  "   "    "         "       "  "    "       "
CHIP1REG1   equ 50H     ; 4002 data ram chip 1, register 1  "   "    "         "       "  "    "       "
CHIP1REG2   equ 60H     ; 4002 data ram chip 1, register 2  "   "    "         "       "  "    "       "
CHIP1REG3   equ 70H     ; 4002 data ram chip 1, register 3  "   "    "         "       "  "    "       "

GPIO        equ 80H     ; 4265 General Purpose I/O device address

; 4265 Modes:   WMP     Port:   W   X   Y   Z
GPIOMODE0   equ 0000B   ;       I   I   I   I (reset)
GPIOMODE4   equ 0100B   ;       O   O   O   O
GPIOMODE5   equ 0101B   ;       I   O   O   O
GPIOMODE6   equ 0110B   ;       I   I   O   O
GPIOMODE7   equ 0111B   ;       I   I   I   O

            org 0000H

;--------------------------------------------------------------------------------------------------
; Power-on-reset Entry
;--------------------------------------------------------------------------------------------------
reset:      nop                     ; To avoid problems with power-on reset, the first instruction at
                                    ; program address 000 should always be an NOP. 
            jms ledsoff             ; turn off all four leds

            ldm 0001B
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

            jms banner              ; print "Intel 4004 SBC" or "Intel 4040 SBC"
reset2:     jms ledsoff             ; all LEDs off
            jms menu                ; print the menu
reset3:     jms getchar             ; wait for a character from serial input, echo it, the character is returned in P1

testfor0:   fim P3,'0'
            jms compare             ; is the character in P1 '0'?
            jcn nz,testfor1         ; jump if no match
            jun reset2              ; no menu item assigned to '0' yet

testfor1:   fim P3,'1'
            jms compare             ; is is the character in P1 '1'?
            jcn nz,testfor2         ; jump if no match
            jun led1demo            ; '1' selects LED demo 1

testfor2:   fim P3,'2'
            jms compare             ; is is the character in P1 '2'?
            jcn nz,testfor3         ; jump if no match
            jun led2demo            ; '2' selects LED demo 2

testfor3:   fim P3,'3'
            jms compare             ; is is the character in P1 '3'?
            jcn nz,testfor4         ; jump if no match
            jun adddemo             ; '3' selects decimal addition demo

testfor4:   fim P3,'4'
            jms compare             ; is is the character in P1 '4'?
            jcn nz,testfor5         ; jump if no match
            jun subdemo             ; '4' selects decimal subtraction demo

testfor5:   fim P3,'5'
            jms compare             ; is is the character in P1 '5'?
            jcn nz,testfor6         ; jump if no match
            jun multdemo            ; '5' selects decimal multiplication demo

testfor6:   fim P3,'6'
            jms compare             ; is is the character in P1 '6'?
            jcn nz,testfor7         ; jump if no match
            jun divdemo             ; '6' selects decimal division demo

testfor7:   fim P3,'7'
            jms compare             ; is is the character in P1 '7'?
            jcn nz,testfor8         ; jump if no match
            jun serialdemo          ; '7' selects serial communications demo

testfor8:   fim P3,'8'
            jms compare             ; is is the character in P1 '8'?
            jcn nz,testfor9         ; jump if no match
            jun game                ; '8' selects number guessing game

testfor9:   fim P3,'9'
            jms compare             ; is is the character in P1 '9'?
            jcn nz,nomatch          ; jump if no match
            jun switchdemo          ; '9' selects rotary switch demo

nomatch:    ld R9                   ; "state" is kept in R9
            jcn z,state0            ; jump if state is '0'

            ldm 1
            clc
            sub R9                  ; compare "state" in R9 to '1' by subtraction
            jcn z,state1            ; jump if state is '1'

            ldm 2
            clc
            sub R9                  ; compare "state" in R9 to '2' by subtraction
            jcn z,state2            ; jump if state is '2'

            ldm 0                   ; else reset "state" back to zero
            xch R9
            jun reset2              ; display the menu options, go back for the next character

state0:     fim P3,ESCAPE           ; state=0, we're waiting for the 1st Escape
            jms compare             ; compare the character in P1 to the "ESCAPE" in P3
            jcn nz,reset2           ; if not ESCAPE, display the menu options, go back for the next character

            ldm 1                   ; the 1st Escape has been received
            xch R9                  ; advance the state from "0" to "1"
            jun reset3              ; go back for the next character

state1:     fim P3,ESCAPE           ; the 1st Escape has been received, we're waiting for the 2nd Escape
            jms compare
            jcn nz,state1a          ; jump if the character in P1 does not match the "ESCAPE" in P3
            ldm 2                   ; else advance the state from "1" to "2"
            xch R9
            jun reset3              ; the 2nd ESCAPE has been received, go back for the next character

state1a:    ldm 0                   ; else reset state back to "0"
            xch R9
            jun reset2              ; display the menu options, go back for the next character

state2:     ldm 0                   ; state=2, the 2nd Escape has been received, now we're waiting for the "?"
            xch R9                  ; reset state back to "0"
            fim P3,"?"
            jms compare             ; was it "?"
            jcn nz,reset2           ; not "?", display the menu options, go back for the next character

            jms newline             ; ESCAPE,ESCAPE,? has been detected
            jms banner
            jms builtby             ; display the "built by" message
            jun reset2              ; display the menu options, go back for the next character
            
;--------------------------------------------------------------------------------------------------
; detects 4004 or 4040 CPU by using the "AN7" instruction available only on the 4040
; returns with accumulator = 0 for 4004 CPU
; returns with accumulator = 1 for 4040 CPU
;--------------------------------------------------------------------------------------------------
detectCPU:  ldm 0
            xch R7                  ; R7 now contains 0000
            ldm 1111b               ; accumulator now contains 1111                 
            an7                     ; logical AND the contents of the accumulator with R7 (4040 CPU only)
            rar                     ; rotate the least significant bit of the accumulator into carry
            jcn c,detectCPU1        ; if carry is set, logical AND failed, must be a 4004
            bbl 1                   ; indicates 4040
detectCPU1: bbl 0                   ; indicates 4004             

;--------------------------------------------------------------------------------------------------
; turn off all four LEDs
;--------------------------------------------------------------------------------------------------
ledsoff:    fim P0,LEDPORT
            src P0
            ldm 0000B
            wmp                     ; write data to RAM LED output port, set all 4 outputs low to turn off all four LEDs
            bbl 0

;--------------------------------------------------------------------------------------------------
; Compare the contents of P1 (R2,R3) with the contents of P3 (R6,R7). Returns with accumulator = 0
; if P1 = P3. Returns with accumulator = 1 if P1 < P3. Returns with accumulator = 2 if P1 > P3.
; Overwrites the contents of P3. Adapted from code in the "MCS-4 Micro Computer Set Users Manual" on page 166:
;--------------------------------------------------------------------------------------------------
compare:    clc                     ; clear carry before "subtract with borrow" instruction
            xch R6                  ; contents of R7 (high nibble of P3) into accumulator
            sub R2                  ; compare the high nibble of P1 (R2) t0 the high nibble of P3 (R6) by subtraction
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
            jms printchar
            fim P1,LF
            jun printchar

;-----------------------------------------------------------------------------------------
; This function is used by all the text string printing functions. If the character in P1 is zero indicating
; the end of the string, returns with accumualtor = 0. Otherwise prints the character and increments
; P0 to point to the next character in the string then returns with accumulator = 1.
;-----------------------------------------------------------------------------------------
txtout:     ld R2                   ; load the most significant nibble into the accumulator
            jcn nz,txtout1          ; jump if not zero (not end of string)
            ld  R3                  ; load the least significant nibble into the accumulator
            jcn nz,txtout1          ; jump if not zero (not end of string)
            bbl 0                   ; end of text found, branch back with accumulator = 0

txtout1:    jms printchar           ; print the character in P1
            inc R1                  ; increment least significant nibble of pointer
            ld R1                   ; get the least significant nibble of the pointer into the accumulator
            jcn zn,txtout2          ; jump if zero (no overflow from the increment)
            inc R0                  ; else, increment most significant nibble of the pointer
txtout2:    bbl 1                   ; not end of text, branch back with accumulator = 1

;--------------------------------------------------------------------------------------------------
; 907 cycles * 11.05 microseconds/cycle = 10,022 microseconds
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
            bbl 0                   ; return with 0 if the start bit was not detected
delayexit:  bbl 1                   ; return with 1 if the start bit was detected

            org 0100H

;--------------------------------------------------------------------------------------------------
; Send the character in P1 (R2,R3) to the serial port (the least significant bit of port 0).
; In addition to P1 (R2,R3) also uses P6 (R12,R13) and P7 (R14,R15).
; NOTE: destroys P1, if needed, make sure that the character in P1 is saved elsewhere!
; (1/(5068000 MHz/7))*8 clocks/cycle = 11.05 microseconds/cycle
; for 300 bps: 1000000 microseconds / 300 bits/second / 11.05 microseconds/cycle = 302 cycles/bit
;--------------------------------------------------------------------------------------------------
printchar:  fim P7,SERIALPORT
            src P7                  ; address of serial port for I/O writes
            ldm 0
            wmp                     ; write the least significant bit of the accumulator to the serial output port
            fim P7,087H             ; 292 cycles
printchar1: isz R14,printchar1
            isz R15,printchar1
            ldm 8                   ; 8 bits to send
            xch R12                 ; R12 is used as the bit counter

printchar2: ld R2                   ; get the most significant nibble of the character from R2
            rar                     ; shift the least significant bit into carry
            xch R2                  ; save the result in R2 for next time
            ld R3                   ; get the least significant nibble of the character from R3
            rar                     ; shift the least significant bit into carry
            xch R3                  ; save the result in R3 for next time
            tcc                     ; transfer the carry bit to the least significant bit of the accumulator
            wmp                     ; write the least significant bit of the accumulator to the serial output port
            fim P7,087H             ; 292 cycles
printchar3: isz R14,printchar3
            isz R15,printchar3
            isz R12,printchar2      ; do it for all 8 bits in R2,R3
            
            ldm 1
            wmp                     ; stop bit
            fim P7,087H             ; 292 cycles
printchar4: isz R14,printchar4
            isz R15,printchar4
            bbl 0

;-----------------------------------------------------------------------------------------
; Wait for a character from the serial input port (TEST input on the 4004 CPU).
; NOTE: the serial input line is inverted by hardware before it gets to the TEST input;
; i.e. TEST=0 when the serial line is high and TEST=1 when the serial line is low,
; therefore the sense of the bit needs to be inverted in software.
; Echo the received character to the serial output port (bit 0 of port 0).
; Flash the LED on bit 0 of the 2nd 4002 about 3 times per second while waiting for
; a character. Returns the 8 bit received character in P1 (R2,R3).
; In addition to P1, also uses P6 (R12,R13) and P7 (R14,R15).
; (1/(5068000 MHz/7))*8 clocks/cycle = 11.05 microseconds/cycle
; for 300 bps: 1000000 microseconds / 300 bits/second / 11.05 microseconds/cycle = 302 cycles/bit
;-----------------------------------------------------------------------------------------
getchar:    ldm 8           
            xch R12                 ; R12 holds the number of bits to receive
            fim P7,LEDPORT
            src P7
            ldm 0
            wmp                     ; turn off all LEDs
getchar2:   jcn tn,getchar4         ; jump if TEST=1 (the start bit has been detected)
            fim P1,0ADH
getchar3:   isz R2,getchar3
            jcn tn,getchar4         ; jump if TEST=1 (the start bit has been detected)
            isz R3,getchar3
            jcn tn,getchar4         ; jump if TEST=1 (the start bit has been detected)
            isz R14,getchar2
            jcn tn,getchar4         ; jump if TEST=1 (the start bit has been detected)
            isz R15,getchar2
            jcn tn,getchar4         ; jump if TEST=1 (the start bit has been detected)
            rar                     ; least significant bit into carry
            cmc                     ; complement it
            ral                     ; back into least significant bit
            wmp                     ; toggle the LED conneted to bit zero of RAM chip 1
            jun getchar2            ; go back and do it again until the start bit is detected

; the start bit has been detected. wait 1/2 bit time...
getchar4:   fim P7,0EBH             ; 144 cycles delay
getchar5:   isz R14,getchar5
            isz R15,getchar5
            fim P7,SERIALPORT
            src P7                  ; define the serial port for I/O writes
            ldm 0                   ; start bit is low
            wmp                     ; echo the start bit to SERIALPORT
            fim P1,0BBH             ; 150 cycles delay (1/2 bit time)
getchar6:   isz R2,getchar6
            isz R3,getchar6
            nop                     ; added to tweak timing

; loop here until all 8 bits bits have been received (302 cycles/bit)
getchar7:   fim P7,0DBH             ; 146 cycles delay (1/2 bit time)
getchar8:   isz R14,getchar8
            isz R15,getchar8
            ldm 1                   ; "0" at the TEST input will be inverted to "1"
            jcn tn,getchar8a        ; jump if TEST input is 1
            jun getchar8b           ; skip the next two instructions since the TEST input is 0
getchar8a:  nop                     ; added to tweak timing
            ldm 0                   ; "1" at the TEST input is inverted to "0"
getchar8b:  wmp                     ; echo the inverted bit back to the serial output port
            rar                     ; rotate the received bit into carry
            ld R2                   ; get the high nibble of the received character from R2
            rar                     ; rotate received bit from carry into most significant bit of R2, least significant bit of R2 into carry
            xch R2                  ; save the high nibble
            ld R3                   ; get the low nibble of the character from R3
            rar                     ; rotate the least significant bit of R2 into the most significant bit of R3
            xch R3                  ; extend register pair to make 8 bits
            fim P7,00CH             ; 138 cycles delay
getchar9:   isz R14,getchar9
            isz R15,getchar9
            nop                     ; added to tweak timing
            nop
            nop
            isz R12,getchar7        ; loop back until all 8 bits are read

; 8 data bits have been received, time to send the stop bit
            fim P7,0BBH             ; 150 cycles delay (1/2 bit time)
getchar10:  isz R14,getchar10
            isz R15,getchar10
            ldm 1
            wmp                     ; send the stop bit
            fim P7,0B7H             ; 286 cycles
getchar11:  isz R14,getchar11
            isz R15,getchar11
            bbl 0                   ; return to caller

;-------------------------------------------------------------------------------
; Get a multi-digit integer from the serial port. Control C cancels.
; Upon entry, P2 points to RAM register for the number and R13 specifies
; the maximum number of digits to get.
; Adapted from code in the "MCS-4 Micro Computer Set Users Manual, Feb. 73".
;-------------------------------------------------------------------------------
getnumber:  jms getchar             ; return with a character from the serial port in P1 (most significant nibble in R2, least significant nibble in R3)
            ld R2                   ; get the most significant nibble of the character
            jcn zn,getnumber3       ; jump if it's not zero
            ldm 03H                 ; get the least significant nibble of the character
            sub R3                  ; compare the least significant nibble to 03H by subtraction
            jcn zn,getnumber2       ; jump if it's not control C (03H)
            jun reset2              ; control C cancels
getnumber2: ldm 0DH
            sub R3                  ; compare the least significant nibble to 0DH by subtraction
            clc
            jcn zn,getnumber3       ; jump its not carriage return (0DH)
            bbl 0                   ; return to caller with fewer than 16 digits if carriage return is entered

; Move digits in RAM 0EH-00H to the next higher address 0FH-01H.
; The digit at 0EH is moved to 0FH, the digit at 0DH is moved to 0EH, the digit at 0CH is moved to 0DH, and so on.
; Moving the digits makes room for the new digit from the serial port which is contained in P1 to be stored at 00H
; at the least significant digit. P3 (R6,R7) is used as a pointer to the source for the move.
; P4 (R8,R9) is used as a pointer to the destination.
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
; Print the contents of RAM register pointed to by P3 as a 16 digit number. R11
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
            jms printchar           ; print the ASCII code for the digit
            src P3
            ldm 0
            xch R11                 ; reset the leading zero flag

prndigits4: ld  R7                  ; least significant nibble of the pointer to the digit
            dac                     ; next digit
            xch R7
            isz R10,prndigits1      ; loop 16 times (print all 16 digits)
            bbl 0                   ; finished with all 16 digits

;-------------------------------------------------------------------------------
; Clear RAM subroutine from page 80 of the "MCS-4 Micro Computer Set Users Manual" Feb.73.
; P2 points to the RAM register to be cleared (zeroed).
;-------------------------------------------------------------------------------
clrram:     ldm 0
            xch R1                  ; R1 is the loop counter (0 means 16 times)
clear:      ldm 0
            src P2
            wrm                     ; write zero into RAM
            inc R5                  ; next character
            isz R1,clear            ; 16 times (zero all 16 nibbles)
            bbl 0

            org 0200H

;-------------------------------------------------------------------------------
; Decimal addition demo. P1 points to the first integer stored in RAM register 10H
; (least significant digit at 10H, most significant digit at 1FH). P2 points to the
; second integer stored in RAM register 20H (least significant digit at 20H, most
; significant digit at 2FH). The 16 digit sum replaces the first integer in RAM
; register 10H (least significant digit at 10H, most significant digit at 1FH).
; Adapted from the code in "MCS-4 Micro Computer Set Users Manual, Feb. 73" page 77.
;--------------------------------------------------------------------------------
adddemo:    jms addinstr
adddemo1:   fim P2,10H              ; P2 points the memory register where the first number (and sum) digits are stored (10H-1FH)
            jms clrram              ; clear RAM 10H-1FH
            fim P2,20H              ; P2 points the memory register where the second number digits are stored (20H-2FH)
            jms clrram              ; clear RAM 20H-2FH

            jms newline             ; position carriage to beginning of next line
            jms newline
            jms firstnum            ; prompt for the first number
            fim P2,10H              ; destination address for first number
            ldm 0                   ; up to 16 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the first number
            jms newline
            jms secondnum           ; prompt for the second number
            fim P2,20H              ; destination address for second number
            ldm 0                   ; up to 16 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the second number
            jms newline
            fim P1,10H              ; P0 points to the first 16 digit number (called the accumulator)
            fim P2,20H              ; P2 points to the second 16 digit number (called the addend) to be added to the first
            jms addition            ; add the two numbers
            jcn zn,adddemo2         ; jump if overflow
            jms sum                 ; print "Sum: "
            fim P3,1FH              ; P3 points to the first digit of the sum at RAM address 1FH
            jms prndigits           ; print the 16 digits of the sum
            jun adddemo1            ; go back for another pair of numbers
adddemo2:   jms overflow            ; the sum of the two numbers overflows 16 digits
            jun adddemo1            ; go back for another pair of numbers

; multi-digit addition function
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
; Decimal subtraction demo.
; P1 points to the minuend stored in RAM register 10H (least significant digit at 10H, most
; significant digit at 1FH). P2 points to the subtrahend is stored in RAM register 20H (least
; significant digit at 20H, most significant digit at 2FH) The difference replaces
; the minuend in RAM register 10H (least significant digit at 10H, most significant digit at 1FH)
; Adapted from code in "MCS-4 Micro Computer Set Users Manual, Feb. 73" page 4-23.
;--------------------------------------------------------------------------------
subdemo:    jms subinstr
subdemo1:   fim P2,10H              ; P2 points the memory register where the minuend digits are stored (10H-1FH)
            jms clrram              ; clear RAM 10H-1FH
            fim P2,20H              ; P2 points the memory register where the subtrahend digits are stored (20H-2FH)
            jms clrram              ; clear RAM 20H-1FH

            jms newline             ; position carriage to beginning of next line
            jms newline             ; blank line
            jms firstnum            ; prompt for the first number (minuend)
            fim P2,10H              ; destination address for minuend: 1FH down to 10H
            ldm 0                   ; up to 16 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the first number (minuend)
            jms newline
            jms secondnum           ; prompt for the second number (subtrahend)
            fim P2,20H              ; destination address for subtrahend: 2FH down to 20H
            ldm 0                   ; up to 16 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the second number (subtrahend)
            jms newline
            jms diff                ; print "Difference:"
            fim P1,10H              ; P1 points to the 16 digit minuend  (number from which another is to be subtracted)
            fim P2,20H              ; P2 points to the 16 digit subtrahend (number to be subtracted from another)
            jms subtract            ; subtract subtrahend from minuend
            jcn z,subdemo3          ; zero means no overflow, the difference is a positive number

; the difference is a negative number, convert from 10's complement.
            fim P2,20H
            jms clrram              ; zero RAM 20H-2FH
            fim P1,20H              ; P1 points to the 16 digit minuend  (all zeros)
            fim P2,10H              ; P2 points to the 16 digit subtrahend (the negative result from subtraction above)
            jms subtract            ; subtract the negative number from zero
            fim P1,'-'              ; minus sign
            fim P3,20H              ; the result is in RAM at 20H-2FH
            jun subdemo4            ; go print the converted result

; the difference is a positive number
subdemo3:   fim P3,10H              ; P3 points to the result in RAM at 10H-1FH
            fim P1,' '              ; space
subdemo4:   jms printchar           ; print a space
            jms prndigits           ; print the 16 digits of the difference
            jun subdemo1            ; go back for another pair of numbers

;-------------------------------------------------------------------------------
; Decimal multiplication demo.
; P1 points to the multiplicand stored in RAM register 10H, characters 05H
; through 0CH where the digit at location 05H is the least significant digit
; and the digit at location 0CH is the most significant digit. P2 points to
; the multiplier stored ins RAM register 10H, characters 04H through 0BH: where
; the digit at location 04H is the least significant digit and the digit
; at location 0BH is the most significant digit. P3 points to the product
; stored in RAM register 00H, characters 00H through 0FH: where the digit
; at location 00H is the least significant digit and the digit at location
; 0FH is the most significant digit.
; The actual multiplication is done by the "MLRT" routine taken from:
; "A Microcomputer Solution to Maneuvering Board Problems" by Kenneth Harper Kerns, June 1973
; Naval Postgraduate School Monterey, California.
;--------------------------------------------------------------------------------
multdemo:   jms multinstr
multdemo1:  fim P2,10H              ; P2 points the memory register where the multiplicand is stored (10H-1FH)
            jms clrram              ; clear RAM 10H-1FH
            fim P2,20H              ; P2 points the memory register where the multiplier is stored (20H-2FH)
            jms clrram              ; clear RAM 20H-2FH

            jms newline             ; position carriage to beginning of next line
            jms newline

            jms firstnum            ; prompt for the multiplicand
            fim P2,15H              ; destination address for multiplicand (15H)
            ldm 16-8                ; up to 8 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the multiplicand (8 digits max) into RAM at 15H-1CH
            jms newline


            jms secondnum           ; prompt for the multiplier
            fim P2,24H              ; destination address for multiplier (24H)
            ldm 16-8                ; up to 8 digits
            xch R13                 ; R13 is the digit counter
            jms getnumber           ; get the multiplier (8 digits max) into RAM at 24H-2BH
            jms newline

            fim P1,10H              ; multiplicand
            fim P2,20H              ; multiplier
            fim P3,00H              ; product goes here
            jms MLRT                ; multi-digit multiplication routine
            jms product             ; print "Product: "
            fim P3,00H              ; P3 points to the product at RAM address 00H-0FH
            jms prndigits           ; print the 16 digits of the product

            jun multdemo1           ; go back for another pair of numbers

;-------------------------------------------------------------------------------
; Decimal division demo.
; P1 points to the dividend in RAM register 00H, characters 00H through 06H (least significant digit at
; location 00H, most significant digit at location 06H). P3 points to the divisor in RAM register 20H,
; characters 00H through 07H (least significant digit at location 00H, most significant digit at location 07H).
; P4 points to the quotient in RAM register 30H (least significant digit at 30H, most significant digit at 3FH).
; P2 points to the remainder in RAM register 10H (least significant digit at 10H, most significant digit at 1FH).
; The actual division is done by the "DVRT" routine taken from:
; "A Microcomputer Solution to Maneuvering Board Problems" by Kenneth Harper Kerns, June 1973
; Naval Postgraduate School Monterey, California.
;--------------------------------------------------------------------------------
divdemo:    jms divinstr
divdemo1:   fim P2,00H              ; P2 points the memory register where the dividend is stored (00H-0FH)
            jms clrram              ; clear RAM 10H-1FH
            fim P2,20H              ; P2 points the memory register where the divisor is stored (20H-2FH)
            jms clrram              ; clear RAM 20H-2FH
            jms newline
            jms newline
            jms firstnum            ; prompt for the dividend
            fim P2,00H              ; destination address for the dividend (00H-06H)
            ldm 16-7                ; maximum of 7 digits for the dividend
            xch R13                 ; R13 is the digit counter for the getnumber function
            jms getnumber           ; get the dividend

            jms newline
            jms secondnum           ; prompt for the divisor
            fim P2,20H              ; destination address for the divisor (20H-27H)
            ldm 16-8                ; maximum of 8 digits for the divisor
            xch R13                 ; R13 is the digit counter for the getnumber function (8 digits)
            jms getnumber           ; get the divisor

            fim P1,00H              ; points to dividend
            fim P2,10H              ; points to remainder
            fim P3,20H              ; points to divisor
            fim P4,30H              ; points to quotient
            jms DVRT                ; multi-digit division routine
            ;jms newline
            ;fim P3,10H             ; P3 points the remainder
            ;jms prndigits
            jms newline
            jms quotient            ; print "Quotient:"
            fim P3,30H              ; P3 points to the quotient
            jms prnquot             ; print the 16 digits of the quotient
            jun divdemo1            ; go back for more of numbers

            org 0300H

;-----------------------------------------------------------------------------------------
; Serial port demo. Echo characters received at the serial input back to the serial output.
;-----------------------------------------------------------------------------------------
serialdemo: jms newline
            jms serinstr
            jms newline
serialdemo1:jms getchar            ; wait for a character. flash the led while waiting. print the character.
            fim P3,CR
            jms compare             ; compare the character in P1 to carriage return in P3
            jcn nz,serialdemo2      ; jump to there is no match
            fim P1,LF               ; print a linefeed for each carriage return
            jms printchar
            jun serialdemo2         ; go back for the next character
serialdemo2:fim P3,03               ; is it Control C?
            jms compare
            jcn nz,serialdemo1
            jun reset2

;-----------------------------------------------------------------------------------------
; Flashing LED demo.
; Flash the LEDs from right to left and then from left to right in a "Knight Rider" or "Cylon"
; type pattern.
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
; Check the 4004's TEST input for reception of the start bit every millisecond.
; Returns with accumulator = 1 if the start bit has been received,
; otherwise returns with accumulator = 0.
; Uses P6 (R12,R13) and P7 (R14,R15)
;-----------------------------------------------------------------------------------------
leddelay:   ldm 15-10               ; 10 times through the outer loop
            xch R13                 ; counter for the outer loop
leddelay1:  ldm 15-10               ; 10 times through the inner loop
            xch R12                 ; counter for the inner loop
leddelay2:  jcn t,$+3               ; skip the following instruction if TEST = 0 (the start bit has not been received)
            bbl 1                   ; the start bit has been detected, return with accumulator = 1
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
            jms printchar           ; print the character in P1
            jun readsw              ; go back and do it again if TEST input is 0 (the start bit has not been received)

exitswdemo  jun reset2

positions:  data    "0123456789ABCDEF"

            org 0400H

;-------------------------------------------------------------------------------
; Multi-digit multiplication function taken from:
; "A Microcomputer Solution to Maneuvering Board Problems" by Kenneth Harper Kerns, June 1973
; Naval Postgraduate School Monterey, California.
;
; P1 points to the multiplicand, P2 points to the multiplier, P3 points to the product.
; Sorry about the lack of comments. That's how it was done back in the day of teletypes.
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
; Print the 16 digit quotient in RAM register pointed to by P3. The least significant
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
            jms printchar           ; print the ASCII code for the digit
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
            jms printchar           ; print the decimal point
            jun prnquot6            ; go increment counter

prnquot5:   jcn cn,prnquot6         ; jump if the next digit to be printed is not part of the fractional part
            jms zeros               ; we're printing the fractional part. is the rest of fractional part all zeros?
            jcn z,prnquot7          ; if the rest of the fractional part is all zeros, skip to the end

prnquot6:   isz R10,prnquot1        ; loop 16 times to print all 16 digits
prnquot7:   bbl 0                   ; finished with all 16 digits, return to caller

;-------------------------------------------------------------------------------
; Returns with zero if what remains of the fractional part of the quotient part
; is all zeros and thus does not need to be printed, otherwise returns with 1.
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

            org 0500H

;-------------------------------------------------------------------------------
; Multi-digit division routine taken from:
; "A Microcomputer Solution to Maneuvering Board Problems" by Kenneth Harper Kerns, June 1973
; Naval Postgraduate School Monterey, California.
;
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

;--------------------------------------------------------------------------------------------------
; Multi-digit subtraction function: P2 points to subtrahend. P1 points to the minuend. The subtrahend is
; subtracted from the minuend. The difference goes into RAM register pointed to by P1. The minuend is
; stored in RAM at 00H-0FH (least significant digit at 00H, most significant digit at 0FH). The subtrahend
; is stored in RAM at 00H-0FH (least significant digit at 00H, most significant digit at 0FH). The difference
; replaces the minuend (least significant digit at 00H, most significant digit at 0FH). Returns 0 if the
; difference is positive. Returns 1 if the difference is negative.
; Adapted from code in "MCS-4 Assembly Language Programming Manual, Feb. 73" page 4-23.
;--------------------------------------------------------------------------------------------------
subtract:   ldm 0
            xch R11                 ; R11 is the loop counter (0 gives 16 times thru the loop for 16 digits)
            stc                     ; set carry = 1
subtract1:  tcs                     ; accumulator = 9 or 10
            src P2                  ; select the subtrahend
            sbm                     ; produce 9's or l0's complement
            clc                     ; set carry = 0
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

            org 0600H

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

            org 0700H

;-----------------------------------------------------------------------------------------
; print the menu options
;-----------------------------------------------------------------------------------------
menu:       fim P0,lo(menutxt)
            jun menuprint

menuprint:  fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,menuprint        ; go back for the next character
            bbl 0

menutxt:    data CR,LF,LF
            data "1 - LED demo 1",CR,LF
            data "2 - LED demo 2",CR,LF
            data "3 - Addition demo",CR,LF
            data "4 - Subtraction demo",CR,LF
            data "5 - Multiplication demo",CR,LF
            data "6 - Division demo",CR,LF
            data "7 - Serial comm demo",CR,LF
            data "8 - Number guessing game",CR,LF
            data "9 - Display switch positions",CR,LF,LF
            data "Your choice (1-9): ",0

            org 0800H

;-----------------------------------------------------------------------------------------
; print the initial banner and prompts for the serial comm, addition and subtraction demos
;-----------------------------------------------------------------------------------------
serinstr:   fim P0,lo(sertxt)
            jun printstr

firstnum:   fim P0,lo(firsttxt)
            jun printstr

secondnum:  fim P0,lo(secondtxt)
            jun printstr

sum:        fim P0,lo(sumtxt)
            jun printstr

overflow:   fim P0,lo(overtxt)
            jun printstr

diff:       fim P0,lo(difftxt)
            jun printstr

product:    fim P0,lo(producttxt)
            jun printstr

quotient:   fim P0,lo(quottxt)
            jun printstr


printstr:   fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,printstr         ; go back for the next character
            bbl 0

firsttxt:   data "First integer:  ",0
secondtxt:  data "Second integer: ",0
sumtxt:     data "Sum:            ",0
difftxt:    data "Difference:    ",0
producttxt: data "Product:        ",0
quottxt:    data "Quotient:       ",0
overtxt     data "Overflow!",0
sertxt:     data CR,LF,"Type some text. ^C to end.",CR,LF,0

banner:     jms detectCPU
            jcn zn,banner1
            fim P0,lo(banner1txt)
            jun printstr
banner1:    fim P0,lo(banner2txt)
            jun printstr

banner1txt: data CR,LF,LF
            data "Intel 4004 SBC",0
banner2txt: data CR,LF,LF
            data "Intel 4040 SBC",0

            org 0900H

;-----------------------------------------------------------------------------------------
; print the instructions for the addition demo
;-----------------------------------------------------------------------------------------
addinstr:   fim P0,lo(addtxt)
addprint:   fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,addprint         ; not yet at the end of the string, go back for the next character
            bbl 0

addtxt:     data CR,LF,LF
            data "Integer addition demo:",CR,LF,LF
            data "Enter two integers from 1 to 16 digits. If fewer than 16 digits,",CR,LF
            data "press 'Enter'. The second integer is added to the first.",0

            org 0A00H

;-----------------------------------------------------------------------------------------
; print the instructions for the subtraction demo and "built by" message
;-----------------------------------------------------------------------------------------
subinstr:   fim P0,lo(subtxt)
subprint:   fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,subprint         ; not yet at the end of the string, go back for the next character
            bbl 0

subtxt:     data CR,LF,LF
            data "Integer subtraction demo:",CR,LF,LF
            data "Enter two integers from 1 to 16 digits. If fewer than 16 digits,",CR,LF
            data "press 'Enter'. The second integer is subtracted from the first.",0

builtby:    fim P0,lo(builttxt)
            jun subprint

builttxt:   data " built by Jim Loos.",CR,LF
            data "Firmware assembled on ",DATE," at ",TIME,".",0

            org 0B00H

;-----------------------------------------------------------------------------------------
; print the instructions for the multiplication demo
;-----------------------------------------------------------------------------------------
multinstr:  fim P0,lo(multitxt)
multiprint: fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,multiprint       ; not yet at the end of the string, go back for the next character
            bbl 0

multitxt:   data CR,LF,LF
            data "Integer multiplication demo:",CR,LF,LF
            data "Enter two integers from 1 to 8 digits. If fewer than 8 digits,",CR,LF
            data "press 'Enter'. The first integer is multiplied by the second.",0

            org 0C00H

;-----------------------------------------------------------------------------------------
; print the instructions for the division demo
;-----------------------------------------------------------------------------------------
divinstr:   fim P0,lo(dividetxt)
divprint:   fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,divprint         ; not yet at the end of the string, go back for the next character
            bbl 0

dividetxt:  data CR,LF,LF
            data "Integer division demo:",CR,LF,LF
            data "Enter two integers from 1 to 7 digits. If fewer than 7 digits,",CR,LF
            data "press 'Enter'. The first integer is divided by the second.",0

            org 0D00H

gameprint:  fin P1                  ; fetch the character pointed to by P0 into P1
            jms txtout              ; print the character, increment the pointer to the next character
            jcn zn,gameprint         ; go back for the next character
            bbl 0

intro:      fim P0,lo(introtxt)
            jun gameprint

prompt:     fim P0,lo(prompttxt)
            jun gameprint

guess:      fim P0,lo(guesstxt)
            jun gameprint

success1:   fim P0,lo(successtxt1)
            jun gameprint

success2:   fim P0,lo(successtxt2)
            jun gameprint

toolow:     fim P0,lo(toolowtxt)
            jun gameprint

toohigh:    fim P0,lo(toohightxt)
            jun gameprint

again:      fim P0,lo(againtxt)
            jun gameprint

introtxt:   data CR,LF,LF,"Try to guess the hex number (00-FF) that I'm thinking of.",0
prompttxt   data CR,LF,"Press any key to continue...",0
guesstxt    data CR,LF,"Your guess? (00-FF) ",0
successtxt1 data CR,LF,"That's it! You guessed it in ",0
successtxt2 data " tries.",CR,LF,0
toolowtxt   data CR,LF,"Too low.",CR,LF,0
toohightxt  data CR,LF,"Too high.",CR,LF,0
againtxt    data CR,LF,"Play again? (Y/N)",0

            org 0E00H

;--------------------------------------------------------------------------------------------------
; Simple number guessing game. The player tries to guess a pseudo random hexadecimal number from
; 00H to FFH stored in P4. The player's guess is stored in P5. The number of the player's guesses is stored in P2.
;--------------------------------------------------------------------------------------------------
game:       jms intro               ; print "Try to guess the hex number (00-FF) that I'm thinking of."
game0:      jms prompt              ; prompt "Press any key to continue..."
game1:      jcn tn,game2            ; jump if TEST=1 (the start bit has been detected)
            isz R9,game1            ; start with whatever is in P4. increment P4 every 4 cycles (every 44 microseconds)
            isz R8,game1
            jun game1               ; go back until the start bit is detected

game2:      ;ld R8
            ;xch R0
            ;ld R9
            ;xch R1                  ; the pseudo random in P4 (R8,R9) was copied to P0 (R0,R1) for printing
            ;jms print2hex           ; for debugging, print the pseudo random number

            ldm 0
            xch R4
            ldm 0
            xch R5                  ; clear the number of attempts stored in P2 (R4,R5)

game3:      inc R5                  ; increment least significant digit of the number of attempts
            ld R5
            jcn zn,game4            ; skip the next instruction if the increment of R5 did not roll over to zero
            inc R4                  ; increment most significant digit of the number of attempts

game4:      jms guess               ; prompt "Your guess: "
            jms getchar             ; get the first hex digit of the player's guess into P1
            fim P3,03H              ; was it control C?
            jms compare             ; compare the character in P1 to control C in P3
            jcn z,game9a            ; jump if the character was control C
            jms ascii2hex           ; convert the first digit to hex (binary, actually)
            jcn zn,game4            ; non-zero means it was an invalid hex digit, go try again
game5:      ld R2                   ; the binary number from the conversion is returned in R2
            xch R10                 ; save the first digit as the high nibble of P5

            jms getchar             ; get the second hex digit of the player's guess into P1
            fim P3,03H              ; was it control C?
            jms compare
            jcn z,game9a            ; control C cancels
            fim P3,CR               ; was it carriage return?
            jms compare
            jcn zn,game6            ; jump if it's not carriage return
            ld R10                  ; this key was carriage return, get what was to be the high nibble of P5
            xch R11                 ; make it the low nibble of P5
            ldm 0
            xch R10                 ; zero the high nibble of P5
            jun game8               ; go to the comparison

game6:      jms ascii2hex           ; convert the second digit to hex
            jcn zn,game4            ; non-zero means it was an invalid hex digit, go try again
game7:      ld R2                   ; the binary number from the conversion routine is returned in R2
            xch R11                 ; make the second digit the low nibble of P5. the player's guess is now saved in P5 (R10,R11)
game8:      ld R10                  ; get the high nibble of P5
            xch R2                  ; save it as the high nibble of P1
            ld R11                  ; get the low nibble of P5
            xch R3                  ; make it the low nibble of P1. the player's guess is now copied from P5 (R10,R11) to P1 (R2,R3)

            ld R8                   ; get the high nibble of P4
            xch R6                  ; save it as the high nibble of P3
            ld R9                   ; get the low nibble of P4
            xch R7                  ; save it as the low nibble of P3. the pseudo random number is now copied from P4 (R8,R9) to P3 (R6,R7)
            jms compare             ; compare the player's guess in P1 to the random number in P3
            xch R2                  ; the result of the comparison is returned in the accumulator. save it in R2
            ld R2
            jcn z,game9             ; zero means the player's guess matches the random number
            ldm 1
            clc
            sub R2                  ; test the result in R2 for "1" by subtraction
            jcn z,game10            ; "1" means the player's guess was too low
            jun game11              ; if it's neither equal nor too low, then the player's guess must be too high

; the player's guess was correct
game9:      jms success1            ; print "That's it! You guessed it in"
            ld R4                   ; get the high nibble of the number of attempts
            xch R0                  ; copy the high nibble of number of attempts from P2 to P0
            ld R5                   ; get the low nibble of the number of attempts
            xch R1                  ; copy the low nibble of number of attempts copied from P2 to P0
            jms print2hex           ; print the number of attempts
            jms success2            ; print " tries."
            jms again               ; prompt "Play again? (Y/N)"
            jms getchar
            fim P3,'Y'              ; is it "Y"
            jms compare
            jcn z,game0             ; go back for another game
            fim P3,'y'              ; is it "y"
            jms compare
            jcn z,game0             ; go back for another game
game9a:     jun reset2

; the player's guess was too low
game10:     jms toolow              ; print "Too low."
            jun game3               ; go back for another attempt

; the player's guess was too high
game11:     jms toohigh             ; print "Too high."
            jun game3               ; go back for another attempt

;--------------------------------------------------------------------------------------------------
; Convert the ASCII hex digit in P1 (0-9 or A-F or a-f) into a binary number (returned in R2).
; Returns Accumulator = 0 if a valid hex digit. Returns with Accumulator = 1 if an invalid digit.
;--------------------------------------------------------------------------------------------------
ascii2hex:  ldm 3
            clc
            sub R2                  ; compare R2 to 3 by subtraction
            jcn z,ascii2hex1        ; jump if most significant nibble of digit is 3 (30H-39H or 0-9)
            ldm 4
            clc
            sub R2                  ; compare R2 to 4 by subtraction
            jcn z,ascii2hex3        ; jump if most significant nibble of digit is 4 (41H-46H or A-F)
            ldm 6
            clc
            sub R2                  ; compare R2 to 6 by subtraction
            jcn z,ascii2hex3        ; jump if most significant nibble of digit is 6 (61H-66H or a-f)
            bbl 1                   ; otherwise its not a hex digit

; jump here if the most significant nibble of the character is "3"
ascii2hex1: ld R3                   ; get the least sifnificant nibble
            xch R2
            ldm 9
            clc
            sub R2                  ; compare the least significant nibble to 9 by subtraction
            jcn c,ascii2hex2        ; carry indicates the lease significant nibble in R2 is less than or equal to 9
            bbl 1                   ; otherwise, return 1 to indicate invalid character
ascii2hex2: bbl 0                   ; return with the binary value of the hex character in R2

; jump here if the most significant nibble of the character is "4" or "6"
ascii2hex3: ldm 6
            clc
            sub R3
            jcn c,ascii2hex4        ; carry indicates R3 is less than or equal to 6
            bbl 1                   ; return 1 to indicate invalid character (least significant nibble > 6)
ascii2hex4: ldm 0
            clc
            sub R3
            jcn cn,ascii2hex5       ; no carry indicates greater than 0
            bbl 1
ascii2hex5: ldm 9                   ; valid digit A-F or a-f
            clc
            add R3                  ; add 9 to the least significant nibble
            xch R2                  ; save it in R2
            bbl 0

;-----------------------------------------------------------------------------------------
; prints the contents of P0 as two hex digits
;-----------------------------------------------------------------------------------------
print2hex:  ld R0                   ; most significant nibble
            jms print1hex
            ld R1                   ; least significant nibble, fall through to the print1hex subroutine below

;-----------------------------------------------------------------------------------------
; print the accumulator as one hex digit, destroys contents of the accumulator
;-----------------------------------------------------------------------------------------
print1hex:  fim P1,030H             ; R2 = 3, R3 = 0;
            clc
            daa                     ; for values A-F, adds 6 and sets carry
            jcn cn,print1hex1       ; no carry means 0-9
            inc R2                  ; R2 = 4 for ascii 41h (A), 42h (B), 43h (C), etc
            iac                     ; we need one extra for the least significant nibble
print1hex1: xch R3                  ; put that value in R3, fall through to the printchar subroutine below
            jun printchar


