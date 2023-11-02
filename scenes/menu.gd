extends Control

func _on_quick_button_pressed():
	Game.world.quickjoin()
	queue_free()

func _on_host_button_pressed():
	Game.world.host()
	queue_free()

func _on_join_button_pressed():
	Game.world.join()
	queue_free()
