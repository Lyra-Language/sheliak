#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Unlike the rest of Sheliak (MIT), this file is GPL-3.0-or-later: it quotes BlastEm's
# source to patch it, and what it adds is code for BlastEm.
"""Patch a pinned BlastEm source tree for use as tests/vdp.sh's oracle.

    tests/blastem_patches.py BLASTEM_SOURCE_DIR

Three patches, none to anything BlastEm emulates:

- render_sdl.c: the no-OpenGL build reads an OpenGL-only field in one line; guard it.
- render_sdl.c: the no-OpenGL screenshot of a non-interlaced frame read every other row of
  the texture (a doubled pitch meant for interlace) from its top-left, border included; save
  it from the texture past the overscan the configuration crops, at its real pitch, as the
  OpenGL path does from its buffer.
- debug.c: a `screenshot FILE` debugger command, saving the next completed frame through
  the same path the screenshot key binding uses (BlastEm offers it from nowhere else).

Each patch asserts the text it replaces exists exactly once, so a new revision that moved
it fails loudly here rather than building an unpatched oracle. Bump PATCHES in
tests/vdp.sh when this file changes, so a cached build is rebuilt.
"""

import sys


def patch(path, old, new):
    source = open(path).read()
    assert source.count(old) == 1, f"{path} changed; revisit tests/blastem_patches.py"
    open(path, "w").write(source.replace(old, new))


root = sys.argv[1]

line = ("\tprocess_framebuffer(which < FRAMEBUFFER_USER_START ? texture_buf : "
        "extras[which - FRAMEBUFFER_USER_START].texture_buf, which, width);")
patch(f"{root}/render_sdl.c", line,
      "#ifdef DISABLE_OPENGL\n\tprocess_framebuffer(texture_buf, which, width);\n#else\n"
      + line + "\n#endif")

patch(f"{root}/render_sdl.c",
      "\t\t\tuint32_t shot_pitch = locked_pitch;\n"
      "\t\t\tif (which == FRAMEBUFFER_EVEN) {\n",
      "\t\t\tuint32_t shot_pitch = locked_pitch;\n"
      "\t\t\tpixel_t *shot = locked_pixels;\n"
      "\t\t\tif (!interlaced) {\n"
      "\t\t\t\tshot = locked_pixels + overscan_left[video_standard]"
      " + (locked_pitch / sizeof(pixel_t)) * overscan_top[video_standard];\n"
      "\t\t\t} else if (which == FRAMEBUFFER_EVEN) {\n")
patch(f"{root}/render_sdl.c",
      "save_png(screenshot_file, locked_pixels, width, shot_height, shot_pitch);",
      "save_png(screenshot_file, shot, width, shot_height, shot_pitch);")
patch(f"{root}/render_sdl.c",
      "save_ppm(screenshot_file, locked_pixels, width, shot_height, shot_pitch);",
      "save_ppm(screenshot_file, shot, width, shot_height, shot_pitch);")

command = r'''static uint8_t cmd_screenshot(debug_root *root, parsed_command *cmd)
{
	if (!eval_expr(root, cmd->args[0].parsed, &cmd->args[0].value)) {
		fprintf(stderr, "Failed to eval %s\n", cmd->args[0].raw);
		return 1;
	}
	char *fname = get_cstring(cmd->args[0].value);
	if (!fname) {
		fprintf(stderr, "Argument to screenshot must be a string\n");
		return 1;
	}
	render_save_screenshot(strdup(fname));
	return 1;
}

'''
entry = r'''	{
		.names = (const char *[]){
			"screenshot", NULL
		},
		.usage = "screenshot FILENAME",
		.desc = "Save the next completed frame to FILENAME (added by Sheliak's test harness)",
		.impl = cmd_screenshot,
		.min_args = 1,
		.max_args = 1,
		.skip_eval = 1
	},
'''
table = "command_def common_commands[] = {\n"
patch(f"{root}/debug.c", table, command + table + entry)
