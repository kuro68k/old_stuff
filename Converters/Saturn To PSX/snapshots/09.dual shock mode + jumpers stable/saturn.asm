;----------------------------------------------------------------------
; Check Saturn pad is connected
;----------------------------------------------------------------------

check_sat_con:
		; TH = 1, TR = 1
		sbi		PORTD, SAT_TH
		sbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB

		; check controller is actually connected
		; do three checks, all must pass for controller to be detected
		ldi		temp0, 0
		sbrs	temp2, SAT_UP		; Up = 0
		inc		temp0
		sbrs	temp2, SAT_DN		; Down = 0
		inc		temp0
		sbrc	temp1, SAT_LF		; Left = 1
		inc		temp0

		cpi		temp0, 3
		brne	sat_disconnected
		ret

sat_disconnected:
		clr		conn
		ret


;----------------------------------------------------------------------
; Wait for Saturn to be connected and then check tournament mode
;----------------------------------------------------------------------

wait_saturn_conn:
		; TH = 1, TR = 1
		sbi		PORTD, SAT_TH
		sbi		PORTD, SAT_TR
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

		ldi		temp0, 0
		rcall	setflash

		rcall	delay250ms

		ldi		temp0, 0x01			; set connected flag to Saturn
		mov		conn, temp0

		; Tournament mode
		mov		temp1, bmap
		andi	temp1, ~(1<<TMODE)	; default off
		mov		bmap, temp1

		; TH = 1, TR = 0
		sbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay
		in		temp2, PIND
		sbrc	temp2, SAT_RT		; Start -> tournament mode
		ret

		; Set up tournament mode
		mov		temp1, bmap
		ori		temp1, (1<<TMODE)
		mov		bmap, temp1
		clr		autospeed			; autofire always off in tournament mode
		rcall	update_bmap_leds
		rcall	update_autof_leds
		rcall	update_leds

		; Fast flash LED for 2s to indicate tournament mode selected
		ldi		temp0, 1
		rcall	setflash
		; Delay approx 1s
		push	temp0
		push	temp1
		push	temp2
		ldi		temp0, 0x96 ;0x48
wait_loop_1:
		ldi		temp1, 0xbc
wait_loop_2:
		ldi		temp2, 0xc4
wait_loop_3:
		dec		temp2
		brne	wait_loop_3
		dec		temp1
		brne	wait_loop_2
		dec		temp0
		brne	wait_loop_1
		pop		temp2
		pop		temp1
		pop		temp0
		; Turn off flash
		ldi		temp0, 0
		rcall	setflash

		ret

;----------------------------------------------------------------------
; Delay ~2us for Saturn controller to respond
;----------------------------------------------------------------------

sat_delay:
		;ret
		push	temp4
		ldi		temp4, 0x02
sat_delay_loop:
		dec		temp4
		brne	sat_delay_loop
		pop		temp4
		ret


;----------------------------------------------------------------------
; Delay ~2us for Saturn controller to respond
;----------------------------------------------------------------------

sat_wait_start_release:
		rcall	check_sat_con
		tst		conn
		breq	sat_setup_discon_exit
		; TH = 1, TR = 0
		sbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay
		in		temp2, PIND
		sbrs	temp2, SAT_RT
		rjmp	sat_wait_start_release
		ret


;----------------------------------------------------------------------
; Pad setup mode
;----------------------------------------------------------------------

sat_setup_discon_exit:
		ret

sat_setup_mode:
		ldi		temp0, 0x01
		rcall	setflash
		clr		bheld

		rcall	sat_wait_start_release

