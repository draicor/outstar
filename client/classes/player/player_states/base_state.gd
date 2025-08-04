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
func switch_weapon(slot: int) -> void:
	var equipment = player.player_equipment
	var animator = player.player_animator
	
	# If the slot is not valid, skip
	if equipment.is_invalid_weapon_slot(slot):
		return
	
	# If this weapon is already equipped, skip
	if equipment.current_slot == slot:
		return
	
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
			# Report to the server we'll switch weapons
			player.send_switch_weapon_packet(weapon_name, weapon_type, weapon_state)
			# Switch to the correct weapon state based on weapon type
			if animator.get_weapon_animation("equip", weapon_type) != {}:
				await animator.play_weapon_animation_and_await("equip", weapon_type)
				equipment.update_hud_ammo()
			player.player_state_machine.change_state(weapon_state)
