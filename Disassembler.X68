*-----------------------------------------------------------
* Title      :CSS 422 Disassembler
* Written by :Group RTX3080
* Date       :
* Description:This program will convert a memory image of
*             istructions and data back to 68000 assembly
*             language and output the disassembled code to
*             the display.
*-----------------------------------------------------------
CR          EQU     $0D
LF          EQU     $0A
HT          EQU     $09
MINADD      EQU     $00000000
MAXADD      EQU     $00FFFFFF

START       ORG     $1000

*-----------------------------------------------------------------------------------------------------------------
*           I/O SECTION OF PROGRAM
*-----------------------------------------------------------------------------------------------------------------

*-----------I/O Welcome Message-----------------------------
WELCOME     LEA     WelcomeMsg,A1   *Prints the welcome message to console
            MOVE.B  #14,D0
            TRAP    #15
            ADDI.B  #3,D6           *Increment line counter by 3.
            
GETSTART    LEA     Request1,A1     *Asks for the starting address
            TRAP    #15
            ADDI.B  #1,D6           *Increment line counter 1
            LEA     StartAdd,A1     *Stores given input as string at StartAdd
            MOVE.B  #2,D0
            TRAP    #15
            
CHECKSTART  CLR.L   D5              *Clears any values left in D5
            MOVE.B  #$0,D4          *Preload register with error byte
            JSR     STRINGASCII     *Jumps to subroutine to convert ASCII character code to hex
            CMP.B   #0,D4           *INVALID input
            BEQ     LOWERROR        *Branch to error message
            
            MOVE.L  #MINADD,D7      *Check minimum starting add
            CMP.L   D7,D5           *Has to be above $00000000
            BLT     LOWERROR        
            
            MOVE.L  #MAXADD,D7      *Check maximum ending add
            CMP.L   D7,D5           *Has to be under $00FFFFFF
            BGT     LOWERROR        
                       
            MOVEA.L  D5,A3           *Saves the resulting value into A3
            MOVE.L   D5,StartVal
            
GETEND      MOVE.B  #14,D0          *Asks for the ending address
            LEA     Request2,A1     *Part one of message
            TRAP    #15
            LEA     StartAdd,A1     *Include starting address in message
            TRAP    #15
            LEA     Request3,A1     *Part two of message
            TRAP    #15
            ADDI.B  #1,D6           *Increment line counter by 1
            LEA     EndAdd,A1       *Stores given input as string at EndAdd
            MOVE.B  #2,D0
            TRAP    #15
            
CHECKEND    CLR.L   D5              *Clears any values left in D5
            MOVE.B  #$0,D4          *Preload register with error byte
            JSR     STRINGASCII     *Jumps to subroutine to convert ASCII character code to hex
            CMP.B   #0,D4           *INVALID input
            BEQ     HIGHERROR       *Branch to error message
            CMP.L   A3,D5           *Has to be higher than starting address
            BLT     HIGHERROR
            
            MOVE.L  #MAXADD,D7      *Check maximum ending add
            CMP.L   D7,D5           *Has to be under $00FFFFFF
            BGT     HIGHERROR
            
            MOVEA.L D5,A4           *Saves the resulting value in D1 and moves it to EndVal
            MOVE.L  D5,EndVal       *Saves the resulting value in D1 and moves it to EndVal
            CLR.L   D5              *Clearing all the registers used for intial IO
            CLR.L   D4
            CLR.L   D2
            
            BRA     LEAVEIO
            
LOWERROR    LEA     ErrorMsg,A1     *Print error message
            MOVE.B  #14,D0
            TRAP    #15
            ADDI.B  #1,D6           *Increment line counter by one
            BRA     GETSTART        *Send back to ask for start address
            
HIGHERROR   LEA     ErrorMsg,A1     *Print error message
            MOVE.B  #14,D0
            TRAP    #15
            ADDI.B  #1,D6           *Increment line counter by one
            BRA     GETEND          *Send back to ask for start address
            
*-----------I/O Calls to Op-Code Routine--------------------      
LEAVEIO     MOVEA.L StartVal,A0     *Move the Start value given into A0
             
ReadMemory  MOVE.L  A0,D1           *Move the current location in memory to D1 to print
            MOVE.B  #15,D0
            MOVE.B  #16,D2
            TRAP    #15             *Print location of current Op-Code in memory to terminal
            
            JSR     print_tabs      *Call print_tabs to print two tabs to screen
            
            MOVE.W  (A0)+,D3        *Get Op-Code and save it in D3
            JSR     FindCode        *Find Op-Code
            ADDI.B  #1,D6           *Add 1 to line counter
            
BadCodeJump JSR     print_newline   *Call print_newline to print a new line
            CMP.B   #31,D6          *Do we have full screen of data?
            BEQ     NewPage
            
NextPage    CMPA.L  EndVal,A0       *Compares current location in memory to ending location
            BGE     end_prog        *If true, branch to EXIT
            BRA     ReadMemory      *If not true, branch back to ReadMemory
            
NewPage     MOVE.B  #0,D6           *Reset counter
            MOVE.B  #14,D0          *Will be printing message from A1
            LEA     NewPageMsg,A1   *Ask user to press enter
            TRAP    #15             *Print to console
            LEA     Wait,A1         *Load message to store user input
            MOVE.B  #2,D0           
            TRAP    #15
            JMP     NextPage        *Continue our code
*-----------------------------------------------------------------------------------------------------------------
*           OP-CODE SECTION OF PROGRAM
*-----------------------------------------------------------------------------------------------------------------

************************************************************
*Subroutine FindCode
*Decription: Compares stored value in D3 to OP-CODES
*We check NOP first because it's the easiest. From there we
*load the op-code from D3 to D4 and shift 16 bits to the right
*so that we can check what the first 2 bits are. Knowing the
*first two bits we can narrow our search into smaller groups
************************************************************ 
FindCode    
NOPCode     MOVE.W  #$4E71,D4       *Moves the OP-Code value for NOP into D4
            CMP.W   D4,D3           *Checks to see if D4 and D3 (Current word in memory) are equivalent
            BNE     FINDXX          *Branch to NOPCode if they are equal
            JSR     print_NOP
            RTS
************************************************************
*Subroutine FINDXX
*Decription: First step in our disassembly is we find the
*first two bits in our instruction format and narrow down
*which op-code it could be based on the 2 bits
************************************************************             
FINDXX      MOVE.W  D3,D4           *Move current op-code into D4
            LSR.W   #$8,D4          *Shift 16 bits right to find first 2 bits
            LSR.W   #$6,D4
            CMP.B   #%00,D4         *Check if our op-code starts with %00
            BEQ     MOVEXCode       *It's a MOVE/MOVEA command
            CMP.B   #%01,D4         *Check if op-code starts with %01
            BEQ     CODE_01         *op-code could be BRA,JSR,MOVEQ,MOVEM,ADDQ,LEA,NOT,BGT.BLE
            CMP.B   #%10,D4         *Check if op-code starts with %10
            BEQ     CODE_10         *op-code could be SUB,OR
            CMP.B   #%11,D4         *Check if op-code begins with %11
            BEQ     CODE_11         *op-code could be ADD,AND,LSL,LSR,ROL,ROR,ASL,ASR
            BRA     print_data
            
*-----------------------------------------------------------------------------------------------------------------
*Sub-section: Leading 2 bits
*Description: In this section is all of the code determining
*which sub group we can branch into based on the leading 2 bits
*of our instruction format.
*-----------------------------------------------------------------------------------------------------------------            

************************************************************
*Subroutine CODE_01
*Decription: First two bits were 01. Know we have to check
*the next 2 bits to see which op-code it is. Op-codes in this
*group are BRA,JSR,MOVEQ,MOVEM,ADDQ,LEA,NOT,BGT.BLE
************************************************************             
CODE_01     MOVE.W  D3,D4           *Get fresh copy of op-code into D4
            LSR.W   #8,D4           *Shift right 12 bits
            LSR.W   #4,D4
            CMP.B   #%0100,D4       *Check if equal to $%0100       
            BEQ     CODE_0100       *Disassemble further, could be MOVEM,LEA,NOT,JSR
            CMP.B   #%0110,D4       *Check if its equal %0110
            BEQ     CODE_0110       *Diassemble further, could be BCC(BGT,BLE,BEQ),BRA
            CMP.B   #%0111,D4       *Check if equal to %0111
            BEQ     MOVEQCode       *It's MOVEQ if its %0111
            CMP.B   #%0101,D4       *Check if it's ADDQ
            BEQ     ADDQCODE
            BRA     print_data
            
************************************************************
*Subroutine CODE_10
*Decription: First two bits were 10. Know we have to check
*the next 2 bits to see which op-code it is. Op-codes in this
*group are SUB,OR
************************************************************            
CODE_10     MOVE.W  D3,D4           *Get fresh copy of op-code into D4
            LSR.W   #8,D4           *Shift right 12 bits
            LSR.W   #4,D4
            CMP.B   #%1001,D4       *Check if its equal to %1001
            BEQ     SUBCode         *It's SUB
            CMP.B   #%1000,D4       *Check if equal to $1000
            BEQ     ORCode          *It's an ORCode
            BRA     print_data

************************************************************
*Subroutine CODE_11
*Decription: First two bits were 11. Know we have to check
*the next 2 bits to see which op-code it is. Op-codes in this
*group are ADD,ADDA,AND,LSL,LSR,ROL,ROR,ASL,ASR
************************************************************            
CODE_11     MOVE.W  D3,D4           *Get fresh copy of op-code into D4
            LSR.W   #8,D4           *Shift right 12 bits
            LSR.W   #4,D4
            CMP.B   #%1110,D4       *Check if its equal to %1110
            BEQ     CODE_1110       *It could be LSL,LSR,ROL,ROR,ASL,ASR
            CMP.B   #%1100,D4       *Check equal to %1100
            BEQ     ANDCode         *It's an AND code
            CMP.B   #%1101,D4       *Check if our 4 bits are %1101
            BEQ     ADDXCode        *If it is then its ADD/ADDA
            BRA     print_data

*-----------------------------------------------------------------------------------------------------------------
*Sub-section: Leading 4 bits
*Description: In this section is all of the code leading into
*further disassembly of the instruction format now checking
*the leading 4 bits to see which op-code we have.
*-----------------------------------------------------------------------------------------------------------------            

