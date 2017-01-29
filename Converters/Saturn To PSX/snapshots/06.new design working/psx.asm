;----------------------------------------------------------------------
; Saturn to Playstation mode
;----------------------------------------------------------------------

psx_mode:
ps:
		; PORT setup
		ldi		temp0, (1<<SAT_TH)|(1<<SAT_TR)|(1<<SEG_OE)	; TH/TR/OE outputs, rest inputs
		out		DDRD, temp0
		ldi		temp0, ~((1<<SAT_TR)|(1<<SEG_OE))			; TH=1, TR=0, rest pull-ups
		out		PORTD, temp0

ps_loop:
		ldi		temp3, 0

ps_wait_ack:
		rcall	check_sat_con
		tst		conn
		breq	ps_sat_discon_exit
		in		temp0, PINC
		sbrc	temp0, PS_ATT
		rjmp	ps_wait_ack

		; Main PSX servicing section

		ldi		psx0, 0xff				; PSX data bytes
		ldi		psx1, 0xff
		clr		afbutton

		ldi		temp0, 0xff				; 1st data is null
		rcall	psx_io

		cpi		temp1, 0x01				; check for ID command
		brne	ps_io_fail

		rcall	psx_sat1				; acknowledge byte and read saturn

		ldi		temp0, 0x41				; standard digital pad
		rcall	psx_io

		cpi		temp1, 0x42				; check for READ command
		brne	ps_io_fail

		rcall	psx_sat2

		ldi		temp0, 0x5a				; data ready
		rcall	psx_io

		rcall	psx_sat4
		rcall	ps_tmode

		mov		temp0, psx0				; data byte 0
		rcall	psx_io

		rcall	psx_sat3
		rcall	ps_autofire

		mov		temp0, psx1				; data byte 1
		rcall	psx_io

		ldi		temp3, 0				; reset timer0
		out		TCNT0, temp3
ps_io_fail:
		in		temp3, TCNT0
		cpi		temp3, 0xe0				; ~30ms
		brsh	ps_io_fail_timeout
		in		temp0, PINC
		sbrs	temp0, PS_ATT
		rjmp	ps_io_fail
ps_io_fail_timeout:

		;ldi		temp0, 0
		;cp		conn, temp0
		tst		conn
		breq	ps_sat_discon_exit

		; check if start button held
		cpi		startf, 0
		breq	ps_start_held
		clr		bheld					; not held, reset counter
		rjmp	ps_loop

ps_start_held:
		mov		temp0, bheld
		cpi		temp0, BHTIME1
		brsh	jump_sat_setup_mode
		rjmp	ps_loop

ps_sat_discon_exit:
		rjmp	wait_conn

		; branch is too far to rjmp
jump_sat_setup_mode:
		sbi		PORTC, PS_DAT			; prevent random input
		sbi		PORTC, PS_ACK
		rcall	sat_setup_mode
		rjmp	ps_loop

;----------------------------------------------------------------------
; Playstation autofire
;
; temp0 trashed
;----------------------------------------------------------------------

ps_autofire:
		; check if in tournament mode
		sbrc	bmap, TMODE
		rjmp	ps_noaf
		; check if autofire is turned off
		mov		temp0, autospeed
		cpi		temp0, 0
		breq	ps_noaf
		; check if autofire is default on or default off
		sbrc	bmap, AF_DEF
		rjmp	ps_af_neg
		; check if autofire button activated
		tst		afbutton
		breq	ps_noaf
		tst		afflag
		brne	ps_noaf
		ori		psx1, 0xf0
		rjmp	ps_noaf
ps_af_neg:
		; check if autofire button activated
		tst		afbutton
		brne	ps_noaf
		tst		afflag
		brne	ps_noaf
		ori		psx1, 0xf0
ps_noaf:
		ret

;----------------------------------------------------------------------
; Playstation tournament mode
;
; temp0 trashed
;----------------------------------------------------------------------

ps_tmode:
		sbrs	bmap, TMODE
		rjmp	ps_no_tmode
		; autofire must be disabled for tournament mode
		;mov		temp0, autospeed
		;cpi		temp0, 0
		;brne	ps_no_tmode
		sbr		psx0, (1<<3)			; clear start button
		clr		bheld					; no setup mode
ps_no_tmode:
		ret

;----------------------------------------------------------------------
; Playstation I/O
;
; Send byte in temp0, receive byte in temp1
;----------------------------------------------------------------------

psx_io:
		ldi		temp1, 0				; returned data
		ldi		temp2, 8				; bit count

