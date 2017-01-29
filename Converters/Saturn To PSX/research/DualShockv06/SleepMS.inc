; ! this proc is made for 10MIPS



SleepMS:		; W = number of milliseconds [1..255]
	char SleepMS_time
	char SleepMS_var2
	
	movwf SleepMS_time
	
	SleepMS_loop1:
		;----[ sleep 1ms, 10000 cycles ]-----------\
		movlw 250
		@@:
			addlw 255
			nop
			nop
			nop
			nop
			nop
			nop
			nop
		bnz @B
		movlw 250
		@@:
			addlw 255
			nop
			nop
			nop
			nop
			nop
			nop
			nop
		bnz @B
		movlw 250
		@@:
			addlw 255
			nop
			nop
			nop
			nop
			nop
			nop
			nop
		bnz @B
		movlw 250
		@@:
			addlw 255
			nop
			nop
			nop
			nop
			nop
			nop
			nop
		bnz @B
		;-----------------------------------------/
	decf SleepMS_time
	bnz SleepMS_loop1
	SleepMS_done:
	return
	
SleepS:
	char SleepS_time
	movwf SleepS_time
	@@:
		invoke SleepMS,250
		invoke SleepMS,250
		invoke SleepMS,250
		invoke SleepMS,250
	decf SleepS_time
	bnz @B
	return