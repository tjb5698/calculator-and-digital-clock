;***************************************************************
;*
;* Title: Calculator and Digital Clock Program with HCS12
;*
;* Objective: CMPEN472 Homework 9
;* 
;* Revision: V2.1
;*
;* Date: March 31 2019
;*
;* Programmer: Trishita Bhattacharya
;*
;* Company : The Pennsylvania State Uninveristy, EECS
;*
;* Algorithm: Real Time Interrupt (RTI)
;*
;* Register use: A: Serial port input, counters, temporary values, 
;*                  byte of numbers,time,operators
;*               B: counters, temporary values, time, 
;*                  byte of numbers,operators  
;*               D: num1, num2, result       
;*             X,Y: pointers to memory locations, print messages,
;*                  num1,num2
;*
;* Memory use: RAM Locations from $3000 for data, 
;*                                $3100 for program
;*
;* Input: Values entered by user on HyperTerminal
;* 
;* Output: HyperTerminal interface
;*
;* Observation: This is a program that uses use serial port, 
;*              arithmetic instructions, simple command line 
;*               parsing, and basic I/O system subroutines.
;*
;***************************************************************

; export symbols
            XDEF        Entry        ; export 'Entry' symbol
            ABSENTRY    Entry        ; for assembly entry point

; include derivative specific macros
SCIBDH      EQU         $00c8
SCIBDL      EQU         $00c9

SCISR1      EQU         $00cc        ; Serial port (SCI) Status Register 1
SCIDRL      EQU         $00cf        ; Serial port (SCI) Data Register

CRGFLG      EQU         $0037        ; Clock and Reset Generator Flags
CRGINT      EQU         $0038        ; Clock and Reset Generator Interrupts
RTICTL      EQU         $003B        ; Real Time Interrupt Control

CR          equ         $0d          ; carriage return, ASCII 'Return' key
LF          equ         $0a          ; line feed, ASCII 'next line' character

;*******************************************************
; variable/data section
            ORG     $3000            ; RAMStart defined as $3000
                                     ; in MC9S12C128 chip

ctr2p5m     DS.W    $01              ; 16bit interrupt counter for 2.5 mSec. of time
nabuf       DS.B    $02              ; buffer used for Num to Ascii
cbuf        DS.B    $0B              ; user input character buffer, maximum 11 char

N1          DS.B    $03   ;Space to store num1 values
N2          DS.B    $03   ;Space to store num2 values
RS          DS.B    $05   ;Space to store final answer

times       DC.B    $00              ; time in sec
timem       DC.B    $00              ; time in min
timeh       DC.B    $0c              ; time in hour
ptimes      DC.B    $00             ; previous time in sec
ptimem      DC.B    $00             ; previous time in min
ptimeh      DC.B    $0c             ; previous time in hour
temptime    DC.B    $00              ; temporarily store time value
na          DC.B    $00              ; temporary store for num to ascii
cbufct      DC.B    $00              ; user input character buffer fill count
colonct     DC.B    $00              ; track of no. of colons used
loopct      DC.B    $00              ; track of no of loops
msg1        DC.B    'Tcalc>  ', $00
msg2        DC.B    'Invalid input format. Correct example => hh:mm:ss', $00
msg3        DC.B    'Typewrite program started', $00

temp          DC.B    $00   ;temporarily stores input value
temp1         DC.B    $00   ;count in ptloop
NUM1          DC.W    $00   ;Number 1
NUM2          DC.W    $00   ;Number 2
Result        DC.W    $00   ;Final answer
OP            DC.B    $00   ;Operation sign
opcount       DC.B    $00   ;no of times an operatoris added
n1count       DC.B    $00   ;no of digits in Num1
n2count       DC.B    $00   ;no of digits in Num2
rcount        DC.B    $00   ;no of digits in final answer
errorcount    DC.B    $00   ;no of errors produced
msg4          DC.B    'Overflow error', $00
msg5          DC.B    'Invalid input format.', $00

Counter1      DC.W    $4fff       ; initial X register count number
Counter2      DC.W    $0020       ; initial Y register count number