************************************************************
*Subroutine CODE_0100
*Narrowed down possibilities for op-code. Now we have to
*determine whether op-code is MOVEM,LEA,NOT,JSR
************************************************************            
CODE_0100   MOVE.W  D3,D4       *Moves the current OP-Code to D4
            ANDI.W  #$FFC0,D4   *Mask bits that indicate JSR
            CMP.W   #$4E80,D4   *Compare to JSR bits
            BEQ     JSRCode     *We know the instruction is JSR
            
            MOVE.W  D3,D4
            ANDI.W  #$F1C0,D4   *Mask bits that indicate LEA
            CMP.W   #$41C0,D4   *Compare to LEA bits
            BEQ     CODE_LEA    *We know the instruction is LEA
            
            MOVE.W  D3,D4       
            CMP.W   #$4E75,D4   *Compare to RTS bits
            BEQ     RTSCode     *We know the instruction is RTS
            
            MOVE.W  D3,D4
            AND.W   #$FB80,D4
            CMP.W   #$4880,D4
            BEQ     CODE_MOVEM
            
            MOVE.W  D3,D4
            AND.W   #$0F00, D4  *Masking to bits 8-11 
            LSR.W   #8,D4       *Shift right 8 bits to get the  bits
            CMP.W   #%0110, D4  *Checking to see if the bits in D4 match that of NOT command
            BEQ     NOTCOMMAND
            BRA     print_data
            
CODE_MOVEM  JSR     print_MOVEM
            JSR     find_sz0
            JSR     print_tabs
            MOVE.W  D3,D4
            AND.W   #$0400,D4
            CMP.W   #$0400,D4
            BEQ     CODE_MOVEMR
            JSR     ea_MOVEMwrite
            RTS
            
CODE_MOVEMR JSR     ea_MOVEMread
            RTS   

NOTCOMMAND  MOVE.B  #14,D0
            LEA     NOT,A1
            TRAP    #15
            JSR     print_tabs
            JSR     p_space4
            JSR     ea_NOT     
            RTS          

CODE_LEA    JSR     print_LEA
            JSR     print_tabs
            JSR     p_space4
            JSR     which_way
            CMP.B   #0,D5
            BNE     ea_LEA
            MOVE.W  D3,D4           *Move op-code into D4
            AND.W   #$0E00,D4       *Mask everything except bit 9-11
            LSR.W   #$8,D4          *Shift bits to the right 9
            LSR.W   #$1,D4
            MOVE.B  D4,D5           *Move data into D5 so that we can call print_dreg
            JSR     print_A
            JSR     print_reg
            JSR     print_comma
            JSR     CHK_MODE0Src
            RTS

************************************************************
*Subroutine CODE_0110
*Narrowed down possibilities for op-code. Now we have to
*determine whether op-code is BCC(BGT,BLE,BEQ),BRA
************************************************************  
*check for 8 bit displacement         
CODE_0110   MOVE.W  D3,D4           *Moves the current OP-Code to D4
            
            AND.W   #$0F00, D4      *Masking to bits 8-11 
            LSR.W   #8,D4           *Shift right 8 bits to get the 
            CMP.W   #%0000,D4       *Checks to see if it is equal to the MOVE command
            BEQ     JSRBRA          *BRANCH IF equal to $0000 = jsrBRA
            CMP.W   #%1110,D4       *compare for BGT 
            BEQ     JSRBGT          *Branch to sub routine for BGT
            CMP.W   #%1111,D4       *Compare for BLE
            BEQ     JSRBLE          *branch to sub routine for BLE
            CMP.W   #%0111,D4       *compare for BEQ
            BEQ     JSRBEQ          *Branch to sub routine BEQ
            BRA     print_data



JSRBRA      MOVE.B  #14,D0
            LEA     BRA,A1          *prints Branch command to console
            TRAP    #15             *Print to console
            JSR     print_tabs
            JSR     p_space4
            JSR     ea_BCC
            RTS
            
JSRBGT      MOVE.B  #14,D0
            LEA     BGT,A1          *prints Branch Greater Than command to console
            TRAP    #15             *Print to console
            JSR     print_tabs
            JSR     p_space4
            JSR     ea_BCC
            RTS
            
JSRBLE      MOVE.B  #14,D0
            LEA     BLE,A1          *prints Branch Less Than command to console
            TRAP    #15             *Print to console
            JSR     print_tabs
            JSR     p_space4
            JSR     ea_BCC
            RTS

JSRBEQ      MOVE.B  #14,D0
            LEA     BEQ,A1          *prints Branch Equal to console
            TRAP    #15             *Print to console
            JSR     print_tabs
            JSR     p_space4
            JSR     ea_BCC
            RTS





************************************************************
*Subroutine CODE_0111
*
************************************************************            
CODE_0111   *Implement code for 0111




************************************************************
*Subroutine CODE_0111
*
************************************************************            
CODE_0111   *Implement code for 0110


************************************************************
*Subroutine CODE_1001
*
************************************************************            
CODE_1001   *Implement code for 1001



************************************************************
*Subroutine CODE_1110
*This code is a little trickier because 4 commands start with
*1110, and those are ROL,ROR,LSL,LSR. We have to check some
*the other bits in the instruction to find out exactly which
************************************************************            
CODE_1110   MOVE.W  D3,D4       *Move op-code into D4
            AND.W   #$00C0,D4   *Mask everything except bit 7 and 6
            LSR.W   #$6,D4
            CMP.B   #%0011,D4
            BEQ     SHIFT_EA
            BRA     SHIFTCode



************************************************************
*Subroutine CODE_1100
*
************************************************************            
CODE_1100   *Implement code for 1100




************************************************************
*Subroutine CODE_1101
*
************************************************************            
CODE_1101   *Implement code for 1101

*-----------------------------------------------------------------------------------------------------------------
*Sub-section: Op-code
*In this section is all of the code that either is getting very close to knowing
*op-code or knowing exactly which op-code we are dealing with
*-----------------------------------------------------------------------------------------------------------------
           
************************************************************
*Subroutine MOVEXCode
*Disassemble further to find out if we have a MOVE op-code
*or a MOVEA
************************************************************             
MOVEXCode   MOVE.W  D3,D4           *Moves the current OP-Code to D4
            AND.W   #$C000,D4       *Masks all but the first 2 bits of the word in D4
            CMP.W   #$0000,D4       *Checks to see if it is equal to the MOVE command            
            MOVE.W  D3,D4           *Move the current OP-Code to D4
            
************************************************************
*Subroutine MOVEACode
*
************************************************************  
MOVEACode   AND.W   #$01C0,D4       *Mask all bits except 8,7, and 6 (Destination mode portion)
            CMP.W   #$0040,D4       *Check to see if it is equal to %0000000001000000
            BNE     MOVECode        *If not equal, than it is a MOVE command, branch to MOVECode
            JSR     print_MOVEA     *Subroutine called to print MOVEA
            BRA     MOVESize        *Branch to MOVESize (skips the call to print MOVE)
************************************************************
*Subroutine MOVECode
*
************************************************************  
MOVECode    JSR     print_MOVE      *Subroutine called to print MOVE
************************************************************
*Subroutine MOVESize
*Finds our which size our move is using
************************************************************  
MOVESize    JSR     find_size       *Subroutine called to determine size and print to screen (.B,.W,or.L)
            JSR     print_tabs      *Subroutine to print out two tabs
            JSR     ea_MOVE         *Subroutine called to print out the Effective Addresses used in MOVE
            RTS                     *Return to where function was called


************************************************************
*Subroutine ADDX
*Disassemble further to find out if we have an ADD or ADDA op-code
************************************************************                       
ADDXCode    MOVE.W  D3,D4           *Moves the current OP-Code to D4
            AND.W   #$01C0,D4       *Mask everything except bits 6-8
            LSR.W   #$6,D4          *Logic shift right 6 spots
            CMP.B   #%0111,D4       *Check OPmode for ADD/ADDA
            BEQ     ADDACode        *0111 and 0011 means it is ADDA
            CMP.B   #%0011,D4       
            BEQ     ADDACode
            BRA     ADDCode

************************************************************
*Subroutine ADDCode
*Description: We know our op-code is ADD. The following code
*is now to get the correct data from our op-code and
*print out it's exact translation from machine code
************************************************************                      
ADDCode     JSR     print_ADD       *Print our ADD outad
            JSR     which_way       *Check if destination is EA or Data reg
            CMP.B   #0,D5
            BNE     ADD_EA          *Destination will be an EA
            MOVE.W  D3,D4           *Move op-code into D4 to manipulate
            AND.W   #$01C0,D4       *Mask all bits except bit 6,7,8
            LSR.W   #$6,D4          *Shift 6 bits to the right so we can read that opmode size
            JSR     find_sz2        *Find size for ADD, read find_sz2 for details
            JSR     print_tabs
            JSR     p_space2
            JSR     ea_ADD          *Print out EA
            JSR     print_comma
            MOVE.W  D3,D5           *Move fresh copy to D5
            AND.W   #$0E00,D5       *Mask all except bit 9-11
            LSR.W   #$8,D5          *Shift right 9
            LSR.W   #$1,D5
            JSR     print_D
            JSR     print_reg      *Print which data reg it is
            RTS

ADD_EA      MOVE.W  D3,D4           *Move op-code into D4 to manipulate
            AND.W   #$01C0,D4       *Mask all bits except bit 6,7,8
            LSR.W   #$6,D4          *Shift 6 bits to the right so we can read that opmode size
            JSR     find_sz3        *Find size for ADD, read find_sz2 for details
            JSR     print_tabs
            JSR     p_space2
            
            MOVE.W  D3,D4           *Move op-code into D4
            AND.W   #$0E00,D4       *Mask everything except bit 9-11
            LSR.W   #$8,D4          *Shift bits to the right 9
            LSR.W   #$1,D4
            MOVE.B  D4,D5           *Move data into D5 so that we can call print_dreg
            JSR     print_D
            JSR     print_reg
            JSR     print_comma
            JSR     ea_ADD

            RTS

************************************************************
*Subroutine ADDACode
*Description: We know our op-code is ADDA. The following code
*is now to get the correct data from our op-code and
*print out it's exact translation from machine code
************************************************************    
ADDACode    JSR     print_ADDA
            MOVE.W  D3,D4           *Move op-code into D4 to manipulate
            AND.W   #$01C0,D4       *Mask all bits except bit 6,7,8
            LSR.W   #$6,D4          *Shift 6 bits to the right so we can read that opmode size
            JSR     find_sz1        *Find size for ADDA, read find_sz1 for details
            JSR     print_tabs  
            JSR     p_space1    
            JSR     ea_ADDA         *Print out the EA, does do ADDI stuff
            JSR     print_comma
            MOVE.W  D3,D5           *fresh copy into D5
            AND.W   #$0E00,D5       *Mask everything except bits 9-11
            LSR.W   #$8,D5          *Shift right 9 bits
            LSR.W   #$1,D5
            JSR     print_A
            JSR     print_reg      *Print out which address reg it is
            RTS


************************************************************
*Subroutine ANDCode
*Description: We know our op-code is AND. The following code
*will now set up our printing to the screen
************************************************************            
ANDCode     JSR     print_AND       *print AND to screen
            JSR     which_way       *Find out whats source whats destination
            CMP.B   #1,D5           *If 1, Destination is EA
            BEQ     AND_EA          *If 0, Destination is Data reg
            MOVE.W  D3,D4           *Move op-code into D4
            AND.W   #$01C0,D4       *Mask everything except bit 6-8
            
            LSR.W   #$6,D4          *Shift it to the right 6 bits
            JSR     find_sz2        *op-mode follows sz2 format, we use sz2 to find size
            JSR     print_tabs
            JSR     p_space2
            JSR     ea_AND_Srce     *EA is the source, print it
            RTS
            
            
