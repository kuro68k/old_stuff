.include "tn461def.inc"

.def	calx	= R6	; joystick calibration
.def	caly	= R7

.def	rumble	= R8	; flags
.def	fail	= R9

.def	gc1		= R10	; Gamecube data
.def	gc2		= R11
.def	gcx		= R12
.def	gcy		= R13
.def	gcl		= R14
.def	gcr		= R15

.def	temp1	= R16
.def	temp2	= R17
.def 	nsix1	= R18
.def 	nsix2	= R19

.def	count	= R20
.def	timer	= R21

.def	param	= R22

.equ	MSD3	= 14	; 13
.equ	MSD2	= 7
.equ	MSD1	= 2		; 3

; Timing macro
.MACRO DELAY
		ldi		timer, @0
DELAY_LOOP:
		dec		timer
		brne	DELAY_LOOP
.ENDMACRO

.LISTMAC

;------------------------------------------------------------------------------------------
; Hardware setup
;------------------------------------------------------------------------------------------

;	N64			- PB3
;	Gamecube	- PB6
;	Debug		- PA0

.equ	nsd		= 3
.equ	gcd		= 6

;------------------------------------------------------------------------------------------
; Interrupt table
;------------------------------------------------------------------------------------------
.cseg

.org 0							;after reset
		rjmp	reset
.org INT0addr					;external interrupt INT0
		rjmp	INT0handler


;------------------------------------------------------------------------------------------
; Startup
;------------------------------------------------------------------------------------------
reset:
		ldi		temp1, HIGH(RAMEND)	; Upper byte
		out 	SPH,temp1			; to stack pointer
		ldi		temp1, LOW(RAMEND)	; Lower byte
		out		SPL, temp1			; to stack pointer

		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1

		clr		calx
		clr		caly

		clr		gc1
		clr		gc2
		clr		gcx
		clr		gcy
		clr		gcl
		clr		gcr

		cbi		PORTB, nsd		; inputs, no pull-ups (use external 3.3V pull ups)
		cbi		PORTB, gcd
		cbi		DDRB, nsd
		cbi		DDRB, gcd

		cbi		PORTA, 0		; N64 debug
		sbi		DDRA, 0
		cbi		PORTA, 1		; Gamecube debug
		sbi		DDRA, 1

		ldi		temp1, 1<<ISC01	; trigger on falling edge
		out		MCUCR, temp1
		ldi		temp1, 1<<INT0	; INT0 enabled
		out		GIMSK, temp1

		;sei						; interupts enabled

;------------------------------------------------------------------------------------------
; Main loop
;
; Continually read the pad
;------------------------------------------------------------------------------------------

mainloop:
		ldi		nsix1, 0
		ldi		nsix2, 0
		ldi		temp1, 0
		ldi		temp2, 0

		DELAY	255
		DELAY	150

		; send 0x00 to identify controller
		ldi		param, 0x00
		rcall	writebyte
		rcall	writestopbit

		; read three bytes for id
		rcall	readbyte
		mov		nsix1, param
		rcall	readbyte
		mov		nsix2, param
		rcall	readbyte
		mov		temp1, param

		DELAY	255
		DELAY	150

		cpi		nsix1, 0x05		; N64 pad
		breq	readn64

		cli						; no N64 pad, so stop responding to GC polls
		clr		calx			; reset calibration data
		clr		caly

		rjmp	mainloop