bitloop:
		; wait for clock to go low
		ldi		temp3, 0				; reset timer0
		out		TCNT0, temp3
wait_clk_low:
		in		temp3, TCNT0
		cpi		temp3, 0xe0				; ~30ms
		brsh	timeout
		in		temp3, PINC
		sbrc	temp3, PS_CLK
		rjmp	wait_clk_low

		; set DATA bit
		;ldi		temp3, 0xdf				; DATA high
		in		temp3, PORTC
		ori		temp3, (1<<PS_DAT)
		sbrs	temp0, 0
		andi	temp3, ~(1<<PS_DAT)		; DATA low
		;sbrs	temp0, 0
		;cbi		PORTC, PS_DAT
		;sbrc	temp0, 0
		;sbi		PORTC, PS_DAT
		out		PORTC, temp3
		lsr		temp0					; next bit

		; wait for clock high again
		ldi		temp3, 0				; reset timer0
		out		TCNT0, temp3
wait_clk_high:
		in		temp3, TCNT0
		cpi		temp3, 0xe0				; ~30ms
		brsh	timeout
		in		temp3, PINC
		sbrs	temp3, PS_CLK
		rjmp	wait_clk_high

		; read bit
		in		temp3, PINC
		lsr		temp1
		sbrc	temp3, PS_CMD
		ori		temp1, 0b10000000

		dec		temp2
		brne	bitloop

		ret

timeout:
		cbi		PORTC, PS_ACK
		nop
		nop
		nop
		nop
		sbi		PORTC, PS_ACK
		ldi		temp1, 0x00				; failed

		rjmp	wait_conn
		ret


;----------------------------------------------------------------------
; Playstation ACK with Saturn I/O interleaved
;----------------------------------------------------------------------

psx_sat1:
		cbi		PORTC, PS_ACK

		; TH = 1, TR = 0
		;in		temp2, PORTD
		;andi	temp2, ~(1<<SAT_TR)
		;ori		temp2, (1<<SAT_TH)
		;out		PORTD, temp2
		sbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB

		ldi		startf, 0xff

		; button mapping
		ldi		ZH, HIGH(psx_sat01_jump)
		ldi		ZL, LOW(psx_sat01_jump)
		mov		temp0, bmap
		andi	temp0, 0b00111111
		add		ZL, temp0
		clr		temp0
		adc		ZH, temp0
		ijmp
psx_sat01_jump:
		rjmp	psx_sat01_def
		rjmp	psx_sat01_a
		rjmp	psx_sat01_b
		rjmp	psx_sat01_c
		rjmp	psx_sat01_x
		rjmp	psx_sat01_y
		rjmp	psx_sat01_z

		; unknown button mapping = default

		; byte 0
		; 	0	1	2	3	4	5	6	7
		; 	SL			ST	UP	RT	DN	LF
		; byte 1
		; 	0	1	2	3	4	5	6	7
		; 	L2	R2	L1	R1	/\	O	X	[]

psx_sat01_def:
psx_sat01_a:
		sbrs	temp2, SAT_UP		; B -> O
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_DN		; C -> R2
		andi	psx1, ~(1<<1)
		sbrs	temp1, SAT_LF		; A -> X
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_RT		; Start
		;andi	psx0, ~(1<<3)
		clr		startf
		rjmp	psx_sat01_done

psx_sat01_b:
		sbrs	temp2, SAT_UP		; B -> O
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_DN		; C -> R2
		andi	psx1, ~(1<<1)
		sbrs	temp1, SAT_LF		; A -> X
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_RT		; Start
		andi	psx0, ~(1<<3)
		rjmp	psx_sat01_done

psx_sat01_c:
		;sbrs	temp2, SAT_UP		; B -> Select (removed for Guilty Gear)
		;andi	psx0, ~(1<<0)
		sbrs	temp2, SAT_DN		; C -> R1
		andi	psx1, ~(1<<3)
		sbrs	temp1, SAT_LF		; A -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_RT		; Start
		;andi	psx0, ~(1<<3)
		clr		startf
		rjmp	psx_sat01_done

psx_sat01_x:
		sbrs	temp2, SAT_UP		; B -> X
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_DN		; C -> R1
		andi	psx1, ~(1<<3)
		sbrs	temp1, SAT_LF		; A -> R2
		andi	psx1, ~(1<<1)
		sbrc	temp2, SAT_RT		; Start
		;andi	psx0, ~(1<<3)
		clr		startf
		rjmp	psx_sat01_done

