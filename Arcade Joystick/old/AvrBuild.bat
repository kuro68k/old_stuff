@ECHO OFF
"d:\Atmel\AVR Tools\AvrAssembler2\avrasm2.exe" -S "E:\code\AVR\labels.tmp" -fI -W+ie -o "E:\code\AVR\joyadapter.hex" -d "E:\code\AVR\joyadapter.obj" -e "E:\code\AVR\joyadapter.eep" -m "E:\code\AVR\joyadapter.map" "E:\code\AVR\joyadapter_v1_1_adi04.asm"
