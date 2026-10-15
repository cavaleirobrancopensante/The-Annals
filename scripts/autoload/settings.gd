extends Node
## Settings kept apart from the saves: language, text size, hints, confirm before closing a house,
## and the last house opened.

signal changed

const PATH := "user://settings.cfg"
const SIZES := ["small", "normal", "large"]
const SCALES := {"small": 0.85, "normal": 1.0, "large": 1.18}

var language := "en"
var text_size := "normal"
var hints := true
var confirm_close := true
var last_slot := 0


func _ready() -> void:
	Strings.register()
	load_settings()
	TranslationServer.set_locale(language)
	Strings.reload_data()


func font_scale() -> float:
	return float(SCALES.get(text_size, 1.0))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	language = str(cfg.get_value("display", "language", language))
	if not Strings.LANGUAGES.has(language):
		language = "en"
	text_size = str(cfg.get_value("display", "text_size", text_size))
	if not SIZES.has(text_size):
		text_size = "normal"
	hints = bool(cfg.get_value("play", "hints", hints))
	confirm_close = bool(cfg.get_value("play", "confirm_close", confirm_close))
	last_slot = int(cfg.get_value("saves", "last_slot", last_slot))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "language", language)
	cfg.set_value("display", "text_size", text_size)
	cfg.set_value("play", "hints", hints)
	cfg.set_value("play", "confirm_close", confirm_close)
	cfg.set_value("saves", "last_slot", last_slot)
	cfg.save(PATH)


func set_language(code: String) -> void:
	if code == language or not Strings.LANGUAGES.has(code):
		return
	language = code
	TranslationServer.set_locale(code)
	Strings.reload_data()
	save_settings()
	changed.emit()


func set_text_size(size: String) -> void:
	if size == text_size or not SIZES.has(size):
		return
	text_size = size
	save_settings()
	changed.emit()


func set_hints(on: bool) -> void:
	hints = on
	save_settings()
	changed.emit()


func set_confirm_close(on: bool) -> void:
	confirm_close = on
	save_settings()
	changed.emit()


func set_last_slot(n: int) -> void:
	last_slot = n
	save_settings()
