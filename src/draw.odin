package main


import "core:log"
import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/render"
import "vui"

// rect: xy: min, zw: size

theme : Theme = {
    font_size = 32,
    line_height = 40,
    line_margin = 4,
    line_padding = 8,
    indent_width = 18,
    border_width = 2,

    card_open = {
        normal = {200, 200, 200, 255},
        active = {255, 255, 255, 255},
        text_normal = {20,20,20, 255},
        text_active = {0,0,0, 255},
    },
    card_done = {
        normal = {20, 200, 20, 255},
        active = {20, 255, 20, 255},
        text_normal = {20,20,20, 255},
        text_active = {0,0,0, 255},
    },
    card_closed = {
        normal = {80, 50, 55, 128},
        active = {90, 55, 60, 128},
        text_normal = {100, 95, 90, 200},
        text_active = {110, 100,95, 200},
    },
}

Theme :: struct {
    font_size : f32,
    line_height : f32,
    line_margin : f32,
    line_padding : f32,
    indent_width : f32,
    border_width : f32,

    // ** colors
    card_open, card_closed, card_done : ThemeCardColor,
}

ThemeCardColor :: struct {
    normal, active, text_normal, text_active : dd.Color32
}