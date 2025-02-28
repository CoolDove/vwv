package main

import "base:runtime"
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
// import "hotvalue"

DEFAULT_WINDOW_TITLE :: "vwv - simple tool for simple soul"

window_size : [2]i32

VERTEX_FORMAT_P3U2C4 :: dgl.VertexFormat{ 3,2,4, 0,0,0,0,0 } // 9
VERTEX_FORMAT_VWV    :: VERTEX_FORMAT_P3U2C4

// hotv : hotvalue.HotValues

font_fallback : int
font_default : int

timer : time.Stopwatch
frame_timer : time.Stopwatch

the_context : runtime.Context

updated_marked : bool

main :: proc() {
	time.stopwatch_start(&timer); defer time.stopwatch_stop(&timer)

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

	// hotv = hotvalue.init("hotvalues")

	window_init("VWV - new version", 400, 600)
	dgl.init()

	time.stopwatch_start(&frame_timer); defer time.stopwatch_stop(&frame_timer)

	init_draw()
	fontstash_init()

	font_fallback = fontstash.AddFontPath(&fsctx.fs, "fallback", "C:/Windows/Fonts/fzytk.ttf")
	font_default = fontstash.AddFontPath(&fsctx.fs, "default", "C:/Windows/Fonts/bookos.ttf")
	fontstash.AddFallbackFont(&fsctx.fs, font_default, font_fallback)

	begin()

	msg: win32.MSG
	mainloop: for updated_marked || win32.GetMessageW(&msg, nil, 0,0) > 0 {
		if updated_marked {
			for win32.PeekMessageW(&msg, nil, 0,0, win32.PM_REMOVE) {
				if msg.message == win32.WM_QUIT do break mainloop
				win32.TranslateMessage(&msg)
				the_context = context
				win32.DispatchMessageW(&msg)
			}
			updated_marked = false;
		} else {
			win32.TranslateMessage(&msg)
			the_context = context
			win32.DispatchMessageW(&msg)
		}

		if !win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_NOREMOVE) {
			update()
		}
	}

	end()

	fontstash_release()
	destroy_draw()

	dgl.release()

	// hotvalue.release(&hotv)
}

mark_update :: proc() {
	updated_marked = true
}
