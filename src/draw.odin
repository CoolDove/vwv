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