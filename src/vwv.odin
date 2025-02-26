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


debug_draw_data : struct { vertex_count : int, indices_count : int, vbuffer_size : int}

_update_mode := true

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
		_, h := draw_text(font_default, fmt.tprintf(fmtter, ..args), {5, y^}, 24, dgl.GREEN, overflow_width = overflow)
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
VisualRecord :: struct {
	r : ^Record,
	rect : dgl.Rect,
}
visual_records : [dynamic]VisualRecord

vwv_update :: proc(delta_s: f64) {
	vui_begin(math.min(delta_s, 1.0/60.0)); defer vui_end()

	main_rect = rect_padding({0,0, auto_cast window_size.x, auto_cast window_size.y}, 10, 10, 10, 10)
	// layout_records()
	window_rect :dgl.Rect= {0,0, auto_cast window_size.x, auto_cast window_size.y}

	if input.wheel_delta != 0 {
		scroll_offset += 10 * auto_cast input.wheel_delta
	}

	draw_rect(window_rect, {15,16,23, 255})
	draw_rect(main_rect, {22,24,33, 255})

	update_visual_records(root)
	hovering : ^VisualRecord
	for &vr in visual_records {
		record_card(&vr, &hovering)
	}

	status_bar_rect := rect_split_bottom(window_rect, 46)
	draw_rect(status_bar_rect, {33,37,61, 255})
	draw_text(font_default, "Status Bar", {status_bar_rect.x + 5, status_bar_rect.y + 4} , 28, {69,153,49, 255})
	if vui_button(1280, rect_padding(rect_split_right(status_bar_rect, 46), 4,4,4,4), "hello") do fmt.printf("hello!\n")
	vui_draggable_button(1222, rect_split_left(status_bar_rect, 32), "Drag me")
	if _update_mode do mark_update()
}

update_visual_records :: proc(root: ^Record) {
	clear(&visual_records)

	x :f32= 10
	y :f32= 10
	ite_record :: proc(r: ^Record, to: ^[dynamic]VisualRecord, x: f32, y: ^f32) {
		append(to, VisualRecord{r, {x, y^, auto_cast window_size.x-x-10, 30}})
		y^ += 30
		ptr := r.child
		for ptr != nil {
			ite_record(ptr, to, x + 40, y)
			ptr = ptr.next
		}
	}
	ite_record(root, &visual_records, x, &y)
}

record_card :: proc(vr: ^VisualRecord, hovering: ^^VisualRecord) {
	state := _vui_state(vr.r.id * 10 + 10000, struct {
		editting : f64, // > 0 means editting, there is an animation bound to this
		cursor : f32,
		scale : f32
	})
	if state.scale < 1 {
		state.scale += auto_cast _vui_ctx().delta_s * 6
		if state.scale >= 1 do state.scale = 1
	}
	is_global_editting := editting_record.record != nil
	rect := rect_padding(vr.rect, 2,2, 2,2)
	rect.y += auto_cast scroll_offset
	rect.w *= tween.ease_outcirc(auto_cast state.scale)

	if hovering^ == nil && rect_in(rect, input.mouse_position) {
		hovering^ = vr
	}
	editting := state.editting > 0
	if hovering^ == vr {
		if !is_global_editting {
			if is_key_pressed(.A) {
				record_add_sibling(hovering^.r).text = "Hello"
			} else if is_key_pressed(.S) {
				record_add_child(hovering^.r).text = "Added"
			} else if is_key_pressed(.D) {
				record_remove(hovering^.r)
			}
			if is_button_pressed(.Left) {
				ed := &editting_record.textedit
				gp := &editting_record.gapbuffer
				gapbuffer_clear(gp)
				gapbuffer_insert_string(gp, 0, vr.r.text)
				textedit_begin(ed, gp)
				editting_record.record = vr.r
				state.editting = 1
				toggle_text_input(true)
			}
		}
	}
	if editting_record.record == vr.r {
		ed := &editting_record.textedit
		if input_text := get_input_text(context.temp_allocator); input_text != {} {
			textedit_insert(ed, input_text)
		} else if is_key_pressed(.Back) {
			textedit_remove(ed, -1)
		} else if is_key_pressed(.Delete) {
			textedit_remove(ed, 1)
		} else if is_key_pressed(.Left) {
			textedit_move(ed, -1)
		} else if is_key_pressed(.Right) {
			textedit_move(ed, 1)
		}
		if is_key_pressed(.Enter) || is_key_pressed(.Escape) {
			vr.r.text = gapbuffer_get_string(&editting_record.gapbuffer)
			// @Temporary:
			editting_record.record = nil
			textedit_end(&editting_record.textedit)
			state.editting = 0
			toggle_text_input(false)
		}
	}

	alpha := cast(u8)(255 * state.scale)
	text_color :dgl.Color4u8= {220,220,220, alpha}
	if editting {
		draw_rect_rounded(rect, 4, 2, {65,65,95, alpha} if hovering^ != vr else {85,85,115, alpha})
		draw_rect_rounded(rect_padding(rect, 2,2,2,2), 4, 2, {95,95,135, alpha})
	} else {
		draw_rect_rounded(rect, 4, 2, {95,95,135, alpha} if hovering^ != vr else {105,105,145, alpha})
	}

	text := vr.r.text
	if editting {
		ed := &editting_record.textedit
		text = gapbuffer_get_string(&editting_record.gapbuffer, context.temp_allocator)
		draw_text(font_default, text, {rect.x+4+1.2, rect.y-4+1.2}, 28, {0,0,0,cast(u8)(128*state.scale)})
		prevx, _ := draw_text(font_default, text[:ed.selection.x], {rect.x+4,     rect.y-4}, 28, text_color)
		draw_text(font_default, text[ed.selection.x:], {rect.x+4 + prevx, rect.y-4}, 28, text_color)
		cursor := rect.x+4 + prevx
		state.cursor += (cursor - state.cursor) * auto_cast _vui_ctx().delta_s * 12
		draw_rect({state.cursor, rect.y-4, 2, 28}, dgl.WHITE)
	} else {
		draw_text(font_default, text, {rect.x+4+1.2, rect.y-4+1.2}, 28, {0,0,0,cast(u8)(128*state.scale)})
		draw_text(font_default, text, {rect.x+4,     rect.y-4}, 28, text_color)
	}
}

RecordEdit :: struct {
	record    : ^Record,
	textedit  : TextEdit,
	gapbuffer : GapBuffer,
}
editting_record : RecordEdit

vwv_begin :: proc() {
	records = make([dynamic]^Record)
	visual_records = make([dynamic]VisualRecord)

	gapbuffer_init(&editting_record.gapbuffer, 16)

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

	update_visual_records(root)
}
vwv_end :: proc() {
	gapbuffer_release(&editting_record.gapbuffer)
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
