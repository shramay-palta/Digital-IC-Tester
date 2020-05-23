.MODEL TINY
.DATA

FAIL_M       DB      " FAIL"
PASS_M       DB      " PASS"

NotFound        DB     " NOT FOUND"    ; when incorrect IC is entered
Flag       DB     00H             ; 00H-IC currently not found(i.e. IC num not in 7408,7486,7432) ,01H- correct IC num entered
IC7408          DB     "7408" ; ICs that we need to check
IC7432          DB     "7432"
IC7486          DB     "7486"
input2          DB     "ENTER -  "; asks user to enter an IC number
NumChars        DW      00H    ; keeps count of number of characters entered

COUNT           DW      0000H    ; keeps count of number of characters to be printed by WriteStr procedure


;Test values for checking correctness
IN7408          DB      00H,55H,0AAH,0FFH   ; AND gate
OUT7408         DB      00H,00H,00H,0FH
IN7486          DB      00H,55H,0AAH,0FFH    ; XOR
OUT7486         DB      00H,0FH,0FH,00H
IN7432          DB      00H,55H,0AAH,0FFH    ; OR
OUT7432         DB      00H,0FH,0FH,0FH

;display table for LCD
TABLE_D         DW     0H,  01H, 2H,  3H
                DW     4H,  5H,  6H,  7H
                DW     8H,  9H,  0AH, 0BH
                DW     0CH, 0DH, 0EH, 0FH
; kb table for keyboard input
TABLE_K         DB     0EEh,0EDH,0EBH,0E7H
                DB     0DEH,0DDH,0DBH,0D7H
                DB     0BEH,0BDH,0BBH,0B7H
                DB     07EH,07DH,07BH,077H

; First 8255
port1a           equ     10h
port1b           equ     12h
port1c           equ     14h
creg1           equ     16h
; Second 8255
port2a          equ     20h
port2b          equ     22h
port2c          equ     24h
creg2           equ     26h

All_Keys            DB      "0123456789SRABCD"  ;list of keypad keys
ICNUM           DB      "XXXX"              ;stores the IC number entered by the user

.CODE
.STARTUP

mov         al,010001010B  ; port1a and lower port1c as output and port1b and upper port1c as input
out         creg2,al


CALL LCD_INIT   ;initialises LCD unit

Start:
    MOV NumChars,0
    MOV Flag,00H
    CALL CLS           ; clears LCD
    LEA DI,input2   ; di stores address of "ENTER-"
    MOV COUNT,9        ; no of characters to be printed
    CALL WriteStr      ; prints input message to LCD

ReadKey:
    MOV COUNT,01H
    CALL KEYBRD        ; keypush is read. AX contains offset in kb table
    LEA DI,All_Keys        ; All_Keys is list of keypad keys
    ADD DI,AX          ; pointing DI to key pressed
    MOV SI,NumChars
    MOV AL,[DI]        ; reads key pushed into al
    CMP AL,"R"         ; On Reset go to start of program
    JE Start
    CMP AL,"S"         ; if backspace and at least one character has been entered go to backspace proc
    JNE  StoreKey
    CMP NumChars,00H   ; No char enetered. Go back to ReadKey
    JE ReadKey
    ; Deleting the previous character
    CALL BACKSPACE
    DEC NumChars
    JMP ReadKey

; AL contains the last key pressed
StoreKey:
    MOV ICNUM[SI],AL    ; stores the key pressed. ICNUM[SI] = [SI + ICNUM]
    CALL WriteStrNext   ; write the char in AL to LCD
    INC NumChars
    ; IC number has 4 characters
    CMP NumChars,04H
    JZ WriteICName
    JMP ReadKey

; writes ic number entered by user onto LCD again after clearing it
WriteICName:
    LEA DI,ICNUM
    MOV COUNT,04H
    CALL WriteStr

; Now checking which IC is it, or if input is wrong

isIt7408:
    LEA BX,IC7408
    CALL CMP_IC_NUM         ; check if ICNUM is equal to 4 digits in BX
    CMP Flag,01H
    JNE isIt7486          ; if Flag then check if IC is good or bad
    CALL Check7408
    JMP S4

isIt7486:
    LEA BX,IC7486
    CALL CMP_IC_NUM
    CMP Flag,01H
    JNE isIt7432
    CALL Check7486
    JMP S4

isIt7432:
    LEA BX,IC7432
    CALL CMP_IC_NUM
    CMP Flag,01H
    JNE NO_IC
    CALL Check7432
    JMP S4

; Invalid Input
NO_IC:
    LEA DI,NotFound
    MOV COUNT,10           ; if no ic found then writes ICNUM "not found" on LCD
    CALL WriteStrNext

S4:
    CALL KEYBRD
    LEA DI,All_Keys
    ADD DI,AX              ; Take the key pressed and put it in AL
    MOV AL,[DI]
    CMP AL,"R"             ; If reset is pressed go back to start
    JE Start
    JMP S4

.EXIT



