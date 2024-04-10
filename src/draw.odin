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
        normal = {180, 200, 140, 255},
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
	text_record_open = {
		normal = {10,10,10, 255},
		hilight = {4,20,4, 255},
		dimmed = {10,10,10, 128},
	},
	text_record_closed = {
		normal = {20,10,12, 128},
		hilight = {20,15,16, 128},
		dimmed = {20,10,12, 64},
	},
	text_record_done = {
		normal = {10,50,10, 255},
		hilight = {4,60,4, 255},
		dimmed = {10,50,10, 128},
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
	text_record_open, text_record_closed, text_record_done : TextTheme,
}

ThemeCardColor :: struct {
    normal, active, text_normal, text_active : dd.Color32
}

TextTheme :: struct {
	normal, hilight, dimmed : Color32,
}

_text_theme_default := TextTheme {
	normal = {10,10,10, 255},
	hilight = {4,20,4, 255},
	dimmed = {10,10,10, 128},
}