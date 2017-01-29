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

#define NUM_KEYS    8

/* The following function returns an index for the first key pressed. It
 * returns 0 if no key is pressed.
 */
static uchar    keyPressed(void)
{
	uchar   i;

	for (i = 0; i < 8; i++)
	{
		if ((PINB & (1<<i)) == 0)
			return i + 1;
	}

    return 0;
}

/* ------------------------------------------------------------------------- */
/* ----------------------------- USB interface ----------------------------- */
/* ------------------------------------------------------------------------- */

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

static const uchar  keyReport[NUM_KEYS + 1][2] PROGMEM = {
/* none */  {0, 0},                     /* no key pressed */
/*  1 */    {MOD_CONTROL_LEFT | MOD_ALT_LEFT | MOD_GUI_LEFT, KEY_NUM1},
/*  2 */    {MOD_CONTROL_LEFT | MOD_ALT_LEFT | MOD_GUI_LEFT, KEY_NUM2},
/*  3 */    {MOD_CONTROL_LEFT | MOD_ALT_LEFT | MOD_GUI_LEFT, KEY_NUM3},
/*  4 */    {MOD_CONTROL_LEFT | MOD_ALT_LEFT | MOD_GUI_LEFT, KEY_NUM4},
/*  5 */    {MOD_CONTROL_LEFT | MOD_ALT_LEFT | MOD_GUI_LEFT, KEY_NUM5},
/*  6 */    {MOD_CONTROL_LEFT | MOD_ALT_LEFT | MOD_GUI_LEFT, KEY_NUM6},
/*  7 */    {MOD_CONTROL_LEFT | MOD_ALT_LEFT | MOD_GUI_LEFT, KEY_NUM7},
/*  8 */    {MOD_CONTROL_LEFT | MOD_ALT_LEFT | MOD_GUI_LEFT, KEY_NUM8}
};

static void buildReport(uchar key)
{
/* This (not so elegant) cast saves us 10 bytes of program memory */
    *(int *)reportBuffer = pgm_read_word(keyReport[key]);
}

uchar	usbFunctionSetup(uchar data[8])
{
usbRequest_t    *rq = (void *)data;

    usbMsgPtr = reportBuffer;
    if((rq->bmRequestType & USBRQ_TYPE_MASK) == USBRQ_TYPE_CLASS){    /* class request type */
        if(rq->bRequest == USBRQ_HID_GET_REPORT){  /* wValue: ReportType (highbyte), ReportID (lowbyte) */
            /* we only have one report type, so don't look at wValue */
            buildReport(keyPressed());
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

int	main(void)
{
	uchar   key, lastKey = 0, keyDidChange = 0;

    hardwareInit();
	usbInit();
	sei();

	for(;;)
	{
		usbPoll();
        key = keyPressed();
        if(lastKey != key){
            lastKey = key;
            keyDidChange = 1;
        }

        if((keyDidChange == 1) && usbInterruptIsReady()){
            keyDidChange = 2;
            buildReport(lastKey);
            usbSetInterrupt(reportBuffer, sizeof(reportBuffer));
        }

		if((keyDidChange == 2) && usbInterruptIsReady())
		{
			keyDidChange = 0;
            buildReport(0);
            usbSetInterrupt(reportBuffer, sizeof(reportBuffer));
		}

	}
	return 0;
}
