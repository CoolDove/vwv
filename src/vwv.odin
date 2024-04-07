package main

import "core:strings"
import "core:log"
import sdl "vendor:sdl2"
import dd "dude/dude/core"
import "dude/dude/render"
import "dude/dude/imdraw"
import "dude/dude/input"
import "vui"

vwv_app : VwvApp
vuictx : vui.VuiContext
root : VwvRecord

VwvApp :: struct {
    view_offset_y : f32,
    state : AppState,

    editting_record : ^VwvRecord,
    editting_point : dd.Vec2,
    // input_builder : strings.Builder,
}

AppState :: enum {
    Normal, Edit
}

VwvRecord :: struct {
    line, detail : strings.Builder,
    info : VwvRecordInfo,
    children : [dynamic]VwvRecord,
}

VwvRecordInfo :: struct {
    tag : u32,
    state : VwvRecordState,
}
VwvRecordState :: enum {
    Open, Close, Done,
}

vwv_record_release :: proc(r: ^VwvRecord) {
    for &c in r.children {
        vwv_record_release(&c)
    }
    delete(r.children)
    strings.builder_destroy(&r.line)
    strings.builder_destroy(&r.detail)
}

vwv_init :: proc() {
    // manually init root node
    strings.builder_init(&root.line)
    strings.builder_init(&root.detail)
    root.children = make([dynamic]VwvRecord)
    
    record_set_line(&root, "vwv")

    ra := record_add_child(&root)
    ra0 := record_add_child(ra)
    ra1 := record_add_child(ra)

    rb := record_add_child(&root)
    rb0 := record_add_child(&root)

    rc := record_add_child(&root)
    rd := record_add_child(&root)

    record_set_line(ra, "Hello, world.")
    record_set_line(ra0, "Dove")
    record_set_line(ra1, "Jet")

    record_set_line(rb, "Lily")
    record_set_line(rb0, "Spike")

    record_set_line(rc, "Zero")
    record_set_line(rd, "巴拉巴拉")

    vui.init(&vuictx, &pass_main, render.system().font_unifont)
}

record_add_child :: proc(parent: ^VwvRecord) -> ^VwvRecord {
    append(&parent.children, VwvRecord{})
    child := &(parent.children[len(parent.children)-1])
    strings.builder_init(&child.line)
    strings.builder_init(&child.detail)
    child.children = make([dynamic]VwvRecord)
    return child
}

record_set_line :: proc(record: ^VwvRecord, line: string) {
    strings.builder_reset(&record.line)
    strings.write_string(&record.line, line)
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

    vwv_record_update(&root, &rect)

    if vwv_app.state == .Edit {
        if str, ok := input.get_textinput_charactors_temp(); ok {
            strings.write_string(&vwv_app.editting_record.line, str)
            dd.dispatch_update()
        }
        if input.get_key_down(.ESCAPE) {
            vwv_app.state = .Normal
            vwv_app.editting_record = nil
            dd.dispatch_update()
        }
    }

    // ** debug draw
    imdraw.quad(&pass_main, vwv_app.editting_point, {4,4}, {255,0,0,255}, order=99999999)
    
}

vwv_record_update :: proc(r: ^VwvRecord, rect: ^dd.Rect, depth :f32= 0) {
    using theme
    indent := indent_width*depth
    corner :dd.Vec2= {rect.x+indent, rect.y}
    size :dd.Vec2= {rect.w-indent, line_height}

    str := strings.to_string(r.line)
    editting := vwv_app.state == .Edit && vwv_app.editting_record == r

    record_rect :dd.Rect= {corner.x, corner.y, size.x, size.y}
    measure : dd.Vec2
    if record_card(&vuictx, vui.get_id_string(str), r, record_rect, editting, &measure) {
        if vwv_app.state == .Normal {
            input.textinput_begin()
            vwv_app.state = .Edit
            vwv_app.editting_record = r
            editting = true
            dd.dispatch_update()
        }
    }
    if editting {
        vwv_app.editting_point = corner + {measure.x, size.y - 16}
        input.textinput_set_imm_composition_pos(vwv_app.editting_point)
    }
    
    rect_grow_y(rect, line_height + line_padding)

    for &c, i in r.children {
        vwv_record_update(&c, rect, depth + 1)
    }
}

rect_grow_y :: proc(rect: ^dd.Rect, y: f32) {
    rect.y += y
    rect.h -= y
}

vwv_window_handler :: proc(using wnd: ^dd.Window, event:sdl.Event) {
    if event.window.event == .RESIZED {
        dd.dispatch_update()
    }
    if input.get_input_handle_result() != .None {
        dd.dispatch_update()
    }
}