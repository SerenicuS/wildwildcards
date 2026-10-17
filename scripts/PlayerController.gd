class_name PlayerController
extends Node

signal action_selected(action: int)
signal restart_requested
signal pause_requested
var accepting: bool = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed("pause_duel"):
		pause_requested.emit()
	elif event.is_action_pressed("rematch"):
		restart_requested.emit()
	elif accepting:
		for mapping in [["reload", DuelRules.Action.RELOAD], ["shield", DuelRules.Action.SHIELD], ["shoot", DuelRules.Action.SHOOT]]:
			if event.is_action_pressed(mapping[0]):
				action_selected.emit(mapping[1])
