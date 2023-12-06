extends Control

var in_room: bool = false

func _on_create_room_pressed():
	$"Create Ctrl".visible = true
	$"Join Ctrl".visible = false


func _on_join_room_pressed():
	$"Create Ctrl".visible = false
	$"Join Ctrl".visible = true


func _on_back_pressed():
	get_tree().change_scene_to_file("res://src/Scenes/UI/main_menu.tscn")


func _on_create_submit_pressed():
	get_tree().change_scene_to_file("res://src/Scenes/Levels/TestLevel.tscn")


func _on_join_submit_pressed():
	get_tree().change_scene_to_file("res://src/Scenes/Levels/TestLevel.tscn")
