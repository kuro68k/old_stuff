/* USB Retro Controller Adapter
 *
 * Connect retro controllers to USB. Supported:
 * 		- Atari/Commodore style joysticks (up to three buttons)
 *		- Sega Saturn
 *		- Sega Mega Drive
 *		- Sega Master System / SG-1000 Mark III
 *		- Nintendo Famicom (NES)
 *		- Nintendo Super Famicom (SNES)
 *
 * (C) 2008 Paul Qureshi aka MoJo
 * With USB stack code (C) 2003 Ing. Igor Cesko (http://www.cesko.host.sk)
 *
 * Version:		1.0
 * Target:		ATmega8
 * Clock:		12MHz ext. crystal
 * Fuses:		Low 0xd9, High 0xbf
 *				- Ext. Crystal/Res High Freq. Start-up Time: 16k + 64ms
 *				- Brown-out detection enabled
 *				- Brown-out level VCC=2.7V
 *				- Boot Flash size = 1024 words Start address $0c00
 *				SPI enabled
 * Contact:		mojo@world3.net
 *				http://joystick.world3.net
 *
 * History:		V1.0
 *				- All controllers working
 */

.include "m8def.inc"
.equ	UBRR			=UBRRL
.equ	EEAR			=EEARL
.equ	RAMEND128		=96+127

.equ	inputport		=PINB
.equ	outputport		=PORTB
.equ	USBdirection	=DDRB
.equ	DATAplus		=1				;signal D+ on PB1
.equ	DATAminus		=0				;signal D- on PB0
.equ	USBpinmask		=0b11111100		;mask low 2 bit (D+,D-) on PB
.equ	USBpinmaskDplus	=~(1<<DATAplus)	;mask D+ bit on PB
.equ	USBpinmaskDminus=~(1<<DATAminus);mask D- bit on PB

.equ	SOPbyte			=0b10000000		;Start of Packet byte
.equ	DATA0PID		=0b11000011		;PID for DATA0 field
.equ	DATA1PID		=0b01001011		;PID for DATA1 field
.equ	OUTPID			=0b11100001		;PID for OUT field
.equ	INPID			=0b01101001		;PID for IN field
.equ	SOFPID			=0b10100101		;PID for SOF field
.equ	SETUPPID		=0b00101101		;PID for SETUP field
.equ	ACKPID			=0b11010010		;PID for ACK field
.equ	NAKPID			=0b01011010		;PID for NAK field
.equ	STALLPID		=0b00011110		;PID for STALL field
.equ	PREPID			=0b00111100		;PID for FOR field

.equ	nSOPbyte		=0b00000001		;Start of Packet byte - reverse order
.equ	nDATA0PID		=0b11000011		;PID for DATA0 field - reverse order
.equ	nDATA1PID		=0b11010010		;PID for DATA1 field - reverse order
.equ	nOUTPID			=0b10000111		;PID for OUT field - reverse order
.equ	nINPID			=0b10010110		;PID for IN field - reverse order
.equ	nSOFPID			=0b10100101		;PID for SOF field - reverse order
.equ	nSETUPPID		=0b10110100		;PID for SETUP field - reverse order
.equ	nACKPID			=0b01001011		;PID for ACK field - reverse order
.equ	nNAKPID			=0b01011010		;PID for NAK field - reverse order
.equ	nSTALLPID		=0b01111000		;PID for STALL field - reverse order
.equ	nPREPID			=0b00111100		;PID for FOR field - reverse order

.equ	nNRZITokenPID	=~0b10000000	;PID mask for Token packet (IN,OUT,SOF,SETUP) - reverse order NRZI
.equ	nNRZISOPbyte	=~0b10101011	;Start of Packet byte - reverse order NRZI
.equ	nNRZIDATA0PID	=~0b11010111	;PID for DATA0 field - reverse order NRZI
.equ	nNRZIDATA1PID	=~0b11001001	;PID for DATA1 field - reverse order NRZI
.equ	nNRZIOUTPID		=~0b10101111	;PID for OUT field - reverse order NRZI
.equ	nNRZIINPID		=~0b10110001	;PID for IN field - reverse order NRZI
.equ	nNRZISOFPID		=~0b10010011	;PID for SOF field - reverse order NRZI
.equ	nNRZISETUPPID	=~0b10001101	;PID for SETUP field - reverse order NRZI
.equ	nNRZIACKPID		=~0b00100111	;PID for ACK field - reverse order NRZI
.equ	nNRZINAKPID		=~0b00111001	;PID for NAK field - reverse order NRZI
.equ	nNRZISTALLPID	=~0b00000111	;PID for STALL field - reverse order NRZI
.equ	nNRZIPREPID		=~0b01111101	;PID for FOR field - reverse order NRZI
.equ	nNRZIADDR0		=~0b01010101	;Address = 0 - reverse order NRZI

		;status bytes - State
.equ	BaseState						=0
.equ	SetupState						=1
.equ	InState							=2
.equ	OutState						=3
.equ	SOFState						=4
.equ	DataState						=5

		;Flags of action
.equ	DoNone							=0
.equ	DoReceiveOutData				=1
.equ	DoReceiveSetupData				=2
.equ	DoPrepareOutContinuousBuffer	=3
.equ	DoReadySendAnswer				=4
.equ	DoPrepareJoystickAnswer			=5
.equ	DoReadySendJoystickAnswer		=6

		;Joystick flags
.equ	JoystickDataRequest				=1
.equ	JoystickDataRequestBit			=0
.equ	JoystickDataReady				=2
.equ	JoystickDataReadyBit			=1
.equ	JoystickDataProcessing			=4
.equ	JoystickDataProcessingBit		=2
.equ	JoystickLastDataPID				=8
.equ	JoystickLastDataPIDBit			=3
.equ	JoystickReportID				=0b00010000
.equ	JoystickReportIDBit				=4


.equ	CRC16poly						=0b1000000000000101				;CRC16 polynomial

.equ	MAXUSBBYTES						=14								;maximum bytes in USB input message
.equ	NumberOfFirstBits				=10								;how many first bits allowed be longer
.equ	NoFirstBitsTimerOffset			=256-12800*12/1024				;Timeout 12.8ms (12800us) to terminate after firsts bits

.equ	InputBufferBegin				=RAMEND128-127					;compare of receiving shift buffer
.equ	InputShiftBufferBegin			=InputBufferBegin+MAXUSBBYTES	;compare of receiving buffera

.equ	OutputBufferBegin				=RAMEND128-MAXUSBBYTES-2		;compare of transmitting buffer
.equ	AckBufferBegin					=OutputBufferBegin-3			;compare of transmitting buffer Ack
.equ	NakBufferBegin					=AckBufferBegin-3				;compare of transmitting buffer Nak
.equ	ConfigByte						=NakBufferBegin-1				;0=unconfigured state
.equ	AnswerArray						=ConfigByte-8					;8 byte answer array
.equ	JoystickBufferBegin				=AnswerArray - MAXUSBBYTES
.equ	JoyOutputBufferLength 			=JoystickBufferBegin - 1
.equ	JoyOutBitStuffNumber 			=JoyOutputBufferLength - 1
.equ	BkpOutputBufferLength 			=JoyOutBitStuffNumber - 1
.equ	BkpOutBitStuffNumber 			=BkpOutputBufferLength - 1
.equ	JoyVal 							=BkpOutBitStuffNumber - 1


.equ	StackBegin			=JoyVal-1	;low reservoir (stack is big cca 54 byte)

.def	JoystickFlags		=R1			;Endpoint 1 interrupt status flags for joystick reports
.def	backupbitcount		=R2			;backup bitcount register in INT0 disconnected
.def	RAMread				=R3			;if reading from SRAM
.def	backupSREGTimer		=R4			;backup Flag register in Timer interrupt
.def	backupSREG			=R5			;backup Flag register in INT0 interrupt
.def	ACC					=R6			;accumulator
.def	lastBitstufNumber	=R7			;position in bitstuffing
.def	OutBitStuffNumber	=R8			;how many bits to send last byte - bitstuffing
.def	BitStuffInOut		=R9			;if insertion or deleting of bitstuffing
.def	TotalBytesToSend	=R10		;how many bytes to send
.def	TransmitPart		=R11		;order number of transmitting part
.def	InputBufferLength	=R12		;length prepared in input USB buffer
.def	OutputBufferLength	=R13		;length answers prepared in USB buffer
.def	MyUpdatedAddress	=R14		;my USB address for update
.def	MyAddress			=R15		;my USB address


.def	ActionFlag			=R16		;what to do in main program loop
.def	temp3				=R17		;temporary register
.def	temp2				=R18		;temporary register
.def	temp1				=R19		;temporary register
.def	temp0				=R20		;temporary register
.def	bitcount			=R21		;counter of bits in byte
.def	ByteCount			=R22		;counter of maximum number of received bytes
.def	inputbuf			=R23		;receiver register 
.def	shiftbuf			=R24		;shift receiving register 
.def	State				=R25		;state byte of status of state machine
.def	USBBufptrY			=R28		;YL register - pointer to USB buffer input/output
.def	ROMBufptrZ			=R30		;ZL register - pointer to buffer of ROM data

.def	temp4				=R21		;MUST BE RESTORED AFTER USE
.def	temp5				=R22		;shared with bitcount/ByteCount

;requirements on descriptors
.equ	GET_STATUS			=0
.equ	CLEAR_FEATURE		=1
.equ	SET_FEATURE			=3
.equ	SET_ADDRESS			=5
.equ	GET_DESCRIPTOR		=6
.equ	SET_DESCRIPTOR		=7
.equ	GET_CONFIGURATION	=8
.equ	SET_CONFIGURATION	=9
.equ	GET_INTERFACE		=10
.equ	SET_INTERFACE		=11
.equ	SYNCH_FRAME			=12

; Class requests
.equ 	GET_REPORT			=1
.equ 	GET_IDLE			=2
.equ 	GET_PROTOCOL		=3
.equ 	SET_REPORT			=9
.equ 	SET_IDLE			=10
.equ 	SET_PROTOCOL		=11

;Standard descriptor types
.equ	DEVICE				=1
.equ	CONFIGURATION		=2
.equ	STRING				=3
.equ	INTERFACE			=4
.equ	ENDPOINT			=5

; Class Descriptor Types
.equ	CLASS_HID			=0x21
.equ	CLASS_Report		=0x22
.equ	CLASS_Physical		=0x23

;databits
.equ	DataBits5			=0
.equ	DataBits6			=1
.equ	DataBits7			=2
.equ	DataBits8			=3

;parity
.equ	ParityNone			=0
.equ	ParityOdd			=1
.equ	ParityEven			=2
.equ	ParityMark			=3
.equ	ParitySpace			=4

