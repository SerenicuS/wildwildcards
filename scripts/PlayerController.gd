class_name PlayerController
extends Node

signal action_selected(action: int)
signal restart_requested
signal pause_requested

var accepting: bool = false
var player_index: int = 0

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if player_index == 0:
		if event.is_action_pressed("pause_duel"):
			if is_inside_tree() and get_viewport():
				get_viewport().set_input_as_handled()
			pause_requested.emit()
			return
		if event.is_action_pressed("rematch"):
			if is_inside_tree() and get_viewport():
				get_viewport().set_input_as_handled()
			restart_requested.emit()
			return
	if accepting:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if player_index == 0:
			if code == KEY_A or event.is_action_pressed("reload"):
				action_selected.emit(DuelRules.Action.RELOAD)
			elif code == KEY_S or event.is_action_pressed("shield"):
				action_selected.emit(DuelRules.Action.SHIELD)
			elif code == KEY_D or event.is_action_pressed("shoot"):
				action_selected.emit(DuelRules.Action.SHOOT)
		elif player_index == 1:
			if code == KEY_J:
				action_selected.emit(DuelRules.Action.RELOAD)
			elif code == KEY_K:
				action_selected.emit(DuelRules.Action.SHIELD)
			elif code == KEY_L:
				action_selected.emit(DuelRules.Action.SHOOT)
