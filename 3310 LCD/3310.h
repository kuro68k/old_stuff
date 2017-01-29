#define	LCD_RESET_PORT	PORTB
#define	LCD_RESET_DDR	DDRB
#define	LCD_RESET_PIN	PINB
#define	LCD_RESET		0

#define	LCD_CTRL_PORT	PORTD
#define	LCD_CTRL_DDR	DDRD
#define	LCD_CTRL_PIN	PIND
#define	LCD_CTRL_MASK	0b11110000
#define	LCD_SCLK		4
#define	LCD_SDIN		5
#define	LCD_DC			6
#define	LCD_SCE			7

#define	LCD_DATA		1
#define	LCD_CMD			0

void lcdinit();
void lcdsend(unsigned char data, char mode);
void lcdlocate(uint8_t x, uint8_t y);
void lcdblit(uint8_t xpos, uint8_t ypos, const uint8_t *image);