;stopbits
.equ	StopBit1			=0
.equ	StopBit2			=1

;user function start number
.equ	USER_FNC_NUMBER		=100

;------------------------------------------------------------------------------------------
; Controller pin definitions
;------------------------------------------------------------------------------------------

; Famicom pins

.equ	FCLKB	=	3
.equ	FLATB	=	4
.equ	FSERB	=	5

; Mega Drive / Master System control pins

.equ	MSELP	=	2

;------------------------------------------------------------------------------------------
; Interrupt table
;------------------------------------------------------------------------------------------
.cseg

.org 0									;after reset
		rjmp	reset
.org INT0addr							;external interrupt INT0
		rjmp	INT0handler

;------------------------------------------------------------------------------------------
; Startup routine
;------------------------------------------------------------------------------------------
reset:
;set up hardware and data structures
		ldi		temp0,StackBegin		;initialization of stack
		out		SPL,temp0

		clr		XH						;RS232 pointer
		clr		YH						;USB pointer
		clr		ZH						;ROM pointer
		clr		JoystickFlags
		ldi		temp0,JoystickDataReady
		or		JoystickFlags,temp0 


		clr		MyUpdatedAddress		;new address USB -  non-decoded
		rcall	InitACKBufffer			;initialization of ACK buffer
		rcall	InitNAKBufffer			;initialization of NAK buffer
		rcall	InitJoystickBufffer		;initialization of Joystick buffer

		rcall	USBReset				;initialization of USB addresses

		ldi		temp0, 0b00000000		;ADC disable
		out 	ADCSRA,temp0	
		
		ldi		temp0,0b11111011		;set pull-up on PORTD
		out		PORTD,temp0
		ldi		temp0,0b00111111		;set pull-up on PORTC
		out		PORTC,temp0
		ldi		temp0,0b00111100		;set pull-up on PORTB
		out		PORTB,temp0

		ldi		temp0,0b00011000		;set input/output on PORTD
		out		DDRD,temp0
		ldi		temp0,0b11000000		;set inputs on PORTC
		out 	DDRC,temp0
		ldi		temp0,0b00011100		;four input/output on PORTB
		out 	DDRB,temp0

		clr		temp0				
		out		EEARH,temp0				;zero EEPROM index
		
		ldi		temp0,0x0F				;INT0 - respond to leading edge
		out		MCUCR,temp0			
		ldi		temp0,1<<INT0			;enable external interrupt INT0
		out		GIMSK,temp0

		rcall	USB_Reset

;------------------------------------------------------------------------------------------
; Start of mainprogram
;------------------------------------------------------------------------------------------

		sei								;enable interrupts globally
Main:
		sbis	inputport,DATAminus		;waiting till change D- to 0
		rjmp	CheckUSBReset			;and check, if isn't USB reset

		cpi		ActionFlag,DoReceiveSetupData
		breq	ProcReceiveSetupData
		cpi		ActionFlag,DoPrepareOutContinuousBuffer
		breq	ProcPrepareOutContinuousBuffer
		sbrc	JoystickFlags,JoystickDataRequestBit
		rjmp	ProcJoystickRequest
		rjmp	Main

CheckUSBReset:
		ldi		temp0,255				;counter duration of reset (according to specification is that cca 10ms - here is cca 100us)
WaitForUSBReset:
		sbic	inputport,DATAminus		;waiting till change D+ to 0
		rjmp	Main
		dec		temp0
		brne	WaitForUSBReset
		rcall	USBReset
		rjmp	Main

ProcPrepareOutContinuousBuffer:
		rcall	PrepareOutContinuousBuffer	;prepare next sequence of answer to buffer
		ldi		ActionFlag,DoReadySendAnswer
		rjmp	Main
ProcReceiveSetupData:
		ldi		USBBufptrY,InputBufferBegin	;pointer to begin of receiving buffer
		mov		ByteCount,InputBufferLength	;length of input buffer
		rcall	DecodeNRZI					;transfer NRZI coding to bits
		rcall	MirrorInBufferBytes			;invert bits order in bytes
		rcall	BitStuff					;removal of bitstuffing
		rcall	PrepareUSBOutAnswer			;prepare answers to transmitting buffer
		ldi		ActionFlag,DoReadySendAnswer
		rjmp	Main

;------------------------------------------------------------------------------------------
; USB Reset
;------------------------------------------------------------------------------------------

USB_Reset:
		ldi		temp0, 0b00000011		;USB as output
		out 	DDRB, temp0

		cbi		outputport, DATAminus

		ldi		temp0, 255
reset_loop_1:
		ldi		temp1, 255
reset_loop_2:
		dec		temp1
		brne	reset_loop_2
		dec		temp0
		brne	reset_loop_1

		ldi		temp0, 0b00000000		;USB as input
		out 	DDRB, temp0

		ret

;------------------------------------------------------------------------------------------
; Famicom reading subtroutine code
;------------------------------------------------------------------------------------------

famidelay:
;at 12 Mhz, 1us = 12 cycles
;Famicom uses old TTL logic so needs to be ready very slowly
		ldi 	temp5, 30			;3 cycles to execute loop
famidelay_loop:
		dec 	temp5
		brne 	famidelay_loop
		ret

readfami:
;read 8 bits of serial data from Famicom controller
		sbi		PORTB, FCLKB		;hold clock high

		sbi		PORTB, FLATB		;latch data in
		rcall	famidelay
		rcall	famidelay
		cbi		PORTB, FLATB
		rcall	famidelay
		
		clr		temp0				;serial byte
		ldi		temp4, 8			;read 8 bits

famicom_ser_1:
		in		temp3, PINB			;read a bit
		lsr		temp0
		sbrs	temp3, FSERB
		ori		temp0, 0b10000000

		cbi		PORTB, FCLKB		;toggle clock line
		rcall	famidelay
		sbi		PORTB, FCLKB
		rcall	famidelay
		
		dec		temp4
		brne	famicom_ser_1
		
		ret

readsuperfami:
;read the next 8 bits for the Super Famicom
		clr		temp0
		ldi		temp4, 8
super_ser_1:
		in		temp3, PINB			;read a bit
		lsr		temp0
		sbrs	temp3, FSERB
		ori		temp0, 0b10000000

		cbi		PORTB, FCLKB		;toggle clock line
		rcall	famidelay
		sbi		PORTB, FCLKB
		rcall	famidelay
		
		dec		temp4
		brne	super_ser_1
		
		ret

;------------------------------------------------------------------------------------------
; Controller decoding
;------------------------------------------------------------------------------------------

ProcJoystickRequest:
		ldi		temp0,0xFF
		andi	temp0,~JoystickDataReady
		andi	temp0,~JoystickDataRequest ;clear request flag to avoid call on next cycle
		and		JoystickFlags,temp0 


; ******************* Directional switches *******************

; Atari / Commodore / Mega Drive

		sbi		PORTB, MSELP		;Mega Drive select to high for reading directions
		nop							;should stay high but the USB code seems to be
		nop							;driving it low occasionally

		in		temp0, PINC			;read joystick direction pins

		lds 	temp1, JoystickBufferBegin+2	;X
		lds 	temp2, JoystickBufferBegin+3	;Y

		ldi		temp1, 0			;centre
		ldi		temp2, 0

		sbrs	temp0,	0			;Up
		ldi		temp2, -127
		sbrs	temp0,	1			;Down
		ldi		temp2, 127
		sbrs	temp0,	2			;Left
		ldi		temp1, -127
		sbrs	temp0,	3			;Right
		ldi		temp1, 127

; Mega Drive

; Sega Saturn

		in		temp0, PIND			;Up Dn Lt Rt
		sbrs	temp0, 1
		ldi		temp2, -127			;Up
		sbrs	temp0, 0
		ldi		temp2, 127			;Down
		sbrs	temp0, 6
		ldi		temp1, -127			;Left
		sbrs	temp0, 5
		ldi		temp1, 126			;Right

		sts		JoystickBufferBegin+2, temp1	;x
		sts		JoystickBufferBegin+3, temp2	;y



; ******************* Fire buttons *******************

; Atari / Commodore

		ldi		temp1, 0			;all buttons off
		ldi		temp2, 0

		in		temp0, PINC
		sbrs	temp0, 4			;fire 1
		ori		temp1, 0b00000001
		sbrs	temp0, 5			;fire 2
		ori		temp1, 0b00000010
		in		temp0, PIND			;fire 3 on port D
		sbrs	temp0, 7			;fire 3
		ori		temp1, 0b00000100

; Mega Drive

		cbi		PORTB, MSELP		;Select low
		nop
		nop
		in		temp0, PINC
		sbi		PORTB, MSELP		;Select high again in case it is needed for +5V

		;detect Mega Drive pad
		mov		temp3, temp0
		ori		temp3, 0b11110011	;mask left and right bits
		cpi		temp3, 0b11110011	;both low
		brne	not_mega

		;decode Mega Drive fire buttons
		;already decoded:	B - fire 1
		;					C - fire 2
		lsl		temp1				;remap B and C to fire 2 and 3
		sbrs	temp0, 4			;button A
		ori		temp1, 0b000000001	;map to fire 1
		sbrs	temp0, 5			;Start
		ori		temp2, 0b000000001	;map to fire 9

not_mega:

; Sega Saturn

		;port d:
		;0 D1
		;1 D0
		;3 S0
		;4 S1
		;5 D3
		;6 D2

		ldi		temp3, 0b11101011	;S0=On S1=Off
		out		PORTD, temp3

		nop							;wait for the 75153
		nop

		in		temp0, PIND			;B C A St
		sbrs	temp0, 1
		ori		temp1, 0b00000010	;fire 2/B
		sbrs	temp0, 0
		ori		temp1, 0b00000100	;fire 3/C
		sbrs	temp0, 6
		ori		temp1, 0b00000001	;fire 1/A
		sbrs	temp0, 5
		ori		temp2, 0b00000001	;fire 9/Start

		ldi		temp3, 0b11100011	;S0=Off S1=Off
		out		PORTD, temp3

		nop							;wait for the 75153
		nop

		in		temp0, PIND			;Z Y X R
		sbrs	temp0, 1
		ori		temp1, 0b00100000	;fire 6/Z
		sbrs	temp0, 0
		ori		temp1, 0b00010000	;fire 5/Y
		sbrs	temp0, 6
		ori		temp1, 0b00001000	;fire 4/X
		sbrs	temp0, 5
		ori		temp1, 0b10000000	;fire 8/R

		ldi		temp3, 0b11111011	;S0=1 S1=1
		out		PORTD, temp3

		nop							;wait for the 75153
		nop

		in		temp0, PIND			;B C A St
		sbrs	temp0, 5
		ori		temp1, 0b01000000	;fire 7/L

		ldi		temp3, 0b11110011
		out		PORTD, temp3