;------------------------------------------------------------------------------------------
; Read N64 controller
;
; Continually read N64 controller and update GC data
;------------------------------------------------------------------------------------------
readn64:
		ldi		nsix1, 0
		ldi		nsix2, 0
		ldi		temp1, 0
		ldi		temp2, 0

		; send 0x01 to read controller status words
		ldi		param, 0x01
		rcall	writebyte
		rcall	writestopbit

		sbi		PORTA, 0		; debug

		; read three bytes for id
		rcall	readbyte		; buttons 1
		mov		nsix1, param
		rcall	readbyte		; buttons 2
		mov		nsix2, param

		rcall	readbyte		; stick x
		mov		temp1, param
		rcall	readbyte		; stick y
		mov		temp2, param

		cbi		PORTA, 0		; debug
		sbi		PORTA, 0
		cbi		PORTA, 0
		sbi		PORTA, 0
		cbi		PORTA, 0
		sbi		PORTA, 0
		cbi		PORTA, 0

		mov		gcx, temp1		; x/y can be transferred directly over
		mov		gcy, temp2

		ldi		temp1, 0		; check if calibration data needs setting
		cp		calx, temp1
		breq	setcalibration

		ldi		temp1, 0
		ldi		temp2, 0

		; 1:	N64				Gamecube
		;		0 - Right		2-1
		;		1 - Left		2-0
		;		2 - Down		2-2
		;		3 - Up			2-3
		;		4 - Start		1-4
		;		5 - Z			2-4
		;		6 - B			1-1
		;		7 - A			1-0

		; d-pad to hat switch is decoding done by n64gc.c, returned in r24
		sbrc	nsix1, 7		; A
		ori		temp1, (1<<0)
		sbrc	nsix1, 6		; B
		ori		temp1, (1<<1)
		sbrc	nsix1, 5		; Z
		ori		temp2, (1<<4)
		sbrc	nsix1, 4		; Start
		ori		temp1, (1<<4)

		sbrc	nsix1, 4		; Start
		sbi		PORTA, 1
		sbrc	nsix1, 4		; Start
		cbi		PORTA, 1

		sbrc	nsix1, 3		; Up
		ori		temp2, (1<<3)
		sbrc	nsix1, 2		; Down
		ori		temp2, (1<<2)
		sbrc	nsix1, 1		; Left
		ori		temp2, (1<<0)
		sbrc	nsix1, 0		; Right
		ori		temp2, (1<<1)

		; 2:	N64				Gamecube
		;		0 - C-Right		1-3 (Y)
		;		1 - C-Left		(change joystick mapping to c-stick)
		;		2 - C-Down		1-2 (X)
		;		3 - C-Up		(change joystick mapping to joystick)
		;		4 - R			2-5
		;		5 - L			2-6

		sbrc	nsix1, 5		; L
		ori		temp2, (1<<5)
		sbrc	nsix1, 4		; R
		ori		temp2, (1<<6)
		sbrc	nsix1, 2		; C-Down
		ori		temp1, (1<<2)
		sbrc	nsix1, 0		; C-Right
		ori		temp1, (1<<3)

		;sbrc	nsix1, 3		; C-Up
		;ori		temp2, (1<<0)
		;sbrc	nsix1, 1		; C-Left
		;ori		temp2, (1<<3)

		ori		temp2, (1<<7)	; bit 7 always 1

		mov		gc1, temp1		; update GC status
		mov		gc2, temp2

		sei						; start responding to Gamecube if not already

		rjmp	mainloop

;------------------------------------------------------------------------------------------
; Set calibration data to the first stick readings taken
;------------------------------------------------------------------------------------------
setcalibration:
		mov		calx, gcx
		mov		caly, gcy

		sbi		PORTA, 1		; debug
		nop
		sbi		PORTA, 0
		nop
		cbi		PORTA, 1
		nop
		cbi		PORTA, 0

		sei						; start responding to the Gamecube

		rjmp	mainloop

;------------------------------------------------------------------------------------------
; Read byte from N64 controller
;
; Byte in param, timer and count trashed
;------------------------------------------------------------------------------------------
readbyte:
		ldi		param, 0
		ldi		timer, 20
		ldi		count, 8
in_byte:
		dec		timer
		breq	timeout
		sbic	PINB, nsd
		rjmp	in_byte
		DELAY	MSD2			;~2us
		lsl		param
		sbic	PINB, nsd
		ori		param, 0b00000001

		sbrc	param, 0
		sbi		PORTA, 0		; debug
		cbi		PORTA, 0		; debug

		ldi		timer, 20
in_wait_high:
		dec		timer
		breq	timeout
		sbis	PINB, nsd
		rjmp	in_wait_high
		dec		count
		brne	in_byte

timeout:
		ret

;------------------------------------------------------------------------------------------
; Write byte to N64 controller
;
; Byte in param, param and count trashed
;------------------------------------------------------------------------------------------
writebyte:
		ldi		count, 8

out_loop:
		sbrc	param, 7
		rjmp	out_1
		
		; send a 0
		sbi		DDRB, nsd
		DELAY	MSD3
		nop
		cbi		DDRB, nsd
		DELAY	MSD1
		nop
		nop
		lsl		param
		dec		count
		brne	out_loop

		ret

out_1:
		; send a 1
		sbi		DDRB, nsd
		DELAY	3			; MSD1
		nop
		nop
		nop
		cbi		DDRB, nsd
		DELAY	MSD3
		nop
		lsl		param
		dec		count
		brne	out_loop

		ret