; Procedure for reading key pressed from the keyboard
KEYBRD PROC NEAR
    PUSHF
    PUSH BX
    PUSH CX
    PUSH DX   ; SAVING THE REGISTERS USED
    MOV         AL,0FFH
    OUT         port2c,AL

    ; Checking all All_Keys are open
    X0:         MOV            AL,00H
                OUT            port2c,AL
    ChkOpn:     IN             AL, port2c
                AND            AL,0F0H
                CMP            AL,0F0H
                JNZ            ChkOpn                    ; Means the key is still pressed, go back to X1
                CALL           D20MS                 ;key debounce check
                MOV            AL,00H
                OUT            port2c ,AL            ;provide column values as output through lower port C

                ; BL has 0 on col no. Al has 0 on row no.
    GetRowCol:  IN             AL,  port2c
                AND            AL,0F0H
                CMP            AL,0F0H
                JZ             GetRowCol
                CALL           D20MS                 ;key debounce check
                MOV            AL,00H
                OUT            port2c ,AL        ;provide column values as output through lower port C
                IN             AL,  port2c
                AND            AL,0F0H
                CMP            AL,0F0H
                JZ             GetRowCol                  ;key debounce check for unintentional keypress

                ; Checking the first row
                MOV            AL, 0EH          ;E = 1110
                MOV            BL,AL
                OUT            port2c,AL
                IN             AL, port2c
                AND            AL,0F0H
                CMP            AL,0F0H
                JNZ            RowCol
                ; Checking the second row
                MOV            AL, 0DH          ; D = 1101
                MOV            BL,AL
                OUT            port2c ,AL
                IN             AL, port2c
                AND            AL,0F0H
                CMP            AL,0F0H
                JNZ            RowCol
                ; Checking the third row
                MOV            AL, 0BH          ; B = 1011
                MOV            BL,AL
                OUT            port2c,AL
                IN             AL, port2c
                AND            AL,0F0H
                CMP            AL,0F0H
                JNZ            RowCol
                ; Checking the fourth row
                MOV            AL, 07H          ; 7 = 0111
                MOV            BL,AL
                OUT            port2c,AL
                IN             AL, port2c
                AND            AL,0F0H
                CMP            AL,0F0H
                JZ             GetRowCol

    ; BL(lower nibble) has 0 on col no. Al(upper nibble) has 0 on row no.
    ; This converts into RowCol format to be checked from kb table. Puts into Al.
    RowCol:     OR            AL,BL
                MOV           CX,0FH
                MOV           DI,00H

    ; Goes through all the 16 possible key combo to tell which key is pressed.
    FindKey:    CMP           AL,TABLE_K[DI]
                JZ            Over
                INC           DI
                LOOP          FindKey

    Over:       MOV AX,DI      ; move the offset of key pressed to AX
                POP DX
                POP CX
                POP BX
                POPF
                RET
KEYBRD   ENDP



; LCD shows the output as "IC NUM -  " initially
LCD_INIT PROC NEAR
    ; initializing LCD for 2 lines & 5*7 matrix
    MOV AL, 38H
    CALL WriteCommand               ;write the command to LCD
    CALL DELAY                  ;delay before next command
    CALL DELAY
    CALL DELAY
    ; LCD ON, Show cursor
    MOV AL, 0EH
    CALL WriteCommand
    CALL DELAY
    ; clear LCD
    MOV AL, 01
    CALL WriteCommand
    CALL DELAY
    ; command for shifting cursor right
    MOV AL, 06
    CALL WriteCommand
    CALL DELAY
    RET
LCD_INIT ENDP


; This procedure just clears the LCD
CLS PROC
    MOV AL, 01          ;AL=00000001, RSLCD is set to 1
    CALL WriteCommand
    CALL DELAY
    CALL DELAY
    RET
CLS ENDP


; this procedure writes command in AL to LCD
; How? -> It first sends the commands to port A which is connected to D0-D7 of LCD
; After that it sets enable pin from high to low with RS=0 for selecting command register
; and R/W = 0 for write operation. This enable thing is mandatory for the command to be executed.
WriteCommand PROC
    MOV DX, port1a
    OUT DX, AL          ; AL contains the command, command already sent to port A
    MOV DX, port1b
    ; Enable High
    MOV AL, 00000100B   
    OUT DX, AL
    ; A small pause
    NOP
    NOP
    ; Enable Low
    MOV AL, 00000000B
    OUT DX, AL
    RET
WriteCommand ENDP


; This procedure writes a string with starting add at DI having count characters to LCD
; It just picks up one character at a time and send to WriteChar for writing it
WriteStr PROC NEAR
    CALL CLS
    LoopOver:
        MOV AL, [DI]
        CALL WriteChar        ;issue it to LCD
        CALL DELAY          ; delay before next character
        CALL DELAY
        INC DI              ; Move to next character
        DEC COUNT
        JNZ LoopOver
    RET
WriteStr ENDP


; WriteStr without CLS. That is next after what is already written.
WriteStrNext PROC NEAR
    LoopOver2:
        MOV AL, [DI]
        CALL WriteChar        ;issue it to LCD
        CALL DELAY          ; delay before next character
        CALL DELAY
        INC DI              ; Move to next character
        DEC COUNT
        JNZ LoopOver2
    RET
