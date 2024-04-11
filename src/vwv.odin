package main

import "core:fmt"
import "core:runtime"
import "core:strings"
import "core:unicode/utf8"
import "core:log"
import sdl "vendor:sdl2"
import dd "dude/dude/core"
import "dude/dude/render"
import "dude/dude/imdraw"
import "dude/dude/input"
import "dude/dude"
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

    // ** operations
    record_operations : [dynamic]RecordOperation,

    // ** time
    msgbubble : string,
    msgbubble_time : f32,

    // ** edit
    text_edit : TextEdit,
    editting_record : ^VwvRecord,
    editting_point : dd.Vec2,

	// ** focus
	// When you set a record focused, you can only update it and its children, so it's safe to hold 
	//	the pointer as a reference.
	focusing_record : ^VwvRecord,

    // ** misc
    _frame_id : u64,
    _save_dirty : bool,
}

AppState :: enum {
    Normal, Edit
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

        record_set_line(ra, "Hello, this is VWV, a simple todo tool.")
            record_set_line(ra0, "Press the '+' button to add a record.")
            record_set_line(ra1, "Press LCtrl+LMB to fold/unfold a record.")
            record_set_line(ra2, "Press LCtrl+RMB to delete a record.")
            record_set_line(ra3, "Press RMB to change the state.")
        record_set_line(rb, "Enjoy yourself.")
        record_set_state(rb, .Done)
    }
    
    vwv_app.record_operations = make([dynamic]RecordOperation)

    vui.init(&vuictx, &pass_main, render.system().default_font)
    vwv_app._save_dirty = false
}

vwv_release :: proc() {
	strings.builder_destroy(&vwv_app.status_bar_info)
    vui.release(&vuictx)
    delete(vwv_app.record_operations)
    record_release_recursively(&root)
}

