@ECHO OFF
"d:\AVR Tools\AvrAssembler2\avrasm2.exe" -S "E:\code\AVR\Converters\Saturn to Supergun\labels.tmp" -fI -W+ie -o "E:\code\AVR\Converters\Saturn to Supergun\Saturn_to_Supergun.hex" -d "E:\code\AVR\Converters\Saturn to Supergun\Saturn_to_Supergun.obj" -e "E:\code\AVR\Converters\Saturn to Supergun\Saturn_to_Supergun.eep" -m "E:\code\AVR\Converters\Saturn to Supergun\Saturn_to_Supergun.map" "E:\code\AVR\Converters\Saturn to Supergun\Saturn_to_Supergun.asm"
