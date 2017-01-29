#include <avr/io.h>
#include <util/delay.h>
#include <avr/pgmspace.h>

#include "3310.h"
#include "bitmod.h"

void lcdinit()
{
	sbr(LCD_RESET_DDR, LCD_RESET);
	cbr(LCD_RESET_PORT,	LCD_RESET);

	LCD_CTRL_DDR	|= LCD_CTRL_MASK;
	LCD_CTRL_PORT	|= LCD_CTRL_MASK;

	cbr(LCD_RESET_PORT,	LCD_RESET);

	_delay_ms(100);

	sbr(LCD_RESET_PORT,	LCD_RESET);

	lcdsend(0x21, LCD_CMD);		// LCD extended commands
//	lcdsend(0b10101000, LCD_CMD);	// contrast
	lcdsend(0x80|0x28, LCD_CMD);		// Set LCD Vop(Contrast)
	lcdsend(0x06, LCD_CMD);		// Set Temp coefficent
	lcdsend(0x13, LCD_CMD);		// LCD bias mode 1:48
	lcdsend(0x20, LCD_CMD);		// Standard Commands, Horizontal addressing

	lcdsend(0x0C, LCD_CMD);		// LCD in normal mode
}

void lcdsend(unsigned char data, char mode)
{
	uint8_t	i;

	cbr(LCD_CTRL_PORT, LCD_SCLK);	// clock starts low

	if (mode)
		sbr(LCD_CTRL_PORT, LCD_DC);		// data byte
	else
		cbr(LCD_CTRL_PORT, LCD_DC);		// command byte
	
	cbr(LCD_CTRL_PORT, LCD_SCE);	// enable

	for (i = 8; i > 0; i--)
	{
		if (data & 0x80)			// set SDIN
			sbr(LCD_CTRL_PORT, LCD_SDIN);
		else
			cbr(LCD_CTRL_PORT, LCD_SDIN);
		sbr(LCD_CTRL_PORT, LCD_SCLK);			// clock out
		cbr(LCD_CTRL_PORT, LCD_SCLK);

		data = data << 1;
	}

	sbr(LCD_CTRL_PORT, LCD_SCE);	// disable
}

void lcdlocate(uint8_t x, uint8_t y)
{
	lcdsend(0x40|(y&0x07), LCD_CMD);
	lcdsend(0x80|(x&0x7f), LCD_CMD);
}

void lcdblit(uint8_t xpos, uint8_t ypos, const uint8_t *image)
{
	uint8_t	width;		// image width in bytes
	uint8_t	height;		// image height in rows
	uint8_t	x, y;		// counters
	uint8_t data;

	width = pgm_read_byte(image++);
	height = pgm_read_byte(image++);

	for (y = 0; y < height; y++)
	{
		lcdlocate(xpos, ypos + y);
		for (x = 0; x < width; x++)
		{
			data = pgm_read_byte(image++);
			lcdsend(data, LCD_DATA);
		}
	}
}
