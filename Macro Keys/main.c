#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>

#include "usbdrv.h"
#include "keyboard.h"

/* ----------------------- hardware I/O abstraction ------------------------ */

static void hardwareInit(void)
{
uchar	i, j;

    PORTB	= 0xff;			/* activate all pull-ups */
    DDRB	= 0;       		/* all pins input */
	PORTC	= 0xff;
	DDRC	= 0;
    PORTD	= 0b11110011;   /* 1111 1010 bin: activate pull-ups except on USB lines */
    DDRD 	= 0b00001100;	/* 0000 0111 bin: all pins input except USB (-> USB reset) */

	j = 0;
	while(--j){     /* USB Reset by device only required on Watchdog Reset */
		i = 0;
		while(--i); /* delay >10ms for USB reset */
	}

    DDRD	= 0b00000000;
}

/* ------------------------------------------------------------------------- */

static uchar    keyPressed(void)
{
	uchar   i;

	for (i = 0; i < 6; i++)
	{
		if ((PINC & (1<<i)) == 0)
			return i + 1;
	}

	for (i = 0; i < 6; i++)
	{
		if ((PINB & (1<<i)) == 0)
			return i + 7;
	}

	if ((PIND & (1<<0)) == 0) return 13;
	if ((PIND & (1<<0)) == 0) return 14;

	for (i = 4; i < 8; i++)
	{
		if ((PIND & (1<<i)) == 0)
			return i + 15;
	}

    return 0;
}

static uchar    reportBuffer[2];    /* buffer for HID reports */
static uchar    idleRate;           /* in 4 ms units */

PROGMEM char usbHidReportDescriptor[35] = { /* USB report descriptor */
    0x05, 0x01,                    // USAGE_PAGE (Generic Desktop)
    0x09, 0x06,                    // USAGE (Keyboard)
    0xa1, 0x01,                    // COLLECTION (Application)
    0x05, 0x07,                    //   USAGE_PAGE (Keyboard)
    0x19, 0xe0,                    //   USAGE_MINIMUM (Keyboard LeftControl)
    0x29, 0xe7,                    //   USAGE_MAXIMUM (Keyboard Right GUI)
    0x15, 0x00,                    //   LOGICAL_MINIMUM (0)
    0x25, 0x01,                    //   LOGICAL_MAXIMUM (1)
    0x75, 0x01,                    //   REPORT_SIZE (1)
    0x95, 0x08,                    //   REPORT_COUNT (8)
    0x81, 0x02,                    //   INPUT (Data,Var,Abs)
    0x95, 0x01,                    //   REPORT_COUNT (1)
    0x75, 0x08,                    //   REPORT_SIZE (8)
    0x25, 0x65,                    //   LOGICAL_MAXIMUM (101)
    0x19, 0x00,                    //   USAGE_MINIMUM (Reserved (no event indicated))
    0x29, 0x65,                    //   USAGE_MAXIMUM (Keyboard Application)
    0x81, 0x00,                    //   INPUT (Data,Ary,Abs)
    0xc0                           // END_COLLECTION
};

static void buildReport(uchar key)
{
	reportBuffer[0] = 0;		// modifier
	reportBuffer[1] = key;		// key
}

uchar	usbFunctionSetup(uchar data[8])
{
usbRequest_t    *rq = (void *)data;

    usbMsgPtr = reportBuffer;
    if((rq->bmRequestType & USBRQ_TYPE_MASK) == USBRQ_TYPE_CLASS){    /* class request type */
        if(rq->bRequest == USBRQ_HID_GET_REPORT){  /* wValue: ReportType (highbyte), ReportID (lowbyte) */
            /* we only have one report type, so don't look at wValue */
            buildReport(0);
            return sizeof(reportBuffer);
        }else if(rq->bRequest == USBRQ_HID_GET_IDLE){
            usbMsgPtr = &idleRate;
            return 1;
        }else if(rq->bRequest == USBRQ_HID_SET_IDLE){
            idleRate = rq->wValue.bytes[1];
        }
    }else{
        /* no vendor specific requests implemented */
    }
	return 0;
}

/* ------------------------------------------------------------------------- */

void sendkey(uchar key)
{
	while(!usbInterruptIsReady()) asm("nop");
	//	usbPoll();
	buildReport(key);
	usbSetInterrupt(reportBuffer, sizeof(reportBuffer));

	while(!usbInterruptIsReady()) asm("nop");
	//	usbPoll();
	buildReport(0);
	usbSetInterrupt(reportBuffer, sizeof(reportBuffer));
}

/* ------------------------------------------------------------------------- */

int	main(void)
{
	uchar   key;
	uchar	lastKey = 0;
	uchar	count;

    hardwareInit();
	usbInit();
	sei();

	for(;;)
	{
		usbPoll();
        key = keyPressed();

        if((lastKey != key) && (key != 0))
		{
            lastKey = key;

			sendkey(KEY_TAB);

			for (count = key; count > 0; count--)
			{
				sendkey(KEY_TAB);
			}

			sendkey(KEY_RETURN);
        }
	}
	return 0;
}
