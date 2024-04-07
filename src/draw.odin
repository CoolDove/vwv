package main


import "core:log"
import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/render"
import "vui"

// rect: xy: min, zw: size

theme : Theme = {
    line_height = 40,
    line_padding = 8,
    indent_width = 12,
    border_width = 2,

    node_background = {233,233,233, 255},
    node_text  = {5,5,5, 255},
    node_border = {10,10,10,255},
}

vwv_draw_record :: proc(r: ^VwvRecord, rect : ^dd.Rect, depth :f32= 0) {
    using theme
    indent := indent_width*depth
    corner :dd.Vec2= {rect.x+indent, rect.y}
    size :dd.Vec2= {rect.w-indent, line_height}

    if vui.button(&vuictx, vui.get_id_string(r.line), r.line, {corner.x, corner.y, size.x, size.y}) {
        log.debugf("record: {}", r.line)
    }
    
    rect_grow_y(rect, line_height + line_padding)

    for &c, i in r.children {
        vwv_draw_record(&c, rect, depth + 1)
    }
}

rect_grow_y :: proc(rect: ^dd.Rect, y: f32) {
    rect.y += y
    rect.h -= y
}

Theme :: struct {
    line_height : f32,
    line_padding : f32,
    indent_width : f32,
    border_width : f32,

    // ** colors
    node_background : dd.Color32,
    node_text : dd.Color32,
    node_border : dd.Color32,
}