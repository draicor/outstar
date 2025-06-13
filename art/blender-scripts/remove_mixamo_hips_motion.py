import bpy

# Add action names here to remove their hips motion ((X, Z) axis only)
ACTION_NAMES_TO_REMOVE_HIPS_HORIZONTAL_MOTION = [
    "rifle_aim_to_down",
    "rifle_down_to_aim",
]

# Name of your armature object
ARMATURE_NAME = "Armature"

# Name of the hips bone (common Mixamo variants)
HIPS_BONE_NAMES = [
    "mixamorig:Hips",
    "Hips",
    "hip",
]


# ================================================================== #


"""Find the hips bone in the armature"""
def get_hips_bone(armature):
    for bone_name in HIPS_BONE_NAMES:
        if bone_name in armature.pose.bones:
            return armature.pose.bones[bone_name]
    
    return None


"""Remove horizontal motion while preserving vertical movement"""
def remove_hips_horizontal_motion(action, hips_bone):
    data_path = f'pose.bones["{hips_bone.name}"].location'
    
    # Process X and Z axes (0=X, 1=Y, 2=Z)
    for axis in {0, 2}:
        # Find fcurve for this axis
        fcurve = next((fc for fc in action.fcurves if fc.data_path == data_path and fc.array_index == axis), None)
        if fcurve:
            # Remove all frames from this axis
            fcurve.keyframe_points.clear()


def remove_horizontal_hips_motion_from_array(actions_names_array):
    # Remove horizontal hips motion from each action
    for action_name in actions_names_array:
        action = bpy.data.actions.get(action_name)
        if not action:
            print(f"Action '{action_name}' not found! Skipping...")
            continue
        
        print(f"Removing horizontal motion from: {action.name}")
        remove_hips_horizontal_motion(action, hips)


def main():
    # Get armature
    armature = bpy.data.objects.get(ARMATURE_NAME)
    if not armature:
        print(f"Armature '{ARMATURE_NAME}' not found!")
        return
    
    # Get hips bone
    hips = get_hips_bone(armature)
    if not hips:
        print("Hips bone not found! Tried: " + ", ".join(HIPS_BONE_NAMES))
        return
    
    # Remove horizontal hips motion from ALL actions
    for action in bpy.data.actions:
        remove_hips_horizontal_motion(action, hips)
    
    print("\nHips horizontal motion removal process done!")
    print("You can now export manually with FBX exporter")


if __name__ == "__main__":
    main()