CursorToCenter  DC.B    $1B, '[08', $3B, '25H', $00   ; move cursor to 8,25 position
ClearScreen     DC.B    $1B, '[2J', $00               ; clear the Hyper Terminal screen
SavePosition    DC.B    $1B, '7', $00                 ; save the current cursor position
UnsavePosition  DC.B    $1B, '8', $00                 ; save the current cursor position
Scroll4Enable   DC.B    $1B, '[1', $3B, '4r',  $00    ; enable scrolling to top 4 lines
;;;;
;*******************************************************
; interrupt vector section

            ORG     $3FF0            ; Real Time Interrupt (RTI) interrupt vector setup
            DC.W    rtiisr

;*******************************************************
; code section
            ORG     $3100
Entry
            LDS     #Entry           ; initialize the stack pointer

            ldx     #$0d
            stx     SCIBDH
            
            ldaa    #$af             ; wait for the user to change settings
dloop       jsr     delay1sec
            deca
            cmpa    #$00
            bne     dloop

            ldx     #ClearScreen     ; clear the Hyper Terminal Screen first
            jsr     printmsg
            
            ldx     #Scroll4Enable   ; enable top 4 lines to scroll if necessary
            jsr     printmsg
            
            ldx     #399
            stx     ctr2p5m          ; initialize interrupt counter with 400.
            ldaa    #$00
            staa    times            ; initialize clock to 12:00:00
            staa    timem
            ldaa    #$0c
            staa    timeh
          
            bset    RTICTL,%00011001   ; set RTI: dev=10*(2**10)=2.555msec for C128 board
                                     ;      4MHz quartz oscillator clock
            bset    CRGINT,%10000000   ; enable RTI interrupt
            bset    CRGFLG,%10000000   ; clear RTI IF (Interrupt Flag)
            
loop        ;ldx     #msg1            ; print the first message, 'Clock>'
            ;jsr     printmsg
            ldaa    #$00             ; initialize counters to 0
            staa    cbufct
            staa    colonct
            staa    temptime
            staa    loopct
            STAA    opcount
            STAA    n1count
            STAA    n2count
            STAA    rcount
            STAA    temp
            STAA    temp1
            STAA    errorcount
            LDX     #$0000
            STX     NUM1
            STX     NUM2
            STX     Result
            STX     OP    
            ldx     #msg1            ; print the first message, 'Tcalc>'
            jsr     printmsg
                        
            ldx     #cbuf            ; load address for the buffer   
            cli
            
loop1       ldab    cbufct           
            jsr     UpDisplay        ; update time display
            
            jsr     getchar          ; check if the user has entered anything
            cmpa    #$00
            beq     loop1
            cmpb    #$0b             ; check if user enters more than 11 letters
            beq     loop2            ; error
            addb    #$01             
            stab    cbufct
            staa    1,x+
            jsr     putchar          ; display the user input on screen
            cmpa    #CR
            bne     loop1
            jsr     nextline     
            
            ldx     #cbuf            ; if user ony uses enter key
            ldaa    0,x
            cmpa    #CR
            beq     loop             ; start new cycle
            jsr     NewCommand       ; process user input
                        
            bra     loop
            
loop2       jsr     nextline
            jsr     tab
            ldx     #msg2            ; print format error message
            jsr     printmsg
            jsr     nextline
            bra     loop
           

;subroutine section below

;***********RTI interrupt service routine***************
rtiisr      bset  CRGFLG,%10000000   ; clear RTI Interrupt Flag
            ldx   ctr2p5m
            inx
            stx   ctr2p5m            ; every time the RTI occur, increase interrupt count
rtidone     RTI
;***********end of RTI interrupt service routine********

