@ECHO OFF
"d:\AVR Tools\AvrAssembler2\avrasm2.exe" -S "E:\code\AVR\Converters\SNES To PSX\labels.tmp" -fI -W+ie -o "E:\code\AVR\Converters\SNES To PSX\SNES_to_PSX.hex" -d "E:\code\AVR\Converters\SNES To PSX\SNES_to_PSX.obj" -e "E:\code\AVR\Converters\SNES To PSX\SNES_to_PSX.eep" -m "E:\code\AVR\Converters\SNES To PSX\SNES_to_PSX.map" "E:\code\AVR\Converters\SNES To PSX\SNES_to_PSX.asm"