AND_EA      MOVE.W  D3,D4           *Move op-code into D4
            AND.W   #$01C0,D4       *Mask everything except bit 6-8
            LSR.W   #$6,D4          *Shift it to the right 6 bits
            JSR     find_sz3        *op-mode follows sz3 format, we use sz3 to find size
            JSR     print_tabs
            JSR     p_space2
            
            MOVE.W  D3,D5           *Move op-code into D5
            AND.W   #$0E00,D5       *Mask everything except bit 9-11
            LSR.W   #$8,D5          *Shifts bit 9 to the right
            LSR.W   #$1,D5
            JSR     print_D
            JSR     print_reg      *Print which data reg it is
            JSR     print_comma
            JSR     ea_AND_Dest     *EA is the destination, print it
            RTS

************************************************************
*Subroutine SHIFTCode
*Description:At this point we know there's no EA involved in our instruction
*We will only be shifting a data register. We still need to figure
*out if this is a form of ROL,ROR command or a LSR,LSL command
************************************************************            
SHIFTCode   MOVE.W  D3,D4           *Move fresh copy of op-code into D4
            AND.W   #$0018,D4       *Mask everything except bits 3 and 4
            LSR.W   #$3,D4          *Shift over 3 bits
            CMP.B   #%0011,D4       *Compare to %0011
            BEQ     ROXCode         *0011 will be a ROX command
            CMP.B   #%0001,D4       *0001 will be an LSX command
            BEQ     LSXCode
            CMP.B   #%0000,D4       *0000 will be an ASX command
            BEQ     ASXCode
            BRA     print_data


************************************************************
*Subroutine ROXCode
*Description:We know it's either ROL,ROR at this point. We just need to check
*one more bit. This operation is being done on a data reg.
************************************************************            
ROXCode     MOVE.W  D3,D4           *Move fresh copy of op-code into D4
            AND.W   #$0100,D4       *Mask everything except bit 8
            LSR.W   #$8,D4          *Shift over 8 bits
            CMP.B   #0,D4           *Compare to 0
            BEQ     RORCode         *0 is RIGHT ROTATE
            CMP.B   #1,D4           
            BRA     ROLCode         *1 is LEFT ROTATE

************************************************************
*Subroutine RORCode
*Description:FINALLY we know it's a ROR command op-code. The following
*code will print everything we have and know to the screen
************************************************************            
RORCode     JSR     print_ror       *Print ror
            JSR     find_sz4        *Find the size for our operation
            JSR     print_tabs      *print our tabs
            JSR     p_space2
            MOVE.W  D3,D4           *Move fresh copy of op code
            AND.W   #$0020,D4       *Mask all bits except bit 5
            LSR.W   #$5,D4          *Shift 5 bits right
            CMP.B   #1,D4           *Is it equal to 1?
            BEQ     ROR_REG         *Amount to roatte is from register 
            JSR     print_immed  
            MOVE.W  D3,D4           *Fresh copy of op-code
            AND.W   #$0E00,D4       *Mask everything except bits 9-11
            LSR.W   #$8,D4          *Shifts 9 bits right
            LSR.W   #$1,D4            
            MOVE.L  D4,D1           *Move number to D1 to print
            MOVE.B  #3,D0
            TRAP    #15             *Print number
            JSR     print_comma     *Print comma       
            MOVE.W  D3,D5           *Move fresh copy op-code to D5
            AND.W   #$0007,D5       *Find which register it is
            JSR     print_D
            JSR     print_reg      *Print the register
            RTS
            
ROR_REG     MOVE.W  D3,D5           *Move fresh copy of D3 to D5
            AND.W   #$0E00,D5       *Mask everything except bits 9-11
            LSR.W   #$8,D5          *Shift right 9 bits
            LSR.W   #$1,D5
            JSR     print_D
            JSR     print_reg      *print which reg it is      
            JSR     print_comma            
            MOVE.W  D3,D5           *Fresh copy of op-code
            AND.W   #$0007,D5
            JSR     print_D
            JSR     print_reg      *Print which register it is
            RTS
              

************************************************************
*Subroutine ROLCode
*Description:FINALLY we know it's a ROL command op-code. The following
*code will print everything we have and know to the screen
************************************************************            
ROLCode     JSR     print_rol       *Print ror
            JSR     find_sz4        *Find the size for our operation
            JSR     print_tabs      *print our tabs
            JSR     p_space2
            MOVE.W  D3,D4           *Move fresh copy of op code
            AND.W   #$0020,D4       *Mask all bits except bit 5
            LSR.W   #$5,D4          *Shift 5 bits right
            CMP.B   #1,D4           *Is it equal to 1?
            BEQ     ROL_REG         *Amount to roatte is from register   
            JSR     print_immed
            MOVE.W  D3,D4           *Fresh copy of op-code
            AND.W   #$0E00,D4       *Mask everything except bits 9-11
            LSR.W   #$8,D4          *Shifts 9 bits right
            LSR.W   #$1,D4            
            MOVE.L  D4,D1           *Move number to D1 to print
            MOVE.B  #3,D0
            TRAP    #15             *Print number
            JSR     print_comma     *Print comma       
            MOVE.W  D3,D5           *Move fresh copy op-code to D5
            AND.W   #$0007,D5       *Find which register it is
            JSR     print_D
            JSR     print_reg      *Print the register
            RTS
            
ROL_REG     MOVE.W  D3,D5           *Move fresh copy of D3 to D5
            AND.W   #$0E00,D5       *Mask everything except bits 9-11
            LSR.W   #$8,D5          *Shift right 9 bits
            LSR.W   #$1,D5
            JSR     print_D
            JSR     print_reg      *print which reg it is      
            JSR     print_comma            
            MOVE.W  D3,D5           *Fresh copy of op-code
            AND.W   #$0007,D5
            JSR     print_D
            JSR     print_reg      *Print which register it is
            RTS

************************************************************
*Subroutine LSXCode
*Description: We know it's either LSR,LSL at this point. We know the operation
*is being performed on a data register.
************************************************************            
LSXCode     MOVE.W  D3,D4           *Move fresh copy of op-code into D4
            AND.W   #$0100,D4       *Mask everything except bit 8
            LSR.W   #$8,D4          *Shift over 8 bits
            CMP.B   #0,D4           *Compare to 0
            BEQ     LSRCode         *0 is LSR
            BRA     LSLCode         *1 is LSL
            
 
************************************************************
*Subroutine LSLCode
*Description: Finally we know it's LSL. The following code
*Will be to print what we have to the screen
************************************************************            
LSLCode     JSR     print_LSL       *Print ror
            JSR     find_sz4        *Find the size for our operation
            JSR     print_tabs      *print our tabs
            JSR     p_space2
            MOVE.W  D3,D4           *Move fresh copy of op code
            AND.W   #$0020,D4       *Mask all bits except bit 5
            LSR.W   #$5,D4          *Shift 5 bits right
            CMP.B   #1,D4           *Is it equal to 1?
            BEQ     LSL_REG         *Amount to roatte is from register   
            JSR     print_immed
            MOVE.W  D3,D4           *Fresh copy of op-code
            AND.W   #$0E00,D4       *Mask everything except bits 9-11
            LSR.W   #$8,D4          *Shifts 9 bits right
            LSR.W   #$1,D4            
            MOVE.L  D4,D1           *Move number to D1 to print
            MOVE.B  #3,D0
            TRAP    #15             *Print number
            JSR     print_comma     *Print comma       
            MOVE.W  D3,D5           *Move fresh copy op-code to D5
            AND.W   #$0007,D5       *Find which register it is
            JSR     print_D
            JSR     print_reg      *Print the register
            RTS
            
LSL_REG     MOVE.W  D3,D5           *Move fresh copy of D3 to D5
            AND.W   #$0E00,D5       *Mask everything except bits 9-11
            LSR.W   #$8,D5          *Shift right 9 bits
            LSR.W   #$1,D5
            JSR     print_D
            JSR     print_reg      *print which reg it is      
            JSR     print_comma            
            MOVE.W  D3,D5           *Fresh copy of op-code
            AND.W   #$0007,D5
            JSR     print_D
            JSR     print_reg      *Print which register it is
            RTS
              
             
 
************************************************************
*Subroutine LSRCode
*Description: Finally we know it's LSR. The following code
*Will be to print what we have to the screen
************************************************************            
LSRCode     JSR     print_LSR       *Print ror
            JSR     find_sz4        *Find the size for our operation
            JSR     print_tabs      *print our tabs
            JSR     p_space2
            MOVE.W  D3,D4           *Move fresh copy of op code
            AND.W   #$0020,D4       *Mask all bits except bit 5
            LSR.W   #$5,D4          *Shift 5 bits right
            CMP.B   #1,D4           *Is it equal to 1?
            BEQ     LSR_REG         *Amount to roatte is from register   
            JSR     print_immed
            MOVE.W  D3,D4           *Fresh copy of op-code
            AND.W   #$0E00,D4       *Mask everything except bits 9-11
            LSR.W   #$8,D4          *Shifts 9 bits right
            LSR.W   #$1,D4            
            MOVE.L  D4,D1           *Move number to D1 to print
            MOVE.B  #3,D0
            TRAP    #15             *Print number
            JSR     print_comma     *Print comma       
            MOVE.W  D3,D5           *Move fresh copy op-code to D5
            AND.W   #$0007,D5       *Find which register it is
            JSR     print_D
            JSR     print_reg      *Print the register
            RTS
            
LSR_REG     MOVE.W  D3,D5           *Move fresh copy of D3 to D5
            AND.W   #$0E00,D5       *Mask everything except bits 9-11
            LSR.W   #$8,D5          *Shift right 9 bits
            LSR.W   #$1,D5
            JSR     print_D
            JSR     print_reg      *print which reg it is      
            JSR     print_comma            
            MOVE.W  D3,D5           *Fresh copy of op-code
            AND.W   #$0007,D5
            JSR     print_D
            JSR     print_reg      *Print which register it is
            RTS
              
            *Insert error checking

************************************************************
*Subroutine ASX
************************************************************            
ASXCode     JSR     which_way       *Left or right?
            CMP.B   #0,D5
            BEQ     ASRCode
            BRA     ASLCode
            
