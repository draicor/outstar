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


# Called from different idle states to switch to another weapon
func switch_weapon(slot: int, broadcast: bool = false) -> void:
	var equipment = player.player_equipment
	var animator = player.player_animator
	var packets = player.player_packets
	
	# If the new slot is not valid or the weapon is already equipped, skip
	if equipment.is_invalid_weapon_slot(slot) or equipment.current_slot == slot:
		packets.complete_packet()
		return
	
	# Block input
	player.is_busy = true
	
	# If we set it to broadcast and this is our local player
	if broadcast and is_local_player:
		# Report to the server we'll switch weapons
		packets.send_switch_weapon_packet(slot)
	
	# Unequip
	if equipment.equipped_weapon:
		# Play the unequip animation if valid
		var current_type: String = equipment.get_current_weapon_type()
		if animator.get_weapon_animation("unequip", current_type) != {}:
			equipment.hide_weapon_hud()
			await animator.play_weapon_animation_and_await("unequip", current_type)
			player.is_busy = true # Block input again because animator released it
	
	equipment.switch_weapon_by_slot(slot) # <-- Calls unequip and equip weapon
	
	# Check if slot has a valid weapon
	var weapon_type: String = equipment.weapon_slots[slot]["weapon_type"]
	var weapon_state: String = equipment.get_weapon_state_by_weapon_type(weapon_type)
	if weapon_state != "":
		# Switch to the correct weapon state based on weapon type
		if animator.get_weapon_animation("equip", weapon_type) != {}:
			await animator.play_weapon_animation_and_await("equip", weapon_type)
			player.is_busy = true # Block input again because animator released it
			equipment.update_hud_ammo()
		player.player_state_machine.change_state(weapon_state)
	
	# Release input
	player.is_busy = false
	
	packets.complete_packet()


# Called from different weapon states to reload
func reload_weapon_and_await(slot: int, amount: int, broadcast: bool) -> void:
	var equipment = player.player_equipment
	var animator = player.player_animator
	var packets = player.player_packets
	
	# Check that we have the right weapon equipped
	if slot != equipment.current_slot:
		packets.complete_packet()
		return
	
	# Block input
	player.is_busy = true
	
	# Get current weapon type and reload animation
	var weapon_type: String = equipment.get_current_weapon_type()
	
	# If we set it to broadcast and this is our local player
	if broadcast and is_local_player:
		# Report to the server we'll switch weapons
		packets.send_reload_weapon_packet(equipment.current_slot, amount)
	
	# Check if we are in the weapon_down_idle_state before reloading
	if is_weapon_down_idle_state:
		# Play the down to aim animation
		await animator.play_weapon_animation_and_await(
			"down_to_aim",
			weapon_type
		)
	
	# Play the reload animation
	await animator.play_weapon_animation_and_await(
		"reload",
		weapon_type
	)
	player.is_busy = true # Block input again because animator released it
	
	# Update the ammo locally
	equipment.reload_equipped_weapon(amount)
	
	# Release input
	player.is_busy = false
	
	packets.complete_packet()


# Returns true if this character has its weapon down
func is_weapon_down_idle_state() -> bool:
	var current_state: String = player.player_state_machine.get_current_state_name()
	match current_state:
		"rifle_down_idle":
			return true
		_:
			return false