;***************Update Display**********************
;* Program: Update count down timer display if 1 second is up
;* Input:   ctr2p5m, timeh, timem, times variables
;* Output:  timer display on the Hyper Terminal
;* Registers modified: A, X, Y
;* Algorithm:
;    Check for 1 second passed
;      if not 1 second yet, just pass
;      if 1 second has reached, then update display and reset ctr2p5m
;**********************************************
UpDisplay
            psha
            pshx
            pshy
                                   
            ldx     ctr2p5m          ; check for 1 sec
            cpx     #399             ; 2.5msec * 400 = 1 sec        0 to 399 count is 400
            lblo    UpExit           ; if interrupt count less than 400, then not 1 sec yet.
                                     ; no need to update display.

            ldx     #0               ; interrupt counter reached 400 count, 1 sec up now
            stx     ctr2p5m          ; clear the interrupt count to 0, for the next 1 sec.

           
            ldx     #SavePosition    ; save cursor position after Clock>
            jsr     printmsg
            
            ldx     #CursorToCenter  ; place cursor at the center of the screen
            jsr     printmsg            
            
            ldaa    timeh            ; convert hour to ascii
            staa    na
            jsr     NumtoAscii
            ldy     #nabuf
            ldaa    0,y
            jsr     putchar          ; print hour digits
            ldaa    1,y
            jsr     putchar
            ldaa    #$3a
            jsr     putchar          ; print ' : '
            
            ldaa    timem            ; convert min to ascii
            staa    na
            jsr     NumtoAscii
            ldy     #nabuf
            ldaa    0,y
            jsr     putchar          ; print min digits
            ldaa    1,y
            jsr     putchar
            ldaa    #$3a
            jsr     putchar          ; print ' : '
            
            ldaa    times            ; convert sec to ascii
            staa    na               
            jsr     NumtoAscii
            ldy     #nabuf
            ldaa    0,y
            jsr     putchar          ; print sec digits
            ldaa    1,y
            jsr     putchar
            
            ldaa    times            ; update sec by 1s
            inca 
            staa    times
            cmpa    #59              ; if 59s 
            bls     UpDone
            ldaa    #$00
            staa    times
            ldaa    timem            ; update min by 1min
            inca
            staa    timem
            cmpa    #59              ; if 59min
            bls     UpDone
            ldaa    #$00
            staa    timem
            ldaa    timeh            ; update hour by 1hr
            inca
            staa    timeh
            cmpa    #$0c             ; if 12hr
            bls     UpDone
            ldaa    #$01             ; update hour to 01hr
            staa    timeh            
          
UpDone      ldx     #UnsavePosition
            jsr     printmsg

UpExit      puly
            pulx
            pula
            rts
;***************end of Update Display***************

;***************New Command Process*******************************
;* Program: Check for 's' command or 'q' command.
;* Input:   Command buffer filled with characters, and the command buffer character count
;*             cbuf, cbufct
;* Output:  Display on Hyper Terminal the time and update every second unless 'q' command
;*          When 's' command is issued, the time display is reset to the user input time.
;*          Interrupt start with CLI for 's' command, interrupt stops with SEI for 'q' command.
;* Registers modified: A, B, X
;* Algorithm:
;*     check 's' or 'q' command, and start or stop the interrupt
;*     print error message if error
;*     clear command buffer
;* 
;**********************************************
NewCommand
            psha

            ldx     #cbuf            ; read command buffer, see if 's' or 'q' command entered
            ldaa    1,x+             
            cmpa    #'s'
            beq     ckset
            cmpa    #'q'
            lbne    Calc

ckquit      ldaa    1,x+
            cmpa    #CR
            lbne    CNerror
CNoff       sei                    ; it is 'q' command, turn off interrupt
            jsr     typewriter     ; start typewriter 
            lbra    CNexit

ckset       ldaa    1,x+           ; check for space  
            cmpa    #$20             
            lbne    CNerror
            
            ldab    timeh          ; save current time
            stab    ptimeh
            ldab    timem
            stab    ptimem
            ldab    times
            stab    ptimes
            
            ldab    cbufct        ; update pointer to buffer 
            subb    #$02
            stab    cbufct
            
tloop       ldab    cbufct        ; to keep track of each input value from buffer
            cmpb    #$01
            lbeq     CNdone
            subb    #$01
            stab    cbufct
            
            ldab    loopct        ; when to look for : and switch to hh/mm/ss
            incb
            cmpb    #$03
            beq     cloop
            stab    loopct
            
            ldaa    1,x+          ; if between 0-9 continue
            cmpa    #$30
            lblo     CNerror
            cmpa    #$39
            lbhi     CNerror
            
            suba    #$30          ; ascii to num
            ldab    loopct
            cmpb    #$02          ; if ten's place
            beq     nextnum
            ldab    #$0a
            mul                   ; multiply by 10
            stab    temptime
            bra     tloop         ; get next num
            
nextnum     adda    temptime      ; if one's place add num2
            staa    temptime
            
            cmpa    #$3C          ; if user entered >60
            lbhs     CNerror       ; error
            
