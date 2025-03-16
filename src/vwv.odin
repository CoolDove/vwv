package main

import "core:time"
import "core:strings"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import "core:fmt"
import "core:hash/xxhash"
import "core:strconv"
import "core:log"
import win32 "core:sys/windows"

import "vendor:fontstash"

import "dgl"
import "hotvalue"
import hla "collections/hollow_array"
import "tween"


Record :: struct {
	id : u64,
	text : strings.Builder,
	editbuffer : GapBuffer,
	// tree
	parent, child, next: ^Record,
}

id_used : u64
records : [dynamic]^Record
root : ^Record

key_handled : bool

begin :: proc() {
	vui_init()
	vwv_begin()
}
end :: proc() {
	vwv_end()
	vui_release()
}

main_rect : dgl.Rect

debug_draw_data : struct { vertex_count : int, indices_count : int, vbuffer_size : int}

BubbleMessage :: struct {
	message: string,
	duration, time: f64 
}
bubble_messages : hla.HollowArray(BubbleMessage)
push_bubble_msg :: proc(msg: string, duration: f64) {
	hla.hla_append(&bubble_messages, BubbleMessage{ msg, duration, 0 })
}

frameid : int
update :: proc() {
	@static log_startup_time := true
	if log_startup_time {
		duration := time.stopwatch_duration(timer)
		startup_ms := time.duration_milliseconds(duration)
		log.debugf("startup time: {} ms", startup_ms)
		log_startup_time = false
	}
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
		// pushlinef(&y, "mouse: {}", input.mouse_position)
		// pushlinef(&y, "wheel delta: {}", input.wheel_delta)
		// pushlinef(&y, "button: {}", input.buttons)
		// pushlinef(&y, "button_prev: {}", input.buttons_prev)
		// pushlinef(&y, "update time: {}", _update_time)
		pushlinef(&y, "vui hot: {}, active: {}", _vui_ctx().hot, _vui_ctx().active)
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
	indent : int,
	rect : dgl.Rect,
}
visual_records : [dynamic]VisualRecord

