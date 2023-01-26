extends Skeleton3D

var left_arm_indices = []
# we include shoulder through index - we will need shoulder and index to get lengths of bones we care about
var left_arm_names = ['DEF-shoulder.L','DEF-upper_arm.L','DEF-upper_arm.L.001','DEF-forearm.L','DEF-forearm.L.001','DEF-hand.L','DEF-f_index.01.L']
var left_arm_lengths = []

var right_arm_indices = []
# we include shoulder through index - we will need shoulder and index to get lengths of bones we care about
var right_arm_names = ['DEF-shoulder.R','DEF-upper_arm.R','DEF-upper_arm.R.001','DEF-forearm.R','DEF-forearm.R.001','DEF-hand.R','DEF-f_index.01.R']
var right_arm_lengths = []
var counter = 0


var set = false
# Called when the node enters the scene tree for the first time.
@onready var target = get_owner().get_node('Target')
@onready var BAs = [$BA0,$BA1,$BA2,$BA3,$BA4,$BA5,$BA6]

# Bone/Skeleton notes
# to_global(get_bone_global_pose(bone index)) will yield the actual global transform of the bone.
# 
# Overall transform of a bone W.R.T. Skeleton is rest pose / custom pose / pose
# "Global pose" is overall transform of the pose W.R.T. Skeleton
#
# Seems like when modifying bone poses need to:
# Determine local pose modification
# Conver to to global pose
# set_bone_global_pose_override(int bone idx, Transform3D pose, float amount, persistent = false)

# To convert a world transform from a Node3D to a global bone pose, multiply Transform3D.affine_inverse 
# origin for my skeleton is between the feet - as assigned in Blender

# Move a bone to have the same global transform as the "target"
# set_bone_global_pose_override(left_arm_indices[6], global_transform.affine_inverse()*target.global_transform,1.0,true)
# global_transform.affine_inverse()*target.global_transform # <- gets the target position in skeleton coordinate system

func _ready():
	set = false
	for each in left_arm_names: # get the index of each bone for later reference
		left_arm_indices.append(find_bone(each))
	for each in right_arm_names:
		right_arm_indices.append(find_bone(each))
	print('Interpret chain results: ')
	print(interpret_bone_chain(right_arm_indices))
	#for i in range(1,len(left_arm_indices)):
	print(left_arm_indices)
	print(global_transform.origin)
	for i in range(len(left_arm_indices)):
		var l = get_bone_global_pose(left_arm_indices[i])
		var r = get_bone_global_pose(right_arm_indices[i])
		print(l.basis)
		print(r.basis)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	#point_bone_at_global_target(left_arm_indices[1],left_arm_indices[2],target.global_transform.origin)
	if counter < 1:
		FABRIK(left_arm_indices,get_tree().get_current_scene().get_node('Target'))
	counter += 1
	

func point_bone_at_global_target(bone_index,child_index,target):
	var t = get_bone_global_pose(bone_index)
	var axis_and_rot = get_axis_and_angle_to_point_bone_at_global_target(bone_index,child_index,target)
	t.basis = t.basis.rotated(axis_and_rot[0],axis_and_rot[1]) 
	set_bone_global_pose_override(bone_index,t,1.0,true)
	
func get_axis_and_angle_to_point_bone_at_global_target(bone_index,child_index,target):
	# Vector describing current direction of the bone
	var current_vec = to_global(get_bone_global_pose(child_index).origin)-to_global(get_bone_global_pose(bone_index).origin)
	# Vector pointing from bone to the target position
	var targ_vec = (target - to_global(get_bone_global_pose(bone_index).origin))
	# Normalize both vectors
	targ_vec = targ_vec.normalized()
	current_vec = current_vec.normalized()
	# Calculate the angle (independent of coordinate frame!)
	var angle_to_rot = current_vec.angle_to(targ_vec)
	# Calculate the rotation axis
	var rotation_axis = current_vec.cross(targ_vec)
	rotation_axis = rotation_axis.normalized()
	
	return [rotation_axis,angle_to_rot]

func interpret_bone_chain(bone_idx_array): # Suitable for Rigify-style bone nomenclature
	# last bone in sequence should NOT be a bone intended to be manipulated in FABRIK
	var mod_idx = []
	var bone_lengths = []
	for i in range(len(bone_idx_array)-1): 
		if '01' in get_bone_name(bone_idx_array[i]): # implies a bone not at a joint - keep aligned to parent
			continue
		elif '01' in get_bone_name(bone_idx_array[i+1]): # if next bone is 01, add its length to parents for FABRIK
			mod_idx.append(bone_idx_array[i])
			if i+2 == len(bone_idx_array): # if bone '01' is the last bone of chain
				bone_lengths.append((get_bone_global_pose(bone_idx_array[i]).origin-get_bone_global_pose(bone_idx_array[i+1]).origin).length())
			else: # 
				var bone_1_length = (get_bone_global_pose(bone_idx_array[i]).origin-get_bone_global_pose(bone_idx_array[i+1]).origin).length()
				var bone_2_length = (get_bone_global_pose(bone_idx_array[i+1]).origin-get_bone_global_pose(bone_idx_array[i+2]).origin).length()
				bone_lengths.append(bone_1_length+bone_2_length)
		else: # all other bones can be transformed
			mod_idx.append(bone_idx_array[i])
			bone_lengths.append((get_bone_global_pose(bone_idx_array[i]).origin-get_bone_global_pose(bone_idx_array[i+1]).origin).length())
	#mod_idx.append(bone_idx_array[-1]) # keep the last 
	var total_length = 0
	for each in bone_lengths:
		total_length = total_length + each
	# return array of bones to be transformed, their lengths, and the total length
	return [mod_idx,bone_lengths,total_length]

