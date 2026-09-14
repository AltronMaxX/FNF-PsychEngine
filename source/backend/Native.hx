package backend;

import lime.app.Application;
import lime.system.Display;
import lime.system.System;

import flixel.util.FlxColor;

#if (cpp && windows)
@:buildXml('
<target id="haxe">
	<lib name="dwmapi.lib" if="windows"/>
	<lib name="gdi32.lib" if="windows"/>
	<lib name="advapi32.lib" if="windows"/>
	<lib name="comctl32.lib" if="windows"/>
</target>
')
@:cppFileCode('
#include <windows.h>
#include <dwmapi.h>
#include <winuser.h>
#include <wingdi.h>
#include <commctrl.h>

#define attributeDarkMode 20
#define attributeDarkModeFallback 19

#define attributeCaptionColor 34
#define attributeTextColor 35
#define attributeBorderColor 36

struct HandleData {
	DWORD pid = 0;
	HWND handle = 0;
};

BOOL CALLBACK findByPID(HWND handle, LPARAM lParam) {
	DWORD targetPID = ((HandleData*)lParam)->pid;
	DWORD curPID = 0;

	GetWindowThreadProcessId(handle, &curPID);
	if (targetPID != curPID || GetWindow(handle, GW_OWNER) != (HWND)0 || !IsWindowVisible(handle)) {
		return TRUE;
	}

	((HandleData*)lParam)->handle = handle;
	return FALSE;
}

HWND curHandle = 0;
void getHandle() {
	if (curHandle == (HWND)0) {
		HandleData data;
		data.pid = GetCurrentProcessId();
		EnumWindows(findByPID, (LPARAM)&data);
		curHandle = data.handle;
	}
}

static void updateWindowTheme(HWND handle) {
	DWORD lightTheme = 1;
	DWORD size = sizeof(lightTheme);
	BOOL darkMode = RegGetValueW(HKEY_CURRENT_USER,
		L"Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Themes\\\\Personalize",
		L"AppsUseLightTheme", RRF_RT_REG_DWORD, NULL, &lightTheme, &size) == ERROR_SUCCESS && lightTheme == 0;

	HIGHCONTRASTW highContrast = {sizeof(HIGHCONTRASTW)};
	if (SystemParametersInfoW(SPI_GETHIGHCONTRAST, sizeof(highContrast), &highContrast, 0)
		&& (highContrast.dwFlags & HCF_HIGHCONTRASTON)) {
		darkMode = FALSE;
	}

	HRESULT result = DwmSetWindowAttribute(handle, attributeDarkMode, &darkMode, sizeof(darkMode));
	if (FAILED(result)) {
		result = DwmSetWindowAttribute(handle, attributeDarkModeFallback, &darkMode, sizeof(darkMode));
	}
	if (SUCCEEDED(result)) {
		RedrawWindow(handle, NULL, NULL, RDW_INVALIDATE | RDW_FRAME | RDW_UPDATENOW);
	}
}

static LRESULT CALLBACK windowThemeProc(HWND handle, UINT message, WPARAM wParam, LPARAM lParam,
	UINT_PTR subclassId, DWORD_PTR refData) {
	if (message == WM_NCDESTROY) {
		RemoveWindowSubclass(handle, windowThemeProc, subclassId);
		if (curHandle == handle) curHandle = 0;
		return DefSubclassProc(handle, message, wParam, lParam);
	}

	LRESULT result = DefSubclassProc(handle, message, wParam, lParam);
	if (message == WM_SETTINGCHANGE || message == WM_THEMECHANGED) {
		updateWindowTheme(handle);
	}
	return result;
}
')
#end
class Native
{
	public static function __init__():Void
	{
		registerDPIAware();
	}

	public static function registerDPIAware():Void
	{
		#if (cpp && windows)
		// DPI Scaling fix for windows 
		// this shouldn't be needed for other systems
		// Credit to YoshiCrafter29 for finding this function
		untyped __cpp__('
			SetProcessDPIAware();	
			#ifdef DPI_AWARENESS_CONTEXT
			SetProcessDpiAwarenessContext(
				#ifdef DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
				DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
				#else
				DPI_AWARENESS_CONTEXT_SYSTEM_AWARE
				#endif
			);
			#endif
		');
		#end
	}

	public static function followSystemTheme():Void
	{
		#if (cpp && windows)
		untyped __cpp__('
			getHandle();
			if (curHandle != (HWND)0) {
				SetWindowSubclass(curHandle, windowThemeProc, 1, 0);
				updateWindowTheme(curHandle);
			}
		');
		#end
	}

	private static var fixedScaling:Bool = false;
	public static function fixScaling():Void
	{
		if (fixedScaling) return;
		fixedScaling = true;

		#if (cpp && windows)
		final display:Null<Display> = System.getDisplay(0);
		if (display != null)
		{
			final dpiScale:Float = display.dpi / 96;
			@:privateAccess Application.current.window.width = Std.int(Main.game.width * dpiScale);
			@:privateAccess Application.current.window.height = Std.int(Main.game.height * dpiScale);

			Application.current.window.x = Std.int((Application.current.window.display.bounds.width - Application.current.window.width) / 2);
			Application.current.window.y = Std.int((Application.current.window.display.bounds.height - Application.current.window.height) / 2);
		}

		untyped __cpp__('
			getHandle();
			if (curHandle != (HWND)0) {
				HDC curHDC = GetDC(curHandle);
				RECT curRect;
				GetClientRect(curHandle, &curRect);
				FillRect(curHDC, &curRect, (HBRUSH)GetStockObject(BLACK_BRUSH));
				ReleaseDC(curHandle, curHDC);
			}
		');
		#end
	}
}