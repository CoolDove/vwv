package main

import "core:log"
import sdl "vendor:sdl2"
import dd "dude/dude/core"
import "dude/dude/render"
import "dude/dude/input"
import "vui"


vuictx : vui.VuiContext
root : VwvRecord

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

    vui.init(&vuictx, &pass_main, render.system().font_unifont)
}

vwv_release :: proc() {
    vui.release(&vuictx)
    vwv_record_release(&root)
}

vwv_update :: proc() {
    viewport := dd.app.window.size
    rect :dd.Rect= {20,20, cast(f32)viewport.x-40, cast(f32)viewport.y-40}

    if input.get_key_down(.A) {
        log.debugf("A down")
    }

    vwv_draw_record(&root, &rect)
}

vwv_window_handler :: proc(using wnd: ^dd.Window, event:sdl.Event) {
    if event.window.event == .RESIZED {
        dd.dispatch_update()
    }
    if input.get_input_handle_result() != .None {
        dd.dispatch_update()
    }
}