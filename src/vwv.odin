package main

import "core:time"
import "core:strings"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import "core:fmt"
import "core:log"
import win32 "core:sys/windows"

import "dgl"
import "hotvalue"
import "tween"


Record :: struct {
	id : u64,
	text : string,
	// tree
	parent, child, next: ^Record,
}

id_used : u64
records : [dynamic]^Record
root : ^Record

begin :: proc() {
	vui_init()
	vwv_begin()
}
end :: proc() {
	vui_release()
	vwv_end()
}

main_rect : dgl.Rect

VisualRecord :: struct {
	rect : dgl.Rect,
	expand : f64,
	hovering : bool,
	clean : bool,
}

visual_records : []VisualRecord

debug_draw_data : struct { vertex_count : int, indices_count : int, vbuffer_size : int}

_update_mode : bool

frameid : int
update :: proc() {
	update_timer : time.Stopwatch
	time.stopwatch_start(&update_timer) ; defer time.stopwatch_stop(&update_timer)

	client_rect : win32.RECT
	win32.GetClientRect(hwnd, &client_rect)
	window_size = {client_rect.right, client_rect.bottom}

	delta_s := time.duration_seconds(time.stopwatch_duration(frame_timer))
	delta_ms := time.duration_milliseconds(time.stopwatch_duration(frame_timer))
	// if delta_ms < 1000/60 do return
	time.stopwatch_reset(&frame_timer)
	time.stopwatch_start(&frame_timer)

	begin_draw({0,0, window_size.x, window_size.y})
	dgl.framebuffer_clear({.Color}, {0,0,0,1})


	vwv_update(delta_s)

	@static debug_lines := true

	if is_key_pressed(.F1) do debug_lines = !debug_lines
	if is_key_pressed(.F2) do _update_mode = !_update_mode

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
		pushlinef(&y, "wheel delta: {}", input.wheel_delta)
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


scroll_offset : f64

vwv_update :: proc(delta_s: f64) {
	vui_begin(math.min(delta_s, 1.0/60.0)); defer vui_end()

	main_rect = rect_padding({0,0, auto_cast window_size.x, auto_cast window_size.y}, 10, 10, 10, 10)
	layout_records(visual_records)
	window_rect :dgl.Rect= {0,0, auto_cast window_size.x, auto_cast window_size.y}

	if input.wheel_delta != 0 {
		scroll_offset += 10 * auto_cast input.wheel_delta
	}

	draw_rect(window_rect, {15,16,23, 255})
	draw_rect(main_rect, {22,24,33, 255})

	// update records
	mpos := input.mouse_position
	hovered := false
	for &vr, idx in visual_records {
		vr.hovering = rect_in(vr.rect, mpos) && !hovered
		if vr.hovering {
			vr.expand += (8-vr.expand) * 10 * delta_s
		}
		else do vr.expand += (0-vr.expand) * 10 * delta_s
	}

	draw_record :: proc(using r : ^Record, x: f64, y: ^f64, hovering: ^^Record) {
		// draw_text(font_default, text, {auto_cast x, auto_cast y^}, 28, dgl.CYAN)
		card_rect := dgl.Rect{auto_cast x, auto_cast y^, auto_cast window_size.x-auto_cast x-10, 30}
		if auto_cast input.mouse_position.y > y^ && auto_cast input.mouse_position.y < y^ + 28.0 {
			hovering^ = r
		}

		y_start := y^
		y^ += 30
		ptr := child
		for ptr != nil {
			draw_record(ptr, x + 40, y, hovering)
			ptr = ptr.next
		}
		if y^ > y_start {
			draw_rect_rounded({auto_cast x, auto_cast y_start, 2, auto_cast y^-auto_cast y_start}, 1, 2, {110,120,128, 64 })
		}

		card_rect = rect_padding(card_rect, 0,0,2,2)
		record_card(r, card_rect, text)
	}

	y := 60.0 + scroll_offset
	hovering : ^Record
	draw_record(root, 10, &y, &hovering)


	if hovering != nil {
		if is_key_pressed(.A) {
			record_add_sibling(hovering).text = "Hello"
		} else if is_key_pressed(.S) {
			record_add_child(hovering).text = "Added"
		} else if is_key_pressed(.D) {
			record_remove(hovering)
		}
	}

	// draw records
	// for vr, idx in visual_records {
	// 	expand := cast(f32)vr.expand
	// 	drect := rect_padding(vr.rect, -expand, -expand, -expand, -expand)
	// 	draw_rect_rounded(drect, 4, 2, {95,95,135, 255})
	// }
	// for vr, idx in visual_records {
	// 	draw_text(font_default, records[idx].text, {vr.rect.x+4+1.2, vr.rect.y+auto_cast vr.expand*0.4+1.2}, 28, {0,0,0,128})
	// 	draw_text(font_default, records[idx].text, {vr.rect.x+4, vr.rect.y+auto_cast vr.expand*0.4}, 28, dgl.LIGHT_GRAY)
	// }

	status_bar_rect := rect_split_bottom(window_rect, 46)
	draw_rect(status_bar_rect, {33,37,61, 255})
	draw_text(font_default, "Status Bar", {status_bar_rect.x + 5, status_bar_rect.y + 4} , 28, {69,153,49, 255})
	if vui_button(1280, rect_padding(rect_split_right(status_bar_rect, 46), 4,4,4,4), "hello") do fmt.printf("hello!\n")
	vui_draggable_button(1222, rect_split_left(status_bar_rect, 32), "Drag me")
	if _update_mode do mark_update()
}

record_card :: proc(r: ^Record, rect: dgl.Rect, text: string) {
	ctx := _vui_ctx()
	id := r.id * 10 + 10000
	state := _vui_state(id, struct {
		hover_time:f64,
		dragging:bool,
		// In dragging mode, this represents the offset from mouse pos to the anchor.
		// In nondragging mode, this is the current rect anchor.
		drag_offset:dgl.Vec2 
	})
	// @Temporary:
	draw_rect(rect, {145,130,140, 64})
	input_rect := rect
	rect := rect
	hovering := false
	if state.dragging {
		hovering = true
		rect.x = input.mouse_position.x-state.drag_offset.x
		rect.y = input.mouse_position.y-state.drag_offset.y

		if is_button_released(.Left) {
			if state.dragging {
				state.dragging = false
				state.drag_offset = {rect.x, rect.y}
			}
		}
	} else {
		if state.drag_offset != {} { // drag recovering
			topos := rect_position(input_rect)
			state.drag_offset = 40 * cast(f32)ctx.delta_s * (topos - state.drag_offset) + state.drag_offset
			if linalg.distance(topos, state.drag_offset) < 2 {
				state.drag_offset = {}
			} else {
				rect.x = state.drag_offset.x
				rect.y = state.drag_offset.y
			}
		}
		hovering = rect_in(rect, input.mouse_position)
		if hovering && is_button_pressed(.Left) {
			// start dragging
			state.dragging = true
			state.drag_offset = input.mouse_position - {rect.x, rect.y}
		}
	}

	state.hover_time += ctx.delta_s if hovering else -ctx.delta_s
	state.hover_time = math.clamp(state.hover_time, 0, 0.2)

	if is_button_released(.Left) {
		if state.dragging {
			state.dragging = false
			state.drag_offset = {rect.x, rect.y}
		}
	}

	color_normal := dgl.col_u2f({195,75,75,   255})
	color_hover  := dgl.col_u2f({215,105,95,  255})
	color_flash  := dgl.col_u2f({245,235,235, 255})

	hovert :f32= cast(f32)(math.min(state.hover_time, 0.2)/0.2)
	hovert = tween.ease_inoutsine(hovert)
	color := hovert*(color_hover-color_normal) + color_normal

	draw_rect_rounded(rect, 4, 2, dgl.col_f2u(color))
	text_color := dgl.col_u2f({218,218,218, 255})
	draw_text(font_default, r.text, {rect.x, rect.y+rect.h*0.5-13-3*hovert}, 22, dgl.col_f2u(text_color))
}

vwv_begin :: proc() {
	records = make([dynamic]^Record)
	visual_records = make([]VisualRecord, len(records))
	root = _new_record()
	root.text = "ROOT"
	aaa := record_add_child(root)
	aaa.text = "AAA"
		a1 := record_add_child(aaa)
		a1.text = "A1"
		a2 := record_add_sibling(a1)
		a2.text = "A2"
	bbb := record_add_sibling(aaa)
	bbb.text = "BBB"
		b1 := record_add_child(bbb)
		b1.text = "B1"
		b2 := record_add_sibling(b1)
		b2.text = "B2"
		b0 := record_add_child(bbb)
		b0.text = "B0"
}
vwv_end :: proc() {
	for r in records do free(r)
	delete(records)
	delete(visual_records)
}

layout_records :: proc(vrecords: []VisualRecord) {
	rect := rect_padding(rect_top(main_rect, 60), 5,5, 10, 0)
	for &vr in vrecords {
		vr.rect = rect
		rect.y += 70
	}
}

@(private="file")
_new_record :: proc() -> ^Record {
	r := new(Record)
	append(&records, r)
	id_used += 1
	r.id = id_used
	return r
}

// Add a new record as the first child of `to` node.
record_add_child :: proc(to: ^Record) -> ^Record {
	r := _new_record()
	r.next = to.child
	to.child = r
	r.parent = to
	return r
}

// Add a new record as the next of `to` node.
record_add_sibling :: proc(to: ^Record) -> ^Record {
	assert(to.parent != nil, "Root node can't have siblings.")
	parent := to.parent
	r := _new_record()
	r.next = to.next
	to.next = r
	r.parent = to.parent
	return r
}

// Remove a record
record_remove :: proc(r: ^Record) {
	assert(r.parent != nil, "Cannot remove root node.")
	assert(r != nil, "Deleting a `nil`")
	if r == r.parent.child {
		r.parent.child = r.next
	} else {
		prev : ^Record = r.parent.child
		for prev.next != r {
			prev = prev.next
		}
		prev.next = r.next
	}
}
