;----------------------------------------------------------------------
; Read config bytes from EEPROM
;----------------------------------------------------------------------

eeprom_read_config:
		push	temp0
		push	temp1

		ldi		ZH, 0
		ldi		ZL, 0

		rcall	eeprom_read_byte	; button mapping
		mov		bmap, temp0
		rcall	eeprom_read_byte	; autofire speed
		mov		autospeed, temp0
		rcall	eeprom_read_byte	; checksum
		mov		temp1, autospeed
		eor		temp1, bmap
		cp		temp0, temp1		; test against checksum
		brne	eeprom_read_invalid
		
		; button mapping sanity checking
		mov		temp0, bmap
		andi	temp0, 0b00111111	; mask tournament mode and autofire reverse bits
		cpi		temp0, HIGHMAP+1	; highest mapping
		brsh	eeprom_read_invalid

		; autofire sanity checking
		mov		temp0, autospeed
		cpi		temp0, 3			; range 0-2
		brsh	eeprom_read_invalid

		pop		temp1
		pop		temp0
		ret

eeprom_read_invalid:
		; reset to defaults
		clr		bmap
		clr		autospeed
		
		pop		temp1
		pop		temp0
		ret


;----------------------------------------------------------------------
; Read byte from EEPROM address Z to temp0, increment Z
;----------------------------------------------------------------------

eeprom_read_byte:
		sbic	EECR, EEWE		; wait for completion of previous write
		rjmp	eeprom_read_byte

		out		EEARH, ZH		; load address
		out		EEARL, ZL
		adiw	Z, 1			; increment address

		sbi		EECR, EERE		; read mode
		in		temp0, EEDR		; read byte
		ret


;----------------------------------------------------------------------
; Write config bytes to EEPROM
;----------------------------------------------------------------------

eeprom_write_config:
		push	temp0

		ldi		ZH, 0
		ldi		ZL, 0

		mov		temp0, bmap			; button mapping
		rcall	eeprom_write_byte
		mov		temp0, autospeed	; autofire speed
		rcall	eeprom_write_byte
		eor		temp0, bmap			; checksum byte
		rcall	eeprom_write_byte

		pop		temp0
		ret


;----------------------------------------------------------------------
; Write byte in temp0 to EEPROM address Z, increment Z
;----------------------------------------------------------------------

eeprom_write_byte:
		sbic	EECR, EEWE		; wait for completion of previous write
		rjmp	eeprom_write_byte

		out		EEARH, ZH		; load address
		out		EEARL, ZL
		adiw	Z, 1			; increment address

		out		EEDR, temp0		; byte to write
		sbi		EECR, EEMWE		; write mode
		sbi		EECR, EEWE		; start write
		ret
