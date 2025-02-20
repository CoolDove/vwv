package main

import "core:fmt"
import "base:runtime"
import "core:strings"
import "core:unicode/utf8"
import "core:log"
import "core:math/linalg"
import "core:math"
import sdl "vendor:sdl2"
import dd "dude/dude/core"
import "dude/dude/render"
import "dude/dude/imdraw"
import "dude/dude/input"
import "dude/dude"
import "dude/dude/dgl"
import "dude/dude/vendor/fontstash"
import "vui"

vwv_app : VwvApp
vuictx : vui.VuiContext
root : VwvRecord

DEBUG_VWV : bool

VwvApp :: struct {
	// ** basic
	view_offset_y : f32,
	state : AppState,

	status_bar_info : strings.Builder,

	pin : bool,
	window_bordered : bool,

	// ** operations
	record_operations : [dynamic]RecordOperation,// Call push_record_operations to push. Flushed every frame.
	selecting_records : [dynamic]u64,
	activating_record : u64,

	// ** time
	msgbubble : string,
	msgbubble_time : f32,

	// ** states
	using state_edit : VwvState_Edit,
	using state_drag : VwvState_DragRecord,

	// ** focus
	// When you set a record focused, you can only update it and its children, so it's safe to hold 
	//	the pointer as a reference.
	focusing_record : ^VwvRecord,

	// ** misc
	_frame_id : u64,
	_save_dirty : bool,

	// ** visual
	visual_view_offset_y : f32,
}

AppState :: enum {
	Normal, Edit, DragRecord
}

VwvState_Edit :: struct {
	text_edit : TextEdit,
	editting_record : ^VwvRecord,
	editting_point : dd.Vec2,
}
VwvState_DragRecord :: struct {
	dragging_record : ^VwvRecord,
	dragging_record_sibling : int, // Sibling index of the record you're dragging.
	arrange_index : int, // The index of slots you want to arrange to.

	drag_record_position : f32, // y-axis position

	drag_gap_height : f32,
	drag_gap_position : f32, // Set when the gap drawn

	// ** Visual
	visual_gap_box : Rect,
}

VwvRecord :: struct {
	id : u64,
	line, detail : GapBuffer,
	using info : VwvRecordInfo,
	children : [dynamic]VwvRecord,
	parent : ^VwvRecord,
}

VwvRecordInfo :: struct {
	tag : u32,
	state : VwvRecordState,
	fold : bool,
	progress : [3]f32, // Used by a parent node, indicates the portion of: open, done, closed.
}
VwvRecordState :: enum {
	Open, Done, Closed,
}