vwv_update :: proc() {
	strings.builder_reset(&vwv_app.status_bar_info)
    if wheel := input.get_mouse_wheel(); wheel.y != 0 {
        vwv_app.view_offset_y += wheel.y * 10.0
    }

    viewport := dd.app.window.size
    app_rect :dd.Rect= {0,0, cast(f32)viewport.x, cast(f32)viewport.y}
    
    
    rect :dd.Rect= {20,20, cast(f32)viewport.x-40, cast(f32)viewport.y-40}
    rect.y += vwv_app.view_offset_y

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
			dd.dispatch_update()
		}
    }

    if input.get_key_repeat(.F1) {
        DEBUG_VWV = !DEBUG_VWV
    }

	if vwv_app.focusing_record != nil {
		focusing := vwv_app.focusing_record
		vwv_record_update(focusing, &rect)
		strings.write_string(&vwv_app.status_bar_info, fmt.tprintf("[Focus:{}]", gapbuffer_get_string(&focusing.line, context.temp_allocator)))
	} else {
		vwv_record_update(&root, &rect)
	}

    {// ** status bar
        sbr := rect_split_top(app_rect, 42)
        imdraw.quad(&pass_main, {sbr.x, sbr.y}, {sbr.w, sbr.h}, {90, 100, 75, 255}, order=LAYER_STATUS_BAR_BASE)
		imdraw.text(&pass_main, vuictx.font, strings.to_string(vwv_app.status_bar_info), rect_position(sbr)+{0,theme.font_size+15}, theme.font_size, {1,1,1,1}, order=LAYER_STATUS_BAR_ITEM)
        checkbutton_rect := rect_padding(rect_split_right(sbr, 42), 4,4,4,4)
        new_pin_value := vcontrol_checkbutton(&vuictx, VUID_BUTTON_PIN, checkbutton_rect, vwv_app.pin, order=LAYER_STATUS_BAR_ITEM)
        if new_pin_value != vwv_app.pin {
            sdl.SetWindowAlwaysOnTop(dd.app.window.window, auto_cast new_pin_value)
            vwv_app.pin = new_pin_value
            dd.dispatch_update()
        }
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

        dmp : dd.Vec2 // debug_msg_pos
        screen_debug_msg :: proc(dmp: ^dd.Vec2, msg: string, intent:i32=0) {
            fsize : f32 = 32
            imdraw.text(&pass_main, render.system().default_font, msg, dmp^ + {0, fsize}, fsize, color={0,1,0,1}, order=999999)
            imdraw.text(&pass_main, render.system().default_font, msg, dmp^ + {0, fsize} + {2,2}, fsize, color={0,0,0,.5}, order=999998)
            dmp.y += fsize + 10
        }
        screen_debug_msg(&dmp, fmt.tprintf("FrameId: {}", vwv_app._frame_id))
        screen_debug_msg(&dmp, fmt.tprintf("Vui active: {}, hover: {}", vuictx.active, vuictx.hot))
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

vwv_record_update :: proc(r: ^VwvRecord, rect: ^Rect, depth :f32= 0) {
    using theme
    indent := indent_width*depth
	record_rect := rect_padding(rect_require(rect_split_bottom(rect^, line_height), indent+4), indent, 0,0,0)
	corner := rect_position(record_rect)
	size := rect_size(record_rect)
    corner_rb := corner+size// right-bottom

    editting := vwv_app.state == .Edit && vwv_app.editting_record == r

    textbox_rect := rect_padding(rect_require(record_rect, 60), 20, 30, 0,0)
    textbox_vid := VUID_BY_RECORD(r, RECORD_ITEM_LINE_TEXTBOX)
	text_theme := theme.text_record_done if r.state == .Done else (theme.text_record_closed if r.state == .Closed else theme.text_record_open)
    edit_point, exit_text := vcontrol_edittable_textline(&vuictx, textbox_vid, textbox_rect, &r.line, &vwv_app.text_edit if editting else nil, text_theme)
    
    if exit_text {
        vwv_state_exit_edit()
        dd.dispatch_update()
    } else if editting {
        vwv_app.editting_point = edit_point
        input.textinput_set_imm_composition_pos(vwv_app.editting_point)
    }
    
    if result := vcontrol_record_card(&vuictx, r, record_rect); result != .None {
        if vwv_app.state == .Normal {
            if result == .Left {// left click to edit
                if input.get_key(.LCTRL) {
					record_toggle_fold(r, !r.fold)
                } else {
                    vwv_state_enter_edit(r)
                    editting = true
                    dd.dispatch_update()
                }
            } else if result == .Right {// right click to change state
				if input.get_key(.LCTRL) {// fold the record
                    push_record_operations(RecordOp_RemoveChild{r})
				} else {// change record state
					record_set_state(r, dd.enum_step(VwvRecordState, r.info.state))
					dd.dispatch_update()
				}
            }
        }
    }
	grow(rect, line_height + line_padding)

	if rect_in(record_rect, input.get_mouse_position()) && len(r.children) != 0 {
		focus_btn_rect := rect_padding(rect_split_right(record_rect, record_rect.h-2), 0,2,2,2)
		focus_btn_vid := VUID_BY_RECORD(r, RECORD_ITEM_BUTTON_FOCUS)
		if vcontrol_button(&vuictx, focus_btn_vid, focus_btn_rect, order=LAYER_RECORD_CONTENT+100) {
			vwv_app.focusing_record = r
			dd.dispatch_update()
			bubble_msg("Enter focus mode, press [ESC] to exit.", 2.0)
			log.debugf("clicked focus")
		}
	}

	if r.fold && len(r.children) > 0 {
		folded_rect := rect_split_top(record_rect, -(theme.line_padding+8))
		idt := indent_width
		folded_rect = rect_padding(rect_require(folded_rect, idt+6, 6, anchor={1,0.5}), idt, 2,2,2)
		bg_rect := rect_padding(record_rect, -2,-2,-2, -(theme.line_padding+8))
		imdraw.quad(&pass_main, rect_position(bg_rect), rect_size(bg_rect), {0,0,0,128}, order = LAYER_RECORD_BASE-1)
		imdraw.quad(&pass_main, rect_position(folded_rect), rect_size(folded_rect), color={215,220,210, 50}, order=LAYER_RECORD_CONTENT+100)
		grow(rect, 8+4)
	} else {
		if vwv_app.state == .Normal {
			width, height :f32= 14, 14
			padding :f32= 2
			btn_rect := dd.Rect{corner.x - width - padding, corner.y + size.y - height, width, height}
			if result := vcontrol_button_add_record(&vuictx, r, btn_rect); result != .None {
				if result == .Left {
					push_record_operations(RecordOp_AddChild{r, true})
				}
			}
		}
		
		for &c, i in r.children {
			vwv_record_update(&c, rect, depth + 1)
		}
	}

	grow :: proc(r: ^dd.Rect, h: f32) {
		r.y += h
		r.h -= h
	}
}

vwv_state_exit_edit :: proc() {
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
    dd.dispatch_update()
}

vwv_mark_save_dirty :: proc() {
    vwv_app._save_dirty = true
}

// ** record operations

RecordOperation :: union {
    RecordOp_AddChild,
    RecordOp_RemoveChild,
}

RecordOp_AddChild :: struct {
    parent : ^VwvRecord,
    edit : bool,
}
RecordOp_RemoveChild :: struct {
    record : ^VwvRecord,
}

push_record_operations :: proc(op: RecordOperation) {
    append(&vwv_app.record_operations, op)
}
clear_record_operations :: proc() {
    clear(&vwv_app.record_operations)
}

flush_record_operations :: proc() {
    operations := vwv_app.record_operations[:]
    for o in operations {
        if vwv_app.state == .Edit {
            vwv_state_exit_edit()
        }
        switch op in o {
        case RecordOp_AddChild:
            new_record := record_add_child(op.parent)
            vwv_state_enter_edit(new_record)
        case RecordOp_RemoveChild:
            if op.record.parent != nil do record_remove_record(op.record)
        }
    }
    clear_record_operations()
}