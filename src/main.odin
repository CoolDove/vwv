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
import "core:math"
import "core:mem"
import win32 "core:sys/windows"

import "vendor:glfw"
import gl "vendor:OpenGL"

import "dude/dude/dgl"

// REPAC_ASSETS :: false
DEFAULT_WINDOW_TITLE :: "vwv - simple tool for simple soul"

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

	timer : time.Stopwatch
	time.stopwatch_start(&timer)

	froze_draw := false

	msg: win32.MSG
	for {
		if frozen || win32.PeekMessageW(&msg, nil, 0,0, win32.PM_REMOVE) {
			if msg.message == win32.WM_QUIT { break }
			win32.TranslateMessage(&msg)
			win32.DispatchMessageW(&msg)
		} else {
			s := time.duration_seconds(time.stopwatch_duration(timer))
			gl.ClearColor(0.2, 0.2, auto_cast math.sin(s)*0.5+0.5, 1) // Pink: 0.9, 0.2, 0.8
			gl.Clear(gl.COLOR_BUFFER_BIT)

			win32.SwapBuffers(win32.GetDC(hwnd))
		}
		if frozen {
			win32.GetMessageW(&msg, nil, 0, 0)
		}
	}

	// window_init(DEFAULT_WINDOW_TITLE, 400, 860)
	// dgl.init()

	// for !glfw.WindowShouldClose(window) {
	//	   glfw.WaitEvents()
	//	   // Note: glfw.PollEvents will block on Windows during window resize, hence
	//	// strange rendering occurs during resize. To keep this example simple, we
	//	   // will not fix this here. A partial solution is found in Rainbow-Triangle
	//	   // and subsequent examples.

	//	   // Create oscillating value (osl).
	//	   
	//	   // Clear screen with color.
	//	   gl.ClearColor(0.9, 0.2, 0.8, 1) // Pink: 0.9, 0.2, 0.8
	//	   gl.Clear(gl.COLOR_BUFFER_BIT)
	//	   
	//	   // Render screen with background color.
	//	   glfw.SwapBuffers(window)
	// }

	// dgl.release()
	// window_destroy()
}
frozen := false


// _dispatch_update := false
// _during_update := false

// _handle_event :: proc(window: ^sdl.Window, event: sdl.Event, window_close: ^bool) {
//	log.debugf("handle event: {}", event.type)
//	if event.type == .WINDOWEVENT {
//		log.debugf("\thandle window event: {}", event.window.event)
//		if event.window.event == .CLOSE {
//			log.debugf("quit")
//			window_close^ = true
//		}
//	   } else {
//		   // input_handle_sdl2(event)
//	   }
//	   // if window.handler != nil {
//	   //	  window.handler(window, event)
//	   // }
// }

// @(private="file")
// update :: proc(game: ^dd.Game, delta: f32) {
//	   using dd, vwv_app
//	   vwv_app._frame_id += 1
// 
//	   viewport := app.window.size
//	   pass_main.viewport = Vec4i{0,0, viewport.x, viewport.y}
//	   pass_main.camera.viewport = vec_i2f(viewport)
// 
//	   vwv_update()
// }
// 
// 
// @(private="file")
// init :: proc(game: ^dude.Game) {
//	   append(&game.render_pass, &pass_main)
// 
//	   using dd
//	   // Pass initialization
//	   wndx, wndy := app.window.size.x, app.window.size.y
//	   render.pass_init(&pass_main, {0,0, wndx, wndy})
//	   pass_main.clear.color = {.2,.2,.2, 1}
//	   pass_main.clear.mask = {.Color,.Depth,.Stencil}
//	   blend := &pass_main.blend.(dgl.GlStateBlendSimp)
//	   blend.enable = true
// 
//	   vwv_init()
//	   dude.timer_check("Vwv Fully Inited")
// }
// 
// @(private="file")
// release :: proc(game: ^dd.Game) {
//	   dude.timer_check("Vwv start release")
//	   vwv_release()
// 
//	   render.pass_release(&pass_main)
//	   dude.timer_check("Vwv released")
// }
// 
// @(private="file")
// on_mui :: proc(ctx: ^mui.Context) {
// }
// 
// @(private="file")
// vwv_window_handler :: proc(using wnd: ^dd.Window, event:sdl.Event) {
//	   if event.window.event == .RESIZED {
//		   dd.dispatch_update()
//	   }
//	   if input.get_input_handle_result() != .None {
//		   dd.dispatch_update()
//	   }
// }