vwv_init :: proc() {
	when ODIN_DEBUG {
		DEBUG_VWV = true
	}

	strings.builder_init(&vwv_app.status_bar_info)
	
	// manually init root node
	record_init(&root)
	record_set_line(&root, "vwv")

	// ** load
	if is_record_file_exist() {
		load()
	} else {
		ra := record_add_child(&root)
			ra0 := record_add_child(ra)
			ra1 := record_add_child(ra)
			ra2 := record_add_child(ra)
			ra3 := record_add_child(ra)
		rb := record_add_child(&root)
            rb0 := record_add_child(rb)
            rb1 := record_add_child(rb)
            rb2 := record_add_child(rb)
		rc := record_add_child(&root)

		record_set_line(ra, "Hello, this is VWV, a simple todo tool.")
			record_set_line(ra0, "Click the '+' button to add a record.")
			record_set_line(ra1, "Press LCtrl+LMB to fold/unfold a record.")
			record_set_line(ra2, "Press LCtrl+RMB to delete a record.")
			record_set_line(ra3, "Press RMB to change the state.")
		record_set_line(rb, "Keyboard operations")
			record_set_line(rb0, "[J]:move down, [K]:move up, [H]:move to the parent")
			record_set_line(rb1, "[A]:switch state, [F]:toggle fold, [Ctrl-F]:focus, [Esc]:exit focus/edit mode")
			record_set_line(rb2, "[Enter]:edit, [Ctrl-Enter]:add a child, [Ctrl-D]:delete")

		record_set_line(rc, "The End")
		record_set_state(rc, .Done)
	}
	
	vwv_app.record_operations = make([dynamic]RecordOperation)
	vwv_app.selecting_records = make([dynamic]u64)

	vui.init(&vuictx, &pass_main, render.system().default_font)
	vwv_app._save_dirty = false

	ICON_TEXTURE = dgl.texture_load_from_mem(#load("./res/icons.png"))
	dgl.texture_set_filter(ICON_TEXTURE.id, .Nearest, .Nearest)

	vwv_app.window_bordered = true

	vwv_app.activating_record = root.id

}

vwv_release :: proc() {
	strings.builder_destroy(&vwv_app.status_bar_info)
	vui.release(&vuictx)
	delete(vwv_app.record_operations)
	delete(vwv_app.selecting_records)
	record_release_recursively(&root)
}

vwv_update :: proc() {
	strings.builder_reset(&vwv_app.status_bar_info)
	if wheel := input.get_mouse_wheel(); wheel.y != 0 {
		vwv_app.view_offset_y += wheel.y * 24.0
	}

	if math.abs(vwv_app.visual_view_offset_y-vwv_app.view_offset_y) > 4 {
		using vwv_app
		visual_view_offset_y = (view_offset_y - visual_view_offset_y) * 0.3 + visual_view_offset_y
		dd.dispatch_update()
	} else {
		vwv_app.visual_view_offset_y = vwv_app.view_offset_y
	}

	viewport := dd.app.window.size
	app_rect :dd.Rect= {0,0, cast(f32)viewport.x, cast(f32)viewport.y}

	rect :dd.Rect= {10,10, cast(f32)viewport.x-20, cast(f32)viewport.y-20}
	rect.y += vwv_app.visual_view_offset_y

	if vwv_app.state == .Edit {
		// ...
	} else if vwv_app.state == .Normal {
		if input.get_key_down(.S) && input.get_key(.LCTRL) {
			save()
		}
		if input.get_key_down(.C) && input.get_key(.LCTRL) && input.get_key(.LSHIFT) {
			save(true)
		}
		if vwv_app.focusing_record != nil && input.get_key_down(.ESCAPE) {
			vwv_app.focusing_record = nil
			bubble_msg("Exit focus mode.", 0.8)
			sdl.SetWindowTitle(dd.app.window.window, DEFAULT_WINDOW_TITLE)
			dd.dispatch_update()
		}
	} else if vwv_app.state == .DragRecord {
		if input.get_mouse_button_down(.Right) {
			vwv_state_exit_drag(false)
		}
	}

	if input.get_key_repeat(.F1) {
		DEBUG_VWV = !DEBUG_VWV
	}

	status_bar(app_rect)

	if vwv_app.focusing_record != nil {
		focusing := vwv_app.focusing_record
		vwv_record_update(focusing, &rect, 0, 0)
		strings.write_string(&vwv_app.status_bar_info, fmt.tprintf("[Focus:{}]", gapbuffer_get_string(&focusing.line, context.temp_allocator)))
	} else {
		vwv_record_update(&root, &rect, 0, 0)
	}
	
	if vwv_app.msgbubble_time > 0 {// ** msg bubble
		using theme
		bubblerect := rect_padding(rect_split_bottom(rect_split_top(app_rect, 120), font_size+8), 4,4,0,0)
		imdraw.quad(&pass_main, {bubblerect.x, bubblerect.y}, {bubblerect.w, bubblerect.h}, {80,90,90, 168}, order=LAYER_FLOATING_PANEL)
		msgrect := rect_padding(bubblerect, 6,6,0,0)
		imdraw.text(&pass_main, vuictx.font, vwv_app.msgbubble, {msgrect.x,msgrect.y+font_size}, font_size, {0.9,0.9,0.8,0.9}, order=LAYER_FLOATING_PANEL+1)
		vwv_app.msgbubble_time -= cast(f32)dd.game.time_delta
		if vwv_app.msgbubble_time <= 0 {
			vwv_app.msgbubble_time = 0
			vwv_app.msgbubble = ""
		}
		dd.dispatch_update()
	}
	
	flush_record_operations()

	if vwv_app._save_dirty {
		save()
		vwv_app._save_dirty = false
	}
	

	if DEBUG_VWV {
		// ** debug draw
		debug_point :: proc(point: dd.Vec2, col:=dd.Color32{255,0,0,255}, size:f32=2, order:i32=99999999) {
			imdraw.quad(&pass_main, point, {size,size}, {255,0,0,255}, order=99999999)
		}

		dmp : dd.Vec2= {16, 16} // debug_msg_pos
		screen_debug_msg :: proc(dmp: ^dd.Vec2, msg: string, intent:i32=0) {
			fsize : f32 = 18
			imdraw.text(&pass_main, render.system().default_font, msg, dmp^ + {0, fsize}, fsize, color={1,1,0,1}, order=999999)
			imdraw.text(&pass_main, render.system().default_font, msg, dmp^ + {0, fsize} + {2,2}, fsize, color={0,0,0,.5}, order=999998)
			dmp.y += fsize + 4
		}
		screen_debug_msg(&dmp, fmt.tprintf("FrameId: {}", vwv_app._frame_id))
		screen_debug_msg(&dmp, fmt.tprintf("Vwv state: {}", vwv_app.state))
		if vwv_app.state == .DragRecord do screen_debug_msg(&dmp, fmt.tprintf("Arrange index: {}", vwv_app.state_drag.arrange_index))
		screen_debug_msg(&dmp, fmt.tprintf("Scroll offset: {}", vwv_app.view_offset_y))
		if vwv_app.state == .DragRecord {
			screen_debug_msg(&dmp, fmt.tprintf("Drag gap: {}", vwv_app.drag_gap_height))
		}
		screen_debug_msg(&dmp, fmt.tprintf("Vui active: {}, hover: {}, hover order: {}", vuictx.active, vuictx.hot, vuictx.hot_order))
		screen_debug_msg(&dmp, fmt.tprintf("Focus record: {}", "nil" if vwv_app.focusing_record == nil else gapbuffer_get_string(&vwv_app.focusing_record.line, context.temp_allocator)))

		if vwv_app.state == .Edit {
			ed := vwv_app.text_edit
			gp := ed.buffer
			screen_debug_msg(&dmp, fmt.tprintf("Edit: gpbuffer size: {}/{}, gap[{},{}], selection[{},{}]", 
				gapbuffer_len(gp), gapbuffer_len_buffer(gp), 
				gp.gap_begin, gp.gap_end, ed.selection.x, ed.selection.y))
		}
		debug_point(vwv_app.editting_point)
	}
}


bubble_msg :: proc(msg: string, duration: f32) {
	vwv_app.msgbubble = msg
	vwv_app.msgbubble_time = duration
}

status_bar :: proc(app_rect: Rect) {
	sbr_height :f32= 42
	sbr := rect_split_top(app_rect, sbr_height)
	imdraw.quad(&pass_main, {sbr.x, sbr.y}, {sbr.w, sbr.h}, {90, 100, 75, 255}, order=LAYER_STATUS_BAR_BASE)
	imdraw.text(&pass_main, vuictx.font, strings.to_string(vwv_app.status_bar_info), rect_position(sbr)+{0,theme.font_size+15}, theme.font_size, {1,1,1,1}, order=LAYER_STATUS_BAR_ITEM)
	vcontrol_panel(&vuictx, VUID_STATUS_BAR_PANEL, sbr, LAYER_STATUS_BAR_BASE)

	icon_unit :f32= sbr_height-8
	checkbox_rect := rect_padding(rect_split_right(sbr, sbr_height), 4,4,4,4)
	new_pin_value := vcontrol_checkbox(&vuictx, VUID_BUTTON_PIN, checkbox_rect, vwv_app.pin, icon=ICON_PIN, order=LAYER_STATUS_BAR_ITEM)
	if new_pin_value != vwv_app.pin {
		sdl.SetWindowAlwaysOnTop(dd.app.window.window, auto_cast new_pin_value)
		vwv_app.pin = new_pin_value
		dd.dispatch_update()
	}

	checkbox_rect.x -= icon_unit+4
	new_bordered_value := vcontrol_checkbox(&vuictx, VUID_BUTTON_WINDOW_BORDERED, checkbox_rect, vwv_app.window_bordered, icon=ICON_WINDOW_BORDERED, order=LAYER_STATUS_BAR_ITEM)
	if new_bordered_value != vwv_app.window_bordered {
		sdl.SetWindowBordered(dd.app.window.window, auto_cast new_bordered_value)
		vwv_app.window_bordered = new_bordered_value
		dd.dispatch_update()
	}

	
	if vwv_app.focusing_record != nil {
		bro : dude.TextBro
		dude.tbro_init(&bro, vuictx.font, theme.font_size); defer dude.tbro_release(&bro)
		idx := dude.tbro_write_string(&bro, "Focusing on: ")
		dude.tbro_write_string(&bro, gapbuffer_get_string(&vwv_app.focusing_record.line, context.temp_allocator))

		pos := rect_position(sbr)+{0,theme.font_size+15}
		config := dude.TextBroExportConfig{
			color = {255,0,0,255},
			transform = dude.mat3_trs(pos, 0,1),
		}
		imdraw.textbro(&pass_main, &bro, 0, idx, config, LAYER_STATUS_BAR_ITEM)
		config.color = {0,255,0,255}
		imdraw.textbro(&pass_main, &bro, idx+1, dude.tbro_length(&bro)-1, config, LAYER_STATUS_BAR_ITEM)
		config.color = {0,0,0,64}
		config.transform = dude.mat3_trs(pos+{2,2}, 0,1)
		imdraw.textbro(&pass_main, &bro, 0, dude.tbro_length(&bro)-1, config, LAYER_STATUS_BAR_ITEM-1)
	}

}

vwv_record_update :: proc(r: ^VwvRecord, rect: ^Rect, depth :f32= 0, sibling_idx:int, parent_dragged:=false) {
	using theme
	indent := indent_width*depth
	is_folded_header := r.fold && len(r.children) > 0

	editting := vwv_app.state == .Edit && vwv_app.editting_record == r
	dragging := vwv_app.dragging_record == r

	drag_context_rect : Rect

	card_height := line_height
	if is_folded_header do card_height += record_progress_bar_height
	
	record_rect := rect_padding(rect_require(rect_split_bottom(rect^, card_height), indent+4), indent, 0,0,0)
	corner := rect_position(record_rect)
	size := rect_size(record_rect)
	render_layer_offset :i32= 10000 if (dragging || parent_dragged) else 0

	container_rect := rect
	container_rect_before := container_rect^

	// ** the card space
	grow(container_rect, card_height + line_padding)

	textbox_rect := rect_split_bottom(rect_padding(rect_require(record_rect, 60), 20, 30, 0,0), line_height)
	textbox_vid := VUID_BY_RECORD(r, RECORD_ITEM_LINE_TEXTBOX)
	text_theme := theme.text_record_done if r.state == .Done else (theme.text_record_closed if r.state == .Closed else theme.text_record_open)
	edit_point, exit_text := vcontrol_edittable_textline(&vuictx, textbox_vid, textbox_rect, LAYER_RECORD_CONTENT+render_layer_offset, &r.line, &vwv_app.text_edit if editting else nil, text_theme)

	if exit_text {
		log.debugf("exit editting")
		editting_record := vwv_app.editting_record
		push_record_operations(RecordOp_ToggleEdit{editting_record, false})
		// Delete the added record if an empty line is left.
		if len(editting_record.children) == 0 && gapbuffer_len(&editting_record.line) == 0 do push_record_operations(RecordOp_RemoveChild{editting_record})
		dd.dispatch_update()
	} else if editting {
		vwv_app.editting_point = edit_point
		input.textinput_set_imm_composition_pos(vwv_app.editting_point)
	}

	card_handle_events := vwv_app.state != .DragRecord || dragging
	
	vbegin_record_card(&vuictx, r)

	if vwv_app.activating_record == r.id {
		_temp_thickness :Vec2= {2,2}
		imdraw.quad(&pass_main, rect_position(record_rect)-_temp_thickness, rect_size(record_rect)+2*_temp_thickness, theme.activate_color)
	}

	if vwv_app.state == .Normal {
		width, height :f32= 14, 14
		padding :f32= 2
		buttons_rect := rect_split_left(record_rect, width+2*padding)

		btn_rect := rect_padding(rect_split_top(buttons_rect, height+2*padding), padding,padding,padding,padding)
		if len(r.children) > 0 {
			if vcontrol_button(&vuictx, VUID_BY_RECORD(r, RECORD_ITEM_BUTTON_FOLD_TOGGLE), btn_rect, LAYER_RECORD_BASE+2, icon=ICON_TRIANGLE_RIGHT if r.fold else ICON_TRIANGLE_DOWN) {
				push_record_operations(RecordOp_ToggleFold{r, !r.fold})
				dd.dispatch_update()
			}
			btn_rect.y -= height
		}

		if vcontrol_button(&vuictx, VUID_BY_RECORD(r, RECORD_ITEM_BUTTON_ADD_RECORD), btn_rect, LAYER_RECORD_BASE+2, icon=ICON_ADD) {
			vui._reset(&vuictx)
			push_record_operations(RecordOp_ToggleFold{r, false})
			push_record_operations(RecordOp_AddChild{r, true})
		}
	}

	// ** focus button
	if card_handle_events && r != &root && rect_in(record_rect, input.get_mouse_position()) && len(r.children) != 0 {
		focus_btn_rect := rect_padding(rect_split_right(record_rect, line_height-2), 0,2,2,2+(record_rect.h-line_height))
		focus_btn_vid := VUID_BY_RECORD(r, RECORD_ITEM_BUTTON_FOCUS)
		if vcontrol_button(&vuictx, focus_btn_vid, focus_btn_rect, icon=ICON_FOCUS, order=LAYER_RECORD_CONTENT+100) {
			vwv_focus_on(r)
			vwv_app.view_offset_y = 0
			vwv_app.visual_view_offset_y = rect.y
		}
	}

	to_start_drag : bool

	dragged_record_rect := rect_padding(record_rect, -2,-2,-1,-1)
	// ** handle card interact result
	if result := vend_record_card(&vuictx, r, record_rect if !dragging else dragged_record_rect, card_handle_events, render_layer_offset); result != .None {
		if vwv_app.state == .Normal {
			if result == .Left {// left click to edit
				if input.get_key(.LCTRL) {
					push_record_operations(RecordOp_ToggleFold{r, !r.fold})
				} else {
					// vwv_state_enter_edit(r)
					push_record_operations(RecordOp_ToggleEdit{r, true})
					editting = true
					dd.dispatch_update()
				}
			} else if result == .Right {// right click to change state
				if input.get_key(.LCTRL) {// fold the record
					push_record_operations(RecordOp_RemoveChild{r})
				} else {// change record state
					push_record_operations(RecordOp_SetState{ r, dd.enum_step(VwvRecordState, r.info.state) })
					dd.dispatch_update()
				}
			} else if result == .Drag {
				to_start_drag = vwv_app.focusing_record != r
			} else {
				// panic("This shouldn't happen.")
			}
		} else if vwv_app.state == .DragRecord {
			if result == .DragRelease {// left click to edit
				vwv_state_exit_drag()
				dd.dispatch_update()
			} else {
				panic("This shouldn't happen")
			}
		}
	}

	if vwv_app.state == .Normal {
		_update_record_keyboard_control(r)
	}

	ArrangeInfo :: struct {
		before : i32,// The sibling before the gap.
		after : i32,// The sibling after the gap.
		before_height : f32,
		after_height : f32,
	}

	arrange_info : ArrangeInfo = {-1,-1,0,0}

	if !is_folded_header { // ** update all children
		dragging_record := vwv_app.dragging_record
		is_drag_parent := vwv_app.state == .DragRecord && dragging_record != nil && dragging_record.parent == r

		if is_drag_parent {
			drag_height := input.get_mouse_position().y - record_rect.h*0.5
			floating_rect := Rect{rect.x, drag_height, rect.w, rect.h - drag_height}
			vwv_app.state_drag.drag_record_position = floating_rect.y
			vwv_record_update(vwv_app.dragging_record, &floating_rect, depth + 1, 0, true) // update the dragged record separately

			for i in 0..<len(r.children) {
				height_before := container_rect.y
				if i == vwv_app.arrange_index {
					_grow_arrange_gap(container_rect)
				} else {
					sibling_idx := _get_sibling_idx(i, vwv_app.arrange_index, vwv_app.dragging_record_sibling)
					vwv_record_update(&r.children[sibling_idx], container_rect, depth + 1, i, dragging || parent_dragged)
					if i == vwv_app.arrange_index-1 {
						arrange_info.before = cast(i32)i
						arrange_info.before_height = container_rect.y - height_before
					} else if i == vwv_app.arrange_index+1 {
						arrange_info.after = cast(i32)i
						arrange_info.after_height = container_rect.y - height_before
					}
				}
			}
		} else {
			for &c,i in r.children {
				vwv_record_update(&c, container_rect, depth + 1, i, dragging || parent_dragged)
			}
		}

		_grow_arrange_gap :: proc(container_rect: ^Rect) {
			gap_rect := rect_split_top(container_rect^, vwv_app.drag_gap_height)

			vpos, vsize := rect_position_size(vwv_app.visual_gap_box)
			{// interpolate the visual rect
				gpos, gsize := rect_position(container_rect^), rect_size(gap_rect)
				if linalg.distance(vpos,gpos) > 2 || linalg.distance(vsize, vsize) > 2 {
					t :f32= 0.3
					vpos = (gpos-vpos)*t + vpos
					vsize = (gsize-vsize)*t + vsize
					dd.dispatch_update()
				} else {
					vpos, vsize = gpos, gsize
				}
				vwv_app.visual_gap_box = rect_from_position_size(vpos, vsize)
			}
			
			imdraw.quad(&pass_main, vpos, vsize, {0, 0, 0, 48})
			vwv_app.state_drag.drag_gap_position = container_rect^.y
			grow(container_rect, vwv_app.drag_gap_height)
		}

		if is_drag_parent {
			if vwv_app.drag_record_position > vwv_app.drag_gap_position && arrange_info.after != -1 {// Drag down
				available_gap := vwv_app.drag_record_position - vwv_app.drag_gap_position
				if available_gap > arrange_info.after_height*0.9 && vwv_app.state_drag.arrange_index < len(r.children) {
					vwv_app.state_drag.arrange_index += 1
					// log.debugf("arrange: {} -> {}", vwv_app.state_drag.dragging_record_sibling, vwv_app.state_drag.arrange_index)
				}
			} else if vwv_app.drag_record_position < vwv_app.drag_gap_position && arrange_info.before != -1 {// Drag up
				available_gap := vwv_app.drag_gap_position - vwv_app.drag_record_position 
				if available_gap > arrange_info.before_height*0.9 && vwv_app.state_drag.arrange_index > 0 {
					vwv_app.state_drag.arrange_index -= 1
					// log.debugf("arrange: {} -> {}", vwv_app.state_drag.dragging_record_sibling, vwv_app.state_drag.arrange_index)
				}
			}
		}
	}

	if to_start_drag {
		vwv_state_enter_drag(r, sibling_idx, container_rect_before.h - container_rect.h, container_rect_before.h)
		vwv_app.visual_gap_box = {record_rect.x, container_rect_before.h, record_rect.w, container_rect_before.h - container_rect.h}
		log.debugf("start dragging, sibling idx: {}", sibling_idx)
		dd.dispatch_update()
	}

	_get_sibling_idx :: proc(i, arrange_idx, drag_sib : int) -> int {
		if i == arrange_idx do return drag_sib
		if arrange_idx < drag_sib do return i - 1 if arrange_idx < i&&i <= drag_sib else i
		if arrange_idx > drag_sib do return i + 1 if drag_sib <= i&&i < arrange_idx else i
		return i
	}

	grow :: proc(r: ^dd.Rect, h: f32) {
		r.y += h
		r.h -= h
	}
}

@(private="file")
_update_record_keyboard_control :: proc(r: ^VwvRecord) {
	if r.id == vwv_app.activating_record {
		if input.get_key_down(.F) || input.get_key_repeat(.F) {
			if input.get_key(.LCTRL) {
				vwv_focus_on(r)
				return
			} else {
				push_record_operations(RecordOp_ToggleFold{ r, !r.fold })
				return
			}
		}
		if input.get_key_up(.RETURN)  {
			if input.get_key(.LCTRL) {
				push_record_operations(RecordOp_AddChild{ r, true })
				return
			} else if input.get_key(.LSHIFT) {
			} else {
				vwv_state_enter_edit(r)
			}
		}
		if input.get_key_up(.A) {
			push_record_operations(RecordOp_SetState{ r, dd.enum_step(VwvRecordState, r.info.state) })
			return
		}
		if (input.get_key_up(.D) && input.get_key(.LCTRL)) || input.get_key_up(.DELETE) {
			push_record_operations(RecordOp_RemoveChild{ r })
			return
		}


		if input.get_key_down(.H) || input.get_key_repeat(.H) {
			if r.parent != nil {
				push_record_operations(RecordOp_ActivateRecord{activate_id=r.parent.id})
				return
			}
		}
		if input.get_key_down(.J) || input.get_key_repeat(.J) {
			current_record := r
			if current_record == nil do return
			if !current_record.fold && len(current_record.children) != 0 {
				push_record_operations(RecordOp_ActivateRecord{activate_id=current_record.children[0].id})
				return
			}
			for current_record != nil && current_record.parent != nil && vwv_app.focusing_record != current_record {
				for &cr, idx in current_record.parent.children {
					if cr.id == current_record.id {
						if idx == len(current_record.parent.children)-1 {
							current_record = current_record.parent
						} else {
							push_record_operations(RecordOp_ActivateRecord{activate_id=current_record.parent.children[idx+1].id})
							return
						}
					}
				}
			}
		} else if input.get_key_down(.K) || input.get_key_repeat(.K) {
			if r == nil || r.parent == nil || vwv_app.focusing_record == r do return
			for &cr, idx in r.parent.children {
				if cr.id == r.id {
					if idx == 0 {
						if r.parent != nil {
							push_record_operations(RecordOp_ActivateRecord{activate_id=r.parent.id})
							return
						}
					} else {
						target := &r.parent.children[idx-1]
						for len(target.children) != 0 && !target.fold {
							target = &target.children[len(target.children)-1]
						}
						push_record_operations(RecordOp_ActivateRecord{activate_id=target.id})
						return
					}
				}
			}
		}
	}
}


draw_debug_rect :: proc(r: Rect, col: Color32) {
	imdraw.quad(&pass_main, rect_position(r), rect_size(r), col)
}

vwv_state_enter_drag :: proc(r: ^VwvRecord, sibling_idx: int, drag_gap_height:f32, drag_gap_position:f32) {
	assert(vwv_app.state == .Normal, "Should call this when in Normal mode.")
	vwv_app.dragging_record = r
	vwv_app.state = .DragRecord
	vwv_app.state_drag.drag_gap_height = drag_gap_height
	vwv_app.state_drag.drag_gap_position = drag_gap_position
	vwv_app.state_drag.drag_record_position = drag_gap_position
	if r.parent == nil do panic("Handle this later")
	else {
		prev := r.parent
		for &c in r.parent.children {
			if &c == r {
				break
			}
			prev = &c
		}
	}
	vwv_app.dragging_record_sibling = sibling_idx
	vwv_app.state_drag.arrange_index = sibling_idx
}
vwv_state_exit_drag :: proc(apply:= true) {
	if apply && vwv_app.dragging_record_sibling != vwv_app.arrange_index {
		push_record_operations(RecordOp_Arrange{vwv_app.dragging_record, vwv_app.dragging_record_sibling, vwv_app.arrange_index})
	}

	assert(vwv_app.state == .DragRecord, "Should call this when in DragRecord mode.")
	vwv_app.state = .Normal
	vwv_app.dragging_record = nil
}

vwv_state_exit_edit :: proc() {
	log.debugf("exit called")
	assert(vwv_app.state == .Edit, "Should call this when in Edit mode.")
	vwv_app.state = .Normal
	vwv_app.editting_record = nil
	vwv_mark_save_dirty()
}
vwv_state_enter_edit :: proc(r: ^VwvRecord) {
	// TODO: Handle the editting point
	assert(vwv_app.state == .Normal, "Should call this when in Normal mode.")
	input.textinput_set_imm_composition_pos(vwv_app.editting_point)
	input.textinput_begin()
	vwv_app.state = .Edit
	textedit_begin(&vwv_app.text_edit, &r.line, gapbuffer_len(&r.line))
	vwv_app.editting_record = r
	vwv_app.activating_record = r.id
	dd.dispatch_update()
}

vwv_focus_on :: proc(r: ^VwvRecord) {
	if vwv_app.focusing_record == r do return
	vui._reset(&vuictx)
	vwv_app.focusing_record = r
	push_record_operations(RecordOp_ToggleFold{r, false})
	parent_line := gapbuffer_get_string(&vwv_app.focusing_record.parent.line, context.temp_allocator)
	sdl.SetWindowTitle(dd.app.window.window, fmt.ctprintf("vwv - {}", parent_line))
	dd.dispatch_update()
	vwv_app.activating_record = r.id
	bubble_msg("Enter focus mode, press [ESC] to exit.", 2.0)
}

vwv_mark_save_dirty :: proc() {
	vwv_app._save_dirty = true
}

// ** record operations

RecordOperation :: union {
	RecordOp_AddChild,
	RecordOp_Arrange,
	RecordOp_RemoveChild,
	RecordOp_ToggleFold,
	RecordOp_SetState,

	RecordOp_ActivateRecord,
	RecordOp_ToggleEdit,
}

RecordOp_AddChild :: struct {
	parent : ^VwvRecord,
	edit : bool,
}
RecordOp_RemoveChild :: struct {
	record : ^VwvRecord,
}
RecordOp_Arrange :: struct {
	record : ^VwvRecord,
	from, to : int,
}
RecordOp_ToggleFold :: struct {
	record : ^VwvRecord,
	fold : bool,
}
RecordOp_SetState :: struct {
	record : ^VwvRecord,
	state : VwvRecordState,
}

RecordOp_ActivateRecord :: struct {
	activate_id : u64,
}
RecordOp_ToggleEdit :: struct {
	r : ^VwvRecord,
	edit : bool,
}

push_record_operations :: proc(op: RecordOperation) {
	append(&vwv_app.record_operations, op)
}
clear_record_operations :: proc() {
	clear(&vwv_app.record_operations)
}

flush_record_operations :: proc() {
	operations := vwv_app.record_operations[:]
	if len(operations) != 0 do dd.dispatch_update()
	for o in operations {
		switch op in o {
		case RecordOp_AddChild:// The `AddChild` operation adds a child and arrange it to the first.
			if op.parent.fold do record_toggle_fold(op.parent, false)
			record_arrange(record_add_child(op.parent), len(op.parent.children)-1, 0)
			if op.edit do vwv_state_enter_edit(&op.parent.children[0])
		case RecordOp_RemoveChild:
			if op.record != nil && op.record.parent != nil {
				if op.record.id == vwv_app.activating_record {
					if op.record.parent != nil do vwv_app.activating_record = op.record.parent.id
				}
				record_remove_record(op.record)
			}
		case RecordOp_Arrange:
			if op.record != nil && op.from != op.to do record_arrange(op.record, op.from, op.to)
		case RecordOp_ToggleFold:
			if op.record != nil do record_toggle_fold(op.record, op.fold)
			vwv_app.view_offset_y += -theme.record_progress_bar_height if op.fold else theme.record_progress_bar_height
		case RecordOp_ActivateRecord:
			vwv_app.activating_record = op.activate_id
		case RecordOp_ToggleEdit:
			if op.edit do vwv_state_enter_edit(op.r)
			else do vwv_state_exit_edit()
		case RecordOp_SetState:
			record_set_state(op.record, op.state)
		}
	}
	clear_record_operations()
}