sat_setup_loop:
		rcall	check_sat_con
		tst		conn
		breq	sat_setup_discon_exit

		ldi		startf, 0xff
		mov		temp0, bmap			; new button mapping
		andi	temp0, 0b00111111	; mask flag bits
		mov		temp4, bmap			; new button mapping flags
		andi	temp4, 0b11000000	; mask mapping lower bits
		mov		temp3, autospeed	; new autofire speed

		; TH = 1, TR = 0
		sbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay
		in		temp2, PIND
		in		temp1, PINB
		sbrs	temp2, SAT_UP		; B
		ldi		temp0, 2
		sbrs	temp2, SAT_DN		; C
		ldi		temp0, 3
		sbrs	temp1, SAT_LF		; A
		ldi		temp0, 1
		sbrc	temp2, SAT_RT		; Start -> held = exit
		clr		bheld
		; TH = 0, TR = 0
		cbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay
		in		temp2, PIND
		in		temp1, PINB
		sbrs	temp2, SAT_UP		; Z
		ldi		temp0, 6
		sbrs	temp2, SAT_DN		; Y
		ldi		temp0, 5
		sbrs	temp1, SAT_LF		; X
		ldi		temp0, 4
		sbrs	temp2, SAT_RT		; R = autofire high speed
		ldi		temp3, 2
		; TH = 1, TR = 1
		sbi		PORTD, SAT_TH
		sbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		sbrs	temp2, SAT_RT		; L = autofire speed low
		ldi		temp3, 1
		; TH = 0, TR = 1
		cbi		PORTD, SAT_TH
		sbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB
		sbrs	temp2, SAT_UP		; Up -> reset all
		rcall	sat_setup_reset
		sbrs	temp2, SAT_DN		; Down -> default button mapping
		ldi		temp0, 0
		sbrs	temp1, SAT_LF		; Left -> autofire off
		;clr		temp3
		;sbrs	temp1, SAT_LF
		andi	temp4, ~(1<<AF_DEF)
		sbrs	temp2, SAT_RT		; Right -> autofire default on
		ori		temp4, (1<<AF_DEF)

		; combine button mapping flags into new bmap (temp0)
		or		temp0, temp4

		; update button mapping if necessary
		cp		temp0, bmap
		breq	sat_setup_no_bmap_change
		mov		bmap, temp0
		rcall	update_bmap_leds
		rcall	update_autof_leds
		rcall	update_leds
sat_setup_no_bmap_change:

		; update autofire speed if necessary
		cp		autospeed, temp3
		breq	sat_setup_no_autof_change
		mov		autospeed, temp3
		cpi		temp3, 2
		breq	sat_setup_af_high
		cpi		temp3, 1
		breq	sat_setup_af_low
		; autofire off = interrupt set to low speed

sat_setup_af_low:
		ldi		temp2, AFlOH
		out		OCR1AH, temp2
		ldi		temp2, AFLOL
		out		OCR1AL, temp2
		rjmp	sat_setup_af_done

sat_setup_af_high:
		ldi		temp2, AFNOH
		out		OCR1AH, temp2
		ldi		temp2, AFNOL
		out		OCR1AL, temp2
		rjmp	sat_setup_af_done

sat_setup_af_done:
		rcall	update_autof_leds
		rcall	update_leds
sat_setup_no_autof_change:


		mov		temp0, bheld
		cpi		temp0, BHTIME2
		breq	sat_setup_exit
		rjmp	sat_setup_loop

sat_setup_exit:
		; save config to EEPROM
		rcall	eeprom_write_config
		ldi		temp0, 0
		rcall	setflash
		rcall	sat_wait_start_release
		clr		bheld
		ret

sat_setup_reset:
		; reset all settings to default
		push	temp2
		ldi		temp2, AFlOH
		out		OCR1AH, temp2
		ldi		temp2, AFLOL
		out		OCR1AL, temp2
		clr		bmap
		clr		autospeed
		clr		afbutton
		clr		temp0
		clr		temp3
		clr		temp4
		rcall	update_bmap_leds
		rcall	update_autof_leds
		rcall	update_leds
		pop		temp2
		ret

/*
		ldi		temp0, AFNOH		; normal autofire speed
		out		OCR1AH, temp0
		ldi		temp0, AFNOL
		out		OCR1AL, temp0
		ldi		temp0, 2
		mov		autospeed, temp0
*/

		; set tournament mode/AF switch flag
		;sbrc	temp3, 0
		;ori		temp0, (1<<7)
		;mov		bmap, temp0