************************************************************
*Subroutine ASLCode
*Description: 
************************************************************            
ASLCode     JSR     print_ASL       *Print ror
            JSR     find_sz4        *Find the size for our operation
            JSR     print_tabs      *print our tabs
            JSR     p_space2
            MOVE.W  D3,D4           *Move fresh copy of op code
            AND.W   #$0020,D4       *Mask all bits except bit 5
            LSR.W   #$5,D4          *Shift 5 bits right
            CMP.B   #1,D4           *Is it equal to 1?
            BEQ     ASL_REG         *Amount to rotate is from register   
            JSR     print_immed
            MOVE.W  D3,D4           *Fresh copy of op-code
            AND.W   #$0E00,D4       *Mask everything except bits 9-11
            LSR.W   #$8,D4          *Shifts 9 bits right
            LSR.W   #$1,D4           
            MOVE.L  D4,D1           *Move number to D1 to print
            MOVE.B  #3,D0
            TRAP    #15             *Print number
            JSR     print_comma     *Print comma       
            MOVE.W  D3,D5           *Move fresh copy op-code to D5
            AND.W   #$0007,D5       *Find which register it is
            JSR     print_D
            JSR     print_reg      *Print the register
            RTS
            
ASL_REG     MOVE.W  D3,D5           *Move fresh copy of D3 to D5
            AND.W   #$0E00,D5       *Mask everything except bits 9-11
            LSR.W   #$8,D5          *Shift right 9 bits
            LSR.W   #$1,D5
            JSR     print_D
            JSR     print_reg      *print which reg it is      
            JSR     print_comma            
            MOVE.W  D3,D5           *Fresh copy of op-code
            AND.W   #$0007,D5
            JSR     print_D
            JSR     print_reg      *Print which register it is
            RTS
              
            
************************************************************
*Subroutine ASRCode
*Description: Finally we know it's LSR. The following code
*Will be to print what we have to the screen
************************************************************            
ASRCode     JSR     print_ASR       *Print ror
            JSR     find_sz4        *Find the size for our operation
            JSR     print_tabs      *print our tabs
            JSR     p_space2
            MOVE.W  D3,D4           *Move fresh copy of op code
            AND.W   #$0020,D4       *Mask all bits except bit 5
            LSR.W   #$5,D4          *Shift 5 bits right
            CMP.B   #1,D4           *Is it equal to 1?
            BEQ     ASR_REG         *Amount to roatte is from register   
            JSR     print_immed
            MOVE.W  D3,D4           *Fresh copy of op-code
            AND.W   #$0E00,D4       *Mask everything except bits 9-11
            LSR.W   #$8,D4          *Shifts 9 bits right
            LSR.W   #$1,D4            
            MOVE.L  D4,D1           *Move number to D1 to print
            MOVE.B  #3,D0
            TRAP    #15             *Print number
            JSR     print_comma     *Print comma       
            MOVE.W  D3,D5           *Move fresh copy op-code to D5
            AND.W   #$0007,D5       *Find which register it is
            JSR     print_D
            JSR     print_reg      *Print the register
            RTS
            
ASR_REG     MOVE.W  D3,D5           *Move fresh copy of D3 to D5
            AND.W   #$0E00,D5       *Mask everything except bits 9-11
            LSR.W   #$8,D5          *Shift right 9 bits
            LSR.W   #$1,D5
            JSR     print_D
            JSR     print_reg      *print which reg it is      
            JSR     print_comma            
            MOVE.W  D3,D5           *Fresh copy of op-code
            AND.W   #$0007,D5
            JSR     print_D
            JSR     print_reg      *Print which register it is
            RTS
                        
           
************************************************************
*Subroutine SHIFT_EA
*Description:Our diassembler has determined that we have
*a shifting command but it is being performed on an EA
*We still need to figure out which shifting command it is
************************************************************            
SHIFT_EA    MOVE.W  D3,D4           *Move fresh copy op-code to D4
            AND.W   #$0400,D4       *Mask everything except bit 10
            LSR.W   #$8,D4          *Shift right 10 bits
            LSR.W   #$2,D4
            CMP.B   #0,D4
            BEQ     AorLSXCode       *If its 0 its an ASX,LSX code
            BRA     ROXEACode       *If its 1 its a ROX code 

************************************************************
*Subroutine ROXEACode
*Description We know its a ROL,ROR command, now we just need
*to figure out which one it is
************************************************************            
ROXEACode   MOVE.W  D3,D4           *Move fresh copy of op-code into D4
            AND.W   #$0100,D4       *Mask everything except bit 8
            LSR.W   #$8,D4          *Shift over 8 bits
            CMP.B   #0,D4           *Compare to 0
            BEQ     ea_ROR          *0 is ROR
            BRA     ea_ROL          *1 is ROL
            

************************************************************
*Subroutine AorLSXCode
************************************************************            
AorLSXCode  MOVE.W  D3,D4
            AND.W   #%1110001011000000,D4  
            CMP.W   #%1110001011000000,D4   *Is is LSX OR ASX
            BEQ     LSXEACode
            BRA     ASXEACode
            
************************************************************
*Subroutine ASXEACode
*Description:
************************************************************            
ASXEACode   JSR     which_way       *Left or right?
            CMP.B   #0,D5           *0 is right
            BEQ     ea_ASR
            BRA     ea_ASL
            

************************************************************
*Subroutine LSXEACode
*Description We know its a LSL,LSR command, now we just need
*to figure out which one it is
************************************************************            
LSXEACode   JSR     which_way       *Is it left or right?
            CMP.B   #0,D5
            BEQ     ea_LSR          *0 is right
            BRA     ea_LSL          *1 is left
            

************************************************************
*Subroutine SUBCode
*We know the instruction is a SUB command
************************************************************            
SUBCode     JSR     print_SUB
            JSR     find_sz4
            JSR     print_tabs
            JSR     p_space2
            JSR     which_way
            CMP.B   #0,D5
            BNE     ea_SUB
            JSR     CHK_MODE0Src
            JSR     print_comma
            MOVE.W  D3,D4           *Move op-code into D4
            AND.W   #$0E00,D4       *Mask everything except bit 9-11
            LSR.W   #$8,D4          *Shift bits to the right 9
            LSR.W   #$1,D4
            MOVE.B  D4,D5           *Move data into D5 so that we can call print_dreg
            JSR     print_D
            JSR     print_reg
            RTS

************************************************************
*Subroutine ORCode
*We know the instruction is an OR command
************************************************************            
ORCode     JSR      print_OR
           JSR      find_sz4
           JSR      print_tabs
           JSR      p_space3
           JSR     which_way
           CMP.B   #0,D5
           BNE     ea_OR
           JSR     CHK_MODE0Src
           JSR     print_comma
           MOVE.W  D3,D4           *Move op-code into D4
           AND.W   #$0E00,D4       *Mask everything except bit 9-11
           LSR.W   #$8,D4          *Shift bits to the right 9
           LSR.W   #$1,D4
           MOVE.B  D4,D5           *Move data into D5 so that we can call print_dreg
           JSR     print_D
           JSR     print_reg
           RTS

************************************************************
*Subroutine JSRCode
*We know the instruction is an JSR command
************************************************************  
JSRCode    JSR      print_JSR
           JSR      print_tabs
           JSR      p_space4
           JSR      ea_JSR
           RTS
           
************************************************************
*Subroutine RTSCode
*We know the instruction is an RTS command
************************************************************ 
RTSCode    JSR      print_RTS
           JSR      print_tabs
           RTS
************************************************************
*Subroutine MOVEQ
*Descripion: We know that the command is a MOVEQ command
************************************************************            
MOVEQCode   MOVE.W  D3,D4           *Moces the current OP-Code to D4
            AND.W   #$0100,D4
            CMP.W   #0,D4
            BNE     not_MOVEQ
            JSR     print_MOVEQ
            
            JSR     print_tabs
            JSR     p_space2
            JSR     ea_MOVEQ
            RTS

not_MOVEQ   *Jump to outpirnt of data as this is not a MOVEQ
            RTS
************************************************************
*Subroutine ADDQ
*Descripion: We know that the command is a ADDQ command
************************************************************  
            
ADDQCODE    MOVE.B  #14,D0
            LEA     ADDQ,A1         *prints Branch Less Than command to console
            TRAP    #15             *Print to console
            MOVE.W  D3,D4           *Moves curent opcode into D4
            AND.W   #$00C0,D4       *masks all but 6 and 7 bits
            LSR.W   #6,D4           *Shift right 6 bits to get the  bits
            JSR     find_sz4
            JSR     print_tabs
            JSR     p_space1
            JSR     print_immed
            
            MOVE.W  D3,D4
            AND.W   #$0E00,D4
            LSR.W   #$8,D4
            LSR.W   #$1,D4
            MOVE.L  D4,D1
            MOVE.B  #15,D0
            MOVE.B  #16,D2
            TRAP    #15
            JSR     print_comma
            JSR     CHK_MODE4
            RTS
*-----------------------------------------------------------------------------------------------------------------
*Sub-section: find_sizes
*This section groups together all the find_sizes you can use to reuse finding the size of an op-mode
*or any other times you need to find a size. Read description to know which find size you can
*use in your code implementation.
*-----------------------------------------------------------------------------------------------------------------

************************************************************
*Subroutine find_size
*Description: Looks at the size of command and loads correct symbol to A4
************************************************************
find_size   MOVE.W  D3,D4           *Moves the current opcode to D4
            AND.W   #$3000,D4       *Masks all but the 12 and 13 bits
            CMP.W   #$1000,D4       *Compare them to 01 (byte operation)
            BNE     CheckWord       *If not equal, branch to CheckWord
            LEA     Byte,A1         *Load byte message to A1
            MOVE.B  #$01,D5
            BRA     print_size      *Branch to print_size
            
CheckWord   CMP.W   #$3000,D4       *Compares D4 (word operation)
            BNE     CheckLong       *If not equal, branch to CheckLong
            LEA     Word,A1         *Load word message to A1
            MOVE.B  #$03,D5
            BRA     print_size      *Branch to print_size
            
CheckLong   LEA     Long,A1         *Load long message to A1
            MOVE.B  #$02,D5
            BRA     print_size      *Branch to print_size

************************************************************
*Subroutine find_sz0
*Description: used to find size of op-mode, or realy any size
*Written for reuasbility. Has to follow 0-word 1-long
*IMPORTANT: MUST format data into D4 before calling this subroutine
************************************************************
find_sz0    MOVE.W  D3,D4
            AND.W   #$0040,D4
            
            CMP.B   #$0040,D4
            BEQ     sz0_long
            LEA     Word,A1
            MOVE.B  #$03,D5
            BRA     print_size
            
sz0_long    LEA     Long,A1
            MOVE.B  #$02,D5
            BRA     print_size

************************************************************
*Subroutine find_sz1
*Description: used to find size of op-mode, or realy any size
*Written for reuasbility. Has to follow 011-word 111-long
*IMPORTANT: MUST format data into D4 before calling this subroutine
************************************************************
find_sz1    CMP.B   #%0011,D4       *Check if op-mode equal to %0011     
            BEQ     sz1_word 
            CMP.B   #%0111,D4
            BEQ     sz1_long
            BRA     bad_instr       *Error op-mode
            
sz1_word    LEA     Word,A1         *Load word message to A1
            MOVE.B  #$03,D5
            BRA     print_size      *Branch to print_size
            
