avrdude -p atmega8 -U lfuse:w:0xd4:m -U hfuse:w:0xd9:m
avrdude -p atmega8 -B 1 -U flash:w:Saturn_to_PSX.hex