ploop       ldaa    temptime
            ldab    colonct
            cmpb    #$00          ;no colon -> hh
            bne     tmin
            staa    timeh
            cmpa    #$0D          ; if user entered >12
            lbhs     CNerror       ; error
            bra     savenext
tmin        cmpb    #$01          ;1 colon -> mm
            bne     tsec
            staa    timem
            bra     savenext
tsec        cmpb    #$02          ;2 colon -> ss
            bne     CNerror
            staa    times
            
savenext    ldaa    #$00          ;clear temptime
            staa    temptime
            bra     tloop         ;get next input value
                
            
cloop       ldab    colonct       ;checks if ss values have been saved 
            cmpb    #$03
            beq     CNdone        ;if yes then exit
            incb
            stab    colonct
            ldaa    1,x+          ;load next and check if colon
            cmpa    #$3a
            bne     CNerror       ;else wrong format
            ldab    #$00          ;once hh/mm/ss finished, reset counter 
            stab    loopct
            lbra     tloop            
            
Calc        ldab    cbufct
            cmpb    #$08
            bhi     erloop 
            jsr     parts
            jsr     Number1
            jsr     Number2
            ldab    errorcount
            cmpb    #$00
            bhi     CNexit
            
            ldab    OP
            cmpb    #$2b
            bne     sub
            jsr     Addition
            bra     CNexit
sub         cmpb    #$2d
            bne     mult
            jsr     Subtraction
            bra     CNexit
mult        cmpb    #$2a
            bne     div
            jsr     Multiplication
            bra     CNexit
div         cmpb    #$2f
            bne     erloop
            jsr     Division
            bra     CNexit                                                 
           
erloop      jsr     Error
            bra     CNexit

CNdone      ldx     #$0000           ; with new command, restart 10 second timer
            stx     ctr2p5m          ; initialize interrupt counter with 400.
            ldab    colonct
            cmpb    #$02
            blo     CNerror                       
            bra     CNexit

CNerror     ldab    ptimeh           ; incase of error, donot update time
            stab    timeh
            ldab    ptimem
            stab    timem
            ldab    ptimes
            stab    times
            jsr     tab
            ldx     #msg2            ; print the 'Command Error' message
            jsr     printmsg
            jsr     nextline
            bra     CNexit

CNexit      pula
            rts
;***************end of New Command Process***************


;**********************NumtoAscii**********************
NumtoAscii
            ldaa    #$00
            ldab    na
            ldx     #$0a          ; divide number by 10
            idiv
            tba   
            adda    #$30          ; convert digit in one's place to ascii
            ldy     #nabuf
            staa    1,y
            exg     x,a
            adda    #$30          ; convert digit in ten's place to ascii
            staa    0,y
            rts
            
          
;*******************end of NumtoAscii*********************


;**********************typewriter**********************
typewriter
            ldx   #msg3
            jsr   printmsg
            jsr   nextline 
  
twloop      jsr   getchar            ; type writer - check the key board
            cmpa  #$00               ;  if nothing typed, keep checking
            beq   twloop
                                       ;  otherwise - what is typed on key board
            jsr   putchar            ; is displayed on the terminal window
            cmpa  #CR
            bne   twloop             ; if Enter/Return key is pressed, move the
            ldaa  #LF                ; cursor to next line
            jsr   putchar
            bra   twloop            
            
            rts
            
          
;*******************end of typewriter*********************


;***********printmsg***************************
;* Program: Output character string to SCI port, print message
;* Input:   Register X points to ASCII characters in memory
;* Output:  message printed on the terminal connected to SCI port
;* 
;* Registers modified: CCR
;* Algorithm:
;     Pick up 1 byte from memory where X register is pointing
;     Send it out to SCI port
;     Update X register to point to the next byte
;     Repeat until the byte data $00 is encountered
;       (String is terminated with NULL=$00)
;**********************************************
NULL            equ     $00
printmsg        psha                   ;Save registers
                pshx
printmsgloop    ldaa    1,X+           ;pick up an ASCII character from string
                                       ;   pointed by X register
                                       ;then update the X register to point to
                                       ;   the next byte
                cmpa    #NULL
                beq     printmsgdone   ;end of strint yet?
                bsr     putchar        ;if not, print character and do next
                bra     printmsgloop