sz1_long    LEA     Long,A1
            MOVE.B  #$02,D5
            BRA     print_size      *Branch to print_size


************************************************************
*Subroutine find_sz2
*Description: used to find size of op-mode, or realy any size
*Written for reuasbility. Has to follow 000-byte 001-word 010-long
*IMPORTANT: MUST format data into D4 before calling this subroutine
************************************************************
find_sz2    CMP.B   #%0000,D4       *Check if op-mode equal to %0011     
            BEQ     sz2_byte        *We know it's a byte
            CMP.B   #%0001,D4       *Check if equal to %0001
            BEQ     sz2_word        *We know it's a word
            CMP.B   #%0010,D4       *Check if equal to %0010
            BEQ     sz2_long        *We know it's a long
            BRA     bad_instr       *Error op-mode
            
sz2_byte    LEA     Byte,A1         *Load word message to A1
            MOVE.B  #01,D5
            BRA     print_size      *Branch to print_size
            
sz2_word    LEA     Word,A1         *Load word message to A1
            MOVE.B  #$03,D5
            BRA     print_size      *Branch to print_size
            
sz2_long    LEA     Long,A1
            MOVE.B  #$02,D5
            BRA     print_size      *Branch to print_size
            
            
************************************************************
*Subroutine find_sz3
*Description: used to find size of op-mode, or realy any size
*Written for reuasbility. Has to follow 100-byte 101-word 110-long
*IMPORTANT: MUST format data into D4 before calling this subroutine
************************************************************
find_sz3    CMP.B   #%0100,D4       *Check if op-mode equal to %0100     
            BEQ     sz3_byte        *We know it's a byte
            CMP.B   #%0101,D4       *Check if equal to %0101
            BEQ     sz3_word        *We know it's a word
            CMP.B   #%0110,D4       *Check if equal to %0110
            BEQ     sz3_long        *We know it's a long
            BRA     bad_instr       *Error op-mode
            
sz3_byte    LEA     Byte,A1         *Load word message to A1
            MOVE.B  #01,D5
            BRA     print_size      *Branch to print_size
            
sz3_word    LEA     Word,A1         *Load word message to A1
            MOVE.B  #$03,D5
            BRA     print_size      *Branch to print_size
            
sz3_long    LEA     Long,A1
            MOVE.B  #$02,D5
            BRA     print_size      *Branch to print_size
            
 
         
************************************************************
*Subroutine find_sz4
*Description: used to find size of op-mode, or realy any size
*Written for reuasbility. Has to follow 00-byte 01-word 10-long
*Data doesnt not have to be formatted beforehand to use this subroutine
************************************************************
find_sz4    MOVE.W  D3,D4           *Move fresh copy of op-code into D4
            AND.W   #$00C0,D4       *Mask everything except bits 6 and 7
            LSR.W   #$6,D4          *Logic shift right 6 bits
            CMP.B   #%0000,D4       *Check if op-mode equal to %0100     
            BEQ     sz4_byte        *We know it's a byte
            CMP.B   #%0001,D4       *Check if equal to %0101
            BEQ     sz4_word        *We know it's a word
            CMP.B   #%0010,D4       *Check if equal to %0110
            BEQ     sz4_long        *We know it's a long
            BRA     bad_instr       *Error op-mode
            
sz4_byte    LEA     Byte,A1         *Load word message to A1
            MOVE.B  #$01,D5
            BRA     print_size      *Branch to print_size
            
sz4_word    LEA     Word,A1         *Load word message to A1
            MOVE.B  #$03,D5
            BRA     print_size      *Branch to print_size
            
sz4_long    LEA     Long,A1
            MOVE.B  #$02,D5
            BRA     print_size      *Branch to print_size

   
************************************************************
*Subroutine print_size
*Description: Prints size of message loaded into A1
*IMPORTANT: A1 must be pre-loaded with message before calling
*this sub-routine
************************************************************

print_size  MOVE.B  #14,D1          *Set TRAP #15 to task 14 (print string)
            TRAP    #15             *Print to console
            RTS

************************************************************
*Subroutine which_way
*Description: Determines which is the source and which is
*the destination between the DN and the EA
*IMPORTANT: must be used where data reg or address reg is 
*inherently part of the instruction format
*IMPORTANT: must be used where bit 8 is the direction decider
*D5 is used to store outcome: 0:Destination is DATAREG
*                             1:Destination is EA
************************************************************               
which_way   MOVE.W  D3,D4           *Move op-code into D4
            AND.W   #$0100,D4       *Mask everything except bit 8
            LSR.W   #$8,D4          *shift 8 bits to the right
            CMP.B   #0,D4           *Is it a 0?
            BNE     store_one       *If it's not destination is EA
            MOVE.B  #0,D5           *If it's 0 destination is DATAREG
            RTS
            
store_one   MOVE.B  #1,D5
            RTS


               
*-----------------------------------------------------------------------------------------------------------------
*           EFFECTIVE ADDRESSING SECTION
*-----------------------------------------------------------------------------------------------------------------
************************************************************
*Subroutine ea_()
*Description: Determines the effective addresses for a given command
************************************************************
ea_MOVE     JSR     CHK_MODE0Src
            JSR     print_comma
            JSR     CHK_MODE0Dest
            RTS
            
ea_MOVEQ    JSR     print_immed
            MOVE.W  D3,D1
            AND.W   #$00FF,D1
            MOVE.B  #16,D2
            MOVE.B  #15,D0
            TRAP    #15
            JSR     print_comma
            JSR     print_D
            MOVE.B  #16,D2
            MOVE.B  #15,D0
            MOVE.W  D3,D1
            LSR.W   #8,D1
            LSR.W   #1,D1
            AND.W   #$0007,D1
            TRAP    #15
            RTS

   
 
ea_ADDQ     MOVE.W  D3,D4           *Move opcode to D4
            AND.W   #$0E00,D4       *Mask all bits except the last 6
            MOVE.B  #16,D2          *Print immediate ea
            MOVE.B  #15,D0
            TRAP    #15
            JSR     print_comma
            AND.W   #$003F,D4       *Mask all bits except the last 6
            JSR     CHK_MODE0Dest
            RTS


ea_BCC      MOVE.W  D3,D4
            AND.W   #$00FF,D4
            CMP.W   #$0000,D4
            BEQ     ea_Bcc16
            CMP.W   #$00FF,D4
            BEQ     ea_Bcc32
            MOVEA.L A0,A5
            MOVE.L  A5,D5
            ADD.B  D4,D5
            MOVEA.L D5,A5
            BRA     print_BccEA

ea_Bcc16    MOVE.W  (A0)+,D4
            MOVEA.L A0,A5
            ADDA.W  D4,A5
            BRA     print_BccEA

ea_Bcc32    MOVE.L  (A0)+,D4
            MOVEA.L A0,A5
            ADDA.L  D4,A5
            BRA     print_BccEA

print_BccEA JSR     print_absolute

            MOVE.L  A5,D1
            MOVE.B  #16, D2
            MOVE.B  #15,D0
            TRAP    #15
            CLR.L   D5
            RTS


ea_MOVEMread    MOVE.W  D3,D4
            JSR     CHK_MOVEM
            JSR     print_comma
            MOVE.W  (A0)+,D3
            JSR     MOVEM_READ
            RTS
                
ea_MOVEMwrite   MOVEA.W A0,A2
            SUBA.W  #$2,A2
            MOVE.W  (A0)+,D3
            JSR     MOVEM_WRITE
            JSR     print_comma
            MOVE.W  (A2),D3
            MOVE.W  D3,D4
            JSR     CHK_MOVEM
            RTS

ea_ADD      JSR     CHK_MODE0Src    *Sees which EAs to check
            RTS

ea_ADDA     JSR     CHK_MODE0Src    *Sees which EAs to check
            RTS

ea_AND_Dest JSR     CHK_MODE1       *Sees which EAs to check
            RTS

ea_AND_Srce JSR     CHK_MODE2       *Sees which EAs to check
            JSR     print_comma
            MOVE.W  D3,D4           *Move op-code into D4
            AND.W   #$0E00,D4       *Mask everything except bit 9-11
            LSR.W   #$8,D4          *Shifts bit 9 to the right
            LSR.W   #$1,D4
            MOVE.B  D4,D5           *Move data to D5 so we can call print_dreg
            JSR     print_D
            JSR     print_reg
            RTS

ea_ROR      JSR     print_ROR
            JSR     print_tabs
            JSR     CHK_MODE3       *Sees which EAs to check
            RTS
            
ea_ROL      JSR     print_ROL
            JSR     print_tabs
            JSR     CHK_MODE3       *Sees which EAs to check
            RTS            
            
ea_LSR      JSR     print_LSR
            JSR     print_tabs
            JSR     p_space4
            JSR     CHK_MODE3       *Sees which EAs to check
            RTS
            
ea_LSL      JSR     print_LSL
            JSR     print_tabs
            JSR     p_space4
            JSR     CHK_MODE3       *Sees which EAs to check
            RTS        

ea_ASR      JSR     print_ASR
            JSR     print_tabs
            JSR     p_space4
            JSR     CHK_MODE3       *Sees which EAs to check
            RTS

ea_ASL      JSR     print_ASL
            JSR     print_tabs
            JSR     p_space4
            JSR     CHK_MODE3       *Sees which EAs to check
            RTS    

ea_SUB      MOVE.W  D3,D4           *Move op-code into D4
            AND.W   #$0E00,D4       *Mask everything except bit 9-11
            LSR.W   #$8,D4          *Shift bits to the right 9
            LSR.W   #$1,D4
            MOVE.B  D4,D5           *Move data into D5 so that we can call print_dreg
            JSR     print_D
            JSR     print_reg
            JSR     print_comma
            JSR     CHK_MODE0Src
            RTS

ea_OR       MOVE.W  D3,D4           *Move op-code into D4
            AND.W   #$0E00,D4       *Mask everything except bit 9-11
            LSR.W   #$8,D4          *Shift bits to the right 9
            LSR.W   #$1,D4
            MOVE.B  D4,D5           *Move data into D5 so that we can call print_dreg
            JSR     print_D
            JSR     print_reg
            JSR     print_comma
            JSR     CHK_MODE0Src
            RTS

ea_LEA      MOVE.W  D3,D4           *Move op-code into D4
            AND.W   #$0E00,D4       *Mask everything except bit 9-11
            LSR.W   #$8,D4          *Shift bits to the right 9
            LSR.W   #$1,D4
            MOVE.B  D4,D5           *Move data into D5 so that we can call print_dreg
            JSR     CHK_MODE0Src
            JSR     print_comma
            JSR     print_A
            JSR     print_reg
            RTS

ea_JSR      JSR     CHK_MODE0Src
            RTS
            
ea_NOT      JSR     CHK_MODE0Src
            RTS       
