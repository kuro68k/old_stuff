#include P18F452.inc
#include macros.inc
#include 16bits.inc
; UNUSABLE pins:
; RA6 - oscillator
; RB5,RB6,RB7 - used for programming the device!








#define PSX_DATA PORTD,RD4
#define PSX_CMD  PORTB,RB0
#define PSX_ATT  PORTD,RD7
#define PSX_CLK  PORTD,RD6
#define PSX_ACK  PORTD,RD5


;-----[ 8 bytes! ]----\
char  IN_Buttons1
char  IN_Buttons2
char  IN_LStickX
char  IN_LStickY
short IN_MouseX_TEMP ;!! these 4 bytes need to be kept temp, to avoid erratic behaviour
short IN_MouseY_TEMP
#define LPT_FRAMESIZE 8 ; 8 bytes
;---------------------/

short MouseX ; !! these 4 bytes are the finalized data ^^, secure to read
short MouseY ; !!! they are global deltas, gradually set to 0 by Mouse_Calculate

char RStickX
char RStickY


char IN_BYTESLEFT


char OUT_TEMP1 ; used to store the currently-sent byte
char OUT_BITSLEFT
char OUT_BYTESLEFT




char W_TEMP
char STATUS_TEMP

	org 0
	goto start
	org 8
OnLPTInterrupt:
	;-----[ read byte ]-----------------------\
	movff PORTC,POSTINC0
	bcf INTCON3,INT1IF  ; clear interrupt flag
	decfsz IN_BYTESLEFT
	retfie
	;-----------------------------------------/
	movwf W_TEMP
	movff STATUS,STATUS_TEMP
	mov IN_BYTESLEFT,LPT_FRAMESIZE
	LFSR FSR0,IN_Buttons1
	;----[ do finalization on received frame !!! ]---------------------\
	ADD16 MouseX,IN_MouseX_TEMP
	ADD16 MouseY,IN_MouseY_TEMP
	;------------------------------------------------------------------/
	movf  W_TEMP,W
	movff STATUS_TEMP,STATUS
	retfie
	
	
	
	
	
INT_OFF macro
	bcf INTCON,GIE  ; disable interrupts
endm
INT_ON macro 
	bsf INTCON,GIE  ; enable interrupts
endm
		

LPT_INIT:
	mov PORTC,0
	mov TRISC,0xFF
	
	LFSR FSR0,IN_Buttons1
	mov IN_BYTESLEFT,LPT_FRAMESIZE
	;--[ interrupt on RB1 ]-------------------\
	SetPinAsInput _RB1
	bcf INTCON2,INTEDG1 ; falling edge
	bsf INTCON3,INT1IE  ; enable interrupt
	bcf INTCON2,RBPU
	bcf INTCON3,INT1IF  ; clear interrupt flag
	bsf INTCON,PEIE
	bsf INTCON,GIE
	;-----------------------------------------/	
	
	return	
	
	
	
	
	
#include SleepMS.inc







