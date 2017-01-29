#define cbr(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
#define sbr(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
