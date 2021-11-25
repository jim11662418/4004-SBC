;--------------------------------------------------------------------------------------------------
; i4004 putchar and getchar functions for 4800 bps, 7 data bits, no parity, 1 stop bit
; (1/(5068000 MHz/7))*8 clocks/cycle = 11.05 µseconds/cycle
; for 4800 bps: 1000000 µseconds ÷ 4800 bits/second ÷ 11.05 µseconds/cycle = 19 cycles/bit
;--------------------------------------------------------------------------------------------------

;--------------------------------------------------------------------------------------------------
; send the character in P1 (R2,R3) to the serial port (the least significant bit of port 0)
; in addition to P1 (R2,R3) also uses P6 (R12,R13) and P7 (R14,R15)
; NOTE: destroys P1, make sure that the character in P1 is saved elsewhere!
;--------------------------------------------------------------------------------------------------
putchar:    fim P7,SERIALPORT
            src P7                  ; address of serial port for I/O writes
            ldm 0
            wmp                     ; send the start bit
            
            fim P7,15
            isz R15,$               ; 2 cycle delay
            ld R2                   ; get the most significant nibble of the character from R2
            ral                     ; rotate the most significant bit into carry
            stc                     ; set the carry bit to 1
            rar                     ; set the most significant bit of the character (the stop bit)
            xch R2                  ; save the most significant nibble of the character in R2
            ldm 16-8                ; send all 8 bits in P1 (7 data bits and 1 stop bit)
            xch R12                 ; R12 is used as the bit counter            

putchar2:   ld R2                   ; get the most significant nibble of the character from R2
            rar                     ; shift the least significant bit into carry
            xch R2                  ; save the result in R2 for next time
            ld R3                   ; get the least significant nibble of the character from R3
            rar                     ; shift the least significant bit into carry
            xch R3                  ; save the result in R3 for next time
            tcc                     ; transfer the carry bit to the least significant bit of the accumulator
            wmp                     ; write the least significant bit of the accumulator to the serial output port
            
            fim P7,13
            isz R15,$               ; 6 cycle delay
            nop                     ; 1 cycle delay
            isz R12,putchar2        ; do it for all 8 bits in P1
            bbl 0            
            
;-----------------------------------------------------------------------------------------
; wait for a character from the serial input port (TEST input on the 4004 CPU).
; NOTE: the serial input line is inverted by hardware before it gets to the TEST input;
; i.e. TEST=0 when the serial line is high and TEST=1 when the serial line is low,
; therefore the sense of the bit needs to be inverted in software. 
; echo the received character bit by bit to the serial output port (bit 0 of port 0).
; returns the 7 bit received character in P1 (R2,R3).
; in addition to P1, also uses P6 (R12,R13) and P7 (R14,R15).
;-----------------------------------------------------------------------------------------  
getchar:    jcn t,$                 ; loop here until the start bit is detected

; the start bit has been detected, delay 1/2 bit time...            
getchar4:   ldm 16-8
            xch R12                 ; R12 holds the number of bits to receive (7 data bits and 1 stop bit); 
            fim P7,SERIALPORT
            src P7                  ; define the serial port for I/O writes    
            nop                     ; timing adjustment
            ldm 0
            wmp                     ; send the start bit
            fim P7,13
            isz R15,$               ; 6 cycle delay
            nop                     ; 1 cycle delay
            
; loop here until all seven bits plus stop bit have been received...
getchar7:   nop                     ; timing adjustment
            nop
            nop
            nop
            ldm 1                   ; "0" at the TEST input will be inverted to "1"
            jcn tn,getchar8a        ; jump if TEST input is 1
            jun getchar8b           ; skip the next two instructions since the TEST input is 0
getchar8a:  nop
            ldm 0                   ; "1" at the TEST input is inverted to "0"
getchar8b:  wmp                     ; echo the inverted bit back to the serial output port
            rar                     ; rotate the received bit into carry
            ld R2                   ; get the high nibble of the received character from R2
            rar                     ; rotate received bit from carry into most significant bit of R2, least significant bit of R2 into carry
            xch R2                  ; save the high nibble
            ld R3                   ; get the low nibble of the character from R3
            rar                     ; rotate the least significant bit of R2 into the most significant bit of R3
            xch R3                  ; extend register pair to make 8 bits
            isz R12,getchar7        ; loop back until all 8 bits are read            

; 7 data bits and 1 stop bit have been received, clear the the most significant bit of the most significant nibble (the stop bit)
            ld R2                   ; get the most significant nibble from R2
            ral
            clc
            rar                     ; shift the cleared carry bit back into the most significant bit of the most significant nibble
            xch R2                  ; save it back into R2
            bbl 0                   ; return to caller            