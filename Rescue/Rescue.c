#include <avr/io.h>
#include <util/delay.h>

#define	HFUSE	0xDF	// Default for ATmega48/88/168, for others see
#define	LFUSE	0x62	// http://www.engbedded.com/cgi-bin/fc.cgi

/*
#define  DATA    PORTD // PORTD = Arduino Digital pins 0-7
#define  DATAD   DDRD  // Data direction register for DATA port
#define  VCC     8		PB0
#define  RDY     12     PB4 // RDY/!BSY signal from target
#define  OE      11		PB3
#define  WR      10		PB2
#define  BS1     9		PB1
#define  XA0     13		PB5
#define  XA1     18    	PC4	// Analog inputs 0-5 can be addressed as
#define  PAGEL   19    	PC5	// digital outputs 14-19
#define  RST     14    	PC0	// Output to level shifter for !RESET
#define  BS2     16		PC2
#define  XTAL1   17		PC3

#define  BUTTON  15    	PC1	// Run button
#define  LED     0
*/

// PORTB
#define	_VCC	(1<<0)
#define	_RDY	(1<<4)
#define	_OE		(1<<3)
#define	_WR		(1<<2)
#define	_BS1	(1<<1)
#define	_XA0	(1<<5)

// PORTC
#define	_XA1	(1<<4)
#define	_PAGEL	(1<<5)
#define	_RST	(1<<0)
#define	_BS2	(1<<2)
#define	_XTAL1	(1<<3)

#define	_BUTTON	(1<<1)

void HardwareInit()
{
	DDRB	= ~(_RDY);			// all outputs except RDY (PB4)
	PORTB	= 0x00;				// no pull-up

	DDRC	= ~(_BUTTON);		// all outputs except BUTTON (PC1)
	PORTC	= (_BUTTON)|(_RST);	// pull-up and 12V off (PC0 = 1)

	DDRD	= 0xff;				// all outputs
	PORTD	= 0x00;
}

void sendcmd(unsigned char command)
{
	PORTC |= _XA1;
	PORTB &= ~(_XA0|_BS1);
	
	PORTD = command;

	PORTC |= _XTAL1;
	_delay_ms(1);
	PORTC &= ~(_XTAL1);
	_delay_ms(1);
}

void writefuse(unsigned char fuse, char highbyte)
{
	PORTC &= ~(_XA1);
	PORTB |= _XA0;
	_delay_ms(1);

	PORTD = fuse;
	PORTC |= _XTAL1;
	_delay_ms(1);
	PORTC &= ~(_XTAL1);

	if (highbyte)
		PORTB |= _BS1;
	else
		PORTB &= ~(_BS1);

	PORTB &= ~(_WR);
	_delay_ms(1);
	PORTB |= _WR;
	_delay_ms(100);
}

int main()
{
	HardwareInit();

	for (;;)
	{
		while (PINC & _BUTTON) {}	// wait for button

		// Initialize pins to enter programming mode
		PORTC &= ~(_PAGEL|_XA1|_BS2);
		PORTB &= ~(_XA0|_BS1);
	
		// Enter programming mode
		PORTB |= _VCC|_WR|_OE;
		_delay_ms(1);
		PORTC &= ~(_RST);
		_delay_ms(1);

		// Program HFUSE
		sendcmd(0b01000000);
		writefuse(HFUSE, 1);

		// Program LFUSE
		sendcmd(0b01000000);
  		writefuse(LFUSE, 0);

		_delay_ms(1000);			// allow button to be released

		// Exit programming mode
		PORTC |= _RST;

		// Turn off outputs
		PORTD = 0x00;
		PORTB &= ~(_VCC|_WR|_OE|_XA0|_BS1);
		PORTC &= ~(_PAGEL|_XA1|_BS2);
	}
}