;------------------------------------------------------------------------------------------
; Write stop bit to N64 controller
;
; timer trashed
;------------------------------------------------------------------------------------------
writestopbit:
		; send stop bit
		sbi		DDRB, nsd
		DELAY	4
		nop
		cbi		DDRB, nsd

		ret

;------------------------------------------------------------------------------------------
; Handle poll from Gamecube
;------------------------------------------------------------------------------------------
INT0handler:
		sbic	PINB, gcd		; make sure data pin is low to prevent false starts
		reti

		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		cbi		PORTA, 0

		; Assume first bit is 0. We then have time to save work registers before next bit.
		push	temp1
		push	temp2
		push	timer
		push	count
		push	param

		ldi		temp1, 0

		; Read 7 bits
		ldi		count, 7
gcread:
		ldi		timer, 20
gcread_wait_high:
		dec		timer
		breq	gctimeout
		sbis	PINB, gcd
		rjmp	gcread_wait_high

		ldi		timer, 20
gcread_wait_low:
		dec		timer
		breq	gctimeout
		sbic	PINB, gcd
		rjmp	gcread_wait_low

		DELAY	MSD2			; ~2us
		lsl		temp1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbic	PINB, gcd
		ori		temp1, 0b00000001

		dec		count
		brne	gcread

		; Check for 0x40 command, in which case we need to read two more bytes.
		; Otherwise, expect stop bit

		cpi		temp1, 0x40
		breq	gcreturn_status

		rcall	gcreadstopbit	; wait for stop bit

		; Check command
		; Note - stop bit is still low at this point, need to wait for line to go high
		; again.
		cpi		temp1, 0x00		; get controller ID
		brne	gc_not_id		; due to jump limits on conditional branching
		rjmp	gcreturn_id

gc_not_id:
		cpi		temp1, 0x41		; origins
		brne	gc_not_origins	; due to jump limits on conditional branching
		rjmp	gcreturn_origins

gc_not_origins:
		; Unknown command or bad data, exit with timeout failure on debug

;------------------------------------------------------------------------------------------
; Write timeout failure to GC debug
;
; timer trashed
;------------------------------------------------------------------------------------------
gctimeout:
		DELAY	20
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1

;------------------------------------------------------------------------------------------
; Exit from interrupt, restore saved registers
;------------------------------------------------------------------------------------------
exitint0:
		pop		param
		pop		count
		pop		timer
		pop		temp2
		pop		temp1
		reti

;------------------------------------------------------------------------------------------
; Wait for stop bit to arrive and finish
;------------------------------------------------------------------------------------------
gcreadstopbit:
		ldi		timer, 50
gcread_stop_bit_high1:
		dec		timer
		breq	gctimeout
		sbis	PINB, gcd
		rjmp	gcread_stop_bit_high1

		ldi		timer, 50
gcread_stop_bit_low:
		dec		timer
		breq	gctimeout
		sbic	PINB, gcd
		rjmp	gcread_stop_bit_low

		ldi		timer, 50
gcread_stop_bit_high2:
		dec		timer
		breq	gctimeout
		sbis	PINB, gcd
		rjmp	gcread_stop_bit_high2

		ret

;------------------------------------------------------------------------------------------
; Return GC controller status
;------------------------------------------------------------------------------------------
gcreturn_status:
		; Read two more bytes
		; Could make a function for this but there is plenty of ROM space so...
		ldi		count, 8
		ldi		temp1, 0
gcread1:
		ldi		timer, 20
gcread_wait_high1:
		dec		timer
		breq	gctimeout
		sbis	PINB, gcd
		rjmp	gcread_wait_high1

		ldi		timer, 20
gcread_wait_low1:
		dec		timer
		breq	gctimeout
		sbic	PINB, gcd
		rjmp	gcread_wait_low1

		DELAY	MSD2			; ~2us
		lsl		temp1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbic	PINB, gcd
		ori		temp1, 0b00000001

		dec		count
		brne	gcread1

		; Byte 2
		ldi		count, 8
gcread2:
		ldi		timer, 20
gcread_wait_high2:
		dec		timer
		breq	gctimeout2
		sbis	PINB, gcd
		rjmp	gcread_wait_high2

		ldi		timer, 20
