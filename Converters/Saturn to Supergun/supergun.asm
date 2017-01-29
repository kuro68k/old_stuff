;----------------------------------------------------------------------
; Saturn to Playstation mode
;----------------------------------------------------------------------

sg_mode:
		; Main Supergun servicing section

		ldi		pbs, 0xff			; PORT shadows
		ldi		pcs, 0xff
		clr		afbutton
		clr		startf

// TH = 1, TR = 0																			
		sbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB

		; button mapping
		ldi		ZH, HIGH(sg10_jump)
		ldi		ZL, LOW(sg10_jump)
		mov		temp0, bmap
		andi	temp0, 0b00111111
		add		ZL, temp0
		clr		temp0
		adc		ZH, temp0
		ijmp
sg10_jump:
		rjmp	sg10_def
		rjmp	sg10_a
		rjmp	sg10_b
		rjmp	sg10_c
		rjmp	sg10_x
		rjmp	sg10_y
		rjmp	sg10_z

sg10_def:
sg10_b:
sg10_y:
		bst		temp1, SAT_LF		; A -> LP
		bld		LPP, LPB
		bst		temp2, SAT_UP		; B -> MP
		bld		MPP, MPB
		bst		temp2, SAT_DN		; C -> HP 
		bld		HPP, HPB
		bst		temp2, SAT_RT		; Start -> Start 
		bld		STP, STB
		rjmp	sg10_done

sg10_a:
		bst		temp1, SAT_LF		; A -> LK
		bld		LKP, LKB
		bst		temp2, SAT_UP		; B -> MK
		bld		MKP, MKB
		bst		temp2, SAT_DN		; C -> HK 
		bld		HKP, HKB
		bst		temp2, SAT_RT		; Start -> Start 
		bld		STP, STB
		rjmp	sg10_done

sg10_c:
sg10_x:
		bst		temp1, SAT_LF		; A -> LP
		bld		LPP, LPB
		bst		temp2, SAT_UP		; B -> MP
		bld		MPP, MPB
		bst		temp2, SAT_DN		; C -> MP 
		bld		MPP, HPB
		bst		temp2, SAT_RT		; Start -> Start 
		bld		STP, STB
		rjmp	sg10_done

sg10_z:
		bst		temp1, SAT_LF		; A -> HP
		bld		HPP, HPB
		bst		temp2, SAT_UP		; B -> MP
		bld		MPP, MPB
		bst		temp2, SAT_DN		; C -> LP 
		bld		LPP, LPB
		bst		temp2, SAT_RT		; Start -> Start 
		bld		STP, STB

sg10_done:


// TH = 0, TR = 0																			
		cbi		PORTD, SAT_TH
		cbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB

		; button mapping
		ldi		ZH, HIGH(sg00_jump)
		ldi		ZL, LOW(sg00_jump)
		mov		temp0, bmap
		andi	temp0, 0b00111111
		add		ZL, temp0
		clr		temp0
		adc		ZH, temp0
		ijmp
sg00_jump:
		rjmp	sg00_def
		rjmp	sg00_a
		rjmp	sg00_b
		rjmp	sg00_c
		rjmp	sg00_x
		rjmp	sg00_y
		rjmp	sg00_z

sg00_def:
		bst		temp1, SAT_LF		; X -> LK
		bld		LKP, LKB
		bst		temp2, SAT_UP		; Y -> MK
		bld		MKP, MKB
		bst		temp2, SAT_DN		; Z -> HK 
		bld		HKP, HKB
		bst		temp2, SAT_RT		; R -> Autofire
		bld		afbutton, 0
		rjmp	sg00_done

sg00_a:
		bst		temp1, SAT_LF		; X -> LP
		bld		LPP, LPB
		bst		temp2, SAT_UP		; Y -> MP
		bld		MPP, MPB
		bst		temp2, SAT_DN		; Z -> LK 
		bld		LKP, LKB
		bst		temp2, SAT_RT		; R -> Autofire
		bld		afbutton, 0
		rjmp	sg00_done

sg00_b:
		bst		temp1, SAT_LF		; X -> MP
		bld		MPP, MPB
		bst		temp2, SAT_UP		; Y -> HP
		bld		HPP, HPB
		bst		temp2, SAT_DN		; Z -> LK 
		bld		LKP, LKB
		bst		temp2, SAT_DN		; R -> Special 
		bld		SPP, SPB
		rjmp	sg00_done

sg00_c:
		bst		temp1, SAT_LF		; X -> HP
		bld		HPP, HPB
		bst		temp2, SAT_UP		; Y -> LK
		bld		LKP, LKB
		bst		temp2, SAT_DN		; Z -> LK 
		bld		LKP, LKB
		bst		temp2, SAT_DN		; R -> Special 
		bld		SPP, SPB
		rjmp	sg00_done

