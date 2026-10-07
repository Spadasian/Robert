extends Node
## Saves and loads the permanent progress (MetaProgression) as a JSON file in the user folder.
## Registered as the autoload "SaveManager" in project.godot, after MetaProgression.
## Only permanent data is saved, never anything from the current run.
##
## Safety: the new file is written next to the old one and renamed into place, and the previous save is kept
## as a .bak copy. If the main file is broken, the backup is used; if both are broken the game starts fresh.
## Windows: Project > Open User Data Folder in the Godot editor shows where save.json is.

const SAVE_PATH: String = "user://save.json"
const BACKUP_PATH: String = "user://save.json.bak"
const TEMP_PATH: String = "user://save.json.tmp"
const SAVE_VERSION: int = 1


func _ready() -> void:
	load_game()
	MetaProgression.data_changed.connect(save_game)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Returns true when the file was written.
func save_game() -> bool:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"meta": MetaProgression.to_dict(),
		"settings": AudioManager.to_dict(),
	}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot write %s (error %d)" % [TEMP_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# Keep the previous save as a backup, then move the new file into place.
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(BACKUP_PATH) # fine if it does not exist yet
		DirAccess.rename_absolute(SAVE_PATH, BACKUP_PATH)
	var error: int = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if error != OK:
		push_warning("SaveManager: cannot move the new save into place (error %d)" % error)
		return false
	return true


## Loads the save (or the backup if the save is broken). Returns true when something was loaded.
func load_game() -> bool:
	for path in [SAVE_PATH, BACKUP_PATH]:
		var data: Dictionary = _read_file(path)
		if data.is_empty():
			continue
		var meta = data.get("meta", {})
		if not (meta is Dictionary):
			push_warning("SaveManager: %s has no valid progress data" % path)
			continue
		if int(data.get("version", 1)) > SAVE_VERSION:
			push_warning("SaveManager: %s was written by a newer version of the game, loading what is known" % path)
		MetaProgression.from_dict(meta)
		var settings = data.get("settings", {})
		if settings is Dictionary:
			AudioManager.from_dict(settings)
		if path == BACKUP_PATH:
			push_warning("SaveManager: the main save was broken, loaded the backup")
		return true
	return false


## Removes every save file and resets the progress in memory.
func delete_save() -> void:
	for path in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	MetaProgression.reset()


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	# JSON.new().parse() reports a broken file quietly (JSON.parse_string would print an engine error).
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		return json.data
	push_warning("SaveManager: %s is not valid JSON" % path)
	return {}


## Development shortcut (editor and debug builds only): Ctrl+Shift+F9 erases all progress.
func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9 and event.ctrl_pressed and event.shift_pressed:
		delete_save()
		print("SaveManager: save deleted, progress reset")