psx_sat01_y:
		sbrs	temp2, SAT_UP		; B -> O 
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_DN		; C -> []
		andi	psx1, ~(1<<7)
		sbrs	temp1, SAT_LF		; A -> X 
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_RT		; Start
		;andi	psx0, ~(1<<3)
		clr		startf
		rjmp	psx_sat01_done

psx_sat01_z:
		sbrs	temp2, SAT_UP		; B -> /\ 
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_DN		; C -> O 
		andi	psx1, ~(1<<5)
		sbrs	temp1, SAT_LF		; A -> [] 
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_RT		; Start
		;andi	psx0, ~(1<<3)
		clr		startf
		rjmp	psx_sat01_done

psx_sat01_done:
		; delay to make ACK correct width
		ldi		temp0, 5
psx_ack_delay3:
		;dec		temp0
		;brne	psx_ack_delay3

		sbi		PORTC, PS_ACK

		ret


;-----------------------------------------------------------------------------

psx_sat2:
		cbi		PORTC, PS_ACK

		; TH = 0, TR = 1
		in		temp2, PORTD
		andi	temp2, ~(1<<SAT_TH)
		ori		temp2, (1<<SAT_TR)
		out		PORTD, temp2
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB

		; all button mappings are the same for d-pad

		; byte 0
		; 	0	1	2	3	4	5	6	7
		; 	SL			ST	UP	RT	DN	LF

		sbrs	temp2, SAT_DN		; Down
		andi	psx0, ~(1<<6)

#ifdef start_mode_dpad
		cpi		startf, 0
		brne	psx_sat2_normal

		sbrs	temp1, SAT_LF		; Left -> Select
		andi	psx0, ~(1<<0)
		sbrs	temp1, SAT_LF		; Left -> Select
		clr		bheld

		sbrs	temp2, SAT_RT		; Right -> Start
		andi	psx0, ~(1<<3)
		sbrs	temp2, SAT_RT		; Right -> Start
		clr		bheld

		sbrs	temp2, SAT_UP		; Up -> PS3 Home (Start+Select+Up)
		andi	psx0, ~((1<<4)|(1<<0)|(1<<3))
		sbrs	temp2, SAT_UP		; Up -> PS3 Home (Start+Select+Up)
		clr		bheld

		rjmp	psx_sat2_done	
#endif

psx_sat2_normal:
		sbrs	temp2, SAT_UP		; Up
		andi	psx0, ~(1<<4)
		sbrs	temp1, SAT_LF		; Left
		andi	psx0, ~(1<<7)
		sbrs	temp2, SAT_RT		; Right
		andi	psx0, ~(1<<5)

psx_sat2_done:
		; delay to make ACK correct width
		ldi		temp0, 5
psx_ack_delay2:
		;dec		temp0
		;brne	psx_ack_delay2
		sbi		PORTC, PS_ACK

		ret


;-----------------------------------------------------------------------------

psx_sat3:
		cbi		PORTC, PS_ACK

		; TH = 0, TR = 0
		in		temp2, PORTD
		andi	temp2, ~((1<<SAT_TH)|(1<<SAT_TR))
		out		PORTD, temp2
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB

		; button mapping
		ldi		ZH, HIGH(psx_sat00_jump)
		ldi		ZL, LOW(psx_sat00_jump)
		mov		temp0, bmap
		andi	temp0, 0b00111111
		add		ZL, temp0
		clr		temp0
		adc		ZH, temp0
		ijmp
psx_sat00_jump:
		rjmp	psx_sat00_def
		rjmp	psx_sat00_a
		rjmp	psx_sat00_b
		rjmp	psx_sat00_c
		rjmp	psx_sat00_x
		rjmp	psx_sat00_y
		rjmp	psx_sat00_z

		; unknown button mapping = default

		; byte 0
		; 	0	1	2	3	4	5	6	7
		; 	SL			ST	UP	RT	DN	LF
		; byte 1
		; 	0	1	2	3	4	5	6	7
		; 	L2	R2	L1	R1	/\	O	X	[]
psx_sat00_def:
		sbrs	temp1, SAT_LF		; X -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_DN		; Y -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_UP		; Z -> L2
		andi	psx1, ~(1<<0)
		mov		temp1, autospeed
		cpi		temp1, 0
		brne	psx_sat00_autof
		sbrs	temp2, SAT_RT		; R -> R1
		andi	psx1, ~(1<<3)
		rjmp	psx_sat00_done