printmsgdone    pulx 
                pula
                rts
;***********end of printmsg********************

;***************putchar************************
;* Program: Send one character to SCI port, terminal
;* Input:   Accumulator A contains an ASCII character, 8bit
;* Output:  Send one character to SCI port, terminal
;* Registers modified: CCR
;* Algorithm:
;    Wait for transmit buffer become empty
;      Transmit buffer empty is indicated by TDRE bit
;      TDRE = 1 : empty - Transmit Data Register Empty, ready to transmit
;      TDRE = 0 : not empty, transmission in progress
;**********************************************
putchar     brclr SCISR1,#%10000000,putchar   ; wait for transmit buffer empty
            staa  SCIDRL                      ; send a character
            rts
;***************end of putchar*****************

;****************getchar***********************
;* Program: Input one character from SCI port (terminal/keyboard)
;*             if a character is received, other wise return NULL
;* Input:   none    
;* Output:  Accumulator A containing the received ASCII character
;*          if a character is received.
;*          Otherwise Accumulator A will contain a NULL character, $00.
;* Registers modified: CCR
;* Algorithm:
;    Check for receive buffer become full
;      Receive buffer full is indicated by RDRF bit
;      RDRF = 1 : full - Receive Data Register Full, 1 byte received
;      RDRF = 0 : not full, 0 byte received
;**********************************************

getchar     brclr SCISR1,#%00100000,getchar7
            ldaa  SCIDRL
            rts
getchar7    clra
            rts
;****************end of getchar**************** 

;****************nextline**********************
nextline    ldaa  #CR              ; move the cursor to beginning of the line
            jsr   putchar          ;   Cariage Return/Enter key
            ldaa  #LF              ; move the cursor to next line, Line Feed
            jsr   putchar
            rts
;****************end of nextline***************


;****************parts***********************
;* Program: Divide input into num1, num2 and operator  
;* Input:   Register Y points to ASCII characters in Buff
;*          Register A stores selected value from Buff
;*          Register B keeps track of temp1, counter, opcount
;* Output:  Operator assigned to OP, num1 and num2 separated
;* 
;* Registers modified: Y, A, B, CCR
;* Algorithm:
;     Loop around Buff to examine each input character
;     If an operator, stored in OP. If a number, check
;     if operator has been assigned or not. If yes, 
;     part of num2 else part of num1.
;     Repeat until the end of Buff is reached
;**********************************************
parts    
          LDY     #cbuf              
          JSR     tab                ;enters a tab
                  
         
ptloop     LDAB    temp1              ;no. of times ploop takes place
          ADDB    #$01
          STAB    temp1
          LDAB    cbufct             ;no.of time ploop loops = size of Buff
          CMPB    #$01
          BEQ     pend               ;exit if reached buffer size
          SUBB    #$01
          STAB    cbufct 
          LDAA    1,Y+               ;load input character and increment Y for next time
          JSR     putchar
          CMPA    #$30               ;check if 0
          BLO     opcheck            ;branch to operator check if lower
          CMPA    #$39               ;check if 9
          BHI     perror             ;branch  to error if higher
          
          LDAB    opcount            ;check if operator has been assigned
          CMPB    #$00
          BEQ     pnum1              ;if not branch for num1
          CMPB    #$01
          BEQ     pnum2              ;if yes branch for num2
          BRA     perror             ;if more than one operator has been assigned, send error

pnum1     STAA    temp               ;store value to temp
          JSR     Num1Store          ;storing num1 from input values
          ldaa    errorcount
          cmpa    #$00
          bhi     pend
          BRA     ptloop              ;go to next input character in Buff
pnum2     STAA    temp
          JSR     Num2Store          ;storing num2 from input values
          ldaa    errorcount
          cmpa    #$00
          bhi     pend
          BRA     ptloop              ;go to next input character in Buff
          
opcheck   LDAB    temp1              ;if first input character from Buff
          CMPB    #$01
          BEQ     perror             ;send error
          CMPA    #$2A               ;if +,-,*,/ go to next
          BEQ     next
          CMPA    #$2B
          BEQ     next
          CMPA    #$2D
          BEQ     next
          CMPA    #$2F 
          BEQ     next
          BRA     perror             ;if not a valid operator, send error
          
