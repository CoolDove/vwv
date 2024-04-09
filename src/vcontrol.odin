package main

import "core:log"
import "core:strings"
import "core:fmt"

import "vui"
import "dude/dude"
import dd "dude/dude/core"
import "dude/dude/imdraw"
import "dude/dude/input"
import "dude/dude/render"


ButtonResult :: enum {
    None, Left, Right,
}

vcontrol_record_card :: proc(using ctx: ^vui.VuiContext, record: ^VwvRecord, rect: dd.Rect, 
                             measure_line:^dd.Vec2=nil/*output*/, measure_editting:^dd.Vec2=nil/*output*/) -> ButtonResult
{
    using vui
    id := VUID_BY_RECORD(record)
    inrect := _is_in_rect(input.get_mouse_position(), rect)
    result := _event_handler_button(ctx, id, inrect)

    using theme
    colors : ^ThemeCardColor

    switch record.info.state {
    case .Open:
        colors = &theme.card_open
    case .Closed:
        colors = &theme.card_closed
    case .Done:
        colors = &theme.card_done
    }
    
    col_bg := colors.normal
    col_text := colors.text_normal
    if active == id {
        col_bg = colors.active
        col_text = colors.text_active
    }

    editting := vwv_app.state == .Edit && vwv_app.editting_record == record
    
    if editting {
        col_bg = colors.active
        col_text = colors.text_active
    }

    corner :dd.Vec2= {rect.x,rect.y}// corner left-top
    corner_rt :dd.Vec2= {rect.x-rect.w,rect.y}// corner right-top
    size :dd.Vec2= {rect.w, rect.h}

    imdraw.quad(&pass_main, corner, size, col_bg, order = LAYER_MAIN)

    // ** draw the state or progress
    if record.info.state == .Closed {
        imdraw.quad(&pass_main, corner+{2,0.5*size.y-1}, {size.x-4, 2}, {10,10,5,128}, order=42003)
    }

    if len(record.children) != 0 {// ** draw the progress bar
        padding_horizontal :f32= 16
        pgb_length_total :f32= size.x - padding_horizontal
        pgb_thickness :f32= 9
        if pgb_length_total > 0 {
            x := corner.x + 0.5 * padding_horizontal
            y := corner.y + size.y - 12
            progress := record.info.progress
            done, open, closed := progress[1], progress[0], progress[2]

            progress_message := fmt.tprintf("%.2f%%", ((done / (1-closed)) * 100) if closed != 1 else 100)
            msg_measure := dude.mesher_text_measure(font, progress_message, font_size * 0.25)
            imdraw.text(&pass_main, font, progress_message, {x + pgb_length_total - msg_measure.x, y + pgb_thickness-2}, font_size * 0.25, {0,0,0, 0.86}, order=42002)

            // ** progress bar background
            imdraw.quad(&pass_main, {x,y+pgb_thickness}, {pgb_length_total, 1}, {10,10,20, 255}, order=42001)

            // ** progress bar
            alpha :u8= 128
            imdraw.quad(&pass_main, {x,y}, {pgb_length_total*done, pgb_thickness}, {20,180,20, alpha}, order=42001)
            x += pgb_length_total*done
            imdraw.quad(&pass_main, {x,y}, {pgb_length_total*open, pgb_thickness}, {128,128,128, alpha}, order=42001)
            x += pgb_length_total*open
            imdraw.quad(&pass_main, {x,y}, {pgb_length_total*closed, pgb_thickness}, {180,30,15, alpha}, order=42001)
        }
    }
    return result
}

vcontrol_button_add_record :: proc(using ctx: ^vui.VuiContext, record: ^VwvRecord, rect: dd.Rect) -> ButtonResult {
    using vui
    id := VUID_BY_RECORD(record, RECORD_ITEM_BUTTON_ADD_RECORD)
    inrect := _is_in_rect(input.get_mouse_position(), rect)
    result := _event_handler_button(ctx, id, inrect)

    using theme
    col :dd.Color32= {65,65,65, 255}
    if hot == id do col = {80,80,80, 255}
    if active == id do col = {95,95,95, 255}
    imdraw.quad(&pass_main, {rect.x,rect.y+0.5*rect.h-2}, {rect.w,4}, col, order=LAYER_MAIN + 1)
    imdraw.quad(&pass_main, {rect.x+0.5*rect.w-2,rect.y}, {4,rect.h}, col, order=LAYER_MAIN + 1)
    return result
}

vcontrol_checkbutton :: proc(using ctx: ^vui.VuiContext, id: vui.ID, rect: dd.Rect, value: bool) -> bool {
    using vui
    inrect := _is_in_rect(input.get_mouse_position(), rect)
    result := _event_handler_button(ctx, id, inrect)

    if value {
        imdraw.quad(&pass_main, {rect.x,rect.y}, {rect.w,rect.h}, {0,255,0,255}, order=LAYER_MAIN + 1)
    } else {
        imdraw.quad(&pass_main, {rect.x,rect.y}, {rect.w,rect.h}, {29,29,28, 255}, order=LAYER_MAIN + 1)
    }
    return !value if result == .Left else value
}

