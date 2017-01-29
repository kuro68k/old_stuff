/*
		ldi		temp0, 0
		ldi		temp3, 0
test:
		;mov		seg0, temp0
		;mov		seg1, temp0
		;rol		temp0
		ldi		ZH, HIGH(2*led_digits)
		ldi		ZL, LOW(2*led_digits)
		add		ZL, temp0
		adc		ZH, temp3
		lpm
		mov		seg0, R0
		mov		seg1, R0
		rcall	update_leds
		inc		temp0
		cpi		temp0, 10
		brne	test_skip
		ldi		temp0, 0
test_skip:
		ldi		temp1, 0
test_delay0:
		ldi		temp2, 0
test_delay1:
		ldi		temp3, 50
test_delay2:
		dec		temp3
		brne	test_delay2
		dec		temp2
		brne	test_delay1
		dec		temp1
		brne	test_delay0
		rjmp	test
*/

;----------------------------------------------------------------------
; 7 segment LED display update
;----------------------------------------------------------------------

update_leds:
		push	temp0
		push	temp1

		sbi		DDRB, SEG_LAT
		cbi		PORTD, SEG_DAT
		cbi		PORTD, SEG_CLK
		cbi		PORTB, SEG_LAT

		mov		temp0, seg1			; autofire
		ldi		temp1, 8
update_leds_loop0:
		sbi		PORTD, SEG_DAT
		sbrs	temp0, 7
		cbi		PORTD, SEG_DAT
		sbi		PORTD, SEG_CLK
		cbi		PORTD, SEG_CLK
		lsl		temp0
		dec		temp1
		brne	update_leds_loop0

		mov		temp0, seg0			; button mapping
		sbrc	bmap, 7				; tournament mode/AF switch
		andi	temp0, ~(1<<7)
		ldi		temp1, 8
update_leds_loop1:
		sbi		PORTD, SEG_DAT
		sbrs	temp0, 7
		cbi		PORTD, SEG_DAT
		sbi		PORTD, SEG_CLK
		cbi		PORTD, SEG_CLK
		lsl		temp0
		dec		temp1
		brne	update_leds_loop1

		sbi		PORTB, SEG_LAT
		cbi		PORTB, SEG_LAT

		pop		temp1
		pop		temp0
		wdr
		ret


;----------------------------------------------------------------------
; Set the autofire 7 seg display to the current autofire setting
;----------------------------------------------------------------------

update_autof_leds:
		push	temp0
		push	temp1

		mov		temp0, autospeed
		cpi		temp0, 0
		breq	update_autof_off
		cpi		temp0, 1
		breq	update_autof_low
		rjmp	update_autof_high
update_autof_low:
		ldi		temp0, 0xc7			; L
		rjmp	update_autof_done
update_autof_high:
		ldi		temp0, 0x89			; H
		rjmp	update_autof_done
update_autof_off:
		ldi		temp0, 0xbf			; -
update_autof_done:
		mov		seg1, temp0
/*
		ldi		temp1, 0
		mov		temp0, autospeed
		ldi		ZH, HIGH(2*led_digits)
		ldi		ZL, LOW(2*led_digits)
		add		ZL, temp0
		adc		ZH, temp1
		lpm
		mov		temp0, R0
		;tst		autof
		;breq	update_autof_off
		;ori		temp0, (1<<7)
update_autof_off:
		mov		seg1, temp0
*/
		pop		temp1
		pop		temp0
		ret


led_digits:
.db	0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xf8, 0x80, 0x98

led_chars:
;	d		A		B		C		X		Y		Z		L		R		S
.db 0xa1,	0x88,	0x83,	0xa7,	0x89,	0x91,	0xa4,	0xc7,	0xaf,	0x92
