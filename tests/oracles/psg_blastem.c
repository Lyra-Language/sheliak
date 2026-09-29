// SPDX-License-Identifier: GPL-3.0-or-later
//
// Unlike the rest of Sheliak (MIT), this file is GPL-3.0-or-later: it exists only to be built
// with BlastEm's psg.c, which is.
/*
 * psg_blastem — BlastEm's PSG (psg.c, GPLv3, built from the pinned BlastEm tree beside it and
 * never linked into Sheliak) run on a script, printing its state after every tick, for
 * tests/psg.sh to compare with Sheliak's PSG.
 *
 *   psg_blastem < script      script lines: "w HEX" writes a byte, "t N" runs N ticks
 *
 * Each tick prints: the four channels' outputs, the noise output, the four attenuations,
 * and the noise shift register.
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "psg.h"

/* The audio, logging and scope hooks psg.c calls, which a state dump needs none of. */
audio_source *render_audio_source(const char *name, uint64_t master_clock, uint64_t sample_divider, uint8_t channels) { return NULL; }
void render_put_stereo_sample(audio_source *src, int16_t left, int16_t right) {}
void render_free_source(audio_source *src) {}
void render_audio_adjust_clock(audio_source *src, uint64_t master_clock, uint64_t sample_divider) {}
void event_log(uint8_t type, uint32_t cycle, uint8_t size, uint8_t *payload) {}
void vgm_sn76489_write(vgm_writer *vgm, uint32_t cycle, uint8_t value) {}
void vgm_sn76489_init(vgm_writer *vgm, uint32_t clock, uint16_t feedback, uint8_t shift_reg_size, uint8_t flags) {}
void vgm_gg_pan_write(vgm_writer *vgm, uint32_t cycle, uint8_t value) {}
/* serialize.c's (linked for psg.c's save states, which this never uses) error path. */
void fatal_error(char *format, ...) { fputs("fatal_error\n", stderr); exit(1); }
long file_size(FILE *f) { return 0; }
void warning(char *format, ...) {}

int main(void)
{
	psg_context psg;
	psg_init(&psg, 1, 1);
	char op;
	unsigned value;
	while (scanf(" %c %x", &op, &value) == 2) {
		if (op == 'w') {
			psg_write(&psg, value);
			continue;
		}
		for (unsigned i = 0; i < value; i++) {
			psg_run(&psg, psg.cycles + 1);
			printf("%d%d%d%d %d %x %x %x %x %04x\n", psg.output_state[0], psg.output_state[1],
			       psg.output_state[2], psg.output_state[3], psg.noise_out, psg.volume[0],
			       psg.volume[1], psg.volume[2], psg.volume[3], psg.lsfr);
		}
	}
	return 0;
}