; ******************* Famicom / Super Famicom *******************

		push	temp4				;must be saved before use
		push	temp5

		;load first 8 bits of serial data
		rcall	readfami

		lds		temp4, JoystickBufferBegin+2	;X
		lds		temp5, JoystickBufferBegin+3	;Y

		;decode bits
		sbrc	temp0, 0
		ori		temp1, 0b00000001	;fire 1/A/B
		sbrc	temp0, 1
		ori		temp1, 0b00000010	;fire 2/B/Y
		sbrc	temp0, 2
		ori		temp2, 0b00000010	;fire 10/Select
		sbrc	temp0, 3
		ori		temp2, 0b00000001	;fire 9/Start

		sbrc	temp0, 4
		ldi		temp5, -127			;up
		sbrc	temp0, 5
		ldi		temp5, 127			;down
		sbrc	temp0, 6
		ldi		temp4, -127			;left
		sbrc	temp0, 7
		ldi		temp4, 127			;right

		sts		JoystickBufferBegin+2, temp4	;x
		sts		JoystickBufferBegin+3, temp5	;y

		;load extended Super Famicom 8 bits
		rcall	readsuperfami

		;the Super Famicom sets bits 13-16 high for detection
		cpi		temp0, 0x10
		brsh	famicom_only

		;decode bits
		sbrc	temp0, 0
		ori		temp1, 0b00000100	;fire 3/NC/A
		sbrc	temp0, 1
		ori		temp1, 0b00001000	;fire 4/NC/X
		sbrc	temp0, 2
		ori		temp1, 0b00010000	;fire 5/NC/L
		sbrc	temp0, 3
		ori		temp1, 0b00100000	;fire 6/NC/R

famicom_only:
		sts		JoystickBufferBegin+4, temp1	;fire 1-8
		sts		JoystickBufferBegin+5, temp2	;fire 9-10

		pop		temp5
		pop		temp4


;------------------------------------------------------------------------------------------
; End of controller decoding
;------------------------------------------------------------------------------------------


SendJoystickReport:
;simulate call to AddCRCOut
;simply push point of return onto stack
		ldi		temp0, low(AddCRCOutReturn)	;ROMpointer to descriptor
		push	temp0
		ldi		temp0,  high(AddCRCOutReturn)
		push	temp0
		
		
		ldi	USBBufptrY,JoystickBufferBegin

		ldi		temp3,JoystickReport1Size	;Joystick report size
		ldi		ByteCount,2					;length of output buffer (only SOP and PID)
		add		ByteCount,temp3				;+ number of bytes
		push	USBBufptrY
		push	ByteCount
		rjmp	AddCRCOut_2					;addition of CRC to buffer

AddCRCOutReturn:	
		inc		ByteCount					;length of output buffer + CRC16
		inc		ByteCount


		;Backup Control pipe buffer pointers to save Control pipe state
		mov		temp0, OutputBufferLength
		sts 	BkpOutputBufferLength,temp0
		mov 	temp0, OutBitStuffNumber
		sts 	BkpOutBitStuffNumber,temp0


		inc		BitStuffInOut					;transmitting buffer - insertion of bitstuff bits
		ldi		USBBufptrY,JoystickBufferBegin	;to transmitting buffer
		rcall	BitStuff
		clr		BitStuffInOut					;receiving buffer - deletion of bitstuff bits


		;copy to Joystick buffer
		sts 	JoyOutputBufferLength, ByteCount
		sts 	JoyOutBitStuffNumber, OutBitStuffNumber


		;Restore Control pipe buffer pointers
		lds		temp0, BkpOutputBufferLength
		mov		OutputBufferLength, temp0
		lds		temp0, BkpOutBitStuffNumber
		mov		OutBitStuffNumber,temp0

		;set joystick data ready flag
		ldi		temp0,JoystickDataReady
		or		JoystickFlags,temp0 

		rjmp	Main

;------------------------------------------------------------------------------------------
; End of main program
;------------------------------------------------------------------------------------------


;------------------------------------------------------------------------------------------
; Interrupt 0 handler
;------------------------------------------------------------------------------------------
INT0Handler:						;prerusenie INT0
		in		backupSREG,SREG
		push	temp0
		push	temp1

		ldi		temp0,3				;pocitadlo trvania log0
		ldi		temp1,2				;pocitadlo trvania log1
DetectSOPEnd:
		sbic	inputport,DATAminus
		rjmp	Increment0			;D+ =0
Increment1:
		ldi		temp0,3				;pocitadlo trvania log0
		dec		temp1				;kolko cyklov trvala log1
		nop
		breq	USBBeginPacket		;ak je to koniec SOP - prijimaj paket
		rjmp	DetectSOPEnd
Increment0:
		ldi		temp1,2				;pocitadlo trvania log1
		dec		temp0				;kolko cyklov trvala log0
		nop
		brne	DetectSOPEnd		;ak nenastal SOF - pokracuj
		rjmp	EndInt0HandlerPOP2
EndInt0Handler:
		pop		ACC
		pop		R26
		pop		temp3
		pop		temp2
EndInt0HandlerPOP:
		pop		USBBufptrY
		pop		ByteCount
		mov		bitcount,backupbitcount	;obnova bitcount registra
EndInt0HandlerPOP2:
		pop		temp1
		pop		temp0
		out		SREG,backupSREG
		ldi		shiftbuf,1<<INTF0		;clear interrupt flag INTF0
		out		GIFR,shiftbuf
		reti							;inak skonci (bol iba SOF - kazdu milisekundu)

USBBeginPacket:
		mov		backupbitcount,bitcount				;zaloha bitcount registra
		in		shiftbuf,inputport					;ak ano nacitaj ho ako nulty bit priamo do shift registra
USBloopBegin:
		push	ByteCount							;dalsia zaloha registrov (setrenie casu)
		push	USBBufptrY
		ldi		bitcount,6							;inicializacia pocitadla bitov v bajte
		ldi		ByteCount,MAXUSBBYTES				;inicializacia max poctu prijatych bajtov v pakete
		ldi		USBBufptrY,InputShiftBufferBegin	;nastav vstupny buffer
USBloop1_6:
		in		inputbuf,inputport
		cbr		inputbuf,USBpinmask		;odmaskovat spodne 2 bity
		breq	USBloopEnd				;ak su nulove - koniec USB packetu
		ror		inputbuf				;presun Data+ do shift registra
		rol		shiftbuf
		dec		bitcount				;zmensi pocitadlo bitov
		brne	USBloop1_6				;ak nie je nulove - opakuj naplnanie shift registra
		nop								;inak bude nutne skopirovat shift register bo buffera
USBloop7:
		in		inputbuf,inputport
		cbr		inputbuf,USBpinmask		;odmaskovat spodne 2 bity
		breq	USBloopEnd				;ak su nulove - koniec USB packetu
		ror		inputbuf				;presun Data+ do shift registra
		rol		shiftbuf
		ldi		bitcount,7				;inicializacia pocitadla bitov v bajte
		st		Y+,shiftbuf				;skopiruj shift register bo buffera a zvys pointer do buffera
USBloop0:								;a zacni prijimat dalsi bajt
		in		shiftbuf,inputport		;nulty bit priamo do shift registra
		cbr		shiftbuf,USBpinmask		;odmaskovat spodne 2 bity
		breq	USBloopEnd				;ak su nulove - koniec USB packetu
		dec		bitcount				;zmensi pocitadlo bitov
		nop								;
		dec		ByteCount				;ak sa nedosiahol maximum buffera
		brne	USBloop1_6				;tak prijimaj dalej

		rjmp	EndInt0HandlerPOP		;inak opakuj od zaciatku

USBloopEnd:
		cpi		USBBufptrY,InputShiftBufferBegin+3	;ak sa neprijali aspon 3 byte
		brcs	EndInt0HandlerPOP					;tak skonci
		lds		temp0,InputShiftBufferBegin+0		;identifikator paketu do temp0
		lds		temp1,InputShiftBufferBegin+1		;adresa do temp1
		brne	TestDataPacket						;ak je dlzka ina ako 3 - tak to moze byt iba DataPaket
TestIOPacket:
	
		andi	temp1,0xFE				;MMM mask out bit 0 of address to avoid conflict with endpoint 1
	
		cp		temp1,MyAddress			;if this isn't assigned (address) for me 
		brne	TestDataPacket			;then this can be still DataPacket
TestSetupPacket:
;test to SETUP packet
		cpi		temp0,nNRZISETUPPID
		brne	TestOutPacket			;if this isn't Setup PID - decode other packet
		ldi		State,SetupState
		rjmp	EndInt0HandlerPOP		;if this is Setup PID - receive consecutive Data packet
TestOutPacket:
;test for OUT packet
		cpi		temp0,nNRZIOUTPID
		brne	TestInPacket			;if this isn't Out PID - decode other packet
		ldi		State,OutState
		rjmp	EndInt0HandlerPOP		;if this is Out PID - receive consecutive Data packet
TestInPacket:
;test on IN packet
		cpi		temp0,nNRZIINPID
		brne	TestDataPacket			;if this isn't In PID - decode other packet
		rjmp	AnswerToInRequest
TestDataPacket:
;test for DATA0 and DATA1 packet
		cpi		temp0,nNRZIDATA0PID
		breq	Data0Packet				;if this isn't Data0 PID - decode other packet
		cpi		temp0,nNRZIDATA1PID
		brne	NoMyPacked				;if this isn't Data1 PID - decode other packet
Data0Packet:
		cpi		State,SetupState		;if was state Setup
		breq	ReceiveSetupData		;receive it
		cpi		State,OutState			;if was state Out
		breq	ReceiveOutData			;receive it
NoMyPacked:
		ldi		State,BaseState			;zero state
		rjmp	EndInt0HandlerPOP		;and receive consecutive Data packet

AnswerToInRequest:
		push	temp2					;backup next registers and continue
		push	temp3
		push	R26
		push	ACC


;this might be Endpoint1 interrupt query
		lds		temp1,InputShiftBufferBegin+1		;address to temp1
		lds		temp2,InputShiftBufferBegin+2		;endpoint and CRC to temp2
		
		ror		temp1 								;move bit 0 to carry
		ror		temp2 								;bring bit 7 to carry
		swap	temp2
		sbrs	temp1, 0							;check bit 1 (6) of address
		rjmp	AddrBit6Zero
		com		temp2
AddrBit6Zero:
		andi	temp2, 0x0F
		cpi		temp2, 0x0A
		breq	ProcessEndpoint0
		cpi		temp2, 0x05
		breq	ProcessEndpoint1
		rjmp 	EndInt0Handler


