package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "core:c"
import "core:log"

import "vendor:glfw"
import "core:unicode/utf16"
import win32 "core:sys/windows"

// import sdl "vendor:sdl3"
import gl "vendor:OpenGL"
import "dgl"

OPENGL_VERSION_MAJOR :: 4
OPENGL_VERSION_MINOR :: 4

window : glfw.WindowHandle

hwnd : win32.HWND

@(private="file")
_opengl_ready := false

window_init :: proc() {
	// instance = hInstance
	instance := win32.HINSTANCE(win32.GetModuleHandleW(nil))
	// 注册窗口类
	wndclass := win32.L("WindowClass")

	wc: win32.WNDCLASSW
	wc.lpfnWndProc = wndproc
	wc.lpszClassName = wndclass
	wc.hInstance = instance
	win32.RegisterClassW(&wc)

	// 创建窗口
	hwnd = win32.CreateWindowExW(
		0, // dwExStyle
		wndclass, // lpClassName
		win32.L("MyWindow"), // lpWindowName
		win32.WS_OVERLAPPEDWINDOW | win32.WS_VISIBLE, // dwStyle
		win32.CW_USEDEFAULT, // x
		win32.CW_USEDEFAULT, // y
		600, // nWidth
		800, // nHeight
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

wndproc :: proc "system" (hwnd: win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
	context = runtime.default_context()
	switch(msg) {
	case win32.WM_SIZE:
		window_size = {auto_cast win32.LOWORD(lparam), auto_cast win32.HIWORD(lparam)}
	case win32.WM_ERASEBKGND:
		return 1 // paint should fill out the client area so no need to erase the background
	case win32.WM_PAINT:
	case win32.WM_DESTROY:
		win32.PostQuitMessage(0)
	case win32.WM_KEYFIRST:
	}
	return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
}


// window_init :: proc(title: string, width, height: int) {
//	// Initialize glfw, specify OpenGL version.
//	glfw.Init()
//	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
//	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
//	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
//	
//	// Create render window.
//	window = glfw.CreateWindow(auto_cast width, auto_cast height, strings.clone_to_cstring(title, context.temp_allocator), nil, nil)
//	assert(window != nil)
// 
//	glfw.MakeContextCurrent(window)
// 
//	// Enable Vsync.
//	glfw.SwapInterval(1)
// 
//	// Load OpenGL function pointers.
//	gl.load_up_to(OPENGL_VERSION_MAJOR, OPENGL_VERSION_MINOR, glfw.gl_set_proc_address)
// 
//	// Set normalized device coords to window coords transformation.
//	w, h := glfw.GetFramebufferSize(window)
//	gl.Viewport(0,0,w,h)
// }
// 
// window_destroy :: proc() {
//	glfw.DestroyWindow(window)
//	glfw.Terminate()
// }


// window : ^sdl.Window
// renderer : ^sdl.Renderer
// 
// window_init :: proc(title: string, width, height: int) {
//	when ODIN_OS == .Windows do win32.SetConsoleOutputCP(.UTF8)
//	sdl.SetHint("SDL_IME_SHOW_UI", "1")
//	sdl.SetHint(sdl.HINT_IME_INTERNAL_EDITING, "1")
// 
//	if sdl.Init({.VIDEO, .EVENTS}) != 0 {
//		fmt.println("failed to init: ", sdl.GetErrorString())
//		return
//	}
// 
//	sdl.GL_SetAttribute(.CONTEXT_MAJOR_VERSION, OPENGL_VERSION_MAJOR)
//	sdl.GL_SetAttribute(.CONTEXT_MINOR_VERSION, OPENGL_VERSION_MINOR)
//	sdl.GL_SetAttribute(.CONTEXT_PROFILE_MASK, cast(i32)sdl.GLprofile.CORE)
// 
//	sdl.GL_SetAttribute(.MULTISAMPLEBUFFERS, 1)
//	sdl.GL_SetAttribute(.MULTISAMPLESAMPLES, 4)
//	
//	major, minor, profile : c.int
//	sdl.GL_GetAttribute(.CONTEXT_MAJOR_VERSION, &major)
//	sdl.GL_GetAttribute(.CONTEXT_MAJOR_VERSION, &minor)
//	sdl.GL_GetAttribute(.CONTEXT_PROFILE_MASK, &profile)
//	log.infof("OpenGL version: {}.{}, profile: {}", major, minor, cast(sdl.GLprofile)profile)
// 
//	flags : sdl.WindowFlags = {.OPENGL}
//	// flags : sdl.WindowFlags = {.OPENGL, .ALLOW_HIGHDPI, .RESIZABLE}
// 
//	window := sdl.CreateWindow(
//		strings.clone_to_cstring(title, context.temp_allocator),
//		sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, auto_cast width, auto_cast height,
//		flags)
// 
//	if window == nil {
//		log.errorf("Failed to instantiate window")
//		return
//	}
// 
//	gl_context := sdl.GL_CreateContext(window)
//	assert(gl_context != nil, fmt.tprintf("Failed to create GLContext for window: {}, because: {}.\n", title, sdl.GetError()))
// 
//	sdl.GL_MakeCurrent(window, gl_context)
//	gl.load_up_to(auto_cast major, auto_cast minor, sdl.gl_set_proc_address)
//	
//	// v sync is disabled for event-driven window
//	// if !config.event_driven do sdl.GL_SetSwapInterval(1)
//	sdl.GL_SetSwapInterval(1)
// 
//	// gl.Enable(gl.MULTISAMPLE)
// 
// }
// 
// window_destroy :: proc() {
//	sdl.DestroyWindow(window)
// }
