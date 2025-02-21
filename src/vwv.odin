package main

import "core:time"
import "core:strings"
import "core:fmt"
import win32 "core:sys/windows"

import "dgl"
import "hotvalue"



Record :: struct {
	text : string,
}

records : []Record= {
	{"Hello, this is the record"},
	{"另一条记录"},
	{"что?"},
}

begin :: proc() {
}
end :: proc() {
}

main_rect : dgl.Rect

VisualRecord :: struct {
	rect : dgl.Rect
}


debug_draw_data : struct { vertex_count : int, indices_count : int, vbuffer_size : int, update_time : f64}

update :: proc() {
	update_timer : time.Stopwatch
	time.stopwatch_start(&update_timer) ; defer time.stopwatch_stop(&update_timer)

	client_rect : win32.RECT
	win32.GetClientRect(hwnd, &client_rect)
	window_size = {client_rect.right, client_rect.bottom}

	delta_ms := time.duration_milliseconds(time.stopwatch_duration(frame_timer))
	// if delta_ms < 1000/60 do return
	time.stopwatch_reset(&frame_timer)
	time.stopwatch_start(&frame_timer)

	begin_draw({0,0, window_size.x, window_size.y})
	dgl.framebuffer_clear({.Color}, {0,0,0,1})

	main_rect = rect_padding({0,0, auto_cast window_size.x, auto_cast window_size.y}, 10, 10, 10, 10)
	draw_rect(main_rect, dgl.WHITE)

	draw_text(font_default, fmt.tprintf("delta ms: {:.2f}", delta_ms), {0,0}, 24, dgl.GREEN)
	draw_text(font_default, fmt.tprintf("窗口大小: {}", window_size), {0, 28}, 24, dgl.GREEN)
	draw_text(font_default, fmt.tprintf("draw state: {}", debug_draw_data), {0, 56}, 24, dgl.GREEN, overflow_width=auto_cast window_size.x)

	debug_draw_data = {
		len(_state.mesh.vertices) / auto_cast dgl.mesh_builder_calc_stride(&_state.mesh),
		len(_state.mesh.indices),
		len(_state.mesh.vertices),
		time.duration_milliseconds(time.stopwatch_duration(update_timer))
	}

	end_draw()
	win32.SwapBuffers(win32.GetDC(hwnd))
	free_all(context.temp_allocator)
}