ProcessEndpoint0:
		cpi		ActionFlag,DoReadySendAnswer		;if isn't prepared answer
		brne	NoReadySend							;then send NAK
		rcall	SendPreparedUSBAnswer				;transmitting answer back
		and		MyUpdatedAddress,MyUpdatedAddress	;if is MyUpdatedAddress nonzero
		brne	SetMyNewUSBAddress_2				;then is necessary to change USB address
		ldi		State,InState
		ldi		ActionFlag,DoPrepareOutContinuousBuffer
		rjmp	EndInt0Handler						;and repeat - wait for next response from USB
ReceiveSetupData:
		push	temp2								;backup next registers and continue
		push	temp3
		push	R26
		push	ACC
		rcall	SendACK								;accept Setup Data packet
		rcall	FinishReceiving						;finish receiving
		ldi		ActionFlag,DoReceiveSetupData
		rjmp	EndInt0Handler
ReceiveOutData:
		push	temp2								;backup next registers and continue
		push	temp3
		push	R26
		push	ACC
		cpi		ActionFlag,DoReceiveSetupData		;if is currently in process command Setup
		breq	NoReadySend							;then send NAK
		rcall	SendACK								;accept Out packet
		clr		ActionFlag
		rjmp	EndInt0Handler
NoReadySend:
		rcall	SendNAK								;still I am not ready to answer
		rjmp	EndInt0Handler						;and repeat - wait for next response from USB

SetMyNewUSBAddress_2:
		rjmp SetMyNewUSBAddress


;------------------------------------------------------------------------------------------
; Endpoint 1
;------------------------------------------------------------------------------------------

ProcessEndpoint1:
;on Endpoint1 In we have interrupt handler which is sending reports of joystick data

		;Check if we have joystick data ready
		sbrs	JoystickFlags, JoystickDataReadyBit
		rjmp	NoJoystickDataReady

		;Backup Control pipe buffer pointers to save Control pipe state
		mov		temp0, OutputBufferLength
		sts 	BkpOutputBufferLength,temp0

		mov 	temp0, OutBitStuffNumber
		sts 	BkpOutBitStuffNumber,temp0

		;Retrieve Joystick buffer parameters
		lds 	temp0,JoyOutBitStuffNumber
		mov 	OutBitStuffNumber, temp0

		lds		ByteCount,JoyOutputBufferLength		;length of answer
		ldi		USBBufptrY,JoystickBufferBegin		;pointer to begin of transmitting buffer
		rcall	SendUSBBuffer	


		;Restore Control pipe buffer pointers
		lds		temp0, BkpOutputBufferLength
		mov		OutputBufferLength, temp0
		lds		temp0, BkpOutBitStuffNumber
		mov		 OutBitStuffNumber,temp0

		;flip data PID
		lds		temp0, JoystickBufferBegin + 1
		cpi		temp0, DATA0PID
		breq	FlipToDATA1PID
		ldi		temp0, DATA0PID
		rjmp	FlipDone
FlipToDATA1PID:
		ldi		temp0, DATA1PID
FlipDone:
		sts		JoystickBufferBegin + 1,temp0

		ldi		temp0,JoystickDataRequest
		or		JoystickFlags,temp0 				;JoystickDataRequest	; request new joystick data

		rjmp	EndInt0Handler						;and complete

NoJoystickDataReady:
  	  	rjmp	EndInt0Handler						;and repeat - wait for next response from USB

;------------------------------------------------------------------------------------------
; Endpoint 1 code end
;------------------------------------------------------------------------------------------

;------------------------------------------------------------------------------------------
SetMyNewUSBAddress:									;set new USB address in NRZI coded
		clr		MyAddress							;original answer state - of my nNRZI USB address
		ldi		temp2,0b00000001					;mask for xoring
		ldi		temp3,8								;bits counter
SetMyNewUSBAddressLoop:
		mov		temp0,MyAddress						;remember final answer
		ror		MyUpdatedAddress					;to carry transmitting bit LSB (in direction firstly LSB then MSB)
		brcs	NoXORBit							;if one - don't change state
		eor		temp0,temp2							;otherwise state will be changed according to last bit of answer
NoXORBit:
		ror		temp0								;last bit of changed answer to carry
		rol		MyAddress							;and from carry to final answer to the LSB place (and reverse LSB and MSB order)
		dec		temp3								;decrement bits counter
		brne	SetMyNewUSBAddressLoop				;if bits counter isn't zero repeat transmitting with next bit
		clr		MyUpdatedAddress					;zero addresses as flag of its next unchanging
		
		;mask out bit 0 to avoid conflict with endpoints
		mov		temp2, MyAddress
		andi	temp2,0xFE
		mov		MyAddress, temp2

		rjmp	EndInt0Handler
;------------------------------------------------------------------------------------------
FinishReceiving:									;corrective actions for receive termination
		cpi		bitcount,7							;transfer to buffer also last not completed byte
		breq	NoRemainingBits						;if were all bytes transfered, then nothing transfer
		inc		bitcount
ShiftRemainingBits:
		rol		shiftbuf							;shift remaining not completed bits on right position
		dec		bitcount
		brne	ShiftRemainingBits
		st		Y+,shiftbuf							;and copy shift register bo buffer - not completed byte
NoRemainingBits:
		mov	ByteCount,USBBufptrY
		subi	ByteCount,InputShiftBufferBegin-1	;in ByteCount is number of received bytes (including not completed bytes)

		mov	InputBufferLength,ByteCount				;and save for use in main program
		ldi	USBBufptrY,InputShiftBufferBegin		;pointer to begin of receiving shift buffer
		ldi	R26,InputBufferBegin+1					;data buffer (leave out SOP)
		push	XH									;save RS232BufptrX Hi index
		clr	XH
MoveDataBuffer:
		ld	temp0,Y+
		st	X+,temp0
		dec	ByteCount
		brne	MoveDataBuffer

		pop	XH										;restore RS232BufptrX Hi index
		ldi	ByteCount,nNRZISOPbyte
		sts	InputBufferBegin,ByteCount				;like received SOP - it is not copied from shift buffer

		ret


;------------------------------------------------------------------------------------------
; Other code
;------------------------------------------------------------------------------------------
USBReset:
;iinitialization of USB state engine
		ldi		temp0,nNRZIADDR0					;initialization of USB address
		mov		MyAddress,temp0
		clr		State								;initialization of state engine
		clr		BitStuffInOut
		clr		OutBitStuffNumber
		clr		ActionFlag
		clr		RAMread								;will be reading from ROM
		sts		ConfigByte,RAMread					;unconfigured state
		ret
;------------------------------------------------------------------------------------------
SendPreparedUSBAnswer:
;poslanie kodovanim NRZI OUT buffer s dlzkou OutputBufferLength do USB
		mov		ByteCount,OutputBufferLength		;dlzka odpovede
SendUSBAnswer:
;poslanie kodovanim NRZI OUT buffer do USB
		ldi		USBBufptrY,OutputBufferBegin		;pointer na zaciatok vysielacieho buffera
SendUSBBuffer:
;poslanie kodovanim NRZI dany buffer do USB
		mov		temp3,ByteCount						;pocitadlo bytov: temp3 = ByteCount
		ld		inputbuf,Y+							;nacitanie prveho bytu do inputbuf a zvys pointer do buffera
		
		;USB ako vystup:
		in  	temp1, USBdirection
		ori 	temp1, ((1<<Dataminus)|(1<<Dataplus))
		mov 	temp2, temp1

		in		temp0, outputport					;******01   kludovy stav portu USB do temp0
		cbr		temp0, (1<<DATAminus)				; 
		ori		temp0, (1<<DATAplus)

		ldi		bitcount,6							;pocitadlo bitov

		ror		inputbuf							;do carry vysielany bit (v smere naskor LSB a potom MSB)
		out		outputport,temp0					;vysli von na USB
		out		USBdirection, temp1					;1 		nahodenie DATAminus : kludovy stav portu USB;
		ldi 	temp1, 0							;2	
		rjmp 	SendUSBAnswerByteLoop				;3,4


SendUSBAnswerLoop:
		ldi		bitcount,7							;4 		pocitadlo bitov
SendUSBAnswerByteLoop:
		nop											;5		oneskorenie kvoli casovaniu
		ror		inputbuf							;6		do carry vysielany bit (v smere naskor LSB a potom MSB)
		brcs	NoXORSend							;7		ak je jedna - nemen stav na USB
		eor		temp0,temp2							;8		inak sa bude stav menit
NoXORSend:
		out		outputport,temp0					;9 		vysli von na USB
		dec		bitcount							; 		zmensi pocitadlo bitov - podla carry flagu
		brne	SendUSBAnswerByteLoop	 			;ak pocitadlo bitov nie je nulove - opakuj vysielanie s dalsim bitom
		sbrs	inputbuf,0							;	 	ak je vysielany bit jedna - nemen stav na USB
		eor		temp0,temp2							;inak sa bude stav menit
NoXORSendLSB:
		dec		temp3								;zniz pocitadlo bytov
		ld		inputbuf,Y+							;nacitanie dalsieho bytu a zvys pointer do buffera
		out		outputport,temp0					;vysli von na USB
		brne	SendUSBAnswerLoop					;opakuj pre cely buffer (pokial temp3=0)

		mov		bitcount,OutBitStuffNumber			;pocitadlo bitov pre bitstuff
		cpi		bitcount,0							;ak nie je potrebny bitstuff
		breq	ZeroBitStuf
SendUSBAnswerBitstuffLoop:
		ror		inputbuf							;do carry vysielany bit (v smere naskor LSB a potom MSB)
		brcs	NoXORBitstuffSend					;ak je jedna - nemen stav na USB
		eor		temp0,temp2							;inak sa bude stav menit
NoXORBitstuffSend:
		out		outputport,temp0					;vysli von na USB
		nop											;oneskorenie kvoli casovaniu
		dec		bitcount							;zmensi pocitadlo bitov - podla carry flagu
		brne	SendUSBAnswerBitstuffLoop			;ak pocitadlo bitov nie je nulove - opakuj vysielanie s dalsim bitom
		ld		inputbuf,Y							;oneskorenie 2 cykly
ZeroBitStuf:
		nop											;oneskorenie 1 cyklus
		cbr		temp0,3
		out		outputport,temp0					; 1,   vysli EOP na USB

		ldi		bitcount,5							; 2,   pocitadlo oneskorenia: EOP ma trvat 2 bity (16 cyklov pri 12MHz)