next      LDAB    opcount            ;update no. of operators
          CMPB    #$01
          BEQ     perror             ;if operator has already been assigned, send error
          ADDB    #$01
          STAB    opcount        
          STAA    OP                 ;save operator
          
          BRA     ptloop              ;go to next input character in Buff
          
perror    JSR     Error              ;send error message
          
pend      RTS          
;****************end of parts******************

;****************NumStore1****************
;* Program: Store num1 from ascii characters to digits
;* Input:   Register Y points to N1 to store num1
;*          Register A loads selected value from Buff
;*          Register B keeps track of n1count
;* Output:  number digits stored in N1
;* 
;* Registers modified: Y, A, B, CCR
;**********************************************
Num1Store
          PSHY
          
          LDAB    n1count            ;keep a track of no. of digits in num1
          CMPB    #$03               ;if greater than 3, send error
          BEQ     n1serror
          LDAA    temp
          SUBA    #$30               ;convert ascii value to number
          LDY     #N1
          STAA    B,Y                ;store in memory space for num1
          ADDB    #$01
          STAB    n1count
          BRA     n1send
          
n1serror  JSR     Error              ;send error message
          
n1send    PULY
          RTS

;****************end of NumStore1**************** 

;********************NumStore2*******************
;* Program: Store num2 from ascii characters to digits
;* Input:   Register Y points to N2 to store num2
;*          Register A loads selected value from Buff
;*          Register B keeps track of n1count
;* Output:  number digits stored in N2
;* 
;* Registers modified: Y, A, B, CCR
;**********************************************
Num2Store
          PSHY
          
          LDAB    n2count            ;keep a track of no. of digits in num2
          CMPB    #$03               ;if greater than 3, send error
          BEQ     n2serror
          LDAA    temp
          SUBA    #$30               ;convert ascii value to number
          LDY     #N2
          STAA    B,Y                ;store in memory space for num2
          ADDB    #$01
          STAB    n2count
          BRA     n2send
          
n2serror  JSR     Error              ;send error message               
          
n2send    PULY          
          RTS

;****************end of NumStore2****************

;****************Number1****************
;* Program: Calculate num1
;* Input:   Register X points to N1 
;*          Register Y used for multiplication
;*          Register A keeps track of n1count
;*          Register B loads selected value from N1
;* Output:  number digits stored in N1
;* 
;* Registers modified: Y, X, A, B, CCR
;**********************************************
Number1
         PSHX
         PSHY
         
         LDX    #N1                  ;load pointer to num1 location
         LDAB   0,X                  ;load first digit of num1
         EXG    B,Y
         STY    NUM1                 ;store first digit in num1
         EXG    Y,B
            
         LDAA   n1count              ;if reached end of N1, exit
         CMPA   #$01
         BEQ    n1end
         
         SUBA   #$01                 ;if there's another digit, 
         STAA   n1count
n1loop   LDAA   #$00
         LDY    #$0A                 
         EMULS                       ;multiply num1 by 10
         ADDB   1,+X                 ;add the next digit 
         STD    NUM1                 ;update num1 value
         LDAA   n1count
         SUBA   #$01
         STAA   n1count
         CMPA   #$00
         BNE    n1loop
                  
n1end    PULY
         PULX
         RTS

;****************end of Number1**************** 

;********************Number2*******************
;* Program: Calculate num2
;* Input:   Register X points to N2 
;*          Register Y used for multiplication
;*          Register A keeps track of n2count
;*          Register B loads selected value from N2
;* Output:  number digits stored in N2
;* 
;* Registers modified: Y, X, A, B, CCR
;**********************************************
Number2
         PSHX
         PSHY
         
         LDX    #N2                  ;load pointer to num2 location
         LDAB   0,X                  ;load first digit of num2
         EXG    B,Y
         STY    NUM2                 ;store first digit in num2
         EXG    Y,B
            
         LDAA   n2count              ;if reached end of N2, exit
         CMPA   #$01
         BEQ    n2end
         
         SUBA   #$01                 ;if there's another digit,
         STAA   n2count
