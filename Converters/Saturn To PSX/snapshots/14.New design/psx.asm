;----------------------------------------------------------------------
; Saturn to Playstation mode
;----------------------------------------------------------------------

; short jumps for branches
ps_sat_discon_exit2:
		rjmp	wait_conn

ps_sat_disconnected:
		clr		conn
		rjmp	sat_disconnected

psx_mode:
ps_loop:
		cbi		DDRA, PS_DAT			; release Data

ps_wait_att:
		rcall	check_sat_con
		tst		conn
		breq	ps_sat_discon_exit2
		sbic	PIND, PS_ATT
		rjmp	ps_wait_att

		; Main PSX servicing section

		cli								; interrupts disabled for duration of comms

		ldi		psx0, 0xff				; PSX data bytes
		ldi		psx1, 0xff
		clr		afbutton

		ldi		temp0, 0xff				; 1st data is null
		rcall	psx_io

		cpi		temp1, 0x01				; check for ID command
		brne	ps_io_finished

		rcall	psx_sat1				; acknowledge byte and read saturn

		ldi		temp0, 0x41				; analogue red / dual shock 73
		rcall	psx_io

		cpi		temp1, 0x42				; check for READ command
		breq	ps_cmd_read
		rjmp	ps_io_finished

ps_cmd_read:
		rcall	psx_sat2

		ldi		temp0, 0x5a				; data ready
		rcall	psx_io

		rcall	psx_sat4
		
		; Tournament mode
		sbrc	tmode, 0
		sbr		psx0, (1<<3)			; clear start button

		mov		temp0, psx0				; data byte 0
		rcall	psx_io

		rcall	psx_sat3

		mov		temp0, psx1				; data byte 1
		rcall	psx_io

ps_io_finished:
		sei								; interrupts back on

		; wait for ATT to go high again
ps_io_fail:
		sbis	PIND, PS_ATT
		rjmp	ps_io_fail

		cbi		DDRA, PS_DAT			; release Data

		rcall	check_sat_con
		tst		conn
		breq	ps_sat_discon_exit

		rjmp	ps_loop

; needs to be close to main loop for conditional brance
ps_sat_discon_exit:
		rjmp	wait_conn


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
wait_clk_low:
		sbic	PIND, PS_CLK
		rjmp	wait_clk_low

		; set DATA bit
		sbrs	temp0, 0
		sbi		DDRA, PS_DAT
		sbrc	temp0, 0
		cbi		DDRA, PS_DAT
		lsr		temp0					; next bit

		; wait for clock high again
wait_clk_high:
		sbis	PIND, PS_CLK
		rjmp	wait_clk_high

		; read bit
		lsr		temp1
		sbic	PIND, PS_CMD
		ori		temp1, 0b10000000

		dec		temp2
		brne	bitloop

		sbic	PIND, PS_ATT
		rjmp	timeout2

		ret

timeout2:
		rjmp	ps_io_finished

timeout:
		cbi		DDRA, PS_DAT		; release
		ldi		temp1, 0x00			; failed
		rjmp	wait_conn
		ret


;----------------------------------------------------------------------
; Playstation ACK with Saturn I/O interleaved                         
;----------------------------------------------------------------------

psx_sat1:
		sbi		DDRD, PS_ACK

		; TH = 1, TR = 0
		sbi		PORTB, SAT_TH
		cbi		PORTB, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PINB

		ldi		startf, 0xff

		sbrs	temp2, SAT_RT		; Start
		rjmp	psx_sat01_start_abc

		; button mapping
psx_sat01_decode:
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
		sbrs	temp2, SAT_LF		; A -> X 
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_UP		; B -> O 
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_DN		; C -> R2
		andi	psx1, ~(1<<1)
		rjmp	psx_sat01_done

psx_sat01_b:
		sbrs	temp2, SAT_LF		; A -> X
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_UP		; B -> O
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_DN		; C -> R1
		andi	psx1, ~(1<<3)
		rjmp	psx_sat01_done

psx_sat01_c:
		sbrs	temp2, SAT_LF		; A -> []
		andi	psx1, ~(1<<7)
		;sbrs	temp2, SAT_UP		; B -> Select (removed for Guilty Gear)
		;andi	psx0, ~(1<<0)
		sbrs	temp2, SAT_DN		; C -> R1
		andi	psx1, ~(1<<3)
		rjmp	psx_sat01_done

psx_sat01_x:
		sbrs	temp2, SAT_LF		; A -> R2
		andi	psx1, ~(1<<1)
		sbrs	temp2, SAT_UP		; B -> X
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_DN		; C -> R1
		andi	psx1, ~(1<<3)
		rjmp	psx_sat01_done

psx_sat01_y:
		sbrs	temp2, SAT_UP		; B -> O 
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_DN		; C -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_LF		; A -> X 
		andi	psx1, ~(1<<6)
		rjmp	psx_sat01_done

