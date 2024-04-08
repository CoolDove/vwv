package main

import "core:time"
import "core:os"
import "core:fmt"
import "core:unicode/utf8"
import "core:log"
import "core:reflect"
import "core:strings"
import "core:math/linalg"
import "core:math"
import "core:mem"

import sdl "vendor:sdl2"
import ma "vendor:miniaudio"

import "dude/dude"
import dd "dude/dude/core"
import "dude/dude/dpac"
import "dude/dude/dgl"
import "dude/dude/input"
import "dude/dude/render"
import mui "dude/dude/microui"
import "dude/dude/imdraw"

REPAC_ASSETS :: false

pass_main : dude.RenderPass

TheTool :: struct {
    mesh_grid : dgl.Mesh,
    _frame_id : u64,
}

@(private="file")
the_tool : TheTool

main :: proc() {
    tracking_allocator : mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    reset_tracking_allocator :: proc(a: ^mem.Tracking_Allocator) -> bool {
        fmt.printf("Memory leak report:\n")
        leaks := false
        for key, value in a.allocation_map {
            fmt.printf("%v: Leaked %v bytes\n", value.location, value.size)
            leaks = true
        }
        mem.tracking_allocator_clear(a)
        return leaks
    }
    defer reset_tracking_allocator(&tracking_allocator)
    
    
    config : dd.DudeConfig
    config.callbacks = { update, init, release, on_mui }
    config.title = "vwv - simple tool for simple soul"
    config.position = {sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED}
    config.width = 400
    config.height = 860
    config.resizable = true
    config.custom_handler = vwv_window_handler
    config.event_driven = true
    config.event_driven_tick_delay_time_ms = 16.67
    config.default_font_data = #load("res/deng.ttf")
    
    dd.dude_main(&config)
}

@(private="file")
update :: proc(game: ^dd.Game, delta: f32) {
    using dd, the_tool
    _frame_id += 1

    viewport := app.window.size
    pass_main.viewport = Vec4i{0,0, viewport.x, viewport.y}
    pass_main.camera.viewport = vec_i2f(viewport)

    vwv_update()

    dmp : Vec2 // debug_msg_pos
    screen_debug_msg :: proc(dmp: ^dd.Vec2, msg: string, intent:i32=0) {
        fsize : f32 = 32
        imdraw.text(&pass_main, render.system().default_font, msg, dmp^ + {0, fsize}, fsize, color={0,1,0,1}, order=999999)
        dmp.y += fsize + 10
    }

    screen_debug_msg(&dmp, fmt.tprintf("FrameId: {}", the_tool._frame_id))
}



@(private="file")
init :: proc(game: ^dude.Game) {
    using the_tool
    append(&game.render_pass, &pass_main)

    using dd
    // Pass initialization
    wndx, wndy := app.window.size.x, app.window.size.y
    render.pass_init(&pass_main, {0,0, wndx, wndy})
    pass_main.clear.color = {.2,.2,.2, 1}
    pass_main.clear.mask = {.Color,.Depth,.Stencil}
    blend := &pass_main.blend.(dgl.GlStateBlendSimp)
    blend.enable = true

    vwv_init()
}

@(private="file")
release :: proc(game: ^dd.Game) {
    vwv_release()
    using dd, the_tool
	dgl.mesh_delete(&mesh_grid)

    render.pass_release(&pass_main)
}

@(private="file")
on_mui :: proc(ctx: ^mui.Context) {
}

@(private="file")
vwv_window_handler :: proc(using wnd: ^dd.Window, event:sdl.Event) {
    if event.window.event == .RESIZED {
        dd.dispatch_update()
    }
    if input.get_input_handle_result() != .None {
        dd.dispatch_update()
    }
}