WriteStrNext ENDP


; Write single character in AL to LCD
; R/W = 0 because we are writing. RS is 1 because data register is to be selected.
WriteChar PROC
    PUSH DX
    MOV DX,port1a            ; DX=port A address
    OUT DX, AL              ; issue the char to LCD
    MOV AL, 00000101B
    MOV DX, port1b           ;port B address
    OUT DX, AL
    MOV AL, 00000001B
    OUT DX, AL
    POP DX
    RET
WriteChar ENDP


BACKSPACE PROC NEAR
    PUSH DX
    PUSH AX
    MOV AL,00010000B    ; used for shifting cursor to one space left
    Call WriteCommand
    CALL DELAY          ; wait before next command
    CALL DELAY
    MOV AL,' '
    CALL WriteChar      ; overwrite " "
    CALL DELAY
    CALL DELAY          ; wait before issuing next command
    MOV AL,00010000B    ; shifting cursor to left
    Call WriteCommand
    POP AX              ;retrive registers
    POP DX
    RET
BACKSPACE ENDP




; delay of 20ms
DELAY PROC
    MOV CX, 1325 ;1325*15.085 usec = 20 msec
    WasteTime:
                NOP
                NOP
                LOOP WasteTime
    RET
DELAY ENDP


; Compares BX and ICNUM for equality
CMP_IC_NUM PROC NEAR
    MOV SI,0000H
    CMP_NUM:
        MOV AL,ICNUM[SI]
        CMP AL,[BX+SI]
        JE NXT_NUM
        JMP EP_CMP_IC
        NXT_NUM:
        CMP SI,03H
        JE PASS_CMP_IC   ; If all chars equal set Flag to 1 before return
        INC SI
        JMP CMP_NUM
    PASS_CMP_IC:
    MOV Flag,01H
    EP_CMP_IC:
    RET
CMP_IC_NUM ENDP



Check7408 PROC NEAR  ;checks if 7408 is good or bad[pass or fail]
    MOV DI,00H

    Testing7408:
        MOV AL,IN7408[DI]
        OUT port2a,AL       ; Input for the 7408 IC
        IN AL,port2b        ; Output value of 7408 goes to AL
        AND AL,0FH          ; Masking. Only lower nibble needed.
        CMP AL,OUT7408[DI]  ; Verify by comparing with expected output.
        JE Next7408
        CALL FAIL
        JMP Ret7408
    Next7408:
        CMP DI,03H           ; All four chars are same
        JE Pass7408         ; Means Pass.
        INC DI               ; If all chars are not read yet, proceed to next char
        JMP Testing7408
    Pass7408:
        CALL PASS
    Ret7408:
        RET
Check7408 ENDP


Check7432 PROC NEAR  ;checks if 7432 is good or bad[pass or fail]
    MOV DI,00H

    Testing7432:
        MOV AL,IN7432[DI]
        OUT port2a,AL       ; Input for the 7432 IC
        IN AL,port2b        ; Output value of 7432 goes to AL
        AND AL,0FH          ; Masking. Only lower nibble needed.
        CMP AL,OUT7432[DI]  ; Verify by comparing with expected output.
        JE Next7432
        CALL FAIL
        JMP Ret7432
    Next7432:
        CMP DI,03H           ; All four chars are same
        JE Pass7432         ; Means Pass.
        INC DI               ; If all chars are not read yet, proceed to next char
        JMP Testing7432
    Pass7432:
        CALL PASS
    Ret7432:
        RET
Check7432 ENDP


Check7486 PROC NEAR  ;checks if 7486 is good or bad[pass or fail]
    MOV DI,00H

    Testing7486:
        MOV AL,IN7486[DI]
        OUT port2a,AL       ; Input for the 7486 IC
        IN AL,port2b        ; Output value of 7486 goes to AL
        AND AL,0FH          ; Masking. Only lower nibble needed.
        CMP AL,OUT7486[DI]  ; Verify by comparing with expected output.
        JE Next7486
        CALL FAIL
        JMP Ret7486
    Next7486:
        CMP DI,03H           ; All four chars are same
        JE Pass7486         ; Means Pass.
        INC DI               ; If all chars are not read yet, proceed to next char
        JMP Testing7486
    Pass7486:
        CALL PASS
    Ret7486:
        RET
Check7486 ENDP


; When IC check fails
FAIL PROC NEAR
    PUSHF
    PUSH DI
    MOV COUNT,05
    LEA DI,FAIL_M      ; ' FAIL'
    CALL WriteStrNext    ; Writes next to the IC number
    POP DI
    POPF
    RET
FAIL ENDP


; When the IC passes the test
PASS PROC NEAR
    PUSHF
    PUSH DI
    MOV COUNT,05        ; Number of letters
    LEA DI,PASS_M     ; ' PASS'
    CALL WriteStrNext   ; Writes next to the IC number
    POP DI
    POPF
    RET
PASS ENDP


; delay generated will be approx 0.25 secs
D20MS:
          mov cx,2220
          xn:
              loop          xn
ret

END
