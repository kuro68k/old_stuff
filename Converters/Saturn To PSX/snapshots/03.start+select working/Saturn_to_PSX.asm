/*	=== Saturn to Supergun, NeoGeo and PSX adapter ===
 
 	ATmega8 with internal oscillator ~8MHz
*/

.include "m8def.inc"

;----------------------------------------------------------------------
; Debug and build options
;----------------------------------------------------------------------

;#define	charmode

;----------------------------------------------------------------------
; Register and I/O definitions
;----------------------------------------------------------------------

; status registers
.def	bmap			= R1	; button mapping
.def	conn			= R2	; pad connected flag
.def	afbutton		= R4	; flag for autofire button on/off
.def	autospeed		= R6	; autofire speed

; 7 segment LED display bitmaps
.def	seg0			= R7	; left
.def	seg1			= R8	; right

; autofire
.def	afflag			= R10	; toggled by timer1 interrupt
.def	sregsave		= R11	; sreg save for interrupt

; working registers
.def	temp0			= R16
.def	temp1			= R17
.def	temp2			= R18
.def	temp3			= R19
.def	temp4			= R20

; start button flag
.def	startf			= R21

; PORT shadows for Saturn I/O
.def	psx0			= R24
.def	psx1			= R25

; Saturn pins
.equ	SAT_DN	=	0	; PORTD
.equ	SAT_UP	=	1	;
.equ	SAT_TH	=	2	;
.equ	SAT_TR	=	3	;
.equ	SAT_RT	=	4	;
.equ	SAT_LF	=	6	; PORTB

; 7 segment LED display pins
.equ	SEG_DAT	=	2	; PORTD
.equ	SEG_CLK	=	3	;
.equ	SEG_LAT	=	7	; PORTB

; PSX pins
.equ	PS_DAT	=	4	; PORTC
.equ	PS_CMD	=	3	;
.equ	PS_CLK	=	1	;
.equ	PS_ACK	=	0	;
.equ	PS_ATT	=	2	;

; Jumpers
.equ	J1		=	7	; PORTB
.equ	J2		=	5	; PORTD

; Autofire speed settings, 16 bit counter with prescaler = 64
.equ	AFLOH	=	0x44	; 7.5Hz
.equ	AFLOL	=	0xd4
.equ	AFNOH	=	0x22	; 15Hz
.equ	AFNOL	=	0x70
.equ	AFHIH	=	0x11	; 30Hz
.equ	AFHIL	=	0x35

;----------------------------------------------------------------------
; Vector table
;----------------------------------------------------------------------

.cseg

.org 0
		rjmp	reset		;RESET External Pin, Power-on Reset, Brown-out, and Watchdog Reset
		reti				;INT0 External Interrupt Request 0
		reti				;INT1 External Interrupt Request 1
		reti				;TIMER2 COMP Timer/Counter2 Compare Match
		reti				;TIMER2 OVF Timer/Counter2 Overflow
		reti				;TIMER1 CAPT Timer/Counter1 Capture Event
		rjmp	afint		;TIMER1 COMPA Timer/Counter1 Compare Match A
		reti				;TIMER1 COMPB Timer/Counter1 Compare Match B
		reti				;TIMER1 OVF Timer/Counter1 Overflow
		reti				;TIMER0 OVF Timer/Counter0 Overflow
		reti				;SPI, STC Serial Transfer Complete
		reti				;USART, RXC USART, Rx Complete
		reti				;USART, UDRE USART Data Register Empty
		reti				;USART, TXC USART, Tx Complete
		reti				;ADC ADC Conversion Complete
		reti				;EE_RDY EEPROM Ready
		reti				;ANA_COMP Analog Comparator
		reti				;TWI Two-wire Serial Interface
		reti				;SPM_RDY Store Program Memory Ready

;----------------------------------------------------------------------
; Autofire interrupt on TIMER1 overflow
;----------------------------------------------------------------------

afint:
		in		sregsave, sreg
		com		afflag
		sbi		DDRC, 4
		sbi		PORTC, 4
		cbi		PORTC, 4
		out		sreg, sregsave
		reti

;----------------------------------------------------------------------
; Reset
;----------------------------------------------------------------------

reset:
		ldi		temp0, LOW(RAMEND)		; initialization of stack
		out		SPL, temp0
		ldi		temp0, HIGH(RAMEND)
		out		SPH, temp0

		; Watchdog timer setup
		;wdr
		;ldi		temp0, (1<<WDCE)|(1<<WDE)|(1<<WDP2)	; 0.25s timeout

		; PORTD setup
		ldi		temp0, (1<<SAT_TH)|(1<<SAT_TR)	; TH/TR outputs, rest inputs
		out		DDRD, temp0
		ldi		temp0, 0b11111111				; pull-ups / start high
		out		PORTD, temp0

		; PORTC setup
		ldi		temp0, 0b00010001		; all outputs except data and ack
		out		DDRC, temp0
		ldi		temp0, 0b00111111		; pull-ups / start high
		out		PORTC, temp0

		; PORTB setup
		ldi		temp0, (1<<7)			; all inputs except LED latch
		out		DDRB, temp0
		ldi		temp0, ~(1<<7)			; pull-ups, latch starts low
		out		PORTB, temp0

		; set up timer0 as 10ms timeout counter for PSX I/O
		ldi		temp0, (1<<CS02)|(1<<CS00)	; 1024 prescaler
		out		TCCR0, temp0

		; set up timer1 as autofire toggle
		ldi		temp0, 0					; no output
		out		TCCR1A, temp0
		ldi		temp0, (1<<CS11)|(1<<CS10)	; 64 prescaler
		ori		temp0, (1<<WGM12)			; CTC mode
		out		TCCR1B, temp0
		ldi		temp0, AFNOH				; normal autofire speed
		out		OCR1AH, temp0
		ldi		temp0, AFNOL
		out		OCR1AL, temp0
		ldi		temp0, (1<<OCIE1A)
		out		TIMSK, temp0

		sei