sg00_x:
		bst		temp1, SAT_LF		; X -> LP
		bld		LPP, LPB
		bst		temp2, SAT_UP		; Y -> MP
		bld		MPP, MPB
		bst		temp2, SAT_DN		; Z -> HP 
		bld		HPP, HPB
		bst		temp2, SAT_DN		; R -> LK
		bld		LKP, LKB
		rjmp	sg00_done

sg00_y:
		bst		afflag, 0
		sbrs	temp1, SAT_LF		; X -> LP (AF) 
		bld		LPP, LPB
		sbrs	temp2, SAT_UP		; Y -> MP (AF) 
		bld		MPP, MPB
		sbrs	temp2, SAT_DN		; Z -> HP (AF) 
		bld		HPP, HPB
		sbrs	temp2, SAT_DN		; R -> LK (AF) 
		bld		LKP, LKB
		rjmp	sg00_done

sg00_z:
		bst		temp1, SAT_LF		; A -> HK
		bld		HKP, HKB
		bst		temp2, SAT_UP		; B -> MK
		bld		MKP, MKB
		bst		temp2, SAT_DN		; C -> LK 
		bld		LKP, LKB
		bst		temp2, SAT_RT		; R -> Autofire
		bld		afbutton, 0

sg00_done:


// TH = 0, TR = 1																			
		cbi		PORTD, SAT_TH
		sbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB

		bst		temp1, SAT_LF		; Left 
		bld		LFP, LFB
		bst		temp2, SAT_UP		; Up 
		bld		UPP, UPB
		bst		temp2, SAT_DN		; Down 
		bld		DNP, DNB
		bst		temp2, SAT_RT		; Right 
		bld		RTP, RTB

// TH = 1, TR = 1																			
		sbi		PORTD, SAT_TH
		sbi		PORTD, SAT_TR
		rcall	sat_delay			; 2us delay
		in		temp2, PIND
		in		temp1, PINB

		; button mapping
		ldi		ZH, HIGH(sg11_jump)
		ldi		ZL, LOW(sg11_jump)
		mov		temp0, bmap
		andi	temp0, 0b00111111
		add		ZL, temp0
		clr		temp0
		adc		ZH, temp0
		ijmp
sg11_jump:
		rjmp	sg11_def
		rjmp	sg11_a
		rjmp	sg11_b
		rjmp	sg11_c
		rjmp	sg11_x
		rjmp	sg11_y
		rjmp	sg11_z

sg11_def:
sg11_a:
sg11_z:
		bst		temp1, SAT_RT		; L -> Special
		bld		LPP, LPB
		rjmp	sg11_done

sg11_b:
sg11_c:
		bst		temp2, SAT_DN		; L -> MK 
		bld		MKP, MKB
		rjmp	sg11_done

sg11_x:
sg11_y:
		bst		temp2, SAT_DN		; R -> LK
		bld		LKP, LKB
		rjmp	sg11_done

sg11_done:

		; autofire
		sbrc	afbutton, 0
		rjmp	sg_no_af
		sbrs	afflag, 0
		rjmp	sg_no_af
		andi	LKP, ~(1<<LKB)
		andi	MKP, ~(1<<MKB)
		andi	HKP, ~(1<<HKB)
		andi	LPP, ~(1<<LPB)
		andi	MPP, ~(1<<MPB)
		andi	HPP, ~(1<<HPB)

sg_no_af:
		; combine pbs with current PB6/PB7 setting
		cli
		in		temp0, PORTB
		ori		temp0, 0b00111111
		and		pbs, temp0
		; update I/O ports
		out		PORTC, pcs
		out		PORTB, pbs
		sei

		; check if any button or d-pad was pressed, if so reset start held count
		ldi		temp0, 0xff
		and		temp0, pbs
		and		temp0, pcs
		cpi		temp0, 0xff
		breq	sg_no_buttons
		clr		bheld
		rjmp	sg_mode

sg_no_buttons:
		; if in fixed button mapping mode disable button held mode
		tst		emumode
		breq	sg_check_start
		rjmp	sg_mode

sg_check_start:
		; check if start button held
		sbrs	STP, STB
		breq	sg_start_held
		clr		bheld					; not held, reset counter
		rjmp	sg_mode

sg_start_held:
		mov		temp0, bheld
		cpi		temp0, BHTIME1
		brsh	jump_sat_setup_mode
		rjmp	sg_mode

		; branch is too far to branch
jump_sat_setup_mode:
		rcall	sat_setup_mode
		rjmp	sg_mode