vwv_update :: proc(delta_s: f64) {
	LAYOUT, BUTTON :: vui_layout_scoped, vui_test_button
	ELEMENT :: _vuibd_element_scoped

	hotvalue.update(&hotv)

	key_handled = false
	if is_key_pressed(.S) && is_key_down(.Ctrl) {
		doc_write()
		push_bubble_msg("SAVED", 1.0)
		key_handled = true
	}

	main_rect = rect_padding({0,0, auto_cast window_size.x, auto_cast window_size.y}, 10, 10, 10, 10)
	// layout_records()
	window_rect :dgl.Rect= {0,0, auto_cast window_size.x, auto_cast window_size.y}

	vui_begin(math.min(delta_s, 1.0/60.0), window_rect)

	if input.wheel_delta != 0 {
		scroll_offset += 10 * auto_cast input.wheel_delta
	}

	draw_rect(window_rect, {15,16,23, 255})
	draw_rect(main_rect, hotv->u8x4_inv("background_color"))

	panel_height := math.max(cast(f32)window_size.y - 200, 0)
	if LAYOUT(36, {26,26, cast(f32)window_size.x * 0.6, panel_height}, .Vertical, 4, {12,12,12,12}, dgl.RED) {
		if BUTTON(37, {0,0, 60, 20}, "AAA").clicked do log.debugf("AAA")
		if LAYOUT(80, {0,0, -200, -120}, .Horizontal, 6, {}, dgl.BLUE) {
			if BUTTON(81, {0,0, 20, 60}, "b1").clicked do log.debugf("b1")
			if BUTTON(82, {0,0, -80, 40}, "b2").clicked do log.debugf("b2")
			if BUTTON(83, {0,0, 15, -20}, "b3").clicked do log.debugf("b3")
		}
		if BUTTON(39, {0,0, -1, -30}, "AUTO LAYOUT BOX").clicked do log.debugf("AUTO LAYOUT BOX")
		if BUTTON(40, {0,0, 100, -25}, "AUTO LAYOUT BOX2").clicked do log.debugf("AUTO LAYOUT BOX2")
		if BUTTON(42, {0,0, -1, 20}, "DDD").clicked do log.debugf("DDD")
	}

	update_visual_records(root)

	if vui_layout_scoped(6789, {20, cast(f32)scroll_offset, cast(f32)window_size.x- 40, 600}, .Vertical, 10) {
		for &vr in visual_records {
			record_card(&vr)
		}
	}

	status_bar_rect := rect_bottom(window_rect, 48)
	if vui_layout_scoped(500, status_bar_rect, .Horizontal, 3, {4,4,4,4}, hotv->u8x4_inv("status_bar_bg_color")) {
		always_on_top := window_get_always_on_top()
		if _ui_status_toggle("置顶", {3,3, 40,-1}, always_on_top) != always_on_top {
			window_set_always_on_top(!always_on_top)
		}

		@static va, vb, vc, vd := false, false, false, false
		va = _ui_status_toggle("&&", {0,0, 40,-1}, va)
		if vui_layout_scoped(500+66, {0,0, 40, 40}, .Vertical, 2) {
			vb = _ui_status_toggle("**", {0,0, -1,-1}, vb)
			vc = _ui_status_toggle("??", {0,0, -1,-1}, vc)
		}
	}

	_ui_status_toggle :: proc(text: string, rect: Rect, on: bool) -> bool {
		_vuibd_begin(500+xxhash.XXH3_64_with_seed(transmute([]u8)text, 42)%200, rect)
		_vuibd_clickable()
		_vuibd_draw_rect({233, 90, 80, 255}, 6)
		_vuibd_draw_rect_hot({255, 100, 70, 255})
		_vuibd_draw_rect_hot_animation(0.2)
		_vuibd_draw_rect_active({255, 244, 255, 255})
		_vuibd_draw_text(dgl.WHITE if on else dgl.DARK_GRAY, text, 22)
		return !on if _vuibd_end().clicked else on
	}

	// bubble messages
	if vui_layout_scoped(6000-1, rect_bottom(window_rect, 60+(24+6)*auto_cast bubble_messages.count), .Vertical, 6) {
		ite : int
		for h in hla.ite_alive_handle(&bubble_messages, &ite) {
			bubble_rect := Rect{60,0, window_rect.w-120, 24}
			bmsg := hla.hla_get_pointer(h)
			if ELEMENT(6000+auto_cast ite, bubble_rect) {
				t := cast(f32)(bmsg.time/bmsg.duration)
				alpha := (1-math.pow(2*tween.ease_outcirc(t)-1, 10))
				_vuibd_draw_rect(dgl.col_f2u({0,0,0,alpha}), 8)
				_vuibd_draw_text(dgl.col_f2u({1,0.8,0,alpha}), bmsg.message, 22)
			}
			bmsg.time += delta_s
			if bmsg.time >= bmsg.duration do hla.hla_remove_handle(h)
		}
	}

	if _update_time > 0 {
		_update_time -= delta_s
		mark_update()
	}

	vui_end()
}
vwv_wndproc :: proc(hwnd: win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) {
	_update_time = 2
}
_update_time : f64

update_visual_records :: proc(root: ^Record) {
	clear(&visual_records)

	x :f32= 10
	y :f32= 10
	indent : int
	ite_record :: proc(r: ^Record, to: ^[dynamic]VisualRecord, x: f32, y: ^f32, indent: int) {
		append(to, VisualRecord{r, indent, {x, y^, auto_cast window_size.x-x-10, 30}})
		y^ += 30
		ptr := r.child
		for ptr != nil {
			ite_record(ptr, to, x + 40, y, indent + 1)
			ptr = ptr.next
		}
	}
	ite_record(root, &visual_records, x, &y, indent)
}

get_record_id :: proc(r: ^Record) -> u64 {
	return r.id * 10 + 10000
}

