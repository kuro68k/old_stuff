/*	=== Saturn to PSX converter ===
 
 	ATmega8 with internal oscillator ~8MHz
*/

.include "tn2313def.inc"

;----------------------------------------------------------------------
; Debug and build options
;----------------------------------------------------------------------

#define build_standard
;#define build_kyle
;#define debug_pad_always_connected

;----------------------------------------------------------------------
; Register and I/O definitions
;----------------------------------------------------------------------

; status registers
.def	bmap			= R1	; button mapping, bit 7 af def. on/off, bit 6 tourn. mode
.def	conn			= R2	; pad connected flag
.def	bheld			= R3	; start button held counter
.def	afbutton		= R4	; flag for autofire button on/off
.def	autospeed		= R5	; autofire speed
.def	emumode			= R6	; 0 = normal mode, 1 = PS2 Saturn Emulation mode
.def	tmode			= R7	; 0 = normal mode, 1 = tournament mode

; autofire
.def	afflag			= R10	; toggled by timer1 interrupt
.def	sregsave		= R11	; sreg save for interrupt

; LED flashing
.def	fcount			= R12
.def	fmask			= R13
.def	fstate			= R14

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
.equ	SAT_TR	=	0	; PORTD
.equ	SAT_TH	=	1	;
.equ	SAT_RT	=	2	;
.equ	SAT_LF	=	3	;
.equ	SAT_DN	=	4	;
.equ	SAT_UP	=	5	;
.equ	SAT_TL	=	0	; PORTA

; PSX pins
.equ	PS_ATT	=	3	; PORTB
.equ	PS_ACK	=	4	;
.equ	PS_CMD	=	5	;
.equ	PS_DAT	=	6	;
.equ	PS_CLK	=	7	;

; LED
.equ	LEDPIN	=	1	; PORTA

; Jumpers
.equ	J_PSS	=	6	; PORTD

; Autofire speed settings, 16 bit counter with prescaler = 64
.equ	AFLOH	=	0x44	; 7.5Hz
.equ	AFLOL	=	0xd4
.equ	AFNOH	=	0x22	; 15Hz
.equ	AFNOL	=	0x70
.equ	AFHIH	=	0x11	; 30Hz
.equ	AFHIL	=	0x35

; Start button hold time
.equ	BHTIME1	=	64		; enter setup mode time
.equ	BHTIME2	=	32		; leave setup mode time

; Highest button map available
.equ	HIGHMAP	=	6

;----------------------------------------------------------------------
; Vector table
;----------------------------------------------------------------------

.cseg

.org 0
		rjmp	reset		;RESET External Pin, Power-on Reset, Brown-out, and Watchdog Reset
		reti				;INT0 External Interrupt Request 0
		reti				;INT1 External Interrupt Request 1
		reti				;TIMER1 CAPT Timer/Counter1 Capture Event
		rjmp	afint		;TIMER1 COMPA Timer/Counter1 Compare Match A
		reti				;TIMER1 OVF Timer/Counter1 Overflow
		rjmp	flint		;TIMER0 OVF Timer/Counter0 Overflow
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
; Autofire interrupt on TIMER1 overflow
;----------------------------------------------------------------------

afint:
		in		sregsave, sreg
		com		afflag
		out		sreg, sregsave
		reti


;----------------------------------------------------------------------
; LED flash interrupt on TIMER0 overflow
;----------------------------------------------------------------------

flint:
		in		sregsave, sreg
		inc		bheld
		sbrc	fmask, 7				; enable bit
		rjmp	flint_exit
		inc		fcount
		and		fcount, fmask
		brne	flint_exit

		sbi		PORTA, LEDPIN
		com		fstate
		sbrs	fstate, 0
		cbi		PORTA, LEDPIN

flint_exit:
		out		sreg, sregsave
		reti


;----------------------------------------------------------------------
; Reset
;----------------------------------------------------------------------

reset:
		ldi		temp0, LOW(RAMEND)			; initialization of stack
		out		SPL, temp0

		;ldi		ZH, HIGH(bit_reverse_lut*2)	; prepare lookup table pointer

		ldi		temp0, 0x0f
		mov		fmask, temp0

		; PORTA setup
		ldi		temp0, 0b00000011			; TL and LED as outputs, J_PSS as input
		out		DDRA, temp0
		ldi		temp0, 0xff					; TL/LED high, pull up on J_PSS
		out		PORTA, temp0

		; PORTB setup
		ldi		temp0, 0x00					; all inputs
		out		DDRB, temp0
		ldi		temp0, ~((1<<PS_DAT)|(1<<PS_ACK))	; DAT/ACK float, rest have pull-ups
		out		PORTB, temp0

		; SPI interface
		ldi		temp0, (1<<USIWM0)				; Three-wire mode
		ori		temp0, (1<<USICS1)				; Positive edge shift, count on both edges
		out		USICR, temp0

		; PORTD setup
		ldi		temp0, (1<<SAT_TR)|(1<<SAT_TH)	; TR/TH outputs, rest inputs
		out		DDRD, temp0
		ldi		temp0, 0xff						; TR/TH start high, pull-ups
		out		PORTD, temp0

		; set up timer0 as LED flasher
		ldi		temp0, 0					; no PWM etc
		out		TCCR0A, temp0
		ldi		temp0, (1<<CS02)|(1<<CS00)	; 1024 prescaler
		out		TCCR0B, temp0
		in		temp0, TIMSK
		ori		temp0, (1<<TOIE0)
		out		TIMSK, temp0

		; set up timer1 as autofire toggle
		ldi		temp0, 0					; no PWM etc
		out		TCCR1A, temp0
		ldi		temp0, (1<<CS11)|(1<<CS10)	; 64 prescaler
		ori		temp0, (1<<WGM12)			; CTC mode
		out		TCCR1B, temp0
		ldi		temp0, AFNOH				; normal autofire speed
		out		OCR1AH, temp0
		ldi		temp0, AFNOL
		out		OCR1AL, temp0
		in		temp0, TIMSK
		ori		temp0, (1<<OCIE1A)
		out		TIMSK, temp0

		clr		conn
		clr		bmap
		clr		startf
		clr		afbutton
		clr		afflag
		clr		bheld
		clr		autospeed
		clr		emumode
		clr		tmode

		sei

;----------------------------------------------------------------------
; Wait for controller to be connected and then set button mapping
;----------------------------------------------------------------------

wait_conn:
		ldi		temp0, 0x0f				; start slow flashing
		rcall	setflash

		rcall	wait_saturn_conn		
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


;----------------------------------------------------------------------
; Set the LED flashing
;
; temp0, flashing rate mask, 0 for flashing off
; temp0 trashed
;----------------------------------------------------------------------

setflash:
		tst		temp0
		breq	setflash_off

		; turn on flashing
		mov		fmask, temp0
		ldi		temp0, 0xff
		mov		fstate, temp0
		sbi		PORTa, LEDPIN
		ret

setflash_off:
		mov		temp0, fmask
		ori		temp0, (1<<7)		; disabled bit
		mov		fmask, temp0
		cbi		PORTa, LEDPIN
		ret


.include "saturn.asm"
.include "psx.asm"
.include "eeprom.asm"
;.include "bit_reverse_lut.asm"