n2loop   LDAA   #$00
         LDY    #$0A
         EMULS                       ;multiply num2 by 10
         ADDB   1,+X                 ;add the next digit
         STD    NUM2                 ;update num2 value
         LDAA   n2count
         SUBA   #$01
         STAA   n2count
         CMPA   #$00
         BNE    n2loop
                  
n2end    PULY
         PULX
         RTS

;****************end of Number2**************** 


;*******************addition*******************
;* Program: Addition operation
;* Input:   Register D used for loading num1, 
;*          addition and storing result
;*          Register A print '='
;* Output:  Num1 is added to Num2 and printed
;* 
;* Registers modified: D, A 
;**********************************************
Addition
          LDD     NUM1               
          ADDD    NUM2 
          STD     Result             ; store num1+num2 
          
          LDAA    #$3D
          JSR     putchar            ; print =
          
          JSR     RtoAscii           ;convert answer to ascii and print
          JSR     PrintResult        ;print final answer
                    
          LDAA     #CR
          JSR      putchar
          LDAA     #LF
          JSR      putchar
          
          RTS

;****************end of addition****************


;*******************subtraction*******************
;* Program: Subtraction operation
;* Input:   Register D used for loading num1, 
;*          subtraction, storing result and 
;*          converting -ve num to 2s coplement
;*          Register A print '-' and '='
;* Output:  Num1 is subtracted from Num2 and printed
;* 
;* Registers modified: D, A, B
;**********************************************

Subtraction

          LDD     NUM1
          SUBD    NUM2 
          STD     Result             ;store num1-num2
          
          LDAA    #$3D
          JSR     putchar            ;print =
          
          LDD     Result
          CPD     #$FC18             ;check if -ve or +ve answer
          BLO     posval             ;if not go to posval
          
          LDAA    #$2D               
          JSR     putchar            ;print - sign
          LDD     Result
          EORA    #$FF               ;invert bits
          EORB    #$FF               
          ADDD    #$0001             ;add 1 for 2s complement
          STD     Result             ;update answer
                    
posval    JSR     RtoAscii           ;convert answer to ascii
          JSR     PrintResult        ;print final answer
         
          LDAA     #CR
          JSR      putchar
          LDAA     #LF
          JSR      putchar
          
          RTS

;****************end of subtraction****************


;*******************multiplication*******************
;* Program: Multiplication operation
;* Input:   Register D used for loading num1, 
;*          multiplication and storing result 
;*          Register Y used for multiplication,
;*          checking for overflow
;*          Register X  used for printing error msg
;*          Register A print '=',CR and LF
;* Output:  Num1 is multiplied with Num2 and printed
;* 
;* Registers modified: D, Y, X, A
;**********************************************
Multiplication

          LDD     NUM1
          LDY     NUM2
          EMUL                      ;num1*num2
          CPY     #$0000            ;check for overflow
          BEQ     validmul
          
          LDAA     #CR
          JSR      putchar
          LDAA     #LF
          JSR      putchar
         ; JSR      tab
          LDX      #msg4
          JSR      printmsg         ;print overflow message
          LDAA     #CR
          JSR      putchar
          LDAA     #LF
          JSR      putchar
          
          BRA     mulend
          
validmul  STD     Result            ;store num1*num2
          LDAA    #$3D              
          JSR     putchar           ;print =
                   
          JSR     RtoAscii          ;convert answer to ascii
          JSR     PrintResult       ;print final answer
          
          LDAA     #CR
          JSR      putchar
          LDAA     #LF
          JSR      putchar
          
mulend    RTS

;****************end of multiplication***************


;*******************division*******************
;* Program: Division operation
;* Input:   Register D used for loading num1, 
;*          multiplication and storing result 
;*          Register X used for division,
;*          checking division by 0
;*          Register A print '=',CR and LF
;* Output:  Num1 is divided by Num2 and printed
;* 
;* Registers modified: D, X, A
;**********************************************

Division

          LDD     NUM1
          LDX     NUM2
          CPX     #$00              ;check if num2=0
          BNE     validdiv          
          
          LDAA     #CR
          JSR      putchar
          LDAA     #LF
          JSR      putchar
          JSR      tab
          LDX      #msg5            ;invalid input error
          JSR      printmsg
          LDAA     #CR
          JSR      putchar
          LDAA     #LF
          JSR      putchar
          
          BRA     divend
          