func get_bone_array_global_positions(bone_idx_array):
	var bone_positions = []
	for idx in bone_idx_array:
		bone_positions.append(get_bone_global_pose(idx).origin)
	return bone_positions
	
func backward_pass(bone_positions,bone_lengths,target_position): # This function calculates an array of positions and vectors, but does not move bones
	# works in skeleton coordinate system - target should already be in skeleton coordinate system
	# also assumes that target already determined to be within reach
	bone_positions.reverse() # flip the array for backwards pass
	var new_bone_positions = []
	# for last bone (first in array), calculate position as -(direction to target).normalized()+target
	# for second in array, last bone's new position is target, repeat
	var current_target = target_position
	var dummy_vector = Vector3.ZERO
	var new_bone_pos = Vector3.ZERO
	for i in range(len(bone_positions)): # Note this adjusts all bones
		dummy_vector = current_target - bone_positions[i]
		new_bone_pos = -dummy_vector.normalized()+current_target
		new_bone_positions.append(new_bone_pos)
		current_target = new_bone_pos
	new_bone_positions.reverse() # Return seequence to original order
	return new_bone_positions
	
func forward_pass(bone_positions,bone_lengths,target_position,first_bone_pos):
	bone_positions[0] = first_bone_pos # this is constrained!
	var new_bone_positions = [first_bone_pos]
	# for first bone, calculate position as (direction to next bone position).normalized()+bone[0]
	# for second in array, last bone's new position is target, repeat
	var current_target = target_position
	var dummy_vector = Vector3.ZERO
	var new_bone_pos = Vector3.ZERO
	for i in range(1,len(bone_positions)): # Here we respect the constraint on the first bone
		current_target = bone_positions[i-1]
		dummy_vector = bone_positions[i] - current_target
		new_bone_pos = dummy_vector.normalized()+current_target
		new_bone_positions.append(new_bone_pos)
		current_target = new_bone_pos
	return new_bone_positions

func get_positions_to_aim_chain_at_target(bone_positions,bone_lengths,target_position):
	var target_direction = (target_position - bone_positions[0]).normalized()
	var new_bone_positions = [bone_positions[0]]
	for i in range(1,len(bone_positions)):
		new_bone_positions.append(bone_positions[i-1]+target_direction*bone_lengths[i])
	return new_bone_positions

func apply_transforms(bone_idx_array,bone_positions,terminal_bone_idx,global_target_position):
	var global_positions = []
	bone_idx_array.append(terminal_bone_idx)
	for each in bone_positions:
		global_positions.append(to_global(each))
	for i in range(len(bone_idx_array)-2):
		point_bone_at_global_target(bone_idx_array[i],bone_idx_array[i+1],global_positions[i+1])
	point_bone_at_global_target(bone_idx_array[-2],bone_idx_array[-1],global_target_position)


func FABRIK(bone_idx_array,target_node,threshold=0.1,max_passes = 15):
	# Get the target node position in the skeleton frame
	var target_position = (global_transform.affine_inverse()*target_node.global_transform).origin
	var modIdx_lengths_totalLength = interpret_bone_chain(bone_idx_array)
	var mod_idx_array = modIdx_lengths_totalLength[0] # the bones to be moved
	var bone_lengths = modIdx_lengths_totalLength[1] # the interpreted lengths
	var total_length = modIdx_lengths_totalLength[2] # the total length of the limb
	var current_bone_positions = get_bone_array_global_positions(mod_idx_array)
	var new_bone_positions = current_bone_positions # for starters!
	var first_bone_position = get_bone_global_pose(mod_idx_array[0]).origin
	if total_length < (target_position - current_bone_positions[0]).length():
		print('out of reach!')
		new_bone_positions = get_positions_to_aim_chain_at_target(current_bone_positions,bone_lengths,target_position)
	else: # execute FABRIK if final bone in chain not closer than threshold
		var passes = 0
		while (new_bone_positions[-1] - target_position).length() > threshold or passes < max_passes:
			new_bone_positions = backward_pass(new_bone_positions,bone_lengths,target_position)
			new_bone_positions = forward_pass(new_bone_positions,bone_lengths,target_position,first_bone_position)
			passes += 1
	apply_transforms(mod_idx_array,new_bone_positions,bone_idx_array[-1],target_node.global_transform.origin)
	
