package main

import "core:time"
import "core:strings"
import "core:math"
import "core:math/rand"
import "core:math/linalg"
import "core:fmt"
import "core:strconv"
import "core:log"
import win32 "core:sys/windows"

import "vendor:fontstash"

import "dgl"
import "hotvalue"
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
		// pushlinef(&y, "窗口大小: {}", window_size)
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
	hotvalue.update(&hotv)

	if is_key_pressed(.S) && is_key_down(.Ctrl) {
		doc_write()
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

	update_visual_records(root)

	// vui_begin_layoutv({20, cast(f32)scroll_offset, cast(f32)window_size.x- 40, 600})
	vui_layout_begin(6789, {20, cast(f32)scroll_offset, cast(f32)window_size.x- 40, 600}, .Vertical, 10); {
		for &vr in visual_records {
			record_card(&vr)
		}
		vui_layout_end()
	}
	// vui_end_layout()

	// vui_layout_begin(6, {60,60, 200, 400}, .Vertical, 6); {
	// 	if vui_test_button(16, {60,60, -1, 60}, "A").clicked {
	// 		log.debugf("clicked A")
	// 	}
	// 	if vui_test_button(17, {60,60, 100, 40}, "B").clicked {
	// 		log.debugf("clicked B")
	// 	}

	// 	vui_layout_begin(7, {0,0, 200, 60}, .Horizontal, 10, {0,0,0,32}); {
	// 		for i in 0..<5 {
	// 			if vui_test_button(20+auto_cast i, {0,0, 30, 60}, "o").clicked {
	// 				log.debugf("clicked h {}", i)
	// 			}
	// 		}
	// 		vui_layout_end()
	// 	}

	// 	if vui_test_button(18, {60,60, 100, 40}, "C").clicked {
	// 		log.debugf("clicked C")
	// 	}
	// 	vui_layout_end()
	// }

	status_bar_rect := rect_split_bottom(window_rect, 46)
	_vuibd_begin(500, status_bar_rect)
	_vuibd_draw_rect(hotv->u8x4_inv("status_bar_bg_color"))
	_vuibd_layout(.Horizontal).padding = 6
	for i in 0..<5 {
		// vui_test_button(60+auto_cast i, {0,0, 60, 60}, "do")
		_vuibd_begin(60+auto_cast i, {0,0, 60, 60})
		_vuibd_clickable()
		_vuibd_draw_rect({233, 90, 80, 255})
		_vuibd_draw_rect_hot({255, 100, 70, 255})
		_vuibd_draw_rect_hot_animation(0.2)
		_vuibd_draw_rect_active({255, 244, 255, 255})
		if _vuibd_end().clicked {
			log.debugf("status bar button")
		}
	}
	_vuibd_end()

	// draw_rect(status_bar_rect, )
	// draw_text(font_default, "Status Bar", {status_bar_rect.x + 5, status_bar_rect.y + 4} , 28, {69,153,49, 255})
	// if vui_button(1280, rect_padding(rect_split_right(status_bar_rect, 46), 4,4,4,4), "hello") do fmt.printf("hello!\n")
	// vui_draggable_button(1222, rect_split_left(status_bar_rect, 32), "Drag me")
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
	baseid :u64= get_record_id(vr.r)

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

	_vuibd_begin(baseid, {cast(f32)indent, 0, cast(f32)width, (tbro_last(tbro).next.y if len(tbro.elems)>0 else 22) + 8})

	record_color_normal    := hotv->u8x4_inv("record_color_normal")
	record_color_highlight := hotv->u8x4_inv("record_color_highlight")
	record_color_active    := hotv->u8x4_inv("record_color_active")

	_vuibd_clickable()
	_vuibd_draw_rect(record_color_normal, 8, 4)
	_vuibd_draw_rect_hot(record_color_highlight)
	_vuibd_draw_rect_hot_animation(0.25)
	_vuibd_draw_rect_active(record_color_active)

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
				if is_key_pressed(.A) {
					if r != root do record_add_sibling(r)
				} else if is_key_pressed(.S) {
					record_add_child(r)
				} else if is_key_pressed(.D) {
					record_remove(r)
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
				draw_rect(rect_from_position_size(textpos+cursor-{0, 22}, {2, 22}), dgl.BLACK)
			}
		}
		tbro_release(tbro)
		free(tbro)
	}, tbro)

	_, current := _vuibd_helper_get_current()

	{
		_vuibd_begin(baseid+1, rect_anchor(current.basic.rect, {1,1,1,1}, {-25, -25, -5, -5}))
		_vuibd_clickable()
		_vuibd_draw_rect({233, 90, 80, 255}, 4)
		_vuibd_draw_rect_hot({255, 120, 90, 255})
		_vuibd_draw_rect_hot_animation(0.2)
		_vuibd_draw_rect_active({255, 244, 255, 255})
		if _vuibd_end().clicked {
			log.debugf("You clicked the mini button of {}", strings.to_string(vr.r.text))
		}
	}

	_vuibd_end()
	// _EState :: struct {
	// 	editting : f64, // > 0 means editting, there is an animation bound to this
	// 	cursor : f32,
	// 	scale : f32
	// }
	// state := _vui_state(vr.r.id * 10 + 10000, _EState)
	// if state.scale < 1 {
	// 	state.scale += auto_cast _vui_ctx().delta_s * 6
	// 	if state.scale >= 1 do state.scale = 1
	// }
	// layout := _vui_get_layout()
	// assert(layout != nil)
	// width := layout.rect.w - cast(f32)(vr.indent * 20) * tween.ease_outcirc(auto_cast state.scale)

	// tbro := new(TextBro, context.temp_allocator)
	// cursoridx : int
	// tbro_init(tbro, font_default, 28, auto_cast width-12)
	// text_color := dgl.col_i2u_inv(hotv->u32("record_text_color"))
	// text_color.a = cast(u8)(cast(f32)text_color.a*state.scale)

	// if state.editting > 0 {
	// 	ed := &editting_record.textedit
	// 	text := strings.to_string(vr.r.text) if state.editting <= 0 else gapbuffer_get_string(&editting_record.gapbuffer, context.temp_allocator)
	// 	cursoridx = tbro_write_string(tbro, text[:ed.selection.x], text_color)
	// 	tbro_write_string(tbro, text[ed.selection.x:], text_color)
	// } else {
	// 	tbro_write_string(tbro, strings.to_string(vr.r.text), text_color)
	// }
	// height :f32= 32.0
	// if last := tbro_last(tbro); last != nil do height = last.next.y + 4

	// _DrawData :: struct {
	// 	vr : ^VisualRecord,
	// 	tbro : ^TextBro,
	// 	cursoridx : int,
	// }

	// data := new(_DrawData)
	// data^ = { vr, tbro, cursoridx }

	// _vui_layout_push(width, height, draw, data)
	// // add a spacing
	// _vui_layout_push(0, 10, nil)

	// draw :: proc(rect: dgl.Rect, data: rawptr) {
	// 	data := cast(^_DrawData)data
	// 	defer free(data)
	// 	state := _vui_state(data.vr.r.id * 10 + 10000, _EState)
	// 	rect := rect
	// 	rect.x += cast(f32)(data.vr.indent * 20)
	// 	using data
	// 	hovering := rect_in(rect, input.mouse_position)
	// 	if hovering {
	// 		if editting_record.record == nil {
	// 			if is_key_pressed(.A) {
	// 				if vr.r != root do record_add_sibling(vr.r)
	// 			} else if is_key_pressed(.S) {
	// 				record_add_child(vr.r)
	// 			} else if is_key_pressed(.D) {
	// 				record_remove(vr.r)
	// 			}
	// 			if is_button_pressed(.Left) {
	// 				ed := &editting_record.textedit
	// 				gp := &editting_record.gapbuffer
	// 				gapbuffer_clear(gp)
	// 				gapbuffer_insert_string(gp, 0, strings.to_string(vr.r.text))
	// 				textedit_begin(ed, gp)
	// 				editting_record.record = vr.r
	// 				state.editting = 1
	// 				toggle_text_input(true)
	// 			}
	// 		}
	// 	}

	// 	editting := state.editting > 0
	// 	if editting {
	// 		ed := &editting_record.textedit
	// 		if input_text := get_input_text(context.temp_allocator); input_text != {} {
	// 			textedit_insert(ed, input_text)
	// 		} else if is_key_repeated(.Back) {
	// 			_, i := textedit_find_previous_rune(ed, ed.selection.x)
	// 			if i != -1 do textedit_remove(ed, i-ed.selection.x)
	// 		} else if is_key_repeated(.Delete) {
	// 			_, i := textedit_find_next_rune(ed, ed.selection.x)
	// 			if i != -1 do textedit_remove(ed, i-ed.selection.x)
	// 		} else if is_key_repeated(.Left) {
	// 			_, i := textedit_find_previous_rune(ed, ed.selection.x)
	// 			if i != -1 do textedit_move(ed, i-ed.selection.x)
	// 		} else if is_key_repeated(.Right) {
	// 			_, i := textedit_find_next_rune(ed, ed.selection.x)
	// 			if i != -1 do textedit_move(ed, i-ed.selection.x)
	// 		} else if is_key_repeated(.Home) {
	// 			textedit_move_to(ed, 0)
	// 		} else if is_key_repeated(.End) {
	// 			textedit_move_to(ed, textedit_len(ed))
	// 		}
	// 		if is_key_pressed(.Enter) || is_key_pressed(.Escape) {
	// 			strings.builder_reset(&vr.r.text)
	// 			strings.write_string(&vr.r.text, gapbuffer_get_string(&editting_record.gapbuffer, context.temp_allocator))
	// 			// @Temporary:
	// 			editting_record.record = nil
	// 			textedit_end(&editting_record.textedit)
	// 			state.editting = 0
	// 			toggle_text_input(false)
	// 		}
	// 	}

	// 	scale, cursor := state.scale, state.cursor

	// 	alpha := cast(u8)(255 * scale)
	// 	record_color_outline := dgl.col_i2u_inv(hotv->u32("record_color_outline")); record_color_outline.a = alpha
	// 	record_color_normal := dgl.col_i2u_inv(hotv->u32("record_color_normal")); record_color_normal.a = alpha
	// 	record_color_highlight := dgl.col_i2u_inv(hotv->u32("record_color_highlight")); record_color_highlight.a = alpha
	// 	if editting {
	// 		draw_rect_rounded(rect, 4, 2, record_color_outline if !hovering else record_color_highlight)
	// 		draw_rect_rounded(rect_padding(rect, 2,2,2,2), 4, 2, record_color_normal)
	// 	} else {
	// 		draw_rect_rounded(rect, 4, 2, record_color_normal if !hovering else record_color_highlight)
	// 	}

	// 	text := vr.r.text
	// 	width := cast(f64)rect.w

	// 	text_shadow_color := dgl.col_i2u_inv(hotv->u32("record_text_shadow_color"))
	// 	text_shadow_color.a = cast(u8)(cast(f32)text_shadow_color.a*state.scale)
	// 	textpos := dgl.Vec2{rect.x+4, rect.y-4}
	// 	for e in tbro.elems {
	// 		d := e.quad_dst
	// 		draw_texture_ex(fsctx.atlas, e.quad_src, {d.x+textpos.x+1.2, d.y+textpos.y+1.2, d.w, d.h}, {0,0}, 0, text_shadow_color)
	// 		draw_texture_ex(fsctx.atlas, e.quad_src, {d.x+textpos.x, d.y+textpos.y, d.w, d.h}, {0,0}, 0, e.color)
	// 	}
	// 	if editting {
	// 		font := fontstash.__getFont(&fsctx.fs, font_default)
	// 		cursor := tbro.elems[cursoridx-1].next if cursoridx > 0 else {0,28}
	// 		height := font.lineHeight*28
	// 		draw_rect({cursor.x+textpos.x, cursor.y+textpos.y-font.descender*28 - height, 2, height}, dgl.col_i2u_inv(hotv->u32("record_cursor_color")))
	// 	}
	// 	tbro_release(tbro)
	// }
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
}
vwv_end :: proc() {
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