;----------------------------------------------------------------------
; Wait for controller to be connected and then set button mapping
;----------------------------------------------------------------------

wait_conn:
		clr		conn
		clr		bmap
		clr		startf
		clr		afbutton
		clr		afflag
		ldi		temp0, 0
		mov		autospeed, temp0

		ldi		temp0, 0xbf				; -
		mov		seg0, temp0
		mov		seg1, temp0
		rcall	update_leds

;----------------------------------------------------------------------
; Wait for Saturn to be connected and then set button mapping
;----------------------------------------------------------------------

wait_saturn_conn:
		; TH = 1, TR = 1
		in		temp2, PORTD
		ori		temp2, (1<<SAT_TH)|(1<<SAT_TR)
		ldi		temp2, 0xff
		out		PORTD, temp2
		rcall	sat_delay

wait_saturn_conn_loop:
		in		temp2, PIND
		in		temp1, PINB

		; do three checks, all must pass for controller to be detected
		ldi		temp0, 0
		sbrs	temp2, SAT_UP		; Up = 0
		inc		temp0
		sbrs	temp2, SAT_DN		; Down = 0
		inc		temp0
		sbrc	temp1, SAT_LF		; Left = 1
		inc		temp0

		cpi		temp0, 3
		brne	wait_saturn_conn

		rcall	delay250ms

		ldi		temp0, 0x01			; set connected flag to Saturn
		mov		conn, temp0

/*
		ldi		temp0, AFNOH		; normal autofire speed
		out		OCR1AH, temp0
		ldi		temp0, AFNOL
		out		OCR1AL, temp0
		ldi		temp0, 2
		mov		autospeed, temp0
*/

		; determine button mapping
		ldi		temp0, 0			; button mapping
		ldi		temp3, 0			; tournament mode/AF switch
		;in		temp2, PIND
		sbrc	temp2, SAT_RT		; L = autofire low speed
		;ldi		temp0, 7
		rjmp	afnorm1
		ldi		temp2, AFLOH
		out		OCR1AH, temp2
		ldi		temp2, AFLOL
		out		OCR1AL, temp2
		ldi		temp2, 1
		mov		autospeed, temp2
afnorm1:

		; TH = 1, TR = 0
		in		temp2, PORTD
		andi	temp2, ~(1<<SAT_TR)
		ori		temp2, (1<<SAT_TH)
		out		PORTD, temp2
		rcall	sat_delay
		in		temp2, PIND
		in		temp1, PINB
		sbrs	temp2, SAT_UP		; B
		ldi		temp0, 2
		sbrs	temp2, SAT_DN		; C
		ldi		temp0, 3
		sbrs	temp1, SAT_LF		; A
		ldi		temp0, 1
		sbrs	temp2, SAT_RT		; Start = tournament mode or AF switch
		ldi		temp3, 1
		; TH = 0, TR = 0
		in		temp2, PORTD
		andi	temp2, ~((1<<SAT_TR)|(1<<SAT_TH))
		out		PORTD, temp2
		rcall	sat_delay
		in		temp2, PIND
		in		temp1, PINB
		sbrs	temp2, SAT_UP		; Z
		ldi		temp0, 6
		sbrs	temp2, SAT_DN		; Y
		ldi		temp0, 5
		sbrs	temp1, SAT_LF		; X
		ldi		temp0, 4
		sbrc	temp2, SAT_RT		; R = autofire high speed
		;ldi		temp0, 8
		rjmp	afnorm2
		ldi		temp2, AFNOH
		out		OCR1AH, temp2
		ldi		temp2, AFNOL
		out		OCR1AL, temp2
		ldi		temp2, 2
		mov		autospeed, temp2
afnorm2:

		; set tournament mode/AF switch flag
		sbrc	temp3, 0
		ori		temp0, (1<<7)
		mov		bmap, temp0

		andi	temp0, ~(1<<7)
		ldi		temp1, 0
#ifdef charmode
		ldi		ZH, HIGH(2*led_chars)
		ldi		ZL, LOW(2*led_chars)
#else
		ldi		ZH, HIGH(2*led_digits)
		ldi		ZL, LOW(2*led_digits)
#endif
		add		ZL, temp0
		adc		ZH, temp1
		lpm
		mov		seg0, R0

		rcall	update_autof_leds
		rcall	update_leds

		rjmp	psx_mode


;----------------------------------------------------------------------
; 250ms delay for things to settle
;----------------------------------------------------------------------

delay250ms:
		push	temp0
		push	temp1
		push	temp2
		ldi		temp0, 0x24
set_loop_0:
		ldi		temp1, 0xbc
set_loop_1:
		ldi		temp2, 0x50		;0xc4 = 500ms
set_loop_2:
		dec		temp2
		brne	set_loop_2
		wdr
		dec		temp1
		brne	set_loop_1
		dec		temp0
		brne	set_loop_0
		pop		temp2
		pop		temp1
		pop		temp0
		ret

.include "saturn.asm"
.include "psx.asm"
.include "7seg.asm"
