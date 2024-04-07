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

    card_normal = {200, 200, 200, 255},
    card_hover = {222, 222, 222, 255},
    card_active = {255, 255, 255, 255},
    
    
}

Theme :: struct {
    line_height : f32,
    line_padding : f32,
    indent_width : f32,
    border_width : f32,

    // ** colors
    node_background,
    node_text,
    node_border : dd.Color32,


    card_normal,
    card_hover,
    card_active : dd.Color32,
    
}