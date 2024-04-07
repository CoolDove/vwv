package main

import "core:strings"
import "core:log"
import sdl "vendor:sdl2"
import dd "dude/dude/core"
import "dude/dude/render"
import "dude/dude/input"
import "vui"

vwv_app : VwvApp
vuictx : vui.VuiContext
root : VwvRecord

VwvApp :: struct {
    view_offset_y : f32,
    state : AppState,

    editting_record : ^VwvRecord,
    input_builder : strings.Builder,
}

AppState :: enum {
    Normal, Edit
}

VwvRecord :: struct {
    line, detail : string,
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
}


vwv_init :: proc() {
    root.line = "vwv"
    append(&root.children, VwvRecord{
        line = "hello, world",
    })
        append(&root.children[0].children, 
            VwvRecord{ line = "dddd" },
            VwvRecord{ line = "sss" },
            VwvRecord{ line = "aa" },
        )
    append(&root.children, VwvRecord{
        line = "second",
    })
        append(&root.children[1].children, 
            VwvRecord{ line = "jjj" },
            VwvRecord{ line = "kk" },
        )
            append(&root.children[1].children[1].children,
                VwvRecord{ line = "zz" },
                VwvRecord{ line = "x" },
            )

    strings.builder_init(&vwv_app.input_builder)
    vui.init(&vuictx, &pass_main, render.system().font_unifont)
}

vwv_release :: proc() {
    strings.builder_destroy(&vwv_app.input_builder)
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
            strings.write_string(&vwv_app.input_builder, str)
        }
        if input.get_key_down(.ESCAPE) {
            vwv_app.editting_record.line = strings.to_string(vwv_app.input_builder)
            vwv_app.state = .Normal
            vwv_app.editting_record = nil
        }
    }
}

vwv_record_update :: proc(r: ^VwvRecord, rect: ^dd.Rect, depth :f32= 0) {
    using theme
    indent := indent_width*depth
    corner :dd.Vec2= {rect.x+indent, rect.y}
    size :dd.Vec2= {rect.w-indent, line_height}

    str := r.line
    if vwv_app.state == .Edit && r == vwv_app.editting_record {
        str = strings.to_string(vwv_app.input_builder)
    }
    editting := vwv_app.state == .Edit && vwv_app.editting_record == r

    record_rect :dd.Rect= {corner.x, corner.y, size.x, size.y}
    if record_card(&vuictx, vui.get_id_string(r.line), r, record_rect, editting) {
        if vwv_app.state == .Normal {
            strings.builder_reset(&vwv_app.input_builder)
            strings.write_string(&vwv_app.input_builder, r.line)
            input.textinput_begin()
            input.textinput_set_rect(record_rect)
            vwv_app.state = .Edit
            vwv_app.editting_record = r
            dd.dispatch_update()
        }
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