SendUSBWaitEOP:
		dec		bitcount							; 3-6-09-12-15
		brne	SendUSBWaitEOP  					; 4-7-10-13-16 

		sbi		outputport,DATAminus				; 17,18   nahodenie DATAminus : kludovy stav na port USB
		cbi		USBdirection,DATAminus				; 19,20		  DATAminus ako vstupny
		cbi		USBdirection,DATAplus				; 23,24   	  DATAplus ako vstupny
		ret
;------------------------------------------------------------------------------------------
ToggleDATAPID:
		lds		temp0,OutputBufferBegin+1			;load last PID
		cpi		temp0,DATA1PID						;if last was DATA1PID byte
		ldi		temp0,DATA0PID
		breq	SendData0PID						;then send zero answer with DATA0PID
		ldi		temp0,DATA1PID						;otherwise send zero answer with DATA1PID
SendData0PID:
		sts		OutputBufferBegin+1,temp0			;DATA0PID byte
		ret
;------------------------------------------------------------------------------------------
ComposeZeroDATA1PIDAnswer:
		ldi		temp0,DATA0PID						;DATA0 PID - in the next will be toggled to DATA1PID in load descriptor
		sts		OutputBufferBegin+1,temp0			;load to output buffer
ComposeZeroAnswer:
		ldi		temp0,SOPbyte
		sts		OutputBufferBegin+0,temp0			;SOP byte
		rcall	ToggleDATAPID						;change DATAPID
		ldi		temp0,0x00
		sts		OutputBufferBegin+2,temp0			;CRC byte
		sts		OutputBufferBegin+3,temp0			;CRC byte
		ldi		ByteCount,2+2						;length of output buffer (SOP and PID + CRC16)
		ret
;------------------------------------------------------------------------------------------

;------------------------------------------------------------------------------------------
InitJoystickBufffer:

		ldi		temp0,JoystickReport1Size			;number of my bytes answers to temp0

		mov 	TotalBytesToSend, temp0

		ldi		temp0,SOPbyte
		sts		OutputBufferBegin+0,temp0			;SOP byte
		ldi		temp0,DATA0PID
		sts		OutputBufferBegin+1,temp0			;DATA0PID byte


		mov		temp3,TotalBytesToSend				;otherwise send only given number of bytes
		mov		ByteCount,TotalBytesToSend;

		ldi		USBBufptrY,OutputBufferBegin+2		;to transmitting buffer
LoadDescriptorFromROM_2:
		lpm											;load from ROM position pointer to R0 <- (ZH:ZL)
		st		Y+,R0								;R0 save to buffer and increment buffer (Y) <- R0, Y++
		adiw	ZH:ZL,1								;increment index to ROM ; Z++
		dec		ByteCount							;till are not all bytes
		brne	LoadDescriptorFromROM_2				;then load next

		ldi		ByteCount,2							;length of output buffer (only SOP and PID)
		add		ByteCount,temp3						;+ number of bytes
		rcall	AddCRCOut							;addition of CRC to buffer
		inc		ByteCount							;length of output buffer + CRC16
		inc		ByteCount


		inc		BitStuffInOut						;transmitting buffer - insertion of bitstuff bits
		ldi		USBBufptrY,OutputBufferBegin		;to transmitting buffer
		rcall	BitStuff
		mov		OutputBufferLength,ByteCount		;length of answer store for transmiting
		clr		BitStuffInOut						;receiving buffer - deletion of bitstuff bits



		;copy to Joystick buffer
		sts 	JoyOutputBufferLength, OutputBufferLength
		sts 	JoyOutBitStuffNumber, OutBitStuffNumber

		mov		ByteCount, OutputBufferLength
		clr 	ZH
		ldi		ZL,  OutputBufferBegin
		ldi		USBBufptrY,JoystickBufferBegin		;to transmitting buffer
CopyToJoyBufferLoop:
		ld		R0, Z+								;load from RAM position pointer to R0 <- (ZH:ZL)
		st		Y+,R0								;R0 save to buffer and increment buffer (Y) <- R0, Y++
		dec		ByteCount							;till are not all bytes
		brne	CopyToJoyBufferLoop					;then load next

		ret
;------------------------------------------------------------------------------------------
InitACKBufffer:
		ldi		temp0,SOPbyte
		sts		ACKBufferBegin+0,temp0				;SOP byte
		ldi		temp0,ACKPID
		sts		ACKBufferBegin+1,temp0				;ACKPID byte
		ret
;------------------------------------------------------------------------------------------
SendACK:
		push	USBBufptrY
		push	bitcount
		push	OutBitStuffNumber
		ldi		USBBufptrY,ACKBufferBegin			;pointer to begin of ACK buffer
		ldi		ByteCount,2							;number of transmit bytes (only SOP and ACKPID)
		clr		OutBitStuffNumber
		rcall	SendUSBBuffer
		pop		OutBitStuffNumber
		pop		bitcount
		pop		USBBufptrY
		ret
;------------------------------------------------------------------------------------------
InitNAKBufffer:
		ldi		temp0,SOPbyte
		sts		NAKBufferBegin+0,temp0				;SOP byte
		ldi		temp0,NAKPID
		sts		NAKBufferBegin+1,temp0				;NAKPID byte
		ret
;------------------------------------------------------------------------------------------
SendNAK:
		push	OutBitStuffNumber
		ldi		USBBufptrY,NAKBufferBegin			;pointer to begin of NACK buffer
		ldi		ByteCount,2							;number of transmited bytes (only SOP and NAKPID)
		clr		OutBitStuffNumber
		rcall	SendUSBBuffer
		pop		OutBitStuffNumber
		ret
;------------------------------------------------------------------------------------------
ComposeSTALL:
		ldi		temp0,SOPbyte
		sts		OutputBufferBegin+0,temp0			;SOP byte
		ldi		temp0,STALLPID
		sts		OutputBufferBegin+1,temp0			;STALLPID byte
		ldi		ByteCount,2							;length of output buffer (SOP and PID)
		ret
;------------------------------------------------------------------------------------------
DecodeNRZI:
;encoding of buffer from NRZI code to binary
		push	USBBufptrY							;back up pointer to buffer
		push	ByteCount							;back up length of buffer
		add		ByteCount,USBBufptrY				;end of buffer to ByteCount
		ser		temp0								;to ensure unit carry (in the next rotation)
NRZIloop:
		ror		temp0								;filling carry from previous byte
		ld		temp0,Y								;nload received byte from buffer
		mov		temp2,temp0							;shifted register to one bit to the right and XOR for function of NRZI decoding
		ror		temp2								;carry to most significant digit bit and shift
		eor		temp2,temp0							;NRZI decoding
		com		temp2								;negate
		st		Y+,temp2							;save back as decoded byte and increment pointer to buffer
		cp		USBBufptrY,ByteCount				;if not all bytes
		brne	NRZIloop							;then repeat
		pop		ByteCount							;restore buffer length
		pop		USBBufptrY							;restore pointer to buffer
		ret											;otherwise finish
;------------------------------------------------------------------------------------------
BitStuff:
;removal of bitstuffing in buffer
		clr		temp3								;counter of omitted bits
		clr		lastBitstufNumber					;0xFF to lastBitstufNumber
		dec		lastBitstufNumber
BitStuffRepeat:
		push	USBBufptrY							;back up pointer to buffer
		push	ByteCount							;back up buffer length
		mov		temp1,temp3							;counter of all bits
		ldi		temp0,8								;sum all bits in buffer
SumAllBits:
		add		temp1,temp0
		dec		ByteCount
		brne	SumAllBits
		ldi		temp2,6								;initialize counter of ones
		pop		ByteCount							;restore buffer length
		push	ByteCount							;back up buffer length
		add		ByteCount,USBBufptrY				;end of buffer to ByteCount
		inc		ByteCount							;and for safety increment it with 2 (because of shifting)
		inc		ByteCount
BitStuffLoop:
		ld		temp0,Y								;load received byte from buffer
		ldi		bitcount,8							;bits counter in byte
BitStuffByteLoop:
		ror		temp0								;filling carry from LSB
		brcs	IncrementBitstuff					;if that LSB=0
		ldi		temp2,7								;initialize counter of ones +1 (if was zero)
IncrementBitstuff:
		dec		temp2								;decrement counter of ones (assumption of one bit)
		brne	NeposunBuffer						;if there was not 6 ones together - don't shift buffer
		cp		temp1,lastBitstufNumber	;
		ldi		temp2,6								;initialize counter of ones (if no bitstuffing will be made then must be started again)
		brcc	NeposunBuffer						;if already was made bitstuffing - don't shift buffer

		dec		temp1
		mov		lastBitstufNumber,temp1				;remember last position of bitstuffing
		cpi		bitcount,1							;for pointing to 7-th bit (which must be deleted or where to insert zero)
		brne	NoBitcountCorrect
		ldi		bitcount,9
		inc		USBBufptrY							;increment pointer to buffer
NoBitcountCorrect:
		dec		bitcount
		bst		BitStuffInOut,0
		brts	CorrectOutBuffer					;if this is Out buffer - increment buffer length
		rcall	ShiftDeleteBuffer					;shift In buffer
		dec		temp3								;decrement counter of omission
		rjmp	CorrectBufferEnd
CorrectOutBuffer:
		rcall	ShiftInsertBuffer					;shift Out buffer
		inc		temp3								;increment counter of omission
CorrectBufferEnd:
		pop		ByteCount							;restore buffer length
		pop		USBBufptrY							;restore pointer to buffer
		rjmp	BitStuffRepeat						;and restart from begin
NeposunBuffer:
		dec		temp1								;if already were all bits
		breq	EndBitStuff							;finish cycle
		dec		bitcount							;decrement bits counter in byte
		brne	BitStuffByteLoop					;if not yet been all bits in byte - go to next bit
													;otherwise load next byte
		inc		USBBufptrY							;increment pointer to buffer
		rjmp	BitStuffLoop						;and repeat
EndBitStuff:
		pop		ByteCount							;restore buffer length
		pop		USBBufptrY							;restore pointer to buffer
		bst		BitStuffInOut,0
		brts	IncrementLength						;if this is Out buffer - increment length of Out buffer
DecrementLength:									;if this is In buffer - decrement length of In buffer
		cpi		temp3,0								;was at least one decrement
		breq	NoChangeByteCount					;if no - don't change buffer length
		dec		ByteCount							;if this is In buffer - decrement buffer length
		subi	temp3,256-8							;if there wasn't above 8 bits over
		brcc	NoChangeByteCount					;then finish
		dec		ByteCount							;otherwise next decrement buffer length
		ret											;and finish
IncrementLength:
		mov		OutBitStuffNumber,temp3				;remember number of bits over
		subi	temp3,8								;if there wasn't above 8 bits over
		brcs	NoChangeByteCount					;then finish
		inc		ByteCount							;otherwise increment buffer length
		mov		OutBitStuffNumber,temp3				;and remember number of bits over (decremented by 8)
