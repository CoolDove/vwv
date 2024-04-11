package main


import dd "dude/dude/core"
import "vui"



// ** Layers
LAYER_MAIN :i32: 420000

LAYER_RECORD_BASE :: LAYER_MAIN + 100
LAYER_RECORD_CONTENT :: LAYER_RECORD_BASE + 100

LAYER_FLOATING_PANEL :i32: 680000

LAYER_STATUS_BAR_BASE :: LAYER_FLOATING_PANEL + 1000
LAYER_STATUS_BAR_ITEM :: LAYER_STATUS_BAR_BASE + 100


// ** VUID

VUID_RECORD_BASE :vui.ID: 420000
// Each record has 256 id for its related vui items.
VUID_BY_RECORD :: proc(r: ^VwvRecord, elem:u8= 0) -> vui.ID {
    return VUID_RECORD_BASE + cast(vui.ID)(r.id * 256) + cast(vui.ID)elem
}
RECORD_ITEM_BUTTON_ADD_RECORD :u8: 4
RECORD_ITEM_BUTTON_FOCUS :u8: 8
RECORD_ITEM_LINE_TEXTBOX :u8: 64


VUID_BUTTON_PIN :vui.ID: 48000+1


// ** Basic Types

Vec2 :: dd.Vec2
Vec3 :: dd.Vec3
Vec4 :: dd.Vec4

Vec2i :: dd.Vec2i
Vec3i :: dd.Vec3i
Vec4i :: dd.Vec4i

Rect :: dd.Rect

Color :: dd.Color
Color32 :: dd.Color32