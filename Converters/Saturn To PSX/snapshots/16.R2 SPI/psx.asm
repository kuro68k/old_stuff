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
		cbi		DDRB, PS_DAT			; release Data

ps_wait_att:
		rcall	check_sat_con
		tst		conn
		breq	ps_sat_discon_exit2
		sbic	PINB, PS_ATT
		rjmp	ps_wait_att

		; Main PSX servicing section

		cli								; interrupts disabled for duration of comms

		ldi		psx0, 0xff				; PSX data bytes
		ldi		psx1, 0xff
		clr		afbutton

		ldi		temp0, 0xff				; 1st data is null
		rcall	psx_io

		cpi		temp1, 0x80 ;0x01				; check for ID command
		brne	ps_io_finished

		rcall	psx_sat1				; acknowledge byte and read saturn

		ldi		temp0, 0x82 ;0x41				; digital pad (analogue red / dual shock = 73)
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
		rcall	swapbits
		rcall	psx_io

		rcall	psx_sat3

		mov		temp0, psx1				; data byte 1
		rcall	swapbits
		rcall	psx_io

		cbi		DDRB, PS_DAT			; release Data

ps_io_finished:
		sei								; interrupts back on

		; wait for ATT to go high again
ps_io_wait_att_high:
		sbis	PINB, PS_ATT
		rjmp	ps_io_wait_att_high

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
		out		USIDR, temp0			; byte to send

		sbi		DDRB, PS_DAT
		cbi		DDRB, PS_CLK
		cbi		DDRB, PS_CMD
		cbi		DDRB, PS_ATT
		sbi		PORTD, PS_ATT

		ldi		temp1, (1<<USIOIF)
		out		USISR, temp1			; reset counter
		ldi		temp1, (1<<USIWM0)|(1<<USICS1)
		out		USICR, temp1			; start SPI transfer

psx_io_wait:
		sbic	PINB, PS_ATT			; make sure ATT is held, if not timeout
		rjmp	psx_io_timeout
		sbis	USISR, USIOIF			; wait for SPI transfer to finish
		rjmp	psx_io_wait

		in		temp1, USIDR			; byte received

		ret

psx_io_timeout:
		rcall	psx_debug
		rcall	psx_debug
		rcall	psx_debug
		rjmp	ps_io_finished


;----------------------------------------------------------------------
; Playstation ACK with Saturn I/O interleaved                         
;----------------------------------------------------------------------

psx_sat1:
		//sbi		DDRD, PS_ACK

		; TH = 1, TR = 0
		sbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND

		ldi		startf, 0xff

#ifdef build_standard
		sbrs	temp2, SAT_RT		; Start
		rjmp	psx_sat01_start_abc
#endif
#ifdef build_kyle
		sbrs	temp2, SAT_RT		; Start
		andi	psx0, ~(1<<3)
#endif

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
#ifdef build_standard
		sbrs	temp2, SAT_LF		; A -> X
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_UP		; B -> O
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_DN		; C -> R1
		andi	psx1, ~(1<<3)
#endif
#ifdef build_kyle
		sbrs	temp2, SAT_LF		; A -> X
		andi	psx1, ~(1<<6)
		sbrs	temp2, SAT_UP		; B -> O
		andi	psx1, ~(1<<5)
		sbrs	temp2, SAT_DN		; C -> R2
		andi	psx1, ~(1<<1)
#endif
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
		//cbi		DDRD, PS_ACK
		rcall	psx_ack
		ret


;-----------------------------------------------------------------------------

psx_sat2:
		//sbi		DDRD, PS_ACK

		; TH = 0, TR = 1
		cbi		PORTD, SAT_TH
		sbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND

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
		//cbi		DDRD, PS_ACK
		rcall	psx_ack
		ret


;-----------------------------------------------------------------------------

psx_sat3:
		//sbi		DDRD, PS_ACK

		; TH = 0, TR = 0
		cbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND

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
#ifdef build_standard
		sbrs	temp2, SAT_LF		; X -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_DN		; Y -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_UP		; Z -> L1
		andi	psx1, ~(1<<2)
		sbrs	temp2, SAT_RT		; R -> R2
		andi	psx1, ~(1<<1)
#endif
#ifdef build_kyle
		sbrs	temp2, SAT_LF		; X -> []
		andi	psx1, ~(1<<7)
		sbrs	temp2, SAT_DN		; Y -> /\
		andi	psx1, ~(1<<4)
		sbrs	temp2, SAT_UP		; Z -> R1
		andi	psx1, ~(1<<3)
		sbrs	temp2, SAT_RT		; R -> L2
		andi	psx1, ~(1<<0)
#endif
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
		//cbi		DDRD, PS_ACK
		rcall	psx_ack

		ret


;-----------------------------------------------------------------------------

psx_sat4:
		//sbi		DDRD, PS_ACK

		; TH = 1, TR = 1
		sbi		PORTD, SAT_TH
		sbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND

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
#ifdef build_standard
		sbrs	temp2, SAT_RT		; L -> L2
		andi	psx1, ~(1<<0)
#endif
#ifdef build_kyle
		sbrs	temp2, SAT_RT		; L -> Select
		andi	psx0, ~(1<<0)
#endif
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
		andi	psx1, ~(1<<4)		; /\ 
		sbrs	temp2, SAT_RT		; L -> /\ + []
		andi	psx1, ~(1<<7)		; []
		rjmp	psx_sat11_done

psx_sat11_done:
		//cbi		DDRD, PS_ACK
		rcall	psx_ack
		ret


;----------------------------------------------------------------------
; Playstation ACK ~2us
;----------------------------------------------------------------------

psx_ack:
		push	temp0
		sbi		DDRB, PS_ACK
		ldi		temp0, 0x05
psx_ack_loop:
		dec		temp0
		brne	psx_ack_loop
		cbi		DDRB, PS_ACK
		pop		temp0
		ret


;----------------------------------------------------------------------
; Swap bits in temp0
;
; Trash temp1
;----------------------------------------------------------------------

swapbits:
		ror 	temp0
		rol 	temp1
		ror 	temp0
		rol 	temp1
		ror 	temp0
		rol 	temp1
		ror 	temp0
		rol 	temp1
		ror 	temp0
		rol 	temp1
		ror 	temp0
		rol 	temp1
		ror 	temp0
		rol 	temp1
		ror 	temp0
		rol 	temp1
		mov		temp0, temp1
		ret

;----------------------------------------------------------------------
; Debug
;----------------------------------------------------------------------

psx_debug:
		sbi		DDRB, PS_ACK
		cbi		DDRB, PS_ACK
		sbi		DDRB, PS_ACK
		cbi		DDRB, PS_ACK
		sbi		DDRB, PS_ACK
		cbi		DDRB, PS_ACK
		sbi		DDRB, PS_ACK
		cbi		DDRB, PS_ACK
ret
