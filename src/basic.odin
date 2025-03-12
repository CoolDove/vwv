package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:c"
import "core:log"

import "core:unicode/utf16"
import win32 "core:sys/windows"

// import sdl "vendor:sdl3"
import gl "vendor:OpenGL"
import "dgl"
// import "hotvalue"

OPENGL_VERSION_MAJOR :: 4
OPENGL_VERSION_MINOR :: 4

hwnd : win32.HWND

dc : win32.HDC

@(private="file")
_opengl_ready := false

window_init :: proc(title: string, width, height: int) {
	// instance = hInstance
	instance := win32.HINSTANCE(win32.GetModuleHandleW(nil))
	// 注册窗口类
	wndclass := win32.L("WindowClass")

	wc: win32.WNDCLASSW
	wc.lpfnWndProc = wndproc
	wc.lpszClassName = wndclass
	wc.hInstance = instance
	cursor := win32.LoadCursorA(nil, win32.IDC_ARROW)
	wc.hCursor = cursor
	win32.RegisterClassW(&wc)

	// 创建窗口
	hwnd = win32.CreateWindowExW(
		0, // dwExStyle
		wndclass, // lpClassName
		win32.utf8_to_wstring(title), // lpWindowName
		win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE, // dwStyle
		win32.CW_USEDEFAULT, // x
		win32.CW_USEDEFAULT, // y
		auto_cast width, // nWidth
		auto_cast height, // nHeight
		nil, // hWndParent
		nil, // hMenu
		instance, // hInstance
		nil, // lpParam
	)
	assert(hwnd != nil, "Failed to create window")

	// 显示窗口
	win32.ShowWindow(hwnd, win32.SW_SHOWDEFAULT)
	win32.UpdateWindow(hwnd)

	// OpenGL 初始化
	dc := win32.GetDC(hwnd)
	desiredPixelFormat := win32.PIXELFORMATDESCRIPTOR {
		nSize      = size_of(win32.PIXELFORMATDESCRIPTOR),
		nVersion   = 1,
		iPixelType = win32.PFD_TYPE_RGBA,
		dwFlags    = win32.PFD_SUPPORT_OPENGL | win32.PFD_DRAW_TO_WINDOW | win32.PFD_DOUBLEBUFFER,
		cRedBits   = 8,
		cGreenBits = 8,
		cBlueBits  = 8,
		cAlphaBits = 8,
		iLayerType = win32.PFD_MAIN_PLANE,
	}
	pixelFormatIndex := win32.ChoosePixelFormat(dc, &desiredPixelFormat)
	pixelFormat: win32.PIXELFORMATDESCRIPTOR
	win32.DescribePixelFormat(dc, pixelFormatIndex, size_of(win32.PIXELFORMATDESCRIPTOR), &pixelFormat)
	win32.SetPixelFormat(dc, pixelFormatIndex, &pixelFormat)

	if true {
		glRc := win32.wglCreateContext(dc)
		assert(bool(win32.wglMakeCurrent(dc, glRc)))

		wglCreateContextAttribsARB :win32.CreateContextAttribsARBType= nil
		wglSwapIntervalEXT :win32.SwapIntervalEXTType= nil

		wglCreateContextAttribsARB = auto_cast win32.wglGetProcAddress("wglCreateContextAttribsARB")
		wglSwapIntervalEXT = auto_cast win32.wglGetProcAddress("wglSwapIntervalEXT")


	when ODIN_DEBUG {
		attrib_list := []c.int {
			win32.WGL_CONTEXT_MAJOR_VERSION_ARB, OPENGL_VERSION_MAJOR,
			win32.WGL_CONTEXT_MINOR_VERSION_ARB, OPENGL_VERSION_MINOR,
			win32.WGL_CONTEXT_PROFILE_MASK_ARB,  win32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
			win32.WGL_CONTEXT_FLAGS_ARB,         win32.WGL_CONTEXT_DEBUG_BIT_ARB,
			0
		}
	} else {
		attrib_list := []c.int {
			win32.WGL_CONTEXT_MAJOR_VERSION_ARB, OPENGL_VERSION_MAJOR,
			win32.WGL_CONTEXT_MINOR_VERSION_ARB, OPENGL_VERSION_MINOR,
			win32.WGL_CONTEXT_PROFILE_MASK_ARB,  win32.WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
			0
		}
	}
		glRc = wglCreateContextAttribsARB(dc, nil, raw_data(attrib_list))

		assert(bool(win32.wglMakeCurrent(dc, glRc)))

		_opengl_ready = true

		gl.load_up_to(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, win32.gl_set_proc_address)
		wglSwapIntervalEXT(1)
	}
}

@(private="file")
_always_on_top : bool
window_set_always_on_top :: proc(on: bool) {
	if on {
		win32.SetWindowPos(hwnd, win32.HWND_TOPMOST, 0,0,0,0, win32.SWP_NOMOVE|win32.SWP_NOSIZE)
		_always_on_top = true
	} else {
		win32.SetWindowPos(hwnd, win32.HWND_NOTOPMOST, 0,0,0,0, win32.SWP_NOMOVE|win32.SWP_NOSIZE)
		_always_on_top = false
	}
}
window_get_always_on_top :: proc() -> bool {
	return _always_on_top
}

wndproc :: proc "system" (hwnd: win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
	context = the_context
	input_process_win32_wndproc({hwnd,msg,wparam,lparam})
	vwv_wndproc(hwnd,msg,wparam,lparam)
	switch(msg) {
	case win32.WM_SIZING:
		update()
	case win32.WM_DESTROY:
		win32.ReleaseDC(hwnd, dc)
		win32.PostQuitMessage(0)
	}
	return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
}
