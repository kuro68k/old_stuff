avrdude -p attiny2313 -U lfuse:w:0xe4:m -U hfuse:w:0x9f:m -U efuse:w:0xff:m
avrdude -p attiny2313 -B 1 -U flash:w:SNES_to_PSX.hex