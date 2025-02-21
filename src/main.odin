package main

import "core:time"
import "core:os"
import "core:fmt"
import "core:unicode/utf8"
import "core:log"
import "core:c"
import "core:reflect"
import "core:strings"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:math"
import "core:mem"
import win32 "core:sys/windows"

import "vendor:glfw"
import gl "vendor:OpenGL"
import "vendor:fontstash"

import "dgl"
import "hotvalue"

DEFAULT_WINDOW_TITLE :: "vwv - simple tool for simple soul"

window_size : [2]i32

VERTEX_FORMAT_P3U2C4 :: dgl.VertexFormat{ 3,2,4, 0,0,0,0,0 } // 9
VERTEX_FORMAT_VWV    :: VERTEX_FORMAT_P3U2C4

hotv : hotvalue.HotValues

main :: proc() {
	tracking_allocator : mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
		fmt.printf("\nMemory leak report:\n")
		leaks := false
		for key, value in a.allocation_map {
		   fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
		   leaks = true
		}
		mem.tracking_allocator_clear(a)
		return leaks
	}
	defer reset_tracking_allocator(&tracking_allocator)

	logger := log.create_console_logger()
	context.logger = logger
	defer log.destroy_console_logger(logger)

	hotv = hotvalue.init("hotvalues")

	window_init("VWV - new version", 400, 600)
	dgl.init()

	timer : time.Stopwatch
	time.stopwatch_start(&timer); defer time.stopwatch_stop(&timer)

	frame_timer : time.Stopwatch
	time.stopwatch_start(&frame_timer); defer time.stopwatch_stop(&frame_timer)

	white := dgl.texture_create_with_color(1,1, {255,255,255,255})
	init_draw()
	fontstash_init()

	font_default := fontstash.AddFontPath(&fsctx.fs, "default", "C:/Windows/Fonts/bookos.ttf")

	heart := dgl.texture_load("./res/heart-break.png"); defer dgl.texture_destroy(heart)

	msg: win32.MSG

	for win32.GetMessageW(&msg, nil, 0,0) > 0 {
		win32.TranslateMessage(&msg)
		win32.DispatchMessageW(&msg)

		if !win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_NOREMOVE) {
			delta_ms := time.duration_milliseconds(time.stopwatch_duration(frame_timer))
			if delta_ms < 1000/60 do continue
			time.stopwatch_reset(&frame_timer)
			time.stopwatch_start(&frame_timer)
			// the real update

			begin_draw({0,0, window_size.x, window_size.y})
			dgl.framebuffer_clear({.Color}, {0,0,0,1})

			draw_rect({20,20, 120,120}, dgl.YELLOW)
			draw_texture_ex(heart, {0,0,auto_cast heart.size.x, auto_cast heart.size.y}, {10,10, 60,60}, tint={255,255,255,255})

			draw_text(font_default, "Hello, Dove\ntest auto wrap with a very looong line.",
				{22,22}, 42, {0,0,0, 128}, overflow_width= 200)
			draw_text(font_default, "Hello, Dove\ntest auto wrap with a very looong line.",
				{20,20}, 42, dgl.CYAN, overflow_width= 200)

			draw_rect({5,40, 120,60}, {255,0,0, hotv->u8("alpha")})

			draw_text(font_default, fmt.tprintf("delta ms: {:.2f}", delta_ms), {0,0}, 38, dgl.GREEN)

			end_draw()
			win32.SwapBuffers(win32.GetDC(hwnd))
			free_all(context.temp_allocator)
		}
	}

	fontstash_release()
	destroy_draw()

	dgl.release()

	hotvalue.release(&hotv)
}
