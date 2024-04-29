package main

import "dude/dude/dgl"

ICON_TEXTURE : dgl.Texture


Icon :: distinct Rect

@(private="file")
_UNIT :f32: 1.0/4.0

ICON_ADD :Icon: {0,0,_UNIT,_UNIT}
ICON_FOCUS :Icon: {_UNIT,0,_UNIT,_UNIT}
ICON_PIN :Icon: {2*_UNIT,0,_UNIT,_UNIT}
ICON_WINDOW_BORDERED :Icon: {3*_UNIT,0,_UNIT,_UNIT}

ICON_TRIANGLE_DOWN :Icon: {0,_UNIT,_UNIT,_UNIT}
ICON_TRIANGLE_RIGHT :Icon: {_UNIT,_UNIT,_UNIT,_UNIT}
