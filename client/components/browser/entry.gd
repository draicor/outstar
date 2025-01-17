extends Control

@onready var master_label: Label = $PanelContainer/MarginContainer/HBoxContainer/MasterLabel
@onready var map_label: Label = $PanelContainer/MarginContainer/HBoxContainer/MapLabel
@onready var players_online_label: Label = $PanelContainer/MarginContainer/HBoxContainer/PlayersContainer/PlayersOnlineLabel
@onready var max_players_label: Label = $PanelContainer/MarginContainer/HBoxContainer/PlayersContainer/MaxPlayersLabel
@onready var room_id_label: Label = $PanelContainer/MarginContainer/HBoxContainer/RoomIdLabel
@onready var join_room_button: Button = $PanelContainer/MarginContainer/HBoxContainer/JoinRoomButton

# Instantiate this as hidden
func _init() -> void:
	hide()

func initialize(nickname: String, map_name: String, players_online: int, max_players: int, room_id: int) -> void:
	set_master(nickname)
	set_map(map_name)
	set_players_online(players_online)
	set_max_players(max_players)
	set_room_id(room_id)
	# Connect the join button to the function call that will send the packet
	join_room_button.connect("pressed", _on_join_room_button_pressed)
	# Show this entry after it has the data
	show()

# Individual functions to change the text for each label
func set_master(nickname: String) -> void:
	master_label.text = nickname

func set_map(map_name: String) -> void:
	map_label.text = map_name

func set_players_online(players_online: int) -> void:
	players_online_label.text = str(players_online)

func set_max_players(max_players: int) -> void:
	max_players_label.text = str(max_players)

func set_room_id(room_id: int) -> void:
	room_id_label.text = str(room_id)

# Connect the Join button to the packet that has to be sent
func _on_join_room_button_pressed() -> void:
	# We emit a signal with our room id as int
	Signals.browser_join_room.emit(int(room_id_label.text))
