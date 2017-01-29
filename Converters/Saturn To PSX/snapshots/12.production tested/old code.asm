/*
		rcall	psx_ack

		ldi		temp0, 127				; data byte 2 (right joystick x)
		rcall	psx_io
		rcall	psx_ack
		ldi		temp0, 127				; data byte 3 (right joystick y)
		rcall	psx_io
		rcall	psx_ack

		; check dual analogue/d-pad mode jumper
		sbis	PINB, 0					; jumper off = dual d-pad + left analogue mode
		rjmp	ps_dpad_only

		ldi		temp0, 127				; data byte 4 (left joystick x)
		sbrs	psx0, 5					; right
		ldi		temp0, 255
		sbrs	psx0, 7					; left
		ldi		temp0, 0
		rcall	psx_io
		rcall	psx_ack

		ldi		temp0, 127				; data byte 5 (left joystick y)
		sbrs	psx0, 6					; down
		ldi		temp0, 255
		sbrs	psx0, 4					; up
		ldi		temp0, 0
		rcall	psx_io
		;rcall	psx_ack
		
		rjmp	ps_io_finished

ps_dpad_only:
		ldi		temp0, 127				; data byte 4 (left joystick x)
		rcall	psx_io
		rcall	psx_ack
		ldi		temp0, 127				; data byte 5 (left joystick y)
		rcall	psx_io
		rcall	psx_ack
*/