record_card :: proc(vr: ^VisualRecord) {
	empty :: proc(id: u64, rect:Rect={0,0,-1,-1}) {
		_vuibd_begin(id, rect); _vuibd_end()
	}
	baseid :u64= get_record_id(vr.r)
	chid :u64= baseid // child id
	CHILDID :: proc(id: ^u64) -> u64 {
		id^ += 1
		return id^
	}

	_, parent := _vuibd_helper_get_current()
	assert(parent != nil && parent.layout.enable, "Record card must be under a layout")
	if parent == nil || !parent.layout.enable do return

	tbro := new(TextBro)
	indent := cast(f64)vr.indent * 18.0
	width := cast(f64)parent.basic.rect.w - 4 - indent

	tbro_init(tbro, font_default, 22, width - 25 - 4)
	cursor_offset :Vec2= {0, 22}
	if editting_record.record == vr.r {
		text := gapbuffer_get_string(&editting_record.gapbuffer, context.temp_allocator)
		ed := &editting_record.textedit
		tbro_write_string(tbro, text[:ed.selection.x], hotv->u8x4_inv("record_text_color"))
		if last := tbro_last(tbro); last != nil {
			cursor_offset = last.next
		}
		tbro_write_string(tbro, text[ed.selection.x:], hotv->u8x4_inv("record_text_color"))
	} else {
		tbro_write_string(tbro, strings.to_string(vr.r.text), hotv->u8x4_inv("record_text_color"))
	}

	card_height :f32= (tbro_last(tbro).next.y) if len(tbro.elems)>0 else 22
	vui_layout_begin(CHILDID(&chid), {0, 0, -1, card_height + 8}, .Horizontal, 0); defer _vuibd_end()

	empty(CHILDID(&chid)) // indent spacing

	// card body
	_vuibd_begin(baseid, {0, 0, cast(f32)width, -1}); defer _vuibd_end()

	record_color_normal    := hotv->u8x4_inv("record_color_normal")
	record_color_highlight := hotv->u8x4_inv("record_color_highlight")
	record_color_active    := hotv->u8x4_inv("record_color_active")

	_vuibd_clickable()
	_vuibd_draw_rect(record_color_normal, 8, 4)
	_vuibd_draw_rect_hot(record_color_highlight)
	_vuibd_draw_rect_hot_animation(0.25)
	_vuibd_draw_rect_active(record_color_active)
	_vuibd_layout(.Horizontal)

	RecordWidget :: struct {
		record   : ^Record,
		editting : bool,
		cursor, visual_cursor   : Vec2,
	}
	assert(size_of(RecordWidget) < 8*8)

	get_record_wjt :: proc(state: ^VuiWidget) -> ^RecordWidget {
		return auto_cast &state.update_custom.data
	}
	// TODO: make a size safe check
	wjt := cast(^RecordWidget)_vuibd_update_custom(proc(w: VuiWidgetHandle) {
		state := _vuibd_helper_get_pointer_from_handle(w)
		recordwjt := get_record_wjt(state)
		recordwjt.visual_cursor = (recordwjt.cursor - recordwjt.visual_cursor) * cast(f32)_vui_ctx().delta_s * 12 + recordwjt.visual_cursor

		interact := &state.basic.interact
		if recordwjt.editting {
			ed := &editting_record.textedit
			if input_text := get_input_text(context.temp_allocator); input_text != {} {
				textedit_insert(ed, input_text)
			} else if is_key_repeated(.Back) {
				_, i := textedit_find_previous_rune(ed, ed.selection.x)
				if i != -1 do textedit_remove(ed, i-ed.selection.x)
			} else if is_key_repeated(.Delete) {
				_, i := textedit_find_next_rune(ed, ed.selection.x)
				if i != -1 do textedit_remove(ed, i-ed.selection.x)
			} else if is_key_repeated(.Left) {
				_, i := textedit_find_previous_rune(ed, ed.selection.x)
				if i != -1 do textedit_move(ed, i-ed.selection.x)
			} else if is_key_repeated(.Right) {
				_, i := textedit_find_next_rune(ed, ed.selection.x)
				if i != -1 do textedit_move(ed, i-ed.selection.x)
			} else if is_key_repeated(.Home) {
				textedit_move_to(ed, 0)
			} else if is_key_repeated(.End) {
				textedit_move_to(ed, textedit_len(ed))
			}

			if interact.pressed_outside || is_key_released(.Escape) || is_key_released(.Enter) {
				recordwjt.editting = false
				strings.builder_reset(&recordwjt.record.text)
				strings.write_string(&recordwjt.record.text, gapbuffer_get_string(&editting_record.gapbuffer, context.temp_allocator))
				textedit_end(ed)
				toggle_text_input(false)
				editting_record.record = nil
				return
			}
			if input_text := get_input_text(context.temp_allocator); input_text != {} {
				textedit_insert(ed, input_text)
			}
		} else {
			r := recordwjt.record
			if editting_record.record == nil && (_vui_ctx().hot == state.basic.id || _vui_ctx().active == state.basic.id) {
				if !key_handled {
					if is_key_pressed(.A) {
						if r != root do record_add_sibling(r)
						key_handled = true
					} else if is_key_pressed(.S) {
						record_add_child(r)
						key_handled = true
					} else if is_key_pressed(.D) {
						record_remove(r)
						key_handled = true
					}
				}
			}
			if interact.clicked {
				recordwjt.editting = true
				gpb := &editting_record.gapbuffer
				gapbuffer_clear(gpb)
				gapbuffer_insert_string(gpb, 0, strings.to_string(recordwjt.record.text))
				toggle_text_input(true)
				textedit_begin(&editting_record.textedit, &editting_record.gapbuffer, 0)
				editting_record.record = recordwjt.record
				return
			}
		}
	})
	wjt.record = vr.r
	wjt.cursor = cursor_offset

	_vuibd_draw_custom(proc(w: VuiWidgetHandle) {
		state := _vuibd_helper_get_pointer_from_handle(w)
		recordwjt := get_record_wjt(state)
		tbro := cast(^TextBro)state.draw_custom.data
		textpos := rect_position(state.basic.rect) + {8, 0}
		text_shadow_color := hotv->u8x4_inv("record_text_shadow_color")
		for e in tbro.elems {
			d := e.quad_dst
			x, y := textpos.x, textpos.y
			draw_texture_ex(fsctx.atlas, e.quad_src, {d.x+x+1.2, d.y+y+1.2, d.w, d.h}, {0,0}, 0, text_shadow_color)
			draw_texture_ex(fsctx.atlas, e.quad_src, {d.x+x, d.y+y, d.w, d.h}, {0,0}, 0, e.color)
			if recordwjt.editting {
				cursor := recordwjt.visual_cursor
				draw_rect(rect_from_position_size(textpos+cursor-{0, 22}+{0, 3}, {2, 22}), e.color)
			}
		}
		tbro_release(tbro)
		free(tbro)
	}, tbro)

	_, current := _vuibd_helper_get_current()

	empty(CHILDID(&chid))

	if vui_layout_scoped(CHILDID(&chid), {0,0, 25, -1}, .Vertical, 0, {0,0,0, 5}) {
		empty(CHILDID(&chid))
		if _mini_button(CHILDID(&chid), rect_anchor(current.basic.rect, {1,1,1,1}, {-25, -25, -5, -5})).clicked {
			log.debugf("You clicked the mini button of {}", strings.to_string(vr.r.text))
		}
		// empty(CHILDID(&chid), {0,0,-1, 5})
	}

	_mini_button :: proc(id: u64, rect: Rect) -> VuiInteract {
		_vuibd_begin(id, rect); 
		_vuibd_clickable()
		_vuibd_draw_rect({233, 90, 80, 255}, 4)
		_vuibd_draw_rect_hot({255, 120, 90, 255})
		_vuibd_draw_rect_hot_animation(0.2)
		_vuibd_draw_rect_active({255, 244, 255, 255})
		return _vuibd_end()
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

	using strings
	root = _new_record()
	write_string(&root.text, "ROOT")

	doc_read()

	// aaa := record_add_child(root)
	// write_string(&aaa.text, "AAA")
	// 	a1 := record_add_child(aaa)
	// 	write_string(&a1.text, "A1")
	// 	a2 := record_add_sibling(a1)
	// 	write_string(&a2.text, "A2")
	// bbb := record_add_sibling(aaa)
	// write_string(&bbb.text, "BBB")
	// 	b1 := record_add_child(bbb)
	// 	write_string(&b1.text, "B1")
	// 	b2 := record_add_sibling(b1)
	// 	write_string(&b2.text, "B2")
	// 	b0 := record_add_child(bbb)
	// 	write_string(&b0.text, "B0")
	update_visual_records(root)

	bubble_messages = hla.hla_make(BubbleMessage)
}
vwv_end :: proc() {
	hla.hla_delete(&bubble_messages)

	gapbuffer_release(&editting_record.gapbuffer)
	for r in records {
		strings.builder_destroy(&r.text)
		free(r)
	}
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
	strings.builder_init(&r.text)
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
// Add a new record as the last child of `to` node.
record_append_child :: proc(to: ^Record) -> ^Record {
	r := _new_record()
	r.parent = to
	if to.child == nil {
		to.child = r
	} else {
		prev := to.child
		for prev.next != nil {
			prev = prev.next
		}
		prev.next = r
	}
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
