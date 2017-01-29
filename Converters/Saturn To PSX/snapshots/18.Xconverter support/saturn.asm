;----------------------------------------------------------------------
; Check Saturn pad is connected
;----------------------------------------------------------------------

check_sat_con:
#ifdef debug_pad_always_connected
		ret
#endif

		; TH = 1, TR = 1
		sbi		PORTD, SAT_TH
		sbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND

		; check controller is actually connected
		; do three checks, all must pass for controller to be detected
		ldi		temp0, 0
		sbrs	temp2, SAT_UP		; Up = 0
		inc		temp0
		sbrs	temp2, SAT_DN		; Down = 0
		inc		temp0
		sbrc	temp2, SAT_LF		; Left = 1
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

		; do three checks, all must pass for controller to be detected
		ldi		temp0, 0
		sbrs	temp2, SAT_UP		; Up = 0
		inc		temp0
		sbrs	temp2, SAT_DN		; Down = 0
		inc		temp0
		sbrc	temp2, SAT_LF		; Left = 1
		inc		temp0

#ifndef debug_pad_always_connected
		cpi		temp0, 3
		brne	wait_saturn_conn
#endif

		ldi		temp0, 0
		rcall	setflash

		rcall	delay250ms

		ldi		temp0, 0x01			; set connected flag to Saturn
		mov		conn, temp0

		; Tournament mode default off
		clr		tmode

		; load last config state
		rcall	eeprom_read_config
		mov		temp0, bmap

		; TH = 1, TR = 1
		sbrs	temp2, SAT_RT		; L
		ldi		temp0, 0			; default mapping

		; TH = 0, TR = 0
		cbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay
		in		temp2, PIND
		sbrs	temp2, SAT_RT		; L
		ldi		temp0, 0			; default mapping
		sbrs	temp2, SAT_LF		; X
		ldi		temp0, 4
		sbrs	temp2, SAT_DN		; Y
		ldi		temp0, 5
		sbrs	temp2, SAT_UP		; Z
		ldi		temp0, 6

		; TH = 1, TR = 0
		sbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay
		in		temp2, PIND
		ldi		temp1, 0xff
		sbrs	temp2, SAT_RT		; Start
		mov		tmode, temp1		; tournament mode
		sbrs	temp2, SAT_LF		; A
		ldi		temp0, 1
		sbrs	temp2, SAT_DN		; C
		ldi		temp0, 3
		sbrs	temp2, SAT_UP		; B
		ldi		temp0, 2

#ifdef build_standard
		; PS2 Saturn Pad emulation jumper
		sbis	PIND, J_PSS
		rjmp	emu_mode
#endif
#ifdef build_kyle
		rjmp	emu_mode
#endif

		mov		bmap, temp0
		rcall	eeprom_write_config

		tst		tmode
		breq	sat_not_tmode

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

sat_not_tmode:
		rjmp	sat_wait_release

emu_mode:
		ldi		temp0, 2			; fixed button mapping
		mov		bmap, temp0
		rjmp	sat_wait_release

		ldi		temp0, 1
		rcall	setflash
		rcall	delay250ms
		rcall	delay250ms
		rcall	delay250ms
		rcall	delay250ms
		ldi		temp0, 0
		rcall	setflash
		ret


;----------------------------------------------------------------------
; Wait for all buttons to be released
;----------------------------------------------------------------------

sat_wait_release:
		clr		temp0

		; 11
		sbi		PORTD, SAT_TH
		sbi		PORTD, SAT_TR
		rcall	sat_delay
		in		temp2, PIND
		com		temp2
		andi	temp2, (1<<SAT_RT)
		or		temp0, temp2

		; 01
		cbi		PORTD, SAT_TH
		rcall	sat_delay
		in		temp2, PIND
		com		temp2
		andi	temp2, (1<<SAT_UP)|(1<<SAT_DN)|(1<<SAT_LF)|(1<<SAT_RT)
		or		temp0, temp2

		; 00
		cbi		PORTD, SAT_TR
		rcall	sat_delay
		in		temp2, PIND
		com		temp2
		andi	temp2, (1<<SAT_UP)|(1<<SAT_DN)|(1<<SAT_LF)|(1<<SAT_RT)
		or		temp0, temp2

		; 10
		sbi		PORTD, SAT_TH
		rcall	sat_delay
		in		temp2, PIND
		com		temp2
		andi	temp2, (1<<SAT_UP)|(1<<SAT_DN)|(1<<SAT_LF)|(1<<SAT_RT)
		or		temp0, temp2

		tst		temp0
		brne	sat_wait_release

		ldi		temp0, 50
sat_wait_release_debounce:
		rcall	sat_delay
		dec		temp0
		brne	sat_wait_release_debounce

		ret

;----------------------------------------------------------------------
; Delay ~2us for Saturn controller to respond
;----------------------------------------------------------------------

sat_delay:
		push	temp4
		ldi		temp4, 0x02
sat_delay_loop:
		dec		temp4
		brne	sat_delay_loop
		pop		temp4
		ret

