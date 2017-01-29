#include <avr/io.h>
#include <util/delay.h>
#include <avr/pgmspace.h>

#include "3310.h"
#include "images.h"
#include "layout.h"

int main()
{
	unsigned char data = 0;
	int i;

	lcdinit();

	lcdblit(0, 0, tomoyo);
	lcdblit(BUTTON1X, BUTTON1Y, buttonlowerF);

	for(;;);
}
