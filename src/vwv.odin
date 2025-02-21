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
	vwv_begin()
}
end :: proc() {
	vwv_end()
}

main_rect : dgl.Rect

VisualRecord :: struct {
	rect : dgl.Rect
}

visual_records : []VisualRecord

debug_draw_data : struct { vertex_count : int, indices_count : int, vbuffer_size : int}

frameid : int
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


	vwv_update()

	@static debug_lines := true

	if is_key_pressed(.F1) do debug_lines = !debug_lines

	pushlinef :: proc(y: ^f32, fmtter: string, args: ..any) {
		overflow :f64= auto_cast window_size.x - 10
		draw_text(font_default, fmt.tprintf(fmtter, ..args), {5+1, y^+1}, 24, {0,0,0, 128}, overflow_width = overflow)
		h := draw_text(font_default, fmt.tprintf(fmtter, ..args), {5, y^}, 24, dgl.GREEN, overflow_width = overflow)
		y^ += h + 2
	}
	y :f32= 5
	if debug_lines {
		pushlinef(&y, "delta ms: {:.2f}", delta_ms)
		pushlinef(&y, "窗口大小: {}", window_size)
		pushlinef(&y, "draw state: {}", debug_draw_data)
		pushlinef(&y, "frameid: {}", frameid)
		pushlinef(&y, "mouse: {}", input.mouse_position)
		pushlinef(&y, "button: {}", input.buttons)
		pushlinef(&y, "button_prev: {}", input.buttons_prev)
	}

	debug_draw_data = {
		len(_state.mesh.vertices) / auto_cast dgl.mesh_builder_calc_stride(&_state.mesh),
		len(_state.mesh.indices),
		len(_state.mesh.vertices)
	}

	end_draw()
	if dc == {} do dc = win32.GetDC(hwnd)
	if dc != {} {
		win32.SwapBuffers(dc)
	}
	free_all(context.temp_allocator)
	frameid += 1
	input_process_post_update()
}

vwv_update :: proc() {
	main_rect = rect_padding({0,0, auto_cast window_size.x, auto_cast window_size.y}, 10, 10, 10, 10)
	layout_records(visual_records)

	draw_rect(main_rect, dgl.WHITE)
	for vr, idx in visual_records {
		draw_rect(vr.rect, {120, 110, 139, 255})
	}
	for vr, idx in visual_records {
		draw_text(font_default, records[idx].text, {vr.rect.x+1.2, vr.rect.y+1.2}, 32, {0,0,0,128})
		draw_text(font_default, records[idx].text, {vr.rect.x, vr.rect.y}, 32, dgl.DARK_GRAY)
	}
}

vwv_begin :: proc() {
	visual_records = make([]VisualRecord, len(records))
}
vwv_end :: proc() {
	delete(visual_records)
}

layout_records :: proc(vrecords: []VisualRecord) {
	rect := rect_padding(rect_top(main_rect, 60), 5,5, 10, 0)
	for &vr in vrecords {
		vr.rect = rect
		rect.y += 70
	}

}