*-----------------------------------------------------------------------------------------------------------------
*CHK_MODES
*Description: Use these to check which modes to check when it's an EA.
*Depending on which MODE you know you DON'T want to check, use one of these
*Can't think of a more efficient way to do it.
*-----------------------------------------------------------------------------------------------------------------

************************************************************
*Subroutine CHK_MODE0Src
*Description: Checks all needed modes 
************************************************************

CHK_MODE0Src   MOVE.W  D3,D4
            AND.W   #$0038,D4
            LSR.W   #$3,D4
            
            CMP.B   #%0000,D4       *Is it data reg mode?
            BEQ     MODE000
            
            CMP.B   #%0001,D4       *Is it Address direct mode?
            BEQ     MODE001
            
            CMP.B   #%0010,D4       *Is it Address indirect mode?
            BEQ     MODE010
            
            CMP.B   #%0011,D4       *Is it address post increment mode?
            BEQ     MODE011
            
            CMP.B   #%0100,D4       *Is it address pre decrement mode?
            BEQ     MODE100
            
            CMP.B   #%0111,D4       *Is it one of the 111 modes?
            BEQ     MODE111
            BRA     bad_instr       *Its a bad instruction

************************************************************
*Subroutine CHK_MOVEM
*Description: Checks all needed modes 
************************************************************

CHK_MOVEM   MOVE.W  D3,D4
            AND.W   #$0038,D4
            LSR.W   #$3,D4
            
            CMP.B   #%0010,D4       *Is it Address indirect mode?
            BEQ     MODE010
            
            CMP.B   #%0011,D4       *Is it address post increment mode?
            BEQ     MODE011
            
            CMP.B   #%0100,D4       *Is it address pre decrement mode?
            BEQ     MODE100
            
            CMP.B   #%0111,D4       *Is it one of the 111 modes?
            BEQ     MOVEM111
            
            CMPA.W  (A0)+,A1
            BRA     bad_instr       *Its a bad instruction

************************************************************
*Subroutine CHK_MODE0Dest
*Description: Checks all needed modes 
************************************************************

CHK_MODE0Dest   MOVE.W  D3,D4
            AND.W   #$01C0,D4
            LSR.W   #$6,D4
            
            CMP.B   #%0000,D4       *Is it data reg mode?
            BEQ     MODE000D
            
            CMP.B   #%0001,D4       *Is it Address direct mode?
            BEQ     MODE001D
            
            CMP.B   #%0010,D4       *Is it Address indirect mode?
            BEQ     MODE010D
            
            CMP.B   #%0011,D4       *Is it address post increment mode?
            BEQ     MODE011D
            
            CMP.B   #%0100,D4       *Is it address pre decrement mode?
            BEQ     MODE100D
            
            CMP.B   #%0111,D4       *Is it one of the 111 modes?
            BEQ     MODE111D
            BRA     bad_instr       *Its a bad instruction

************************************************************
*Subroutine CHK_MODE1
*Description: Checks all needed modes EXCEPT Address reg direct
************************************************************

CHK_MODE1   MOVE.W  D3,D4
            AND.W   #$0038,D4
            LSR.W   #$3,D4
            
            CMP.B   #%0000,D4       *Is it data reg mode?
            BEQ     MODE000
            
            CMP.B   #%0010,D4       *Is it Address indirect mode?
            BEQ     MODE010
            
            CMP.B   #%0011,D4       *Is it address post increment mode?
            BEQ     MODE011
            
            CMP.B   #%0100,D4       *Is it address pre decrement mode?
            BEQ     MODE100
            
            CMP.B   #%0111,D4       *Is it one of the 111 modes?
            BEQ     MODE111
            BRA     bad_instr       *Its a bad instruction
            
************************************************************
*Subroutine CHK_MODE2
*Description: Checks all needed modes EXCEPT Address reg direct
*and Data Register
************************************************************

CHK_MODE2   MOVE.W  D3,D4
            AND.W   #$0038,D4
            LSR.W   #$3,D4
            
            CMP.B   #%0,D4          *Is it data reg?
            BEQ     MODE000
            
            CMP.B   #%0010,D4       *Is it Address indirect mode?
            BEQ     MODE010
            
            CMP.B   #%0011,D4       *Is it address post increment mode?
            BEQ     MODE011
            
            CMP.B   #%0100,D4       *Is it address pre decrement mode?
            BEQ     MODE100
            
            CMP.B   #%0111,D4       *Is it one of the 111 modes?
            BEQ     MODE111
            BRA     bad_instr       *Its a bad instruction    

************************************************************
*Subroutine CHK_MODE3
*Description: Checks all needed modes EXCEPT Address reg direct
*add reg direct, and data address mod
************************************************************

CHK_MODE3   MOVE.W  D3,D4
            AND.W   #$0038,D4
            LSR.W   #$3,D4
            
            CMP.B   #%0010,D4       *Is it Address indirect mode?
            BEQ     MODE010
            
            CMP.B   #%0011,D4       *Is it address post increment mode?
            BEQ     MODE011
            
            CMP.B   #%0100,D4       *Is it address pre decrement mode?
            BEQ     MODE100
            
            MOVE.W  D3,D4
            AND.W   #$003F,D4
            
            CMP.B   #%0000000000111000,D4       *Is it one of the 111 modes?
            BEQ     WordMode
            
            CMP.B   #%0000000000111001,D4       *Is it one of the 111 modes?
            BEQ     LongMode
            BRA     bad_instr       *Its a bad instruction   
            
************************************************************
*Subroutine CHK_MODE4
*Description: Checks all needed modes data immediate
************************************************************

CHK_MODE4   MOVE.W  D3,D4
            AND.W   #$0038,D4
            LSR.W   #$3,D4
            
            CMP.B   #%0000,D4       *Is it data reg?
            BEQ     MODE000
            
            CMP.B   #%0001,D4       *Is it Address direct mode?
            BEQ     MODE001
            
            CMP.B   #%0010,D4       *Is it Address indirect mode?
            BEQ     MODE010
            
            CMP.B   #%0011,D4       *Is it address post increment mode?
            BEQ     MODE011
            
            CMP.B   #%0100,D4       *Is it address pre decrement mode?
            BEQ     MODE100
            
            MOVE.W  D3,D4
            AND.W   #$003F,D4
            
            CMP.B   #%0000000000111000,D4       *Is it one of the 111 modes?
            BEQ     WordMode
            
            CMP.B   #%0000000000111001,D4       *Is it one of the 111 modes?
            BEQ     LongMode
            BRA     bad_instr       *Its a bad instruction               
*-----------------------------------------------------------------------------------------------------------------
*Mode codes
*Description: use these to determine and print out which mode it is 
*-----------------------------------------------------------------------------------------------------------------
            
MODE000     JSR     print_D
            JSR     find_EA_reg
            RTS
            

MODE001     JSR     print_A
            JSR     find_EA_reg
            RTS

MODE010     JSR     print_ARIStart
            JSR     find_EA_reg
            JSR     print_ARIEnd
            RTS

MODE011     JSR     print_ARIStart
            JSR     find_EA_reg
            JSR     print_ARIPostEnd
            RTS

MODE100     JSR     print_ARIPreStart
            JSR     find_EA_reg
            JSR     print_ARIEnd
            RTS

MODE111     MOVE.W  D3,D4
            AND.W   #$0007,D4
            CMP.B   #$0000,D4
            BEQ     WordMode
            CMP.B   #$0001,D4
            BEQ     LongMode
            CMP.B   #$0004,D4
            BEQ     DataMode
            BRA     bad_instr       *Its a bad instruction
            RTS
            
WordMode    JSR     print_absolute
            MOVE.W  (A0)+,D1
            MOVE.B  #15,D0
            MOVE.B  #16,D2
            TRAP    #15
            RTS

LongMode    JSR     print_absolute
            MOVE.L  (A0)+,D1
            MOVE.B  #15,D0
            MOVE.B  #16,D2
            TRAP    #15
            RTS

DataMode    JSR     print_immed
            CMP.B   #$02,D5
            BEQ     DataModeSL
            MOVE.W  (A0)+,D1
            BRA     DataModeP
DataModeSL  MOVE.L  (A0)+,D1
DataModeP   MOVE.B  #15,D0
            MOVE.B  #16,D2
            TRAP    #15
            RTS    

find_EA_reg MOVE.W  D3,D4           *Move fresh copy of op-code into D4
            AND.W   #$0007,D4       *Mask everything except bits 0-2
            CMP.B   #7,D4           *If higher than 7, not a valid register
            BGT     EA_Reg_Err
            CMP.B   #0,D4           *If less than 0, not a valid register
            BLT     EA_Reg_Err
            
            MOVE.L  D4,D1           *Move number 0-7 into D1 to be printed
            MOVE.B  #3,D0
            TRAP    #15
            RTS
            
EA_Reg_Err  *Print error

*-----------------------------------------------------------------------------------------------------------------
*Mode codes for .W or .L for MOVEM
*Description: use these to determine and print out which 111 mode is used in MOVEM
*-----------------------------------------------------------------------------------------------------------------
MOVEM111    MOVE.W  D3,D4
            AND.W   #$0007,D4
            CMP.B   #$0000,D4
            BEQ     WordMode
            CMP.B   #$0001,D4
            BEQ     LongMode
            
            CMPA.W  (A0)+,A1
            BRA     bad_instr
            RTS
            
*-----------------------------------------------------------------------------------------------------------------
*Mode codes for Destination Registers
*Description: use these to determine and print out which mode it is 
*-----------------------------------------------------------------------------------------------------------------
            
MODE000D    JSR     print_D
            JSR     find_EA_regD
            RTS
            

MODE001D    JSR     print_A
            JSR     find_EA_regD
            RTS

MODE010D    JSR     print_ARIStart
            JSR     find_EA_regD
            JSR     print_ARIEnd
            RTS

MODE011D    JSR     print_ARIStart
            JSR     find_EA_regD
            JSR     print_ARIPostEnd
            RTS

MODE100D    JSR     print_ARIPreStart
            JSR     find_EA_regD
            JSR     print_ARIEnd
            RTS

MODE111D    MOVE.W  D3,D4           *Move fresh copy of op-code into D4
            AND.W   #$0E00,D4       *Mask everything except bits 9-11
            LSR.W   #$6,D4
            LSR.W   #$3,D4
            CMP.B   #$0000,D4
            BEQ     WordModeD
            CMP.B   #$0001,D4
            BEQ     LongModeD
            CMP.B   #$0004,D4
            BEQ     DataModeD
            
WordModeD   JSR     print_absolute
            MOVE.W  (A0)+,D1
            MOVE.B  #15,D0
            MOVE.B  #16,D2
            TRAP    #15
            RTS

LongModeD   JSR     print_absolute
            MOVE.L  (A0)+,D1
            MOVE.B  #15,D0
            MOVE.B  #16,D2
            TRAP    #15
            RTS

DataModeD   JSR     print_immed
            CMP.B   #$02,D5
            BEQ     DataModeDL
            MOVE.W  (A0)+,D1
            BRA     DataModePD