validdiv  IDIV                      
          STX     Result            ;store num1/num2
          LDAA    #$3D
          JSR     putchar           ;print =
         
          JSR     RtoAscii          ;convert answer to ascii
          JSR     PrintResult       ;print final answer
          
          LDAA     #CR
          JSR      putchar
          LDAA     #LF
          JSR      putchar
          
divend    RTS

;****************end of division****************


;*******************RtoAscii********************
;* Program: Converting answer to ascii
;* Input:   Register D used for loading result 
;*          Register X used for dividing result
;*          for conversion
;*          Register Y points to RS
;*          Register A keeps a track of rcount
;* Output:  Answer stores in RS
;* 
;* Registers modified: D, X, Y, A
;**********************************************

RtoAscii
          PSHY
          PSHX
          
          LDY     #RS               ;load pointer to answer location
          
          LDD     Result
RAloop    LDX     #$000A
          IDIV                      ;divide answer by 10
          ADDB    #$30              ;convert remainder,i.e, last digit to ascii
          STAB    1,Y+              ;store ascii value of last digit, increment Y for next time
          LDAA    rcount            ;track number of digits in answer
          ADDA    #$01
          STAA    rcount
          EXG     D,X               
          CPD     #$0000            ;if quotient =0, exit
          BNE     RAloop
          
          PULX
          PULY
          RTS

;****************end of RtoAscii****************


;*******************PrintResult*******************
;* Program: Print final answer
;* Input:   Register Y points to RS
;*          Register A loads selected value from RS 
;*          Register B keeps a track of rcount
;* Output:  Answer printed
;* 
;* Registers modified: Y, A, B
;**********************************************
PrintResult
          PSHY
         
          LDY     #RS               ;load pointer to answer location
         
rloop     LDAB    rcount
          CMPB    #$00
          BEQ     rend              ;no.of time rloop loops = size of RS
          SUBB    #$01
          STAB    rcount    
          LDAA    B,Y               ;print a digit of the answer
          JSR     putchar
          BRA     rloop
          
rend      PULY
          RTS

;****************end of PrintResult****************


;***********************error**********************
;* Program: Sends error message
;* Input:   Register X prints error message
;*          Register A tracks errorcount, print
;*          LF and CR 
;* Output:  Error message printed
;* 
;* Registers modified: X, A
;**************************************************
Error
          PSHX
          
          LDAB     errorcount       ;tracks if error message was printed
          ADDB     #$01
          STAB     errorcount          
          LDAA     #CR
          JSR      putchar
          LDAA     #LF
          JSR      putchar
          JSR      tab              ;adds tab
          LDX      #msg5
          JSR      printmsg         ;print invalid input format error
          LDAA     #CR
          JSR      putchar
          LDAA     #LF
          JSR      putchar
          
          PULX
          RTS

;****************end of error****************

;********************tab********************
;* Program: Enters tb space
;* Input:   Register A prints tab
;* Output:  Tab printed
;* 
;* Registers modified: A
;**************************************************
tab
          PSHA
                    
          LDAA    #$09
          JSR     putchar           ;prints one tab
          
          PULA 
          RTS

;****************end of tab****************


;**************************************************************
; delay1s subroutine
;
; This subroutine cause a few sec. delay
;
; Input: a 16bit count number in 'Counter2'
; Output: timedelay cpu cylce waited
; Registers: Y register as counter
; Memory locations: a 16bit input number in 'Counter2'        
 

delay1sec                             
          PSHY
          
          LDY     Counter2            ; long delay by
dly1sLoop JSR     delay1ms            ; Y * delay1ms
          DEY
          BNE     dly1sLoop
          
          PULY
          RTS
;**************************************************************


;**************************************************************
; delay1ms subroutine
;
; This subroutine cause a few msec. delay
;
; Input: a 16bit count number in 'Counter1'
; Output: timedelay cpu cylce waited
; Registers: X register as counter
; Memory locations: a 16bit input number in 'Counter1'        
          
delay1ms
          PSHX
          
          LDX     Counter1          ; short delay
dlymsLoop NOP                       ; X * NOP
          DEX
          BNE     dlymsLoop
          
          PULX
          RTS                                  
          
;************************************************************



            END                    ; this is end of assembly source file
                                   ; lines below are ignored - not assembled