psx_sat01_z:
		sbrs	temp2, SAT_UP		; B -> /\ 
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_DN		; C -> O 
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_LF		; A -> [] 
		andi	psx1, ~(1<<7)
		rjmp	psx_sat01_done

psx_sat01_start_abc:
		; Start/Home disbaled in tournament mode
		sbrc	tmode, 0
		rjmp	psx_sat01_tmode

		sbrs	temp2, SAT_UP		; B -> Select
		andi	psx0, ~(1<<0)
		sbrs	temp2, SAT_LF		; A -> Start
		andi	psx0, ~(1<<3)
		sbrs	temp2, SAT_DN		; C -> PS Home
		andi	psx0, ~((1<<3)|(1<<0)|(1<<4))
		rjmp	psx_sat01_done

psx_sat01_tmode:
		; In tournament mode Start -> Select
		andi	psx0, ~(1<<0)
		rjmp	psx_sat01_decode

psx_sat01_done:
		cbi		DDRD, PS_ACK
		ret


;-----------------------------------------------------------------------------

psx_sat2:
		sbi		DDRD, PS_ACK

		; TH = 0, TR = 1
		cbi		PORTB, SAT_TH
		sbi		PORTB, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PINB

		; all button mappings are the same for d-pad

		; byte 0
		; 	0	1	2	3	4	5	6	7
		; 	SL			ST	UP	RT	DN	LF

		sbrs	temp2, SAT_DN		; Down
		andi	psx0, ~(1<<6)
		sbrs	temp2, SAT_UP		; Up
		andi	psx0, ~(1<<4)
		sbrs	temp2, SAT_LF		; Left
		andi	psx0, ~(1<<7)
		sbrs	temp2, SAT_RT		; Right
		andi	psx0, ~(1<<5)

psx_sat2_done:
		cbi		DDRD, PS_ACK
		ret


;-----------------------------------------------------------------------------

psx_sat3:
		sbi		DDRD, PS_ACK

		; TH = 0, TR = 0
		cbi		PORTB, SAT_TH
		cbi		PORTB, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PINB

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
		sbrs	temp2, SAT_LF		; X -> []
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
		sbrs	temp2, SAT_LF		; X -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_DN		; Y -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_UP		; Z -> R1
		andi	psx1, ~(1<<3)
		sbrs	temp2, SAT_RT		; R -> L2
		andi	psx1, ~(1<<0)
		rjmp	psx_sat00_done

psx_sat00_b:	// PS2 Saturn Emulation 
		sbrs	temp2, SAT_LF		; X -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_DN		; Y -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_UP		; Z -> L1
		andi	psx1, ~(1<<2)
		sbrs	temp2, SAT_RT		; R -> R2
		andi	psx1, ~(1<<1)
		rjmp	psx_sat00_done

psx_sat00_c:
		sbrs	temp2, SAT_LF		; X -> X 
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_DN		; Y -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_UP		; Z -> O 
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_RT		; R -> R2
		andi	psx1, ~(1<<1)
		rjmp	psx_sat00_done

psx_sat00_x:
		sbrs	temp2, SAT_LF		; X -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_DN		; Y -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_UP		; Z -> O 
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_RT		; R -> L1
		andi	psx1, ~(1<<2)
		rjmp	psx_sat00_done

psx_sat00_y:	// Autofire 
		; autofire inactive in tournament mode
		sbrc	tmode, 0
		rjmp	psx_sat00_done

		sbrc	afflag, 0
		rjmp	psx_sat00_done

		sbrs	temp2, SAT_LF		; X -> X (AF)
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_DN		; Y -> O (AF)
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_UP		; Z -> [] (AF)
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_RT		; R -> /\ (AF)
		andi	psx1, ~(1<<4)
		rjmp	psx_sat00_done

psx_sat00_z:
		sbrs	temp2, SAT_LF		; X -> []
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
		cbi		DDRD, PS_ACK

		ret


;-----------------------------------------------------------------------------

psx_sat4:
		sbi		DDRD, PS_ACK

		; TH = 1, TR = 1
		sbi		PORTB, SAT_TH
		sbi		PORTB, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PINB

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
		andi	psx1, ~(1<<4)		; /\ 
		sbrs	temp2, SAT_RT		; L -> /\ + []
		andi	psx1, ~(1<<7)		; []
		rjmp	psx_sat11_done

psx_sat11_done:
		cbi		DDRD, PS_ACK
		ret


;----------------------------------------------------------------------
; Playstation ACK ~4us
;----------------------------------------------------------------------

psx_ack:
		push	temp0
		sbi		DDRD, PS_ACK
		ldi		temp0, 12
psx_ack_loop:
		dec		temp0
		brne	psx_ack_loop
		cbi		DDRD, PS_ACK
		pop		temp0
		ret