DataModeDL  MOVE.L  (A0)+,D1
DataModePD  MOVE.B  #15,D0
            MOVE.B  #16,D2
            TRAP    #15
            RTS    

find_EA_regD MOVE.W  D3,D4           *Move fresh copy of op-code into D4
            AND.W   #$0E00,D4       *Mask everything except bits 9-11
            LSR.W   #$6,D4
            LSR.W   #$3,D4
            MOVE.L  D4,D1           *Move number 0-7 into D1 to be printed
            MOVE.B  #3,D0
            TRAP    #15
            RTS
            
EA_Reg_ErrD  *Print error

************************************************************
*Subroutine MOVEM_READ
*Description: Prints the registers used for the read MOVEM op-code
************************************************************
MOVEM_READ  CLR.L   D5
            MOVE.W  D3,D4
            CLR.L   D3
            ASL.L   #8,D4
            ASL.L   #8,D4
MOVEM_LOOP  ROL.L   #1,D4
            MOVE.B  D4,D3
            ROR.L   #1,D3
            ADDQ.W  #1,D5
            CMP.W   #16,D5
            BNE     MOVEM_LOOP
            
            ASR.L   #8,D3
            ASR.L   #8,D3
            CLR.L   D5
            
            CLR.L   D4
            MOVE.W  D3,D4

            JSR     MOVEM_WRITE

            RTS

************************************************************
*Subroutine MOVEM_WRITE
*Description: Prints the registers used for the read MOVEM op-code
************************************************************
MOVEM_WRITE MOVE.W  D3,D4           *Checks the 7th bit for A0
            AND.W   #$0080,D4       *Mask all but the 7th bit
            CMP.W   #$0080,D4       *See if the bit is eaul to 1
            BNE     MOVEM_WA1       *If not, move to checking next bit
            JSR     print_A         *If equal to 1, print out register
            MOVE.B  #$0,D5
            JSR     print_reg0
            
            MOVE.W  D3,D4           *Get a new copy of Register List Mask field
            AND.W   #$FF7F,D4       *Mask the bits that have been checked
            CMP.W   #0,D4          *Compare to 0, if equal branch to end
            BEQ     MOVEM_WE
            JSR     print_slash     *If not equal, print / and  continue to check
            
MOVEM_WA1   MOVE.W  D3,D4
            AND.W   #$0040,D4
            CMP.W   #$0040,D4
            BNE     MOVEM_WA2
            JSR     print_A
            MOVE.B  #$1,D5
            JSR     print_reg1
            
            MOVE.W  D3,D4
            AND.W   #$FF3F,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WA2   MOVE.W  D3,D4
            AND.W   #$0020,D4
            CMP.W   #$0020,D4
            BNE     MOVEM_WA3
            JSR     print_A
            MOVE.B  #$2,D5
            JSR     print_reg2
            
            MOVE.W  D3,D4
            AND.W   #$FF1F,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WA3   MOVE.W  D3,D4
            AND.W   #$0010,D4
            CMP.W   #$0010,D4
            BNE     MOVEM_WA4
            JSR     print_A
            MOVE.B  #$3,D5
            JSR     print_reg3
            
            MOVE.W  D3,D4
            AND.W   #$FF0F,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WA4   MOVE.W  D3,D4
            AND.W   #$0008,D4
            CMP.W   #$0008,D4
            BNE     MOVEM_WA5
            JSR     print_A
            MOVE.B  #$4,D5
            JSR     print_reg4

            MOVE.W  D3,D4
            AND.W   #$FF07,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash

MOVEM_WA5   MOVE.W  D3,D4
            AND.W   #$0004,D4
            CMP.W   #$0004,D4
            BNE     MOVEM_WA6
            JSR     print_A
            MOVE.B  #$5,D5
            JSR     print_reg5
            
            MOVE.W  D3,D4
            AND.W   #$FF03,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WA6   MOVE.W  D3,D4
            AND.W   #$0002,D4
            CMP.W   #$0002,D4
            BNE     MOVEM_WA7
            JSR     print_A
            MOVE.B  #$6,D5
            JSR     print_reg6
            
            MOVE.W  D3,D4
            AND.W   #$FF01,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WA7   MOVE.W  D3,D4
            AND.W   #$0001,D4
            CMP.W   #$0001,D4
            BNE     MOVEM_WD0
            JSR     print_A
            MOVE.B  #$7,D5
            JSR     print_reg7
            
            MOVE.W  D3,D4
            AND.W   #$FF00,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WD0   MOVE.W  D3,D4
            AND.W   #$8000,D4
            CMP.W   #$8000,D4
            BNE     MOVEM_WD1
            JSR     print_D
            MOVE.B  #$0,D5
            JSR     print_reg0
            
            MOVE.W  D3,D4
            AND.W   #$7F00,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WD1   MOVE.W  D3,D4
            AND.W   #$4000,D4
            CMP.W   #$4000,D4
            BNE     MOVEM_WD2
            JSR     print_D
            MOVE.B  #$1,D5
            JSR     print_reg1
            
            MOVE.W  D3,D4
            AND.W   #$3F00,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WD2   MOVE.W  D3,D4
            AND.W   #$2000,D4
            CMP.W   #$2000,D4
            BNE     MOVEM_WD3
            JSR     print_D
            MOVE.B  #$2,D5
            JSR     print_reg2
            
            MOVE.W  D3,D4
            AND.W   #$1F00,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WD3   MOVE.W  D3,D4
            AND.W   #$1000,D4
            CMP.W   #$1000,D4
            BNE     MOVEM_WD4
            JSR     print_D
            MOVE.B  #$3,D5
            JSR     print_reg3
            
            MOVE.W  D3,D4
            AND.W   #$0F00,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash

MOVEM_WD4   MOVE.W  D3,D4
            AND.W   #$0800,D4
            CMP.W   #$0800,D4
            BNE     MOVEM_WD5
            JSR     print_D
            MOVE.B  #$4,D5
            JSR     print_reg4
            
            MOVE.W  D3,D4
            AND.W   #$0700,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WD5   MOVE.W  D3,D4
            AND.W   #$0400,D4
            CMP.W   #$0400,D4
            BNE     MOVEM_WD6
            JSR     print_D
            MOVE.B  #$5,D5
            JSR     print_reg5
            
            MOVE.W  D3,D4
            AND.W   #$0300,D4
            CMP.W   #0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WD6   MOVE.W  D3,D4
            AND.W   #$0200,D4
            CMP.W   #$0200,D4
            BNE     MOVEM_WD7
            JSR     print_D
            MOVE.B  #$6,D5
            JSR     print_reg6
            
            MOVE.W  D3,D4
            AND.W   #$0100,D4
            CMP.W   #$0,D4
            BEQ     MOVEM_WE
            JSR     print_slash
            
MOVEM_WD7   MOVE.W  D3,D4
            AND.W   #$0100,D4
            CMP.W   #$0100,D4
            BNE     MOVEM_WE
            JSR     print_D
            MOVE.B  #$7,D5
            JSR     print_reg7

MOVEM_WE    CLR.L   D5
            RTS

*-----------Program Exit------------------------------------            
EXIT        MOVE.B  #9,D0           *Halts the simulator and exits the program
            TRAP    #15

*-----------------------------------------------------------------------------------------------------------------
*           I/O SUBROUTINES
*-----------------------------------------------------------------------------------------------------------------

************************************************************
*Subroutine print_()
*Description: Prints the OP-Code to the console
************************************************************
print_NOP   LEA     NOPmsg,A1       *Load NOP
            BRA     print_it

print_MOVE  LEA     MOVEmsg,A1      *Load MOVE
            BRA     print_it

print_MOVEA LEA     MOVEAmsg,A1     *Load MOVEA
            BRA     print_it
            
print_ADD   LEA     ADDmsg,A1     *Load ADDA
            BRA     print_it            
            
print_ADDA  LEA     ADDAmsg,A1     *Load ADDA
            BRA     print_it      
            
print_AND   LEA     ANDmsg,A1     *Load AND
            BRA     print_it   

print_ROL   LEA     ROLmsg,A1     *Load ROL
            BRA     print_it      

print_ROR   LEA     RORmsg,A1     *Load ROR
            BRA     print_it       

print_LSR   LEA     LSRmsg,A1     *Load LSR
            BRA     print_it       

print_LSL   LEA     LSLmsg,A1     *Load LSL
            BRA     print_it                   
            
print_ASR   LEA     ASRmsg,A1     *Load LSR
            BRA     print_it       

print_ASL   LEA     ASLmsg,A1     *Load LSL
            BRA     print_it       
            
print_MOVEQ LEA     MOVEQmsg,A1
            BRA     print_it
            
print_MOVEM LEA     MOVEMmsg,A1
            BRA     print_it

print_SUB   LEA     SUBmsg,A1
            BRA     print_it
            
print_OR    LEA     ORmsg,A1
            BRA     print_it
            
print_LEA   LEA     LEAmsg,A1
            BRA     print_it
            
print_JSR   LEA     JSRmsg,A1
            BRA     print_it

print_RTS   LEA     RTSmsg,A1
            BRA     print_it
*ADD MORE STRINGS AS WE ADD THE OP-CODES

print_it    MOVE.B  #14,D1          *Print OP-Code
            TRAP    #15
            RTS                     *Return to where subroutine was called

************************************************************
*Subroutine STRINGASCII
*Description: Converts String ASCII to Hexadecimal
*Will use D4 to store valid input (1/0) valid/invlad
*Will store valid user input into D5
************************************************************
STRINGASCII MOVE.B  (A1)+,D2        *Move the most significant bit to D2
            CMP.B   #$0,D2          *Check next character for null
            BEQ     ENDSA           *If null, branch to end stringascii

            CMP.B   #102,D2         *Check if byte > 102
            BGT     ERROR
            
            CMP.B   #96,D2          *Within range we know is lowercase
            BGT     LOWER2HEX          
            
            CMP.B   #70,D2          * 96 > Byte > 70 error
            BGT     ERROR
            
            CMP.B   #64,D2          *Byte within range we know is upper
            BGT     UPPER2HEX
            
            CMP.B   #57,D2          * 57 < Byte < 64 error
            BGT     ERROR
            
            CMP.B   #48,D2          *Within range we know is a number
            BLT     ERROR
            SUBI.B  #48,D2          *Subtract to get value
            BRA     PUSH            *Done decoding number value, push on

LOWER2HEX   SUBI.B  #87,D2          *Change ASCII lowercase to value
            BRA     STRINGASCII

UPPER2HEX   SUBI.B  #55,D2          *Change ASCII uppercase to value

PUSH        ASL.L   #4,D5           *Make room for next byte
            ADD.B   D2,D5           *"push" new converted byte on
            BRA     STRINGASCII
            
ERROR       MOVE.B  #$0,D4          *Not valid character or byte
            RTS
            
