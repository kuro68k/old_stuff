/*	=== Saturn to Supergun/NeoGeo ===
 
 	ATmega8 with internal oscillator ~8MHz
*/

.include "m8def.inc"

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

; 7 segment LED display bitmaps
.def	seg0			= R7	; left
.def	seg1			= R8	; right

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

; PORT shadows
.def	pbs				= R24
.def	pcs				= R25

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
.equ	SEG_OE	=	5	;
.equ	SEG_LAT	=	7	; PORTB

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

; Status bits on bmap
.equ	AF_DEF	=	7
.equ	TMODE	=	6

; Supergun/NeoGeo I/O
#define	LPP			pbs
.equ	LPB		=	3
#define	MPP			pcs
.equ	MPB		=	2
#define	HPP			pbs
.equ	HPB		=	4
#define	LKP			pcs
.equ	LKB		=	3
#define	MKP			pcs
.equ	MKB		=	4
#define	HKP			pcs
.equ	HKB		=	5

#define	STP			pbs
.equ	STB		=	5
#define	SPP			pbs
.equ	SPB		=	0

#define	UPP			pbs
.equ	UPB		=	1
#define	DNP			pcs
.equ	DNB		=	0
#define	LFP			pbs
.equ	LFB		=	2
#define	RTP			pcs
.equ	RTB		=	1

;----------------------------------------------------------------------
; Vector table
;----------------------------------------------------------------------

.cseg

.org 0
		rjmp	reset		;RESET External Pin, Power-on Reset, Brown-out, and Watchdog Reset
		reti				;INT0 External Interrupt Request 0
		reti				;INT1 External Interrupt Request 1
		reti				;TIMER2 COMP Timer/Counter2 Compare Match
		rjmp	flint		;TIMER2 OVF Timer/Counter2 Overflow
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
		out		sreg, sregsave
		reti


;----------------------------------------------------------------------
; LED flash interrupt on TIMER2 overflow
;----------------------------------------------------------------------

flint:
		in		sregsave, sreg
		inc		bheld
		sbrc	fmask, 7				; enable bit
		rjmp	flint_exit
		inc		fcount
		and		fcount, fmask
		brne	flint_exit

		sbi		PORTD, SEG_OE
		com		fstate
		sbrs	fstate, 0
		cbi		PORTD, SEG_OE

flint_exit:
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

		ldi		temp0, 0x0f
		mov		fmask, temp0

		; Watchdog timer setup
		;wdr
		;ldi		temp0, (1<<WDCE)|(1<<WDE)|(1<<WDP2)	; 0.25s timeout

		; PORTD setup
		; TH/TR/OE/NC-L outputs, rest inputs
		ldi		temp0, (1<<SAT_TH)|(1<<SAT_TR)|(1<<SEG_OE)|(1<<6)
		out		DDRD, temp0
		ldi		temp0, ~(1<<SEG_OE)		; pull-ups / TH/TR/NC-L start high, OE start low
		out		PORTD, temp0

		; PORTC setup
		ldi		temp0, 0xff				; all outputs
		out		DDRC, temp0
		ldi		temp0, 0xff				; start high
		out		PORTC, temp0

		; PORTB setup
		ldi		temp0, ~(1<<6)			; all outputs except Saturn D2/LF
		out		DDRB, temp0
		ldi		temp0, 0xff				; pull-ups / start high
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

		; set up timer2 as LED flasher
		ldi		temp0, (1<<CS22)|(1<<CS21)|(1<<CS20)	; 256 prescaler
		out		TCCR2, temp0
		ldi		temp0, 0				; I/O clock
		out		ASSR, temp0
		in		temp0, TIMSK
		ori		temp0, (1<<TOIE2)
		out		TIMSK, temp0

		clr		conn
		clr		bmap
		clr		startf
		clr		afbutton
		clr		afflag
		clr		bheld
		clr		autospeed
		clr		emumode

		sei

		;ldi		temp0, 0xbf				; -
		;mov		seg0, temp0
		;mov		seg1, temp0
		;rcall	update_leds

		;ldi		temp0, 0x0f				; start slow flashing
		;rcall	setflash

		;rcall	delay250ms

		rcall	eeprom_read_config
		ldi		temp0, 0
		rcall	setflash
		rcall	update_bmap_leds
		rcall	update_autof_leds
		rcall	update_leds

		; TH = 1, TR = 0
		sbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB
;		sbrc	temp2, SAT_RT		; Start -> Start 
;		rjmp	tournament_mode

		rjmp	sg_mode

;tournament_mode:
;		or

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
; Read jumpers and update config
;----------------------------------------------------------------------

jumper_read_config:
		push	temp0

		; Fixed MoJo button mapping jumper
		sbic	PIND, 7					; jumper = emulation mode
		rjmp	jumper_emu_off

		ldi		temp0, 1				; check if emulation mode needs updating
		cp		temp0, emumode
		brne	jumper_set_emu_mode
		rjmp	jumper_exit

jumper_set_emu_mode:
		ldi		temp0, 1
		mov		emumode, temp0
		clr		autospeed				; autofire off 
		ldi		temp0, 2
		mov		bmap, temp0
		rcall	update_bmap_leds
		rcall	update_autof_leds
		rcall	update_leds
		rjmp	jumper_exit

jumper_emu_off:
		ldi		temp0, 0
		cp		temp0, emumode
		brne	jumper_clear_emu_mode
		rjmp	jumper_exit

jumper_clear_emu_mode:
		clr		emumode
		clr		bmap
		rcall	update_bmap_leds
		rcall	update_autof_leds
		rcall	update_leds
		rjmp	jumper_exit

jumper_exit:
		pop		temp0
		ret

.include "saturn.asm"
.include "supergun.asm"
.include "7seg.asm"
.include "eeprom.asm"

debugled:
		push	temp0
		push	temp1
		push	temp2

		ldi		temp0, 0x01
		rcall	setflash

		ldi		temp0, 128
debugled_l0:
		ldi		temp1, 0
debugled_l1:
		ldi		temp2, 0
debugled_l2:
		dec		temp2
		brne	debugled_l2
		dec		temp1
		brne	debugled_l1
		dec		temp0
		brne	debugled_l0

		pop		temp2
		pop		temp1
		pop		temp0
		ret
