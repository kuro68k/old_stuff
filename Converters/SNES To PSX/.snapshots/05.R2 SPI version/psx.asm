;----------------------------------------------------------------------
; SNES to Playstation mode
;----------------------------------------------------------------------

psx_mode:
		ser		psx0
		ser		psx1

		cbi		DDRB, PS_DAT			; release Data

psx_loop:
		sbis	PINB, PS_ATT
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
		sbis	PINB, PS_ATT
		rcall	ps_service
		bst		temp0, 4	; Up
		bld		psx0, 4
		bst		temp0, 5	; Down
		bld		psx0, 6
		sbis	PINB, PS_ATT
		rcall	ps_service
		bst		temp0, 6	; Left
		bld		psx0, 7
		bst		temp0, 7	; Right
		bld		psx0, 5
		sbis	PINB, PS_ATT
		rcall	ps_service

		; byte 1
		;	0	1	2	3	4	5	6	7
		;	A	X	L	R	-	-	-	-

		bst		temp1, 0	; A -> O 
		bld		psx1, 5
		bst		temp1, 1	; X -> /\ 
		bld		psx1, 4
		sbis	PINB, PS_ATT
		rcall	ps_service

		bst		temp0, 2	; Select  
		bld		psx0, 0
		bst		temp0, 3	; Start
		bld		psx0, 3
		sbis	PINB, PS_ATT
		rcall	ps_service
		bst		temp1, 2	; L -> L1
		bld		psx1, 2
		bst		temp1, 3	; R -> R1 
		bld		psx1, 3
		sbis	PINB, PS_ATT
		rcall	ps_service

		rjmp	psx_loop


;----------------------------------------------------------------------
; PSX Servicing Routine
;----------------------------------------------------------------------
ps_service:
		push	temp0
		push	temp1
		push	temp2
		push	temp3

		ldi		temp0, 0xff				; 1st data is null
		rcall	psx_io

		cpi		temp1, 0x80 ;0x01				; check for ID command
		brne	ps_io_wait_att_high

		rcall	psx_ack

		ldi		temp0, 0x82 ; 0x41				; analogue red / dual shock 73
		rcall	psx_io

		cpi		temp1, 0x42				; check for READ command
		brne	ps_io_finished

		rcall	psx_ack

		ldi		temp0, 0x5a				; data ready
		rcall	psx_io
		rcall	psx_ack

		mov		temp0, psx0				; data byte 0
		rcall	swapbits
		rcall	psx_io
		rcall	psx_ack

		mov		temp0, psx1				; data byte 1
		rcall	swapbits
		rcall	psx_io
		rcall	psx_ack

ps_io_finished:
		cbi		DDRB, PS_DAT			; release Data

ps_io_wait_att_high:					; wait for ATT to go high again
		sbis	PINB, PS_ATT
		rjmp	ps_io_wait_att_high

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
		out		USIDR, temp0			; byte to send

		sbi		DDRB, PS_DAT
		cbi		DDRB, PS_CLK
		cbi		DDRB, PS_CMD
		cbi		DDRB, PS_ATT

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
		rjmp	ps_io_finished


;----------------------------------------------------------------------
; Playstation ACK ~4us
;----------------------------------------------------------------------

psx_ack:
		push	temp0
		cbi		PORTB, PS_ACK
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
