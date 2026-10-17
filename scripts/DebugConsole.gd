extends CanvasLayer

var log_store: CombatLog
var panel: PanelContainer
var history: RichTextLabel
var copy_button: Button
var clear_button: Button
var profile: RefCounted
var can_reset: Callable
var command_input: LineEdit
var pending_command: String = ""
var confirmation_deadline: int = 0
const CONFIRMATION_USEC: int = 30000000

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	panel = PanelContainer.new()
	panel.position = Vector2(590, 174)
	panel.size = Vector2(670, 324)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.04, 0.06, 0.92)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	var title := Label.new()
	title.text = "COMBAT LOG  ·  ` to close"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(title)
	copy_button = Button.new()
	copy_button.text = "Copy Log"
	copy_button.focus_mode = Control.FOCUS_NONE
	copy_button.pressed.connect(copy_log)
	toolbar.add_child(copy_button)
	clear_button = Button.new()
	clear_button.text = "Clear Log"
	clear_button.focus_mode = Control.FOCUS_NONE
	clear_button.pressed.connect(log_store.clear)
	clear_button.pressed.connect(cancel_confirmation)
	toolbar.add_child(clear_button)
	history = RichTextLabel.new()
	history.bbcode_enabled = false
	history.selection_enabled = true
	history.focus_mode = Control.FOCUS_NONE
	history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history.add_theme_font_size_override("normal_font_size", 15)
	column.add_child(history)
	var command_row := HBoxContainer.new()
	column.add_child(command_row)
	command_input = LineEdit.new()
	command_input.placeholder_text = "Developer command (help) · click to type"
	command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_input.max_length = 80
	command_input.text_submitted.connect(submit_command)
	command_row.add_child(command_input)
	var run_button := Button.new()
	run_button.text = "Run"
	run_button.focus_mode = Control.FOCUS_NONE
	run_button.pressed.connect(func(): submit_command(command_input.text))
	command_row.add_child(run_button)
	log_store.changed.connect(refresh)
	panel.hide()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (
		event.physical_keycode == KEY_QUOTELEFT or event.keycode == KEY_QUOTELEFT):
		panel.visible = not panel.visible
		if panel.visible:
			refresh()
		else:
			command_input.release_focus()
			cancel_confirmation()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	if not panel.visible:
		return
	var bar := history.get_v_scroll_bar()
	var follow: bool = bar.value >= bar.max_value - bar.page - 2.0
	var old_scroll: float = bar.value
	history.text = log_store.full_text()
	history.scroll_following = follow
	if not follow:
		bar.set_deferred("value", old_scroll)

func copy_log() -> void:
	DisplayServer.clipboard_set(log_store.full_text())

func cancel_confirmation() -> void:
	pending_command = ""
	confirmation_deadline = 0

func _reset_allowed() -> bool:
	return profile != null and can_reset.is_valid() and can_reset.call() and not profile.is_match_active()

func submit_command(raw_command: String) -> void:
	var command := raw_command.strip_edges().to_lower()
	var previous := pending_command
	var deadline := confirmation_deadline
	# Consume/cancel before executing anything, including errors and unknown input.
	cancel_confirmation()
	command_input.clear()
	command_input.release_focus()
	if command == "help":
		_report("Commands: reset_stats, reset_profile. Main menu only; explicit confirmation required within 30 seconds.")
	elif command in ["reset_stats", "reset_profile", "confirm_reset_stats", "confirm_reset_profile"]:
		if not _reset_allowed():
			_report("Reset rejected. Return to the main menu first; active matches cannot be reset.")
			return
		if command.begins_with("confirm_"):
			var requested := command.trim_prefix("confirm_")
			if previous != requested or Time.get_ticks_usec() > deadline:
				_report("No matching confirmation pending (or it expired). Enter reset_stats or reset_profile again.")
				return
			var error: Error = profile.reset_stats() if requested == "reset_stats" else profile.reset_profile()
			if error == OK:
				_report("Statistics reset and saved." if requested == "reset_stats" else "Profile reset to defaults and saved.")
				if profile.last_save_error != OK:
					_report("Reset preserved in recovery backup; primary save will be retried.")
			else:
				_report("Reset failed (%s). No reset was committed; enter the command again to retry." % error_string(error))
		else:
			pending_command = command
			confirmation_deadline = Time.get_ticks_usec() + CONFIRMATION_USEC
			_report(("Reset all lifetime statistics?" if command == "reset_stats" else "Reset identity, appearance, elimination field and statistics to defaults?") +
				" Type confirm_%s within 30 seconds to proceed. Any different command cancels confirmation." % command)
	else:
		_report("Unknown command. Type help. Any pending confirmation was canceled.")

func _report(message: String) -> void:
	log_store.append("[DEV] %s\n\n" % message)