NoChangeByteCount:
		ret											;finish
;------------------------------------------------------------------------------------------
ShiftInsertBuffer:
;shift buffer by one bit to right from end till to position: byte-USBBufptrY and bit-bitcount
		mov		temp0,bitcount						;calculation: bitcount= 9-bitcount
		ldi		bitcount,9
		sub		bitcount,temp0						;to bitcount bit position, which is necessary to clear

		ld		temp1,Y								;load byte which still must be shifted from position bitcount
		rol		temp1								;and shift to the left through Carry (transmission from higher byte and LSB to Carry)
		ser		temp2								;FF to mask - temp2
HalfInsertPosuvMask:
		lsl		temp2								;zero to the next low bit of mask
		dec		bitcount							;till not reached boundary of shifting in byte
		brne	HalfInsertPosuvMask
		
		and		temp1,temp2							;unmask that remains only high shifted bits in temp1
		com		temp2								;invert mask
		lsr		temp2								;shift mask to the right - for insertion of zero bit
		ld		temp0,Y								;load byte which must be shifted from position bitcount to temp0
		and		temp0,temp2							;unmask to remains only low non-shifted bits in temp0
		or		temp1,temp0							;and put together shifted and nonshifted part

		ld		temp0,Y								;load byte which must be shifted from position bitcount
		rol		temp0								;and shift it to the left through Carry (to set right Carry for further carry)
		st		Y+,temp1							;and load back modified byte
ShiftInsertBufferLoop:
		cpse	USBBufptrY,ByteCount				;if are not all entire bytes
		rjmp	NoEndShiftInsertBuffer				;then continue
		ret											;otherwise finish
NoEndShiftInsertBuffer:
		ld		temp1,Y								;load byte
		rol		temp1								;and shift to the left through Carry (carry from low byte and LSB to Carry)
		st		Y+,temp1							;and store back
		rjmp	ShiftInsertBufferLoop				;and continue
;------------------------------------------------------------------------------------------
ShiftDeleteBuffer:
;shift buffer one bit to the left from end to position: byte-USBBufptrY and bit-bitcount
		mov		temp0,bitcount						;calculation: bitcount= 9-bitcount
		ldi		bitcount,9
		sub		bitcount,temp0						;to bitcount bit position, which must be shifted
		mov		temp0,USBBufptrY					;backup pointera to buffer
		inc		temp0								;position of completed bytes to temp0
		mov		USBBufptrY,ByteCount				;maximum position to pointer
ShiftDeleteBufferLoop:
		ld		temp1,-Y							;decrement buffer and load byte
		ror		temp1								;and right shift through Carry (carry from higher byte and LSB to Carry)
		st		Y,temp1								;and store back
		cpse	USBBufptrY,temp0					;if there are not all entire bytes
		rjmp	ShiftDeleteBufferLoop				;then continue

		ld		temp1,-Y							;decrement buffer and load byte which must be shifted from position bitcount
		ror		temp1								;and right shift through Carry (carry from higher byte and LSB to Carry)
		ser		temp2								;FF to mask - temp2
HalfDeletePosuvMask:
		dec		bitcount							;till not reached boundary of shifting in byte
		breq	DoneMask
		lsl		temp2								;zero to the next low bit of mask
		rjmp	HalfDeletePosuvMask
DoneMask:
		and		temp1,temp2							;unmask to remain only high shifted bits in temp1
		com		temp2								;invert mask
		ld		temp0,Y								;load byte which must be shifted from position bitcount to temp0
		and		temp0,temp2							;unmask to remain only low nonshifted bits in temp0
		or		temp1,temp0							;and put together shifted and nonshifted part
		st		Y,temp1								;and store back
		ret											;and finish
;------------------------------------------------------------------------------------------
MirrorInBufferBytes:
		push	USBBufptrY
		push	ByteCount
		ldi		USBBufptrY,InputBufferBegin
		rcall	MirrorBufferBytes
		pop		ByteCount
		pop		USBBufptrY
		ret
;------------------------------------------------------------------------------------------
MirrorBufferBytes:
		add		ByteCount,USBBufptrY				;ByteCount shows to the end of message 
MirrorBufferloop:
		ld		temp0,Y								;load received byte from buffer
		ldi		temp1,8								;bits counter
MirrorBufferByteLoop:
		ror		temp0								;to carry next least bit
		rol		temp2								;from carry next bit to reverse order 
		dec		temp1								;was already entire byte
		brne	MirrorBufferByteLoop				;if no then repeat next least bit
		st		Y+,temp2							;save back as reversed byte  and increment pointer to buffer
		cp		USBBufptrY,ByteCount				;if not yet been all
		brne	MirrorBufferloop					;then repeat
		ret											;otherwise finish

AddCRCOut:
		push	USBBufptrY
		push	ByteCount
		ldi		USBBufptrY,OutputBufferBegin
AddCRCOut_2:
		rcall	CheckCRC
		com	temp0									;negation of CRC
		com			temp1
		st		Y+,temp1							;save CRC to the end of buffer (at first MSB)
		st		Y,temp0								;save CRC to the end of buffer (then LSB)
		dec		USBBufptrY							;pointer to CRC position
		ldi		ByteCount,2							;reverse bits order in 2 bytes CRC
		rcall	MirrorBufferBytes					;reverse bits order in CRC (transmiting CRC - MSB first)
		pop		ByteCount
		pop		USBBufptrY
		ret
;------------------------------------------------------------------------------------------
CheckCRC:
;input: USBBufptrY = begin of message	,ByteCount = length of message
		add		ByteCount,USBBufptrY				;ByteCount points to the end of message 
		inc		USBBufptrY							;set the pointer to message start - omit SOP
		ld		temp0,Y+							;load PID to temp0
													;and set the pointer to start of message - omit also PID
		cpi		temp0,DATA0PID						;if is DATA0 field
		breq	ComputeDATACRC						;compute CRC16
		cpi		temp0,DATA1PID						;if is DATA1 field
		brne	CRC16End							;if no then finish 
ComputeDATACRC:
		ser		temp0								;initialization of remaider LSB to 0xff
		ser		temp1								;initialization of remaider MSB to 0xff
CRC16Loop:
		ld		temp2,Y+							;load message to temp2 and increment pointer to buffer
		ldi		temp3,8								;bits counter in byte - temp3
CRC16LoopByte:
		bst		temp1,7								;to T save MSB of remainder (remainder is only 16 bits - 8 bit of higher byte)
		bld		bitcount,0							;to bitcount LSB save T - of MSB remainder
		eor		bitcount,temp2						;XOR of bit message and bit remainder - in LSB bitcount
		rol		temp0								;shift remainder to the left - low byte (two bytes - through carry)
		rol		temp1								;shift remainder to the left - high byte (two bytes - through carry)
		cbr		temp0,1								;znuluj LSB remains
		lsr		temp2								;shift message to right
		ror		bitcount							;result of XOR bits from LSB to carry
		brcc	CRC16NoXOR							;if is XOR bitmessage and MSB of remainder = 0 , then no XOR
		ldi		bitcount,CRC16poly>>8				;to bitcount CRC polynomial - high byte
		eor		temp1,bitcount						;and make XOR from remains and CRC polynomial - high byte
		ldi		bitcount,CRC16poly&0xFF				;to bitcount CRC polynomial - low byte
		eor		temp0,bitcount						;and make XOR of remainder and CRC polynomial - low byte
CRC16NoXOR:
		dec		temp3								;were already all bits in byte
		brne	CRC16LoopByte						;unless, then go to next bit
		cp		USBBufptrY,ByteCount				;was already end-of-message 
		brne	CRC16Loop							;unless then repeat
CRC16End:
		ret											;otherwise finish (in temp0 and temp1 is result)
;------------------------------------------------------------------------------------------
LoadDescriptorFromROM:
		lpm											;load from ROM position pointer to R0
		st		Y+,R0								;R0 save to buffer and increment buffer
		adiw	ZH:ZL,1								;increment index to ROM
		dec		ByteCount							;till are not all bytes
		brne	LoadDescriptorFromROM				;then load next
		rjmp	EndFromRAMROM						;otherwise finish
;------------------------------------------------------------------------------------------
LoadDescriptorFromROMZeroInsert:
		lpm											;load from ROM position pointer to R0
		st		Y+,R0								;R0 save to buffer and increment buffer

		bst		RAMread,3							;if bit 3 is one - don't insert zero
		brtc	InsertingZero						;otherwise zero will be inserted
		adiw	ZH:ZL,1								;increment index to ROM
		lpm											;load from ROM position pointer to R0
		st		Y+,R0								;R0 save to buffer and increment buffer
		clt											;and clear
		bld		RAMread,3							;the third bit in RAMread - for to the next zero insertion will be made
		rjmp	InsertingZeroEnd					;and continue
InsertingZero:
		clr		R0									;for insertion of zero
		st		Y+,R0								;zero save to buffer and increment buffer
InsertingZeroEnd:
		adiw	ZH:ZL,1								;increment index to ROM
		subi	ByteCount,2							;till are not all bytes
		brne	LoadDescriptorFromROMZeroInsert		;then load next
		rjmp	EndFromRAMROM						;otherwise finish
;------------------------------------------------------------------------------------------
LoadDescriptorFromSRAM:
		ld		R0,Z								;load from position RAM pointer to R0
		st		Y+,R0								;R0 save to buffer and increment buffer
		adiw	ZH:ZL,1								;increment index to RAM
		dec		ByteCount							;till are not all bytes
		brne	LoadDescriptorFromSRAM				;then load next
		rjmp	EndFromRAMROM						;otherwise finish
;------------------------------------------------------------------------------------------
LoadDescriptorFromEEPROM:
		out		EEARL,ZL							;set the address EEPROM Lo
		out		EEARH,ZH							;set the address EEPROM Hi
		sbi		EECR,EERE							;read EEPROM to register EEDR
		in		R0,EEDR								;load from EEDR to R0
		st		Y+,R0								;R0 save to buffer and increment buffer
		adiw	ZH:ZL,1								;increment index to EEPROM
		dec		ByteCount							;till are not all bytes
		brne	LoadDescriptorFromEEPROM			;then load next
		rjmp	EndFromRAMROM						;otherwise finish
;------------------------------------------------------------------------------------------
LoadXXXDescriptor:
		ldi		temp0,SOPbyte						;SOP byte
		sts		OutputBufferBegin,temp0				;to begin of tramsmiting buffer store SOP
		ldi		ByteCount,8							;8 byte store
		ldi		USBBufptrY,OutputBufferBegin+2		;to transmitting buffer

		and		RAMread,RAMread						;if will be reading from RAM or ROM or EEPROM
		brne	FromRAMorEEPROM						;0=ROM,1=RAM,2=EEPROM,4=ROM with zero insertion (string)
