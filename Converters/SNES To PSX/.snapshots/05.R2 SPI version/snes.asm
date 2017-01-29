;----------------------------------------------------------------------
; SNES Read
;
; temp0 - first 8 bits
; temp1 - second 8 bits
; temp2/temp3/temp4 trashed
;----------------------------------------------------------------------

snes_read:
		clr		temp0
		clr		temp1

// latch																					
		sbi		PORTD, SNES_LAT

		ldi		temp2, 20			; ~12us
snes_latch_loop1:
		sbis	PINB, PS_ATT		; 2
		rcall	ps_service			; -
		dec		temp2				; 1
		brne	snes_latch_loop1	; 2

		cbi		PORTD, SNES_LAT

// byte 0																					
		ldi		temp3, 8			; read 8 bits
snes_byte0_loop:
		cbi		PORTD, SNES_CLK
		ldi		temp2, 10			; ~6us
snes_clock_loop1:
		sbis	PINB, PS_ATT		; 2
		rcall	ps_service			; -
		dec		temp2				; 1
		brne	snes_clock_loop1	; 2

		; read bit
		lsr		temp0
		sbic	PIND, SNES_DAT
		ori		temp0, (1<<7)

		sbi		PORTD, SNES_CLK
		ldi		temp2, 10			; ~6us
snes_clock_loop2:
		sbis	PINB, PS_ATT		; 2
		rcall	ps_service			; -
		dec		temp2				; 1
		brne	snes_clock_loop2	; 2

		dec		temp3
		brne	snes_byte0_loop

// byte 2																					
		ldi		temp3, 4			; read 4 bits
snes_byte1_loop:
		cbi		PORTD, SNES_CLK
		ldi		temp2, 10			; ~6us
snes_clock_loop3:
		sbis	PINB, PS_ATT		; 2
		rcall	ps_service			; -
		dec		temp2				; 1
		brne	snes_clock_loop3	; 2

		; read bit
		lsr		temp1
		sbic	PIND, SNES_DAT
		ori		temp1, (1<<3)

		sbi		PORTD, SNES_CLK
		ldi		temp2, 10			; ~6us
snes_clock_loop4:
		sbis	PINB, PS_ATT		; 2
		rcall	ps_service			; -
		dec		temp2				; 1
		brne	snes_clock_loop4	; 2

		dec		temp3
		brne	snes_byte1_loop

		ret
