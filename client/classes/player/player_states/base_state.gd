extends Node
class_name BaseState

signal finished(next_state_name)

var player_state_machine: PlayerStateMachine = null
var player: Player = null
var state_name: String = "unnamed_state"
var is_local_player: bool = false # set to true for local player
var signals_connected: bool = false # to only do this once


func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass


# Called from different states (IDLE states) to switch to a different weapon slot
func switch_weapon(slot: int, broadcast: bool = false) -> void:
	player.is_busy = true
	
	var equipment = player.player_equipment
	var animator = player.player_animator
	var packets = player.player_packets
	
	# If the new slot is not valid or the weapon is already equipped, skip
	if equipment.is_invalid_weapon_slot(slot) or equipment.current_slot == slot:
		player.is_busy = false
		return
	
	# If we are still moving, send this packet to the back of the queue
	if player.player_movement.in_motion:
		print("Tried to switch weapons while still in motion")
		await player.player_movement.movement_completed
	
	# If holding a weapon
	if equipment.equipped_weapon:
		# Play the unequip animation if valid
		var current_type: String = equipment.get_current_weapon_type()
		if animator.get_weapon_animation("unequip", current_type) != {}:
			equipment.hide_weapon_hud()
			await animator.play_weapon_animation_and_await("unequip", current_type)
	
	equipment.switch_weapon_by_slot(slot) # <-- Calls unequip and equip weapon
	
	# Check if slot has a valid weapon
	var weapon_name: String = equipment.weapon_slots[slot]["weapon_name"]
	var weapon_type: String = equipment.weapon_slots[slot]["weapon_type"]
	if weapon_name != "" and weapon_type != "":
		var weapon_state: String = equipment.get_weapon_state_by_weapon_type(weapon_type)
		if weapon_state != "":
			# If we set it to broadcast and this is our local player
			if broadcast and is_local_player:
				# Report to the server we'll switch weapons
				packets.send_switch_weapon_packet(slot)
			
			# Switch to the correct weapon state based on weapon type
			if animator.get_weapon_animation("equip", weapon_type) != {}:
				await animator.play_weapon_animation_and_await("equip", weapon_type)
				equipment.update_hud_ammo()
			player.player_state_machine.change_state(weapon_state)
	
	player.is_busy = false
	# Signal packet completion
	if packets.is_processing_packet():
		packets.complete_packet()
