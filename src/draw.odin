package main


import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/render"

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

vwv_draw_record :: proc(r: ^VwvRecord, rect : ^dd.Vec4, depth :f32= 0) {
    using theme
    indent := indent_width*depth
    corner :dd.Vec2= {rect.x+indent, rect.y}
    size :dd.Vec2= {rect.z-indent, line_height}
    imdraw.quad(&pass_main, corner, size, node_border)
    imdraw.quad(&pass_main, corner+{border_width, border_width}, size-2*{border_width,border_width}, node_background)
    imdraw.text(&pass_main, render.system().font_unifont, r.line, corner+{5,line_height-8}, line_height-5, dd.col_u2f(node_text))
    rect_grow_y(rect, line_height + line_padding)

    for &c, i in r.children {
        vwv_draw_record(&c, rect, depth + 1)
    }
}

rect_grow_y :: proc(rect: ^dd.Vec4, y: f32) {
    rect.y += y
    rect.w -= y
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