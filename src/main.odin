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

DEFAULT_WINDOW_TITLE :: "vwv - simple tool for simple soul"

window_size : [2]i32

VERTEX_FORMAT_P3U2C4 :: dgl.VertexFormat{ 3,2,4, 0,0,0,0,0 } // 9
VERTEX_FORMAT_VWV    :: VERTEX_FORMAT_P3U2C4

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

	window_init()
	dgl.init()

	timer : time.Stopwatch
	time.stopwatch_start(&timer)

	mb : dgl.MeshBuilder
	dgl.mesh_builder_init(&mb, VERTEX_FORMAT_VWV)
	defer dgl.mesh_builder_release(&mb)

	dgl.mesh_builder_add_vertices(&mb,
		{ 0,0,0,    0,0,  1,0,0,1 },
		{ 300,0,0,  0,0,  0,1,0,1 },
		{ 0,400,0,   0,0,  0,0,1,1 },
	)
	dgl.mesh_builder_add_indices(&mb, 0, 1, 2)

	triangle := dgl.mesh_builder_create(mb)

	shader := dgl.shader_load_from_sources(#load("../res/default.vert"), #load("../res/default.frag"))
	uniform_mvp :dgl.UniformLocMat4x4= dgl.uniform_get_location(shader, "mvp")
	uniform_texture0 :dgl.UniformLocTexture= dgl.uniform_get_location(shader, "texture0")

	white := dgl.texture_create_with_color(1,1, {255,255,255,255})
	init_draw()
	fontstash_init()

	font_fzytk := fontstash.AddFontPath(&fsctx.fs, "fzytk", "./fzytk.ttf")

	heart := dgl.texture_load("./res/heart-break.png"); defer dgl.texture_destroy(heart)

	msg: win32.MSG
	for {
		if win32.PeekMessageW(&msg, nil, 0,0, win32.PM_REMOVE) {
			if msg.message == win32.WM_QUIT { break }
			win32.TranslateMessage(&msg)
			win32.DispatchMessageW(&msg)
		} else {
			s := time.duration_seconds(time.stopwatch_duration(timer))
			begin_draw({0,0, window_size.x, window_size.y})
			dgl.framebuffer_clear({.Color}, {0,0,0,1})

			draw_rect({20,20, 120,120}, {255, 255, 0, 255})

			draw_texture_ex(heart, {0,0,auto_cast heart.size.x, auto_cast heart.size.y}, {10,10, 60,60}, tint={255,255,255,255})

			draw_rect({5,40, 120,60}, {255, 0, 0, 128})
			draw_text(font_fzytk, "Hello, Dove\ntest auto wrap with a very looong line.", {20,20}, 42, {255,0,255, 255}, overflow_width= 200)

			end_draw()
			win32.SwapBuffers(win32.GetDC(hwnd))
		}
	}

	fontstash_release()
	destroy_draw()

	dgl.release()
}