psx_sat00_a:
psx_sat00_b:
		sbrs	temp1, SAT_LF		; X -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_DN		; Y -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_UP		; Z -> R1
		andi	psx1, ~(1<<3)
		sbrs	temp2, SAT_RT		; R -> L2
		andi	psx1, ~(1<<0)
		rjmp	psx_sat00_done

psx_sat00_c:
		sbrs	temp1, SAT_LF		; X -> X 
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_DN		; Y -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_UP		; Z -> O 
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_RT		; R -> R2
		andi	psx1, ~(1<<1)
		rjmp	psx_sat00_done

psx_sat00_x:
		sbrs	temp1, SAT_LF		; X -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_DN		; Y -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_UP		; Z -> O 
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_RT		; R -> L1
		andi	psx1, ~(1<<2)
		rjmp	psx_sat00_done

psx_sat00_y:
		bst		afflag, 0			; autofire on/off bit
		sbrs	temp1, SAT_LF		; X -> X (AF)
		bld		psx1, 6
		sbrs	temp2, SAT_DN		; Y -> O (AF)
		bld		psx1, 5
		sbrs	temp2, SAT_UP		; Z -> [] (AF)
		bld		psx1, 7
		sbrs	temp2, SAT_RT		; R -> /\ (AF)
		bld		psx1, 4
		rjmp	psx_sat00_done

psx_sat00_z:
		sbrs	temp1, SAT_LF		; X -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_DN		; Y -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_UP		; Z -> O 
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_RT		; R -> /\ + O 
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_RT		; R -> /\ + O 
		andi	psx1, ~(1<<5)
		rjmp	psx_sat00_done

psx_sat00_autof:
		sbrs	temp2, SAT_RT		; R -> autofire
		inc		afbutton
		rjmp	psx_sat00_done

psx_sat00_done:
		; delay to make ACK correct width
		ldi		temp0, 5
psx_ack_delay4:
		;dec		temp0
		;brne	psx_ack_delay4
		sbi		PORTC, PS_ACK

		ret


;-----------------------------------------------------------------------------

psx_sat4:
		;ldi		temp0, ~(1<<PS_ACK)		; ACK low
		;out		PORTB, temp0
		cbi		PORTC, PS_ACK

		; TH = 1, TR = 1
		in		temp2, PORTD
		ori		temp2, (1<<SAT_TH)|(1<<SAT_TR)
		out		PORTD, temp2
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB

		; button mapping
		ldi		ZH, HIGH(psx_sat11_jump)
		ldi		ZL, LOW(psx_sat11_jump)
		mov		temp0, bmap
		andi	temp0, 0b00111111
		add		ZL, temp0
		clr		temp0
		adc		ZH, temp0
		ijmp
psx_sat11_jump:
		rjmp	psx_sat11_def
		rjmp	psx_sat11_a
		rjmp	psx_sat11_b
		rjmp	psx_sat11_c
		rjmp	psx_sat11_x
		rjmp	psx_sat11_y
		rjmp	psx_sat11_z

		; unknown button mapping = default

		; byte 0
		; 	0	1	2	3	4	5	6	7
		; 	SL			ST	UP	RT	DN	LF
		; byte 1
		; 	0	1	2	3	4	5	6	7
		; 	L2	R2	L1	R1	/\	O	X	[]

psx_sat11_def:
psx_sat11_a:
psx_sat11_c:
		sbrs	temp2, SAT_RT		; L -> L1
		andi	psx1, ~(1<<2)
		rjmp	psx_sat11_done

psx_sat11_b:
		sbrs	temp2, SAT_RT		; L -> Select
		andi	psx0, ~(1<<0)
		rjmp	psx_sat11_done

psx_sat11_x:
		sbrs	temp2, SAT_RT		; L -> L2
		andi	psx1, ~(1<<0)
		rjmp	psx_sat11_done

psx_sat11_y:
		sbrs	temp2, SAT_RT		; L -> /\
		andi	psx1, ~(1<<4)
		rjmp	psx_sat11_done

psx_sat11_z:
		sbrs	temp2, SAT_RT		; L -> /\ + []
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_RT		; L -> /\ + []
		andi	psx1, ~(1<<7)
		rjmp	psx_sat11_done

psx_sat11_done:
		; delay to make ACK correct width
		ldi		temp0, 7
psx_ack_delay1:
		;dec		temp0
		;brne	psx_ack_delay1

		sbi		PORTC, PS_ACK

		ret
