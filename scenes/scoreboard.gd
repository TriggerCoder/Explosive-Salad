extends Node

@export var score : int = 0 : set = _set_score

func _ready():
	set_multiplayer_authority(1)

func _set_score(value):
	score = value

func _process(_delta):
	if Input.is_action_just_pressed("show_score"):
		$Control.visible = true
		var rows = $Control/MarginContainer/VBoxContainer.get_children()
		for row in rows:
			row.queue_free()
		var players = get_tree().get_nodes_in_group("Players")
		for p in players:
			var row = preload("res://scenes/score_item.tscn").instantiate()
			row.get_node("Name").text = p.name
			row.get_node("Score").text = str(p.scoreboard.score)
			$Control/MarginContainer/VBoxContainer.add_child(row)
	if Input.is_action_just_released("show_score"):
		$Control.visible = false