FromROM:
		rjmp	LoadDescriptorFromROM				;load descriptor from ROM
FromRAMorEEPROM:
		sbrc	RAMread,2							;if RAMREAD=4
		rjmp	LoadDescriptorFromROMZeroInsert		;read from ROM with zero insertion
		sbrc	RAMread,0							;if RAMREAD=1
		rjmp	LoadDescriptorFromSRAM				;load data from SRAM
		rjmp	LoadDescriptorFromEEPROM			;otherwise read from EEPROM
EndFromRAMROM:
		sbrc	RAMread,7							;if is most significant bit in variable RAMread=1
		clr		RAMread								;clear RAMread
		rcall	ToggleDATAPID						;change DATAPID
		ldi		USBBufptrY,OutputBufferBegin+1		;to transmitting buffer - position of DATA PID
		ret
;------------------------------------------------------------------------------------------
PrepareUSBOutAnswer:
;prepare answer to buffer
		rcall	PrepareUSBAnswer					;prepare answer to buffer
MakeOutBitStuff:
		inc		BitStuffInOut						;transmitting buffer - insertion of bitstuff bits
		ldi		USBBufptrY,OutputBufferBegin		;to transmitting buffer
		rcall	BitStuff
		mov		OutputBufferLength,ByteCount		;length of answer store for transmiting
		clr		BitStuffInOut						;receiving buffer - deletion of bitstuff bits
		ret

;------------------------------------------------------------------------------------------
PrepareUSBAnswer:
;prepare answer to buffer
		clr		RAMread							;zero to RAMread variable - reading from ROM
		lds		temp0,InputBufferBegin+2		;bmRequestType to temp0
		lds		temp1,InputBufferBegin+3		;bRequest to temp1
		cbr		temp0,0b10011111				;if is 5 and 6 bit zero
		brne	CheckVendor						;then this isn't  Vendor Request
		rjmp	StandardRequest					;but this is standard Request
CheckVendor:
		cpi		temp0, 0b01000000
		breq	VendorRequest
		cpi 	temp0, 0b00100000
		breq	ClassRequest

		rjmp	VendorRequest

;------------------------------------------------------------------------------------------
ClassRequest:
		cpi		temp1,GET_REPORT		
		breq	ComposeGET_REPORT		

		cpi		temp1,GET_IDLE		
		breq	ComposeGET_IDLE		

		cpi		temp1,GET_PROTOCOL		
		breq	ComposeGET_PROTOCOL	

		cpi		temp1,SET_REPORT		
		breq	ComposeSET_REPORT		

		cpi		temp1,SET_IDLE		
		breq	ComposeSET_IDLE		

		cpi		temp1,SET_PROTOCOL		
		breq	ComposeSET_PROTOCOL		

		rjmp	ZeroDATA1Answer					;if that was something unknown, then prepare zero answer

;------------------------------------------------------------------------------------------
; Class Requests
;------------------------------------------------------------------------------------------

ComposeGET_REPORT:				
		rjmp	ZeroDATA1Answer
ComposeGET_IDLE:
		rjmp	ZeroDATA1Answer
ComposeGET_PROTOCOL:
		rjmp	ZeroDATA1Answer
ComposeSET_REPORT:
		rjmp	ZeroDATA1Answer
ComposeSET_IDLE:
		rjmp	ZeroDATA1Answer
ComposeSET_PROTOCOL:
		rjmp	ZeroDATA1Answer

;------------------------------------------------------------------------------------------
VendorRequest:

		rjmp	ZeroDATA1Answer					;if that it was something unknown, then prepare zero answer

;------------------------------------------------------------------------------------------
; User functions can go here, but there are none for this device
;------------------------------------------------------------------------------------------

OneZeroAnswer:									;send single zero
		ldi	temp0,1								;number of my bytes answers to temp0
		rjmp	ComposeGET_STATUS2

;------------------------------------------------------------------------------------------
; Standard USB requests
;------------------------------------------------------------------------------------------

StandardRequest:
		cpi		temp1,GET_STATUS		
		breq	ComposeGET_STATUS		

		cpi		temp1,CLEAR_FEATURE		
		breq	ComposeCLEAR_FEATURE		

		cpi		temp1,SET_FEATURE		
		breq	ComposeSET_FEATURE		

		cpi		temp1,SET_ADDRESS			;if to set address
		breq	ComposeSET_ADDRESS			;set the address

		cpi		temp1,GET_DESCRIPTOR		;if requested descriptor
		breq	ComposeGET_DESCRIPTOR		;generate it

		cpi		temp1,SET_DESCRIPTOR		
		breq	ComposeSET_DESCRIPTOR		

		cpi		temp1,GET_CONFIGURATION		
		breq	ComposeGET_CONFIGURATION	

		cpi		temp1,SET_CONFIGURATION		
		breq	ComposeSET_CONFIGURATION	

		cpi		temp1,GET_INTERFACE		
		breq	ComposeGET_INTERFACE		

		cpi		temp1,SET_INTERFACE		
		breq	ComposeSET_INTERFACE		

		cpi		temp1,SYNCH_FRAME		
		breq	ComposeSYNCH_FRAME		
											;if not found known request
		rjmp	ZeroDATA1Answer				;if that was something unknown, then prepare zero answer

ComposeSET_ADDRESS:
		lds		MyUpdatedAddress,InputBufferBegin+4	;new address to MyUpdatedAddress
		rjmp	ZeroDATA1Answer						;send zero answer

ComposeSET_CONFIGURATION:

		lds		temp0,InputBufferBegin+4			;number of configuration to variable ConfigByte
		sts		ConfigByte,temp0					;
ComposeCLEAR_FEATURE:
ComposeSET_FEATURE:
ComposeSET_INTERFACE:
ZeroStringAnswer:
		rjmp	ZeroDATA1Answer						;send zero answer
ComposeGET_STATUS:
TwoZeroAnswer:
		ldi		temp0,2								;number of my bytes answers to temp0
ComposeGET_STATUS2:
		ldi		ZH, high(StatusAnswer<<1)			;ROMpointer to  answer
		ldi		ZL,  low(StatusAnswer<<1)
		rjmp	ComposeEndXXXDescriptor				;and complete
ComposeGET_CONFIGURATION:
		lds		temp0,ConfigByte
		ldi		temp0,1								;number of my bytes answers to temp0
		ldi		ZH, high(ConfigAnswerMinus1<<1)		;ROMpointer to  answer
		ldi		ZL,  low(ConfigAnswerMinus1<<1)+1
		rjmp	ComposeEndXXXDescriptor				;and complete
ComposeGET_INTERFACE:
		ldi		ZH, high(InterfaceAnswer<<1)		;ROMpointer to answer
		ldi		ZL,  low(InterfaceAnswer<<1)
		ldi		temp0,1								;number of my bytes answers to temp0
		rjmp	ComposeEndXXXDescriptor				;and complete
ComposeSYNCH_FRAME:
ComposeSET_DESCRIPTOR:
		rcall	ComposeSTALL
		ret
ComposeGET_DESCRIPTOR:
		
		; check if we received HID Class Descriptor request
		lds		temp0,InputBufferBegin+2			;bmRequestType to temp0
		cpi 	temp0, 0b10000001
		breq	ComposeClassDescriptor
		
		; if not, process standard descriptor requests
		lds		temp1,InputBufferBegin+5			;DescriptorType to temp1
		cpi		temp1,DEVICE						;DeviceDescriptor
		breq	ComposeDeviceDescriptor				;
		cpi		temp1,CONFIGURATION					;ConfigurationDescriptor
		breq	ComposeConfigDescriptor				;
		cpi		temp1,STRING						;StringDeviceDescriptor
		breq	ComposeStringDescriptor				;

		ret
ComposeClassDescriptor:

		lds		temp1,InputBufferBegin+5			;DescriptorType to temp1
		cpi		temp1,CLASS_HID						;HID class descripto
		breq	ComposeHIDClassDescriptor			;
		cpi		temp1,CLASS_Report					;ConfigurationDescriptor
		breq	ComposeReportDescriptor				;
		cpi		temp1,CLASS_Physical				;StringDeviceDescriptor
		breq	ComposePhysicalDescriptor
		ret

ComposeDeviceDescriptor:
		ldi		ZH, high(DeviceDescriptor<<1)		;ROMpointer to descriptor
		ldi		ZL,  low(DeviceDescriptor<<1)
		ldi		temp0,0x12							;number of my bytes answers to temp0
		rjmp	ComposeEndXXXDescriptor				;and completen
ComposeConfigDescriptor:
		ldi		ZH, high(ConfigDescriptor<<1)		;ROMpointer to descriptor
		ldi		ZL,  low(ConfigDescriptor<<1)
		ldi		temp0,9+9+9+7						;number of my bytes answers to temp0
		rjmp	ComposeEndXXXDescriptor				;and complete

ComposeHIDClassDescriptor:	
		ldi		ZH, high(HIDDescriptor<<1)			;ROMpointer to descriptor
		ldi		ZL,  low(HIDDescriptor<<1)
		ldi		temp0,9								;number of my bytes answers to temp0
		rjmp	ComposeEndXXXDescriptor				;and complete

ComposeReportDescriptor:	;
		ldi		ZH, high(ReportDescriptor<<1)		;ROMpointer to descriptor
		ldi		ZL,  low(ReportDescriptor<<1)
		ldi		temp0,ReportDescriptorSize			;number of my bytes answers to temp0
		rjmp	ComposeEndXXXDescriptor				;and complete

ComposePhysicalDescriptor:
		rjmp	ComposeEndXXXDescriptor				;and complete

ComposeStringDescriptor:
		ldi		temp1,4+8							;if RAMread=4(insert zeros from ROM reading) + 8(behind first byte no load zero)
		mov		RAMread,temp1
		lds		temp1,InputBufferBegin+4			;DescriptorIndex to temp1
		cpi		temp1,0								;LANGID String
		breq	ComposeLangIDString					;
		cpi		temp1,2								;DevNameString
		breq	ComposeDevNameString
		cpi		temp1,3								;NameString
		breq	ComposeNameString
		cpi		temp1,1								;ComposeVendorString
		breq	ComposeVendorString


		rjmp	ZeroStringAnswer		
		rjmp	ZeroDATA1Answer						;if is DescriptorIndex higher than 2 - send zero answer

ComposeVendorString:
		ldi		ZH, high(VendorStringDescriptor<<1)								;ROMpointer to descriptor
		ldi		ZL,  low(VendorStringDescriptor<<1)
		ldi		temp0,(VendorStringDescriptorEnd-VendorStringDescriptor)*4-2	;number of my bytes answers to temp0
		rjmp	ComposeEndXXXDescriptor											;and complete
