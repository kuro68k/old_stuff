;----------------------------------------------------------------------
; Saturn to Playstation mode
;----------------------------------------------------------------------

psx_mode:
		ser		psx0
		ser		psx1

psx_loop:
		sbis	PINC, PS_ATT
		rcall	ps_service

		rcall	snes_read

		; byte 0
		;	0	1	2	3	4	5	6	7
		;	B	Y	SL	ST	UP	DN	LF	RT
		
		; PSX
		; byte 0
		; 	0	1	2	3	4	5	6	7
		; 	SL			ST	UP	RT	DN	LF
		; byte 1
		; 	0	1	2	3	4	5	6	7
		; 	L2	R2	L1	R1	/\	O	X	[]

		bst		temp0, 0	; B -> X 
		bld		psx1, 6
		bst		temp0, 1	; Y -> [] 
		bld		psx1, 7
		sbis	PINC, PS_ATT
		rcall	ps_service
		bst		temp0, 4	; Up
		bld		psx0, 4
		bst		temp0, 5	; Down
		bld		psx0, 6
		sbis	PINC, PS_ATT
		rcall	ps_service
		bst		temp0, 6	; Left
		bld		psx0, 7
		bst		temp0, 7	; Right
		bld		psx0, 5
		sbis	PINC, PS_ATT
		rcall	ps_service

		; byte 1
		;	0	1	2	3	4	5	6	7
		;	A	X	L	R	-	-	-	-

		bst		temp1, 0	; A -> O 
		bld		psx1, 5
		bst		temp1, 1	; X -> /\ 
		bld		psx1, 4
		sbis	PINC, PS_ATT
		rcall	ps_service

		sbic	PINB, 0				; Select button jumper 
		rjmp	psx_sel_normal		; Select = Select 

		sbis	PINC, PS_ATT
		rcall	ps_service

		sbrc	temp0, 2			; Select held = normal mapping 
		rjmp	psx_sel_normal

		ori		psx0, (1<<3)		; Start released
		ori		psx1, (1<<2)|(1<<3)	; L1/R1 released
		bst		temp0, 3	; Start -> Select
		bld		psx0, 0
		sbis	PINC, PS_ATT
		rcall	ps_service
		bst		temp1, 2	; L -> L2
		bld		psx1, 0
		bst		temp1, 3	; R -> R2 
		bld		psx1, 1
		sbis	PINC, PS_ATT
		rcall	ps_service

		rjmp	psx_loop

psx_sel_normal:
		ori		psx0, (1<<0)		; Select released
		ori		psx1, (1<<0)|(1<<1)	; L2/R2 released
		bst		temp0, 2	; Select  
		bld		psx0, 0
		bst		temp0, 3	; Start
		bld		psx0, 3
		sbis	PINC, PS_ATT
		rcall	ps_service
		bst		temp1, 2	; L -> L1
		bld		psx1, 2
		bst		temp1, 3	; R -> R1 
		bld		psx1, 3
		sbis	PINC, PS_ATT
		rcall	ps_service

		rjmp	psx_loop



;----------------------------------------------------------------------
; PSX Servicing Routine
;----------------------------------------------------------------------
ps_service:
		;cli								; interrupts disabled for duration of comms
		push	temp0
		push	temp1
		push	temp2
		push	temp3

		ldi		temp0, 0xff				; 1st data is null
		rcall	psx_io

		cpi		temp1, 0x01				; check for ID command
		brne	ps_io_wait_att_high

		rcall	psx_ack

		ldi		temp0, 0x41				; analogue red / dual shock 73
		rcall	psx_io

		cpi		temp1, 0x42				; check for READ command
		brne	ps_io_wait_att_high

		rcall	psx_ack

		ldi		temp0, 0x5a				; data ready
		rcall	psx_io
		rcall	psx_ack

		mov		temp0, psx0				; data byte 0
		rcall	psx_io
		rcall	psx_ack

		mov		temp0, psx1				; data byte 1
		rcall	psx_io
		rcall	psx_ack

ps_io_wait_att_high:					; wait for ATT to go high again
		sbis	PINC, PS_ATT
		rjmp	ps_io_wait_att_high

		cbi		PORTC, PS_DAT			; prevent random input
		cbi		PORTC, PS_ACK

		pop		temp3
		pop		temp2
		pop		temp1
		pop		temp0
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
wait_clk_low:
		sbic	PINC, PS_CLK
		rjmp	wait_clk_low

		; set DATA bit
		sbrs	temp0, 0
		sbi		DDRC, PS_DAT
		sbrc	temp0, 0
		cbi		DDRC, PS_DAT
		lsr		temp0					; next bit

		; wait for clock high again
wait_clk_high:
		sbis	PINC, PS_CLK
		rjmp	wait_clk_high

		; read bit
		lsr		temp1
		sbic	PINC, PS_CMD
		ori		temp1, 0b10000000

		dec		temp2
		brne	bitloop

		ret

timeout:
		cbi		PORTC, PS_DAT
		ret

;----------------------------------------------------------------------
; Playstation ACK ~4us
;----------------------------------------------------------------------

psx_ack:
		push	temp0
		sbi		DDRC, PS_ACK
		ldi		temp0, 12
psx_ack_loop:
		dec		temp0
		brne	psx_ack_loop
		cbi		DDRC, PS_ACK
		pop		temp0
		ret
