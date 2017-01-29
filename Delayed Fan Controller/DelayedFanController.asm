/*	=== Fan speed controller with startup delay ===
 
 	ATtiny13 with internal oscillator ~9.6MHz
*/

.include "tn13def.inc"

;----------------------------------------------------------------------
; Register and I/O definitions
;----------------------------------------------------------------------

; working registers
.def	temp0			= R20
.def	temp1			= R21

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
		reti				;TIMER1 COMPA Timer/Counter1 Compare Match A
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
; Reset
;----------------------------------------------------------------------

reset:
		wdr
		; 0.5 seconds timout
		;ldi		temp0, (1<<WDE)|(1<<WDCE)|(1<<WDE)|(1<<WDP2)|(1<<WDP0)
		;out		WDTCR, temp0

		ldi		temp0, LOW(RAMEND)		; initialization of stack
		out		SPL, temp0
		;ldi		temp0, HIGH(RAMEND)
		;out		SPH, temp0

		wdr

		; PORTB setup
		ldi		temp0, 0xff				; all outputs
		out		DDRB, temp0
		ldi		temp0, 0xff				; start on
		out		PORTB, temp0


;----------------------------------------------------------------------
; Main code
;----------------------------------------------------------------------

		ldi		temp0, 2				; 2 second delay 
startuploop:
		wdr
		rcall	delay1s
		dec		temp0
		brne	startuploop

		ldi		temp0, 0				; turn off fan
		out		PORTB, temp0

pwmloop:
		;sleep
		nop
		rjmp	pwmloop

		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		sbi		PORTB, 3
		cbi		PORTB, 3
		rjmp	pwmloop

		sbi		PORTB, 3
		nop
		cbi		PORTB, 3
		nop
		nop
		rjmp	pwmloop


;----------------------------------------------------------------------
; Delay 1 second
;----------------------------------------------------------------------

delay1s:
			ldi  R17, $33
WGLOOP0:	ldi  R18, $F8
WGLOOP1:	ldi  R19, $FC
WGLOOP2:	dec  R19
			brne WGLOOP2
			dec  R18
			brne WGLOOP1
			dec  R17
			wdr
			brne WGLOOP0
			ret
