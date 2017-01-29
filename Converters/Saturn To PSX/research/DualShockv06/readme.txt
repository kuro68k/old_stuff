October 2007

Description:
  An emulator of a simplified DualShock controller.
  Target: the Xinga PS2->USB adapter. Playing Resistance with your PC's keyboard and mouse. Or
	adding any keyboard macros/combos to help you own your buddies :). Similar to FragFX,
	but with the potential to become better. 
  Microcontroller: PIC18F452, in 40MHz mode (10MIPS)

Notes on the Xinga adapter:
  - The clock is unforgiving, around 3 microseconds per cycle. So, 1.5us to detect CLK-change 
    and write data, then same with reading. 
  - The polling rate is fortunately once every 10ms
  - If it couldn't poll, it uses the previous data! Fortunately. 

Notes on the PIC18F452, regarding porting to other PIC:
  - 5MIPS minimum (20MHz). 
  - not every pin could be used for PSX input/output! Disabled internal pull-up resistors seem
	a preference >_> (won't work on pins without such resistors, though!). Forget about
	hardware-accelerated SPI. Didn't work. Forget about putting lots of code in the
	interrupts, any 5-6 more cycles and it's prone to misbehave or skip polls if
	you use PSX_ATT.  

Connecting the LPT to the MCU:
	LPT's data[0..7] - connect to PORTC of MCU
	LPT's Strobe  - connect to RB1 (used as interrupt)
	PSX pins: see the pinouts of any PSX controller, and look at the .asm code for reference.


Next to do: 
  - measure and study the logarithmic-curve of Resistance:FoM (for the right stick). To counter it either in firmware or software. 