;----------------------------------------------------------------------
; Check Saturn pad is connected
;----------------------------------------------------------------------

check_sat_con:
		; TH = 1, TR = 1
		in		temp2, PORTD
		ori		temp2, (1<<SAT_TH)|(1<<SAT_TR)
		out		PORTD, temp2
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
; Delay ~2us for Saturn controller to respond
;----------------------------------------------------------------------

sat_delay:
		;ret
		ldi		temp4, 0x02
sat_delay_loop:
		dec		temp4
		brne	sat_delay_loop
		ret