gcread_wait_low2:
		dec		timer
		breq	gctimeout2
		sbic	PINB, gcd
		rjmp	gcread_wait_low2

		DELAY	MSD2			; ~2us
		lsl		temp2
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbic	PINB, gcd
		ori		temp2, 0b00000001

		dec		count
		brne	gcread2

		rcall	gcreadstopbit	; wait for stop bit

		; Check command
		cpi		temp1, 0x03		; only known command, check status
		brne	gctimeout2		; otherwise fail

		mov		param, gc1		; 0 buttons
		rcall	gcwritebyte
		mov		param, gc2		; 1 buttons
		rcall	gcwritebyte
		mov		param, gcx		; 2 joystick x
		rcall	gcwritebyte
		mov		param, gcy		; 3 joystick y
		rcall	gcwritebyte
		ldi		param, 0x80		; 4 c-stick x
		rcall	gcwritebyte
		ldi		param, 0x80		; 5 c-stick y
		rcall	gcwritebyte
		mov		param, gcl		; 6 left trigger
		rcall	gcwritebyte
		mov		param, gcr		; 7 right trigger
		rcall	gcwritebyte

		rcall	gcwritestopbit

		sbi		PORTA, 1		; debug
		cbi		PORTA, 1

		rjmp	exitint0

;------------------------------------------------------------------------------------------
; Write timeout failure to GC debug
;
; Same as gctimeout, placed here so it is in reach of conditional branches in
; gcreturn_status
;
; timer trashed
;------------------------------------------------------------------------------------------
gctimeout2:
		DELAY	20
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1
		sbi		PORTA, 1		; debug
		cbi		PORTA, 1

		rjmp	exitint0

;------------------------------------------------------------------------------------------
; Return GC controller origins
;
; Return an ideal result of 00 80 80 80 80 80 00 00 02 02
;							0  1  2  3  4  5  6  7  8  9
;------------------------------------------------------------------------------------------
gcreturn_origins:
		DELAY	1
		nop
		nop
		nop
		nop

		sbi		PORTA, 1		; debug
		cbi		PORTA, 1

		ldi		param, 0x00		; 0
		rcall	gcwritebyte
		ldi		param, 0x80		; 1
		rcall	gcwritebyte
		ldi		param, 0x80		; 2
		rcall	gcwritebyte
		ldi		param, 0x80		; 3
		rcall	gcwritebyte
		ldi		param, 0x80		; 4
		rcall	gcwritebyte
		ldi		param, 0x80		; 5
		rcall	gcwritebyte
		ldi		param, 0x00		; 6
		rcall	gcwritebyte
		ldi		param, 0x00		; 7
		rcall	gcwritebyte
		ldi		param, 0x02		; 8
		rcall	gcwritebyte
		ldi		param, 0x02		; 9
		rcall	gcwritebyte

		rcall	gcwritestopbit

		sbi		PORTA, 1		; debug
		cbi		PORTA, 1

		rjmp	exitint0		

;------------------------------------------------------------------------------------------
; Return GC controller ID
;------------------------------------------------------------------------------------------
gcreturn_id:
		DELAY	1
		nop
		nop
		nop
		nop

		sbi		PORTA, 1		; debug
		cbi		PORTA, 1

		ldi		param, 0x09
		rcall	gcwritebyte
		ldi		param, 0x00
		rcall	gcwritebyte
		ldi		param, 0x20
		rcall	gcwritebyte
		rcall	gcwritestopbit

		sbi		PORTA, 1		; debug
		cbi		PORTA, 1

		rjmp	exitint0		

;------------------------------------------------------------------------------------------
; Write byte to GC controller
;
; Byte in param, param and count trashed
;------------------------------------------------------------------------------------------
gcwritebyte:
		ldi		count, 8

gc_out_loop:
		sbrc	param, 7
		rjmp	gc_out_1
		
		; send a 0
		sbi		DDRB, gcd
		DELAY	MSD3
		nop
		cbi		DDRB, gcd
		DELAY	MSD1
		nop
		nop
		lsl		param
		dec		count
		brne	gc_out_loop

		ret

gc_out_1:
		; send a 1
		sbi		DDRB, gcd
		DELAY	MSD1
		nop
		nop
		cbi		DDRB, gcd
		DELAY	MSD3

		sbi		PORTA, 0		; debug
		cbi		PORTA, 0

		nop
		lsl		param
		dec		count
		brne	gc_out_loop

		ret

;------------------------------------------------------------------------------------------
; Write stop bit to GC controller
;
; timer trashed
;------------------------------------------------------------------------------------------
gcwritestopbit:
		; send stop bit
		DELAY	9
		sbi		DDRB, gcd
		DELAY	MSD1
		cbi		DDRB, gcd

		ret