// If `edit` is nil, this control will only display the text. You pass in a edit, the control will
//  work.
//  Return: If you pressed outside or press `ESC` or `RETURN` to exit the edit.
vcontrol_edittable_textline :: proc(using ctx: ^vui.VuiContext, id: vui.ID, rect: dd.Rect, buffer: ^GapBuffer, edit:^TextEdit=nil) -> bool {
    using vui

    inrect := _is_in_rect(input.get_mouse_position(), rect)
    result := false
    rcorner, rsize := rect_position(rect), rect_size(rect)
    editting := edit != nil
    if editting {// Manually enable the text editting.
        if edit.buffer != buffer do textedit_begin(edit, buffer, gapbuffer_len(buffer))

        active = id
        hot = id if inrect else 0
        
        if  (!inrect && (input.get_mouse_button_up(.Left) || input.get_mouse_button_down(.Right))) || // Click outside
            (input.get_key_down(.ESCAPE) || input.get_key_down(.RETURN)) // Press ESC or RETURN
        {
            result = true
            active = 0
        }

        // ** text editting logic
        ed := edit
        if str, ok := input.get_textinput_charactors_temp(); ok {
            textedit_insert(ed, str)
            dd.dispatch_update()
        }

        if input.get_key_repeat(.LEFT) {
            to :int= -1
            if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
                to = textedit_find_previous_word_head(ed, ed.selection.x)
            } else {
                _, to = textedit_find_previous_rune(ed, ed.selection.x)
            }
            if to > -1 do textedit_move_to(ed, to)
        } else if input.get_key_repeat(.RIGHT) {
            to :int= -1
            if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
                to = textedit_find_next_word_head(ed, ed.selection.x)
            } else {
                _, to = textedit_find_next_rune(ed, ed.selection.x)
            }
            if to > -1 do textedit_move_to(ed, to)
        }
        
        if input.get_key_repeat(.BACKSPACE) {
            to :int= -1
            if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
                to = textedit_find_previous_word_head(ed, ed.selection.x)
            } else {
                _, to = textedit_find_previous_rune(ed, ed.selection.x)
            }
            if to > -1 do textedit_remove(ed, to-ed.selection.x)
        } else if input.get_key_repeat(.DELETE) {
            to :int= -1
            if input.get_key(.LCTRL) || input.get_key(.RCTRL) {
                to = textedit_find_next_word_head(ed, ed.selection.x)
            } else {
                _, to = textedit_find_next_rune(ed, ed.selection.x)
            }
            if to > -1 do textedit_remove(ed, to-ed.selection.x)
        }
    }
    using theme
    col_text := dd.Color32{10,10,10, 255}

    draw_text_ptr : f32
    DrawText :: struct {
        ptr : f32,
        font : dude.DynamicFont,
        font_size : f32,
        offset_y : f32,
        rect : dd.Rect,
    }

    dt := DrawText{ 0, font, font_size, font_size+line_margin, rect }

    draw_text :: proc(d: ^DrawText, str: string, col: dd.Color32) {
        corner := rect_position(d.rect)
        next :dd.Vec2
        mesr := dude.mesher_text_measure(d.font, str, d.font_size, out_next_pos =&next)
        imdraw.text(&pass_main, d.font, str, corner+{d.ptr, d.offset_y}, d.font_size, dd.col_u2f(col), order = 42002)
        d.ptr += next.x
    }

    text_line := gapbuffer_get_string(buffer); defer delete(text_line)
    if editting {
        if input.get_textinput_editting_text() != "" {
            draw_text(&dt, text_line[:edit.selection.x], col_text)
            imdraw.quad(&pass_main, rcorner+{dt.ptr, 1}, {2,rsize.y-2}, col_text, order = 42002) // draw the cursor
            col_text_dimmed := col_text; col_text_dimmed.a = 128
            draw_text(&dt, input.get_textinput_editting_text(), col_text_dimmed)
            draw_text(&dt, text_line[edit.selection.x:], col_text)
        } else {
            next :dd.Vec2
            mesr := dude.mesher_text_measure(font, text_line[:edit.selection.x], font_size, out_next_pos =&next)
            draw_text(&dt, text_line, col_text)
            imdraw.quad(&pass_main, rcorner+{next.x, 1}, {2,rsize.y-2}, col_text, order = 42002) // draw the cursor
        }
    } else {
        draw_text(&dt, text_line, col_text)
    }
    
    return result
}


@(private="file")
_event_handler_button :: proc(using ctx: ^vui.VuiContext, id: vui.ID, inrect: bool) -> ButtonResult {
    using vui
    result := ButtonResult.None
    if active == id {
        if input.get_mouse_button_up(.Left) {
            active = 0
            if inrect {
                result = .Left
            }
        } else if input.get_mouse_button_up(.Right) {
            active = 0
            if inrect {
                result = .Right
            }
        }
    } else {
        if hot == id {
            if inrect {
                if input.get_mouse_button_down(.Left) || input.get_mouse_button_down(.Right) {
                    active = id
                }
            } else {
                if !inrect do hot = 0
            }
        } else {
            if inrect && active == 0 {
                hot = id
            }
        }
    }
    return result
}