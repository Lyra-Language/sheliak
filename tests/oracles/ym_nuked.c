// SPDX-License-Identifier: LGPL-2.1-or-later
//
// Unlike the rest of Sheliak (MIT), this file is LGPL-2.1-or-later: it exists only to be built
// with Nuked-OPN2's ym3438.c, which it includes.
/*
 * ym_nuked — Nuked-OPN2 (LGPL-2.1, downloaded pinned into build/deps/nuked-opn2 and never
 * linked into Sheliak) run on a script as a YM2612, printing its output, for tests/ym.sh to
 * compare with Sheliak's YM2612.
 *
 *   ym_nuked < script
 *
 * Script lines: "w PORT HEX" writes a byte to port 0-3; "c N" runs N cycles; "s N" runs N
 * samples (24 cycles each), printing each sample's two outputs summed over its cycles; "r PORT" reads the
 * status, printing it; "t" prints the log-sine and exponent ROMs.
 */
#include <stdio.h>
#include "ym3438.c"

int main(void)
{
	static ym3438_t chip;
	OPN2_SetChipType(ym3438_mode_ym2612);
	OPN2_Reset(&chip);
	char op;
	while (scanf(" %c", &op) == 1) {
		unsigned port, value;
		if (op == 'w' && scanf("%u %x", &port, &value) == 2) {
			OPN2_Write(&chip, port, value);
		} else if (op == 'c' && scanf("%u", &value) == 1) {
			Bit16s out[2];
			for (unsigned n = 0; n < value; n++) OPN2_Clock(&chip, out);
		} else if (op == 's' && scanf("%u", &value) == 1) {
			for (unsigned n = 0; n < value; n++) {
				int left = 0, right = 0;
				for (int c = 0; c < 24; c++) {
					Bit16s out[2];
					OPN2_Clock(&chip, out);
					left += out[0];
					right += out[1];
				}
				printf("%d %d\n", left, right);
			}
		} else if (op == 'r' && scanf("%u", &port) == 1) {
			printf("status %02x\n", OPN2_Read(&chip, port));
		} else if (op == 't') {
			for (int i = 0; i < 256; i++) printf("logsin %d %d\n", i, logsinrom[i]);
			for (int i = 0; i < 256; i++) printf("exp %d %d\n", i, exprom[i]);
		}
	}
	return 0;
}
