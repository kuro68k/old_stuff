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
		sbrc	bmap, AF_DEF	; default on/off
		andi	temp0, ~(1<<7)	; decimal dot on
		
		mov		seg1, temp0

		pop		temp1
		pop		temp0
		ret


;----------------------------------------------------------------------
; Set the button mapping 7 seg display to the current mapping
;----------------------------------------------------------------------

update_bmap_leds:		
		push	temp0
		push	temp1
		mov		temp0, bmap
		andi	temp0, 0b00111111	; mask out status bits
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
		mov		temp0, R0

		sbrc	bmap, TMODE		; tournament mode
		andi	temp0, ~(1<<7)	; decimal dot on
		
		mov		seg0, temp0

		pop		temp1
		pop		temp0
		ret


;----------------------------------------------------------------------
; Set the autofire 7 seg display to the current autofire setting
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
		sbi		PORTD, SEG_OE
		ret

setflash_off:
		mov		temp0, fmask
		ori		temp0, (1<<7)		; disabled bit
		mov		fmask, temp0
		cbi		PORTD, SEG_OE
		ret

led_digits:
.db	0xc0, 0xf9, 0xa4, 0xb0, 0x99, 0x92, 0x82, 0xf8, 0x80, 0x98

led_chars:
;	d		A		B		C		X		Y		Z		L		R		S
.db 0xa1,	0x88,	0x83,	0xa7,	0x89,	0x91,	0xa4,	0xc7,	0xaf,	0x92