PSX_INIT:
	;-----[ init PSX pins ]-------[
	ifdef PSX_GND
		SetPin PSX_GND,0
		SetPinAsOutput PSX_GND
	endif
	SetPin PSX_DATA,1
	SetPin PSX_ACK,1
	SetPin LATC,2,0
	SetPinAsOutput PSX_DATA
	SetPinAsOutput PSX_ACK
	
	SetPinAsInput PSX_CMD
	SetPinAsInput PSX_ATT
	SetPinAsInput PSX_CLK
	;-----------------------------/
		
	return



invokeVarInvert macro What,Var
	movfw Var
	xorlw 255
	rcall What
endm

rxtx_SendBit macro BitID ; used only in rxtx() 
	WaitLowPin PSX_CLK
	BitCopy WREG,BitID,PSX_DATA
	WaitHighPin PSX_CLK
endm


;----[ rxtxNormal ]---------------------------------------[
rxtxNormal:  ; sends a byte and ACK
	char rxtxNormal_data
	INT_OFF
	movwf rxtxNormal_data
	;---[ send ACK ]---------\
	WaitXMicrosecs 8
	SetPin PSX_ACK,0
	
	WaitXMicrosecs 3
	SetPin PSX_ACK,1
	;------------------------/
	
	movf rxtxNormal_data,W
	; !! continues onto rxtx
;---------------------------------------------------------/

;=========[ subroutine rxtx . ]========================================================[
rxtx:  ; this does not send ACK !!
	INT_OFF
	rxtx_SendBit 0
	rxtx_SendBit 1
	rxtx_SendBit 2
	rxtx_SendBit 3
	rxtx_SendBit 4
	rxtx_SendBit 5
	rxtx_SendBit 6
	rxtx_SendBit 7
	INT_ON
	return
;=====================================================================================/

;========[ subroutine rxtxSkip ]=========================[
rxtxSkip:
	WaitLowPin PSX_CLK
	WaitHighPin PSX_CLK
	WaitLowPin PSX_CLK
	WaitHighPin PSX_CLK
	WaitLowPin PSX_CLK
	WaitHighPin PSX_CLK
	WaitLowPin PSX_CLK
	WaitHighPin PSX_CLK
	WaitLowPin PSX_CLK
	WaitHighPin PSX_CLK
	WaitLowPin PSX_CLK
	WaitHighPin PSX_CLK
	WaitLowPin PSX_CLK
	WaitHighPin PSX_CLK
	WaitLowPin PSX_CLK
	WaitHighPin PSX_CLK
	return
;========================================================/



Mouse_Calculate:
	short coordX
	short coordY
	
	MOV16 MouseX,coordX
	MOV16 MouseY,coordY
	
	
	;===========[ calculate RStickX ]============\
	btfsc coordX+1,7
	bra xIsNegative
	xIsPositive: ; coordX>=0
		tstfsz coordX+1
		bra xIsPG
		btfsc coordX,7
		bra xIsPG
		; coordX is 0..127 -----\
		movff coordX,RStickX
		clrf  coordX
		bra xIsDone
		;-----------------------/
		xIsPG: ; coordX>127 -------\
		SUBI16 coordX,127
		mov RStickX,127
		bra xIsDone
		;--------------------------/
	xIsNegative: ; coordX<0
		movlw 0xFF
		cpfseq coordX+1
		bra xIsNG
		btfss coordX,7
		bra xIsNG
		;--[ coordX is -128..-1 ]---\
		movff coordX,RStickX
		clrf coordX
		clrf coordX+1
		bra xIsDone
		;---------------------------/
		xIsNG: ; coordX<-128 -----\
		ADDI16 coordX,128
		mov RStickX,-128
		;-------------------------/
			
	xIsDone:
	btg RStickX,7 ; RStickX+=0x80
	;============================================/
	
	;===========[ calculate RStickY ]============\
	btfsc coordY+1,7
	bra yIsNegative
	yIsPositive: ; coordY>=0
		tstfsz coordY+1
		bra yIsPG
		btfsc coordY,7
		bra yIsPG
		; coordY is 0..127 -----\
		movff coordY,RStickY
		clrf  coordY
		bra yIsDone
		;-----------------------/
		yIsPG: ; coordY>127 -------\
		SUBI16 coordY,127
		mov RStickY,127
		bra yIsDone
		;--------------------------/
	yIsNegative: ; coordY<0
		movlw 0xFF
		cpfseq coordY+1
		bra yIsNG
		btfss coordY,7
		bra yIsNG
		;--[ coordY is -128..-1 ]---\
		movff coordY,RStickY
		clrf coordY
		clrf coordY+1
		bra yIsDone
		;---------------------------/
		yIsNG: ; coordY<-128 -----\
		ADDI16 coordY,128
		mov RStickY,-128
		;-------------------------/
			
	yIsDone:
	btg RStickY,7 ; RStickY+=0x80
	;============================================/
	
	
	
	MOV16 coordX,MouseX
	MOV16 coordY,MouseY
	
	
	; -32768 = 8000
	;   -999 = FC19
	;   -129 = FF7F
	;   -128 = FF80
	;      0 = 0000
	;    127 = 007F
	;    129 = 0081
	;    999 = 03E7
	;  32767 = 7FFF
	
	;;  RStickX=low(MouseX)
	;;if(MouseX<-128){
	;;	RStickX= -128;
	;;}else if(MouseX>127){
	;;	RStickX= 127;
	;;}
	
	
	
	
	
	
	
	
	
	return

		

Mouse_Init:
	
	mov IN_Buttons1,1
	mov IN_Buttons2,0
	mov IN_LStickX,0x80
	mov IN_LStickY,0x80
	mov RStickX,0x80
	mov RStickY,0x80
	INIT16 MouseX,0
	INIT16 MouseY,0
	
	
	return

       
start:
	invoke SleepMS,250
	invoke SleepMS,250
	mov TRISC,0
	mov PORTC,0
	
	
	rcall Mouse_Init
	rcall LPT_INIT
	rcall PSX_INIT
	
		
	
	
MainLoop:
	;WaitHighPin PSX_ATT
	;WaitLowPin  PSX_ATT
	WaitLowPin PSX_CLK
	INT_OFF
	rcall rxtxSkip
	INT_ON
	rcall Mouse_Calculate
	invoke rxtxNormal,0x73 ; means "dualshock, 3x2 = 6 bytes"
	invoke rxtxNormal,0x5A ; "ok, I'm sending data over"
	
	
	invokeVarInvert rxtxNormal,IN_Buttons1
	invokeVarInvert rxtxNormal,IN_Buttons2
	
	
	invokeVar rxtxNormal,RStickY
	invokeVar rxtxNormal,RStickX
	invokeVar rxtxNormal,IN_LStickX
	invokeVar rxtxNormal,IN_LStickY
	
	;incf IN_Buttons2 ; let's play :)
	;incf IN_Buttons1
	
	bra MainLoop
	







	
	end