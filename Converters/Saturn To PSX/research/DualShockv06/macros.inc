#define _RA0		PORTA,RA0
#define _RA1		PORTA,RA1
#define _RA2		PORTA,RA2
#define _RA3		PORTA,RA3
#define _RA4		PORTA,RA4
#define _RA5		PORTA,RA5
#define _RA6		PORTA,RA6
#define _RA7		PORTA,RA7

#define _RB0		PORTB,RB0
#define _RB1		PORTB,RB1
#define _RB2		PORTB,RB2
#define _RB3		PORTB,RB3
#define _RB4		PORTB,RB4
#define _RB5		PORTB,RB5
#define _RB6		PORTB,RB6
#define _RB7		PORTB,RB7


#define _RC0		PORTC,RC0
#define _RC1		PORTC,RC1
#define _RC2		PORTC,RC2
#define _RC3		PORTC,RC3
#define _RC4		PORTC,RC4
#define _RC5		PORTC,RC5
#define _RC6		PORTC,RC6
#define _RC7		PORTC,RC7

#define _RD0		PORTD,RD0
#define _RD1		PORTD,RD1
#define _RD2		PORTD,RD2
#define _RD3		PORTD,RD3
#define _RD4		PORTD,RD4
#define _RD5		PORTD,RD5
#define _RD6		PORTD,RD6
#define _RD7		PORTD,RD7

#define _RE0		PORTE,RE0
#define _RE1		PORTE,RE1
#define _RE2		PORTE,RE2





	
	variable MyKIPS = 10000 ; thousands of instructions per second. 
	
	
		CONFIG OSC=HSPLL, OSCS=OFF			
		CONFIG PWRT=OFF, BOR=OFF, BORV=25
		CONFIG WDT=OFF, WDTPS=128 
		CONFIG CCP2MUX=OFF
		CONFIG STVR=OFF, LVP=ON, DEBUG=OFF
		CONFIG CP0=OFF, CP1=OFF, CP2=OFF, CP3=OFF
		CONFIG CPB=OFF, CPD=OFF
		CONFIG WRT0=OFF, WRT1=OFF, WRT2=OFF, WRT3=OFF
		CONFIG WRTB=OFF, WRTC=OFF, WRTD=OFF
		CONFIG EBTR0=OFF, EBTR1=OFF, EBTR2=OFF, EBTR3=OFF, EBTRB=OFF


	errorlevel -205
	errorlevel -206
	errorlevel -207	
	

mov macro where,what ; where is definitely a variable! what is definitely a literal
	if what==0 || what==255
		if what==255
			setf where
		else
			clrf where
		endif
	else
		movlw what
		movwf where
	endif
	endm
	
movfw macro FromWhere ; W = memory[FromWhere]
	movf FromWhere,w
	endm
	
	
	variable @CurCharID = 01h ;used by the "char" macro
		
	
char macro What
	What = @CurCharID
	@CurCharID = @CurCharID + 1
	endm


short macro What
	What = @CurCharID
	@CurCharID = @CurCharID + 2
	endm
	
	variable @IsDec = 100
	if @IsDec !=0x64
		error "*** Dude, please set the build-config to have default-base in Decimal!! 100 !=0x64"
	endif
	


CharArray macro ArrayName,ArraySize
	ArrayName = @CurCharID
	@CurCharID = @CurCharID + ArraySize
	endm


invoke macro What,Param1
	movlw Param1
	rcall What
	endm
	
invokeVar macro What,Var
	movfw Var
	rcall What
	endm
	
WaitLowPin macro Port,Pin
	local label1
	label1:
	btfsc Port,Pin
	bra label1
	endm
	
WaitHighPin macro Port,Pin
	local label1
	label1:
	btfss Port,Pin
	bra label1
	endm
	
	
	
SetPinAsOutput macro Port,Pin
	if Port==PORTA || Port==TRISA
		bcf TRISA,Pin
	else
		if Port==PORTB || Port==TRISB
			bcf TRISB,Pin
		else
			if Port==PORTC || Port==TRISC
				bcf TRISC,Pin
			else
				if Port==PORTD || Port==TRISD
					bcf TRISD,Pin
				else 
					error "*** Dude, unknown port"
				endif
			endif
		endif
	endif
	endm

SetPinAsInput macro Port,Pin
	if Port==PORTA || Port==TRISA
		bsf TRISA,Pin
	else
		if Port==PORTB || Port==TRISB
			bsf TRISB,Pin
		else
			if Port==PORTC || Port==TRISC
				bsf TRISC,Pin
			else
				if Port==PORTD || Port==TRISD
					bsf TRISD,Pin
				else 
					error "*** Dude, unknown port"
				endif
			endif
		endif
	endif
	endm
	
BitCopy macro SrcPort,SrcPin,DestPort,DestPin
	btfsc SrcPort,SrcPin
	bsf DestPort,DestPin
	btfss SrcPort,SrcPin
	bcf DestPort,DestPin
	endm
	
SetPin macro Port,Pin,Value
	if Value==0
		bcf Port,Pin
	else
		bsf Port,Pin
	endif
	endm
	
SetBit macro Port,Pin,Value
	if Value==0
		bcf Port,Pin
	else
		bsf Port,Pin
	endif
	endm
	

	
	
	variable @B=0

@@ macro param1
	@B = $
	endm


GetArrayByte macro ArrayName,Index ; Index is either W, or a file-register!
	if Index!=W
		movf Index,W
	endif
	LFSR FSR0,ArrayName
	movf PLUSW0,W
endm



WaitXMicrosecs macro numMicroSecs ; for 10MIPS
	local label1
	movlw numMicroSecs
	label1:
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		addlw -1
		bnz label1
	
endm


        LIST

