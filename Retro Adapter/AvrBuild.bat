@ECHO OFF
"d:\AVR Tools\AvrAssembler2\avrasm2.exe" -S "E:\code\AVR\Retro Adapter\labels.tmp" -fI -W+ie -o "E:\code\AVR\Retro Adapter\Retro_Adapter.hex" -d "E:\code\AVR\Retro Adapter\Retro_Adapter.obj" -e "E:\code\AVR\Retro Adapter\Retro_Adapter.eep" -m "E:\code\AVR\Retro Adapter\Retro_Adapter.map" "E:\code\AVR\Retro Adapter\Retro Adapter.asm"
