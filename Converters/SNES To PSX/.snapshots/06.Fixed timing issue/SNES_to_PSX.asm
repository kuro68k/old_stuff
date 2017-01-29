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
.equ	PS_ATT	=	3	; PORTB
.equ	PS_ACK	=	4	;
.equ	PS_CMD	=	5	;
.equ	PS_DAT	=	6	;
.equ	PS_CLK	=	7	;

; SNES pins
.equ	SNES_DAT=	3	; PORTD
.equ	SNES_LAT=	4	;
.equ	SNES_CLK=	5	;

; Optional LED
.equ	LEDPIN	=	1	; PORTA

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
		ldi		temp0, (1<<LEDPIN)		; all inputs except LED
		out		DDRA, temp0
		ldi		temp0, ~(1<<LEDPIN)		; all pull-ups, LED on
		out		PORTA, temp0

		; PORTD setup
		ldi		temp0, (1<<SNES_LAT)|(1<<SNES_CLK)	; Data input, Latch/Clock outputs
		out		DDRD, temp0
		ldi		temp0, ~(1<<SNES_LAT)	; Latch starts low, Clock high, pull-ups
		out		PORTD, temp0

		; PORTB setup
		ldi		temp0, 0x00				; all inputs
		out		DDRB, temp0
		ldi		temp0, ~((1<<PS_DAT)|(1<<PS_ACK))	; DAT/ACK float, rest have pull-ups
		out		PORTB, temp0

		; SPI interface
		ldi		temp0, (1<<USIWM0)				; Three-wire mode
		ori		temp0, (1<<USICS1)				; Positive edge shift, count on both edges
		out		USICR, temp0

		clr		tmode

		sei

		rjmp	psx_mode

.include "psx.asm"
.include "snes.asm"