ComposeDevNameString:
		ldi		ZH, high(DevNameStringDescriptor<<1)							;ROMpointer to descriptor
		ldi		ZL,  low(DevNameStringDescriptor<<1)
		ldi		temp0,(DevNameStringDescriptorEnd-DevNameStringDescriptor)*4-2	;number of my bytes answers to temp0
		rjmp	ComposeEndXXXDescriptor											;and complete
ComposeNameString:
		ldi		ZH, high(NameStringDescriptor<<1)								;ROMpointer to descriptor
		ldi		ZL,  low(NameStringDescriptor<<1)
		ldi		temp0,(NameStringDescriptorEnd-NameStringDescriptor)*4-2		;number of my bytes answers to temp0
		rjmp	ComposeEndXXXDescriptor											;and complete
ComposeLangIDString:
		clr		RAMread
		ldi		ZH, high(LangIDStringDescriptor<<1)								;ROMpointer to descriptor
		ldi		ZL,  low(LangIDStringDescriptor<<1)
		ldi		temp0,(LangIDStringDescriptorEnd-LangIDStringDescriptor)*2		;number of my bytes answers to temp0
		rjmp	ComposeEndXXXDescriptor											;and complete

ComposeEndXXXDescriptor:
		lds		TotalBytesToSend,InputBufferBegin+9
		tst		TotalBytesToSend
		brne	OurConfigLength
		lds		TotalBytesToSend,InputBufferBegin+8
		cp		TotalBytesToSend,temp0
		brcs	HostConfigLength
OurConfigLength:
		mov		TotalBytesToSend,temp0

HostConfigLength:
		mov		temp0,TotalBytesToSend				;
		clr		TransmitPart						;zero the number of 8 bytes answers
		andi	temp0,0b00000111					;if is length divisible by 8
		breq	Length8Multiply						;then not count one answer (under 8 byte)
		inc		TransmitPart						;otherwise count it
Length8Multiply:
		mov		temp0,TotalBytesToSend				;
		lsr		temp0								;length of 8 bytes answers will reach
		lsr		temp0								;integer division by 8
		lsr		temp0
		add		TransmitPart,temp0					;and by addition to last non entire 8-bytes to variable TransmitPart
		ldi		temp0,DATA0PID						;DATA0 PID - in the next will be toggled to DATA1PID in load descriptor
		sts		OutputBufferBegin+1,temp0			;store to output buffer
		rjmp	ComposeNextAnswerPart

ZeroDATA1Answer:
		rcall	ComposeZeroDATA1PIDAnswer
		ret
;------------------------------------------------------------------------------------------
; End of USB requests
;------------------------------------------------------------------------------------------

PrepareOutContinuousBuffer:
		rcall	PrepareContinuousBuffer
		rcall	MakeOutBitStuff
		ret
;------------------------------------------------------------------------------------------
PrepareContinuousBuffer:
		mov		temp0,TransmitPart
		cpi		temp0,1
		brne	NextAnswerInBuffer					;if buffer empty
		rcall	ComposeZeroAnswer					;prepare zero answer
		ret
NextAnswerInBuffer:
		dec		TransmitPart						;decrement general length of answer
ComposeNextAnswerPart:
		mov		temp1,TotalBytesToSend				;decrement number of bytes to transmit 
		subi	temp1,8								;is is necessary to send more as 8 byte
		ldi		temp3,8								;if yes - send only 8 byte
		brcc	Nad8Bytov
		mov		temp3,TotalBytesToSend				;otherwise send only given number of bytes
		clr		TransmitPart
		inc		TransmitPart						;and this will be last answer
Nad8Bytov:
		mov		TotalBytesToSend,temp1				;decremented number of bytes to TotalBytesToSend
		rcall	LoadXXXDescriptor
		ldi		ByteCount,2							;length of output buffer (only SOP and PID)
		add		ByteCount,temp3						;+ number of bytes
		rcall	AddCRCOut							;addition of CRC to buffer
		inc		ByteCount							;length of output buffer + CRC16
		inc		ByteCount
		ret											;finish





;------------------------------------------------------------------------------------------
.equ	USBversion		=0x0100		;for what version USB is that (1.00)
.equ	VendorUSBID		=0x8282		;vendor identifier (MoJo=0x8282 - unofficial)
.equ	DeviceUSBID		=0x8002		;product identifier (Retro Adapter)
.equ	DeviceVersion	=0x0100		;version number of product (version=1.00)
.equ	MaxUSBCurrent	=0xA0		;current consumption from USB (50mA)
;------------------------------------------------------------------------------------------
DeviceDescriptor:
		.db	0x12,0x01		;0 byte - size of descriptor in byte
							;1 byte - descriptor type: Device descriptor
		.dw	USBversion		;2,3 byte - version USB LSB (1.00)
		.db	0x00,0x00		;4 byte - device class
							;5 byte - subclass
		.db	0x00,0x08		;6 byte - protocol code
							;7 byte - FIFO size in bytes
		.dw	VendorUSBID		;8,9 byte - vendor identifier 
		.dw	DeviceUSBID		;10,11 byte - product identifier 
		.dw	DeviceVersion	;12,13 byte - product version number 
		.db	0x01,0x02		;14 byte - index of string "vendor"
							;15 byte - index of string "product"
		.db	0x00,0x01		;16 byte - index of string "serial number" (0=none)
							;17 byte - number of possible configurations
DeviceDescriptorEnd:
;------------------------------------------------------------------------------------------
ConfigDescriptor:
		.db	0x9,0x02		;length, descriptor type
ConfigDescriptorLength:
		.dw	9+9+9+7			;entire length of all descriptors + HID 
ConfigAnswerMinus1:			;for sending the number - congiguration number (attention - addition of 1 required)
		.db	1,1				;numInterfaces, congiguration number
		.db	2,0x80			;string index (0=none), attributes; bus powered
;InterfaceDescriptor-1:
		.db	MaxUSBCurrent/2,0x09  ;current consumption,    interface descriptor length
		.db	0x04,0			;interface descriptor; number of interface
InterfaceAnswer:			;for sending number of alternatively interface
		.db	0,1				;alternatively interface; number of endpoints except EP0
		.db	0x03,0			;interface class - HID; interface subclass
		.db	0,3				;protocol code; string index - Device name
HIDDescriptor:
		.db 0x09,0x21		;HID descriptor length , HID descriptor type (defined by USB)
		.dw 0x101			;HID Class Specification release number
		.db	0,0x01			;Hardware target country.;	;Number of HID class descriptors to follow.
		.db	0x22, ReportDescriptorSize			;Report descriptor type.; length LSB
		.db	0, 0x07			;Total length of Report descriptor MSB, EndPointDescriptor length
EndPointDescriptor:	
		.db	0x5, 0x81		;descriptor type - endpoint
		.db	0x3, 0x08		;endpoint address In 1; transfer type -interrupt;max packet size LSB
		.db	0, 10			;max packet size MSB,polling interval [ms];


ConfigDescriptorEnd:

;------------------------------------------------------------------------------------------
StatusAnswer:
		.db 0,0				;2 zero answers
;------------------------------------------------------------------------------------------

;(ReportDescriptorEnd-ReportDescriptor)*2+1
.equ	ReportDescriptorSize = 63 ;61

.equ	JoystickReportCount =1
.equ	JoystickReport1Size =4	;3

ReportDescriptor:
		.db 0x05,0x01		;Usage_Page (Generic Desktop)
		.db 0x09,0x05		;Usage (Game Pad)
		.db 0xA1,0x01		;Collection (Application)
		.db 0x09,0x01			;Usage (Pointer)
		.db 0xA1,0x00			;Collection (Physical)		
		.db 0x09,0x30				;Usage (X)
		.db 0x09,0x31				;Usage (Y)
		.db 0x15,0x81				;Logical_Minimum (-127)
		.db 0x25,0x7F				;Logical Maximum (127)
		.db 0x75,0x08				;Report_Size (8)
		.db 0x95,0x02				;Report_Count (2)
		.db 0x81,0x02				;Input (Data, Var, Abs)		
		.db 0xC0,0x16   		;End_Collection, dummy

		.db 0xA1,0x00			;Collection (Physical)
		.db 0x05,0x09				;Usage_Page (Button)
		.db 0x19,0x01				;Usage_Minimum (Button 1)
		.db 0x29,0x0a				;Usage_Maximum (Button 10)
		.db 0x15,0x00				;Logical_Minimum (0)
		.db 0x25,0x01				;Logical_Maximum (1)
		.db 0x75,0x01				;Report_Size (1)
		.db 0x95,0x0a				;Report_Count (2)
		.db 0x55,0x00				;Unit_Exponent (0)
		.db 0x65,0x00				;Unit (None)
		.db 0x81,0x02				;Input (Data, Var, Abs)

;round it out
		.db 0x05,0x01				;Usage_Page (Generic Desktop)
		.db 0x09,0x00				;Usage (Undefined)
		.db 0x15,0x01				;Logical_Minimum (0)
		.db 0x25,0x06				;Logical_Maximum (5)
		.db 0x75,0x06				;Report_Size (6)
		.db 0x95,0x01				;Report_Count (1)
		.db 0x81,0x02				;Input (Data, Var, Abs)
		.db 0xC0,0x00			;End_Collection , dummy padding

ReportDescriptorEnd:


;------------------------------------------------------------------------------------------
LangIDStringDescriptor:
		.db	(LangIDStringDescriptorEnd-LangIDStringDescriptor)*2,3		;length, type: string descriptor
		.dw	0x0209														;English
LangIDStringDescriptorEnd:
;------------------------------------------------------------------------------------------
VendorStringDescriptor:
		.db	(VendorStringDescriptorEnd-VendorStringDescriptor)*4-2,3	;length, type: string descriptor
CopyRight:
		.db	"(C) 2008 Paul Qureshi, (C) 2003 Ing. Igor Cesko "
CopyRightEnd:
VendorStringDescriptorEnd:
;------------------------------------------------------------------------------------------
DevNameStringDescriptor:
		.db	(DevNameStringDescriptorEnd-DevNameStringDescriptor)*4-2,3	;length, type: string descriptor
		.db	"Retro Adapter "
DevNameStringDescriptorEnd:

NameStringDescriptor:
		.db	(NameStringDescriptorEnd-NameStringDescriptor)*4-2,3		;length, type: string descriptor
		.db	"USB To Atari/Commodore/Saturn/Mega Drive/Master System/Famicom/Super Famicom adapter"
NameStringDescriptorEnd:
;------------------------------------------------------------------------------------------
