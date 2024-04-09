package main

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
    view_offset_y : f32,
    state : AppState,

    pin : bool,

    // ** operations
    record_operations : [dynamic]RecordOperation,

    // ** edit
    text_edit : TextEdit,
    editting_record : ^VwvRecord,
    editting_point : dd.Vec2,
}

AppState :: enum {
    Normal, Edit
}

VwvRecord :: struct {
    id : u64,
    line, detail : GapBuffer,
    info : VwvRecordInfo,
    children : [dynamic]VwvRecord,
    parent : ^VwvRecord,
}

VwvRecordInfo :: struct {
    tag : u32,
    state : VwvRecordState,
    progress : [3]f32, // Used by a parent node, indicates the portion of: open, done, closed.
}
VwvRecordState :: enum {
    Open, Done, Closed,
}

vwv_init :: proc() {
    when ODIN_DEBUG {
        DEBUG_VWV = true
    }
    
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

        rb := record_add_child(&root)

        record_set_line(ra, "Hello, welcome to use VWV.")
            record_set_line(ra0, "Press the '+' button to add a record.")
            record_set_line(ra1, "Press LCtrl+LMB to remove a record.")
            record_set_line(ra2, "Press RMB to change the state.")
        record_set_line(rb, "Enjoy yourself.")
        record_set_state(rb, .Done)
    }
    
    vwv_app.record_operations = make([dynamic]RecordOperation)

    vui.init(&vuictx, &pass_main, render.system().default_font)
}

vwv_release :: proc() {
    vui.release(&vuictx)
    delete(vwv_app.record_operations)
    record_release_recursively(&root)
}

vwv_update :: proc() {
    if wheel := input.get_mouse_wheel(); wheel.y != 0 {
        vwv_app.view_offset_y += wheel.y * 10.0
    }

    viewport := dd.app.window.size
    app_rect :dd.Rect= {0,0, cast(f32)viewport.x, cast(f32)viewport.y}
    
    
    rect :dd.Rect= {20,20, cast(f32)viewport.x-40, cast(f32)viewport.y-40}
    rect.y += vwv_app.view_offset_y

    if vwv_app.state == .Edit {
        ed := &vwv_app.text_edit
        if str, ok := input.get_textinput_charactors_temp(); ok {
            textedit_insert(ed, str)
            dd.dispatch_update()
        }
        if input.get_key_down(.ESCAPE) || input.get_key_down(.RETURN) {
            vwv_state_exit_edit()
            dd.dispatch_update()
        }

        if input.get_key_repeat(.LEFT) {
            to :int= -1
            if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
                to = textedit_find_previous_word_head(ed, ed.selection.x)
            } else {
                _, to = textedit_find_previous_rune(ed, ed.selection.x)
            }
            if to > -1 do textedit_move_to(ed, to)
        } else if input.get_key_repeat(.RIGHT) {
            to :int= -1
            if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
                to = textedit_find_next_word_head(ed, ed.selection.x)
            } else {
                _, to = textedit_find_next_rune(ed, ed.selection.x)
            }
            if to > -1 do textedit_move_to(ed, to)
        }
        
        if input.get_key_repeat(.BACKSPACE) {
            to :int= -1
            if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
                to = textedit_find_previous_word_head(ed, ed.selection.x)
            } else {
                _, to = textedit_find_previous_rune(ed, ed.selection.x)
            }
            if to > -1 do textedit_remove(ed, to-ed.selection.x)
        } else if input.get_key_repeat(.DELETE) {
            to :int= -1
            if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
                to = textedit_find_next_word_head(ed, ed.selection.x)
            } else {
                _, to = textedit_find_next_rune(ed, ed.selection.x)
            }
            if to > -1 do textedit_remove(ed, to-ed.selection.x)
        }

    } else if vwv_app.state == .Normal {
        if input.get_key_down(.S) && input.get_key(.LCTRL) {
            save()
        }
    }

    if input.get_key_repeat(.F1) {
        DEBUG_VWV = !DEBUG_VWV
    }

    vwv_record_update(&root, &rect)

    {// ** status bar
        sbr := rect_split_top(app_rect, 42)
        imdraw.quad(&pass_main, {sbr.x, sbr.y}, {sbr.w, sbr.h}, {90, 100, 75, 100})
        checkbutton_rect := rect_padding(rect_split_right(sbr, 42), 4,4,4,4)
        new_pin_value := vcontrol_checkbutton(&vuictx, VUID_BUTTON_PIN, checkbutton_rect, vwv_app.pin)
        if new_pin_value != vwv_app.pin {
            sdl.SetWindowAlwaysOnTop(dd.app.window.window, auto_cast new_pin_value)
            vwv_app.pin = new_pin_value
            dd.dispatch_update()
        }
    }
    
    flush_record_operations()

    if DEBUG_VWV {
        // ** debug draw
        debug_point :: proc(point: dd.Vec2, col:=dd.Color32{255,0,0,255}, size:f32=2, order:i32=99999999) {
            imdraw.quad(&pass_main, point, {size,size}, {255,0,0,255}, order=99999999)
        }

        debug_point(vwv_app.editting_point)
    }
}

vwv_record_update :: proc(r: ^VwvRecord, rect: ^dd.Rect, depth :f32= 0) {
    using theme
    indent := indent_width*depth
    corner := dd.Vec2{rect.x+indent, rect.y}// left-top
    size := dd.Vec2{rect.w-indent, line_height}
    corner_rb := corner+size// right-bottom

    editting := vwv_app.state == .Edit && vwv_app.editting_record == r

    record_rect :dd.Rect= {corner.x, corner.y, size.x, size.y}
    measure : dd.Vec2
    if result := vcontrol_record_card(&vuictx, r, record_rect, &measure); result != .None {
        if vwv_app.state == .Edit {
            if !editting {
                vwv_state_exit_edit()
                dd.dispatch_update()
            }
        }
        if vwv_app.state == .Normal {
            if result == .Left {// left click to edit
                if input.get_key(.LCTRL) {
                    push_record_operations(RecordOp_RemoveChild{r})
                } else {
                    vwv_state_enter_edit(r)
                    editting = true
                    dd.dispatch_update()
                }
            } else if result == .Right {// right click to change state
                record_set_state(r, dd.enum_step(VwvRecordState, r.info.state))
                dd.dispatch_update()
            }
        }
    }
    if editting {
        vwv_app.editting_point = corner + {measure.x, line_margin + font_size}
        input.textinput_set_imm_composition_pos(vwv_app.editting_point)
    }
    
    height_step := line_height + line_padding
    rect.y += height_step
    rect.h -= height_step

    if vwv_app.state == .Normal {
        width, height :f32= 14, 14
        padding :f32= 2
        rect := dd.Rect{corner.x - width - padding, corner.y + size.y - height, width, height}
        if result := vcontrol_button_add_record(&vuictx, r, rect); result != .None {
            if result == .Left {
                push_record_operations(RecordOp_AddChild{r, true})
            }
        }
    }

    for &c, i in r.children {
        vwv_record_update(&c, rect, depth + 1)
    }
}

vwv_state_exit_edit :: proc() {
    assert(vwv_app.state == .Edit, "Should call this when in Edit mode.")
    vwv_app.state = .Normal
    vwv_app.editting_record = nil
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