ENDSA       MOVE.B  #$1,D4          *End STRINGASCII, everything passed
            RTS

************************************************************
*Subroutine to_letter (Used by STRINGASCII)
*Description: Converts ASCII letter to Hexadecimal number     
************************************************************
to_letter   AND.B   #$0F,D2         *Mask the first 4 bits
            ADD.B   #$9,D2          *Add $9 to it to get the proper hexidecimal number
            RTS                     *Return to where subroutine was called


************************************************************
*Subroutine to_number (Used by STRINGASCII)
*Decription: Converts ASCII number to Hexidecimal number
************************************************************ 
to_number   AND.B   #$0F,D2         *Mask the first 4 bits
            RTS                     *Return to where subroutine was called
            
************************************************************
*Subroutine line_count
*Increment line counter
************************************************************
line_count  ADDI.B  #1,D6
            RTS
            
************************************************************
*Subroutine print_tabs
*Description: Prints out two tabs into the console
************************************************************
print_tabs  MOVE.B  #14,D0          
            LEA     Tab,A1          *Loads '    ' to A1
            TRAP    #15
            TRAP    #15             *Prints two tabs
            RTS
            
************************************************************
*Subroutine p_space1
*Description: Prints out 1 space to console
************************************************************
p_space1    MOVE.B  #14,D0          
            LEA     Space1,A1
            TRAP    #15
            RTS
            
            
************************************************************
*Subroutine p_space2
*Description: Prints out 2 spaces to console
************************************************************
p_space2    MOVE.B  #14,D0          
            LEA     Space2,A1
            TRAP    #15
            RTS
            
************************************************************
*Subroutine p_space3
*Description: Prints out 3 spaces to console
************************************************************
p_space3    MOVE.B  #14,D0          
            LEA     Space3,A1
            TRAP    #15
            RTS
            
************************************************************
*Subroutine p_space4
*Description: Prints out 4 spaces to console
************************************************************
p_space4    MOVE.B  #14,D0          
            LEA     Space4,A1
            TRAP    #15
            RTS
            
************************************************************
*Subroutine print_newline
*Description: Prints out two tabs into the console
************************************************************
print_newline   MOVE.B  #14,D0
            LEA     NewLine,A1      *Loads new line to A1
            TRAP    #15             *Print to console
            RTS
            
************************************************************
*Subroutine print_comma
*Description: Prints out comma into the console
************************************************************
print_comma MOVE.B  #14,D0
            LEA     Comma,A1        *Loads , to A1
            TRAP    #15             *Print to console
            RTS

************************************************************
*Subroutine print_slash
*Description: Prints out a / into the console
************************************************************
print_slash MOVE.B  #14,D0
            LEA     Slash,A1        *Loads , to A1
            TRAP    #15             *Print to console
            RTS
            
************************************************************
*Subroutine print_immed
*Description: Prints out comma into the console
************************************************************
print_immed MOVE.B  #14,D0
            LEA     Immediate,A1        *Loads , to A1
            TRAP    #15             *Print to console
            RTS

************************************************************
*Subroutine print_absolute
*Description: Prints out comma into the console
************************************************************
print_absolute  MOVE.B  #14,D0
            LEA     Absolute,A1     *Loads $ to A1
            TRAP    #15             *Print to console
            RTS


************************************************************
*Subroutine print_D
*Description: Prints out comma into the console
************************************************************
print_D     MOVE.B  #14,D0
            LEA     Dn,A1           *Loads , to A1
            TRAP    #15             *Print to console
            RTS

************************************************************
*Subroutine print_A
*Description: Prints out comma into the console
************************************************************
print_A     MOVE.B  #14,D0
            LEA     An,A1           *Loads , to A1
            TRAP    #15             *Print to console
            RTS

************************************************************
*Subroutine print_openparen
*Description: Prints out comma into the console
************************************************************
print_ARIStart MOVE.B  #14,D0
            LEA     ARIStart,A1     *Loads , to A1
            TRAP    #15             *Print to console
            RTS

************************************************************
*Subroutine print_ARIEnd
*Description: Prints out comma into the console
************************************************************
print_ARIEnd MOVE.B  #14,D0
            LEA     ARIEnd,A1       *Loads , to A1
            TRAP    #15             *Print to console
            RTS
     
************************************************************
*Subroutine print_ARIPostEnd
*Description: Prints out comma into the console
************************************************************
print_ARIPostEnd MOVE.B  #14,D0
            LEA     ARIPostEnd,A1   *Loads , to A1
            TRAP    #15             *Print to console
            RTS
            
************************************************************
*Subroutine print_openparen
*Description: Prints out comma into the console
************************************************************
print_ARIPreStart MOVE.B  #14,D0
            LEA     ARIPreStart,A1  *Loads , to A1
            TRAP    #15             *Print to console
            RTS    
            
************************************************************
*Subroutine print_reg
*Prints out which register it is.
*IMPORTANT: Must move register information to print into
*D5 before calling this method.
************************************************************  
print_reg

print_reg0  CMP.B   #0,D5
            BNE     print_reg1
            LEA     reg0_msg,A1
            BRA     print_it
            
print_reg1  CMP.B   #1,D5
            BNE     print_reg2
            LEA     reg1_msg,A1
            BRA     print_it
            
print_reg2  CMP.B   #2,D5
            BNE     print_reg3
            LEA     reg2_msg,A1
            BRA     print_it
            
print_reg3  CMP.B   #3,D5
            BNE     print_reg4
            LEA     reg3_msg,A1
            BRA     print_it
            
print_reg4  CMP.B   #4,D5
            BNE     print_reg5
            LEA     reg4_msg,A1
            BRA     print_it
            
print_reg5  CMP.B   #5,D5
            BNE     print_reg6
            LEA     reg5_msg,A1
            BRA     print_it
            
print_reg6  CMP.B   #6,D5
            BNE     print_reg7
            LEA     reg6_msg,A1
            BRA     print_it
            
print_reg7  CMP.B   #7,D5
            LEA     reg7_msg,A1
            BRA     print_it     

************************************************************
*Subroutine print_data
*Description: Prints out comma into the console
************************************************************
print_data  MOVE.B  #14,D0
            LEA     DataMsg,A1      *Loads , to A1
            TRAP    #15             *Print to console
            JSR     print_tabs
            JSR     p_space3
            JSR     print_absolute
            MOVE.W  D3,D1
            MOVE.B  #16,D2
            MOVE.B  #15,D0
            TRAP    #15
            *ADD.B   #1,D6
            RTS    

************************************************************
*Subroutine bad_instr
*Description: When we have a bad instruction we print
*Bad Instruction, then move onto the next word
************************************************************
bad_instr   MOVE.B  #14,D0
            LEA     BadCodeMsg,A1
            TRAP    #15
            JMP     BadCodeJump        
            
 
************************************************************
*Subroutine end_prog
*Description: Ask the user if they want to run the
*disassembler again or to exit the program
************************************************************
end_prog    MOVE.B  #14,D0
            LEA     EndingMsg,A1    *Loads , to A1
            TRAP    #15             *Print to console
            MOVE.B  #4,D0
            TRAP    #15             *Load user number from keyboard
            
            CMP.B   #1,D1           *Check if rerun program
            BEQ     RERUN
            
            CMP.B   #0,D1           *Check if ending program
            BEQ     END
            
            
            MOVE.B  #14,D0          *Load trap 14
            LEA     EnderMsg,A1     *Load error msg
            TRAP    #15             *Print error msg
            BRA     end_prog        *Loop to ask for valid input
   
RERUN       JMP     WELCOME 
  
END         BRA     EXIT
*-----------Variables---------------------------------------
StartAdd    DS.B    9
EndAdd      DS.B    9

StartVal    DC.L    4
EndVal      DC.L    0

WelcomeMsg  DC.B    'Hello and welcome to the disassembler made by team RTX3080!',CR,LF
            DC.B    'This program will disassemble a portion of memory.',CR,LF
            DC.B    'Please enter locations in hexadecimal format without $ symbol.',CR,LF,0
Request1    DC.B    'Please enter a starting address between $00000000 and $00FFFFFF:',0
Request2    DC.B    'Please enter an ending address between $',0
Request3    DC.B    ' and $00FFFFFF:',0

NewPageMsg  DC.B    'Press enter to see next page of data.',0

ErrorMsg    DC.B    'Please enter a valid address!',CR,LF,0

DataMsg     DC.B    'Data',0

BadCodeMsg  DC.B    'Invalid Addressing Mode',0

EndingMsg   DC.B    'Type 1 to run program again, 0 to exit (1/0):',0
EndErMsg    DC.B    'Please type a valid command!',0


NewLine     DC.B    '',CR,LF,0
Tab         DC.B    '   ',0
Space1      DC.B    ' ',0
Space2      DC.B    '  ',0
Space3      DC.B    '   ',0
Space4      DC.B    '    ',0
Comma       DC.B    ',',0
Slash       DC.B    '/',0
Wait        DS.B    80

Byte        DC.B    '.B',0
Word        DC.B    '.W',0
Long        DC.B    '.L',0

Filler      DC.B    '',0
An          DC.B    'A',0
Dn          DC.B    'D',0
ARIStart    DC.B    '(A',0
ARIEnd      DC.B    ')',0
ARIPostEnd  DC.B    ')+',0
ARIPreStart DC.B    '-(A',0
Hash        DC.B    '#',0
Immediate   DC.B    '#$',0
Absolute    DC.B    '$',0

NOPmsg      DC.B    'NOP',0
MOVEmsg     DC.B    'MOVE',0
MOVEAmsg    DC.B    'MOVEA',0
ADDmsg      DC.B    'ADD',0
ADDAmsg     DC.B    'ADDA',0
ANDmsg      DC.B    'AND',0
RORmsg      DC.B    'ROR',0
ROLmsg      DC.B    'ROL',0
LSRmsg      DC.B    'LSR',0
LSLmsg      DC.B    'LSL',0
ASRmsg      DC.B    'ASR',0
ASLmsg      DC.B    'ASL',0
MOVEQmsg    DC.B    'MOVEQ',0
MOVEMmsg    DC.B    'MOVEM',0
SUBmsg      DC.B    'SUB',0
ORmsg       DC.B    'OR',0
LEAmsg      DC.B    'LEA',0
JSRmsg      DC.B    'JSR',0
RTSmsg      DC.B    'RTS',0

BRA         DC.B    'BRA',0
BGT         DC.B    'BGT',0
BLE         DC.B    'BLE',0
BEQ         DC.B    'BEQ',0
ADDQ        DC.B    'ADDQ',0
NOT         DC.B    'NOT',0

reg0_msg    DC.B    '0',0
reg1_msg    DC.B    '1',0
reg2_msg    DC.B    '2',0
reg3_msg    DC.B    '3',0
reg4_msg    DC.B    '4',0
reg5_msg    DC.B    '5',0
reg6_msg    DC.B    '6',0
reg7_msg    DC.B    '7',0


            END    START
*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
