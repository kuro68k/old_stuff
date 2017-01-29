/*	=== Saturn to PSX converter ===
 
 	ATmega8 with internal oscillator ~8MHz
*/

.include "tn2313def.inc"

;----------------------------------------------------------------------
; Debug and build options
;----------------------------------------------------------------------

; None so far

;----------------------------------------------------------------------
; Register and I/O definitions
;----------------------------------------------------------------------

; status registers
.def	tmode			= R7	; 0 = normal mode, 1 = tournament mode

; working registers
.def	temp0			= R16
.def	temp1			= R17
.def	temp2			= R18
.def	temp3			= R19
.def	temp4			= R20

; PSX I/O bytes
.def	psx0			= R24
.def	psx1			= R25

; PSX pins
.equ	PS_DAT	=	0	; PORTA 
.equ	PS_CMD	=	2	; PORTD
.equ	PS_CLK	=	4	;
.equ	PS_ACK	=	5	;
.equ	PS_ATT	=	3	;

; SNES pins
.equ	SNES_DAT=	1	; PORTB
.equ	SNES_LAT=	0	;
.equ	SNES_CLK=	6	; PORTD


;----------------------------------------------------------------------
; Vector table
;----------------------------------------------------------------------

.cseg

.org 0
		rjmp	reset		;RESET External Pin, Power-on Reset, Brown-out, and Watchdog Reset
		reti				;INT0 External Interrupt Request 0
		reti				;INT1 External Interrupt Request 1
		reti				;TIMER1 CAPT Timer/Counter1 Capture Event
		reti				;TIMER1 COMPA Timer/Counter1 Compare Match A
		reti				;TIMER1 OVF Timer/Counter1 Overflow
		reti				;TIMER0 OVF Timer/Counter0 Overflow
		reti				;USART, RXC USART, Rx Complete
		reti				;USART, UDRE USART Data Register Empty
		reti				;USART, TXC USART, Tx Complete
		reti				;ANA_COMP Analog Comparator
		reti				;PCINT
		reti				;TIMER1 COMPB Match B
		reti				;TIMER0 COMPA Match A
		reti				;TIMER0 COMPB Match B
		reti				;USI START
		reti				;USI OVERFLOW
		reti				;EE READY
		reti				;WDT OVERFLOW


;----------------------------------------------------------------------
; Reset
;----------------------------------------------------------------------

reset:
		ldi		temp0, LOW(RAMEND)		; initialization of stack
		out		SPL, temp0

		; PORTA setup
		ldi		temp0, 0				; all inputs
		out		DDRA, temp0
		ldi		temp0, ~(1<<PS_DAT)		; pull-ups, except DATA
		out		PORTA, temp0

		; PORTB setup
		ldi		temp0, (1<<SNES_LAT)	; Latch output, Data input
		out		DDRB, temp0
		ldi		temp0, ~(1<<SNES_LAT)	; Latch starts low, pull-ups
		out		PORTB, temp0

		; PORTD setup
		ldi		temp0, (1<<SNES_CLK)	; all inputs except SNES Clock
		out		DDRD, temp0
		ldi		temp0, ~(1<<PS_ACK)		; pull-ups + CLK starts high, PS_ACK floats
		out		PORTD, temp0

		clr		tmode

		sei

		rjmp	psx_mode

.include "psx.asm"
.include "snes.asm"

