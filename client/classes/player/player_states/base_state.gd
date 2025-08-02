extends Node
class_name BaseState

signal finished(next_state_name)

var player_state_machine: PlayerStateMachine = null
var player: Player = null
var state_name: String = "unnamed_state"


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
	
	# If slot has a weapon, equip it
	if equipment.weapon_slots[slot]["weapon_name"] != "":
		var weapon_type: String = equipment.weapon_slots[slot]["weapon_type"]
		if animator.get_weapon_animation("equip", weapon_type) != {}:
			await animator.play_weapon_animation_and_await("equip", weapon_type)
			equipment.update_hud_ammo()
		
		# Switch to the correct weapon state based on weapon type
		var weapon_state: String = equipment.get_weapon_state_by_weapon_type(weapon_type)
		if weapon_state != "":
			player.player_state_machine.change_state(weapon_state)
