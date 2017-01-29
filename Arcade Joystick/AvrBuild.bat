@ECHO OFF
"d:\Atmel\AVR Tools\AvrAssembler2\avrasm2.exe" -S "E:\code\AVR\Arcade Joystick\labels.tmp" -fI -W+ie -o "E:\code\AVR\Arcade Joystick\Arcade_Joystick.hex" -d "E:\code\AVR\Arcade Joystick\Arcade_Joystick.obj" -e "E:\code\AVR\Arcade Joystick\Arcade_Joystick.eep" -m "E:\code\AVR\Arcade Joystick\Arcade_Joystick.map" "E:\code\AVR\Arcade Joystick\Arcade_Joystick.asm"
