extends Node

signal capture_finished(path: String, clipboard_ok: bool)

const SCREENSHOT_DIR := "res://debug/screenshots"

func capture_viewport(viewport: Viewport) -> void:
	_capture_async(viewport)

func _capture_async(viewport: Viewport) -> void:
	await RenderingServer.frame_post_draw
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null:
		push_warning("Screenshot failed: viewport has no texture")
		capture_finished.emit("", false)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_warning("Screenshot failed: empty viewport image")
		capture_finished.emit("", false)
		return
	var saved_path := _save_image(image)
	var clipboard_ok := _copy_to_clipboard(saved_path)
	capture_finished.emit(saved_path, clipboard_ok)
	if not saved_path.is_empty():
		print("Screenshot saved: %s" % saved_path)
	if clipboard_ok:
		print("Screenshot copied to clipboard")

func _ensure_dir() -> String:
	var abs_dir := ProjectSettings.globalize_path(SCREENSHOT_DIR)
	var err := DirAccess.make_dir_recursive_absolute(abs_dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("Screenshot folder create failed (%s): %s" % [err, abs_dir])
	return abs_dir

func _build_filename() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "screenshot_%04d%02d%02d_%02d%02d%02d.png" % [
		dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second
	]

func _save_image(image: Image) -> String:
	var abs_dir := _ensure_dir()
	var file_path := "%s/%s" % [abs_dir, _build_filename()]
	if image.save_png(file_path) != OK:
		push_warning("Screenshot save failed: %s" % file_path)
		return ""
	return file_path

func _copy_to_clipboard(file_path: String) -> bool:
	if file_path.is_empty():
		return false
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		return false
	match OS.get_name():
		"Linux":
			return _copy_png_linux(file_path)
		"Windows":
			return _copy_png_windows(file_path)
		"macOS":
			return _copy_png_macos(file_path)
	return false

func _copy_png_linux(file_path: String) -> bool:
	var quoted := _shell_quote(file_path)
	if OS.has_environment("WAYLAND_DISPLAY"):
		if _run_cmd("bash", PackedStringArray(["-c", "wl-copy -t image/png < %s" % quoted])):
			return true
	if _run_cmd("xclip", PackedStringArray(["-selection", "clipboard", "-target", "image/png", "-i", file_path])):
		return true
	return false

func _copy_png_windows(file_path: String) -> bool:
	var win_path := file_path.replace("/", "\\").replace("'", "''")
	var ps := (
		"Add-Type -AssemblyName System.Windows.Forms; "
		+ "Add-Type -AssemblyName System.Drawing; "
		+ "[System.Windows.Forms.Clipboard]::SetImage([System.Drawing.Image]::FromFile('%s'))"
		% win_path
	)
	return _run_cmd("powershell.exe", PackedStringArray(["-NoProfile", "-Command", ps]))

func _copy_png_macos(file_path: String) -> bool:
	var quoted := _shell_quote(file_path)
	var script := "set the clipboard to (read (POSIX file %s) as «class PNGf»)" % quoted
	return _run_cmd("osascript", PackedStringArray(["-e", script]))

func _run_cmd(executable: String, arguments: PackedStringArray) -> bool:
	var output: Array = []
	return OS.execute(executable, arguments, output, true, false) == 0

func _shell_quote(value: String) -> String:
	return "'%s'" % value.replace("'", "'\\''")
