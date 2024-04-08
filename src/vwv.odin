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

VwvApp :: struct {
    view_offset_y : f32,
    state : AppState,

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

vwv_record_release :: proc(r: ^VwvRecord) {
    for &c in r.children {
        vwv_record_release(&c)
    }
    delete(r.children)
    gapbuffer_release(&r.line)
    gapbuffer_release(&r.detail)
    // strings.builder_destroy(&r.line)
    // strings.builder_destroy(&r.detail)
}

vwv_init :: proc() {
    // manually init root node
    gapbuffer_init(&root.line, 32)
    gapbuffer_init(&root.detail, 32)
    root.children = make([dynamic]VwvRecord)
    
    record_set_line(&root, "vwv")

    ra := record_add_child(&root)
    ra0 := record_add_child(ra)
    ra1 := record_add_child(ra)

    rb := record_add_child(&root)
    rb0 := record_add_child(rb)
    rb1 := record_add_child(rb)
    rb2 := record_add_child(rb)

    rc := record_add_child(&root)
    rd := record_add_child(&root)

    record_set_line(ra, "Hello, world.")
    record_set_line(ra0, "Dove")
    record_set_line(ra1, "Jet")

    record_set_line(rb, "Lily")
    record_set_line(rb0, "Spike ")
    record_set_line(rb1, "Lilyyyy")
    record_set_line(rb2, "Spikyyy")

    record_set_line(rc, "Zero")
    record_set_line(rd, "巴拉巴拉")

    vui.init(&vuictx, &pass_main, render.system().default_font)
}

vwv_release :: proc() {
    vui.release(&vuictx)
    vwv_record_release(&root)
}

vwv_update :: proc() {
    if wheel := input.get_mouse_wheel(); wheel.y != 0 {
        vwv_app.view_offset_y += wheel.y * 10.0
    }

    viewport := dd.app.window.size
    rect :dd.Rect= {20,20, cast(f32)viewport.x-40, cast(f32)viewport.y-40}
    rect.y += vwv_app.view_offset_y

    if vwv_app.state == .Edit {
        ed := &vwv_app.text_edit
        if str, ok := input.get_textinput_charactors_temp(); ok {
            // strings.write_string(&vwv_app.editting_record.line, str)
            textedit_insert(ed, str)
            dd.dispatch_update()
        }
        if input.get_key_down(.ESCAPE) || input.get_key_down(.RETURN) {
            vwv_state_exit_edit()
            dd.dispatch_update()
        }

        if input.get_key_repeat(.LEFT) {
            to := textedit_find_previous_rune(ed, ed.selection.x)
            if to > -1 do textedit_move_to(ed, to)
        } else if input.get_key_repeat(.RIGHT) {
            to := textedit_find_next_rune(ed, ed.selection.x)
            if to > -1 do textedit_move_to(ed, to)
        }
        
        if input.get_key_repeat(.BACKSPACE) {
            to := textedit_find_previous_rune(ed, ed.selection.x)
            if to > -1 do textedit_remove(ed, to-ed.selection.x)
        } else if input.get_key_repeat(.DELETE) {
            to := textedit_find_next_rune(ed, ed.selection.x)
            if to > -1 do textedit_remove(ed, to-ed.selection.x)
        }
    }

    vwv_record_update(&root, &rect)

    // ** debug draw
    debug_point :: proc(point: dd.Vec2, col:=dd.Color32{255,0,0,255}, size:f32=2, order:i32=99999999) {
        imdraw.quad(&pass_main, point, {size,size}, {255,0,0,255}, order=99999999)
    }
    
    debug_point(vwv_app.editting_point)

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
                if vwv_app.state == .Normal {
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
                new_record := record_add_child(r)
                vwv_state_enter_edit(new_record)
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