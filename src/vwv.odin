package main

import "core:log"
import sdl "vendor:sdl2"
import "./dude"

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
}

vwv_release :: proc() {
    vwv_record_release(&root)
}

vwv_update :: proc() {
    viewport := dude.app.window.size
    rect :dude.Vec4= {20,20, cast(f32)viewport.x-40, cast(f32)viewport.y-40}
    vwv_draw_record(&root, &rect)
    log.debugf("update")
}

vwv_window_handler :: proc(using wnd:^dude.Window, event:sdl.Event) {
    if event.window.event == .RESIZED {
        dude.manually_update()
    }

    // if draw {
    //     using dude
    //     viewport := app.window.size
    //     pass_main.viewport = Vec4i{0,0, viewport.x, viewport.y}
    //     pass_main.camera.viewport = vec_i2f(viewport)

    //     // viewport := dude.app.window.size
    //     rect :dude.Vec4= {20,20, cast(f32)viewport.x-40, cast(f32)viewport.y-40}
    //     vwv_draw_record(&root, &rect)
    //     log.debugf("draw")

    //     sdl.GL_SwapWindow(dude.app.window.window)
    // }
}