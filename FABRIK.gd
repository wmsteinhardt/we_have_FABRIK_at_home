extends Skeleton3D

var left_arm_indices = []
# we include shoulder through index - we will need shoulder and index to get lengths of bones we care about
var left_arm_names = ['DEF-upper_arm.L','DEF-upper_arm.L.001','DEF-forearm.L','DEF-forearm.L.001','DEF-hand.L','DEF-f_index.01.L']
var left_arm_lengths = []

var right_arm_indices = []
# we include shoulder through index - we will need shoulder and index to get lengths of bones we care about
var right_arm_names = ['DEF-upper_arm.R','DEF-upper_arm.R.001','DEF-forearm.R','DEF-forearm.R.001','DEF-hand.R','DEF-f_index.01.R']
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
	print(interpret_bone_chain(left_arm_indices))
	#for i in range(1,len(left_arm_indices)):

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	#point_bone_at_global_target(left_arm_indices[1],left_arm_indices[2],target.global_transform.origin)
	FABRIK(right_arm_indices,get_tree().get_current_scene().get_node('Target'),0.001,2,true)
	FABRIK(left_arm_indices,get_tree().get_current_scene().get_node('Target'),0.001,2,false)
	if Input.is_action_just_released("ui_end"):
		FABRIK(left_arm_indices,get_tree().get_current_scene().get_node('Target'))
		FABRIK(right_arm_indices,get_tree().get_current_scene().get_node('Target'))
	if Input.is_action_just_released("ui_home"):
		clear_bones_global_pose_override()
		
func point_bone_at_global_target(bone_index,child_index,global_target):
	var t = get_bone_global_pose(bone_index)
	var axis_and_rot = get_axis_and_angle_to_point_bone_at_global_target(bone_index,child_index,global_target)
	t.basis = t.basis.rotated(axis_and_rot[0],axis_and_rot[1]) 
	if axis_and_rot[1] > 0.01:
		set_bone_global_pose_override(bone_index,t,1.0,true)
	else:
		print('Rotation angle was only ',axis_and_rot[1])
	
func get_axis_and_angle_to_point_bone_at_global_target(bone_index,child_index,global_target):
	# Vector describing current direction of the bone
	var current_vec = to_global(get_bone_global_pose(child_index).origin)-to_global(get_bone_global_pose(bone_index).origin)
	# Vector pointing from bone to the target position
	var targ_vec = (global_target - to_global(get_bone_global_pose(bone_index).origin))
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
				bone_lengths.append((get_bone_global_rest(bone_idx_array[i]).origin-get_bone_global_rest(bone_idx_array[i+1]).origin).length())
			else: # 
				var bone_1_length = (get_bone_global_rest(bone_idx_array[i]).origin-get_bone_global_rest(bone_idx_array[i+1]).origin).length()
				var bone_2_length = (get_bone_global_rest(bone_idx_array[i+1]).origin-get_bone_global_rest(bone_idx_array[i+2]).origin).length()
				bone_lengths.append(bone_1_length+bone_2_length)
		else: # all other bones can be transformed
			mod_idx.append(bone_idx_array[i])
			bone_lengths.append((get_bone_global_rest(bone_idx_array[i]).origin-get_bone_global_rest(bone_idx_array[i+1]).origin).length())
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
	# for last bone (first in array), calculate position as -bone_length*(direction to target).normalized()+target
	# for second in array, last bone's new position is target, repeat
	var current_target = target_position
	var dummy_vector = Vector3.ZERO
	var new_bone_pos = Vector3.ZERO
	for i in range(len(bone_positions)): # Note this adjusts all bones
		dummy_vector = current_target - bone_positions[i]
		new_bone_pos = -bone_lengths[i]*dummy_vector.normalized()+current_target
		new_bone_positions.append(new_bone_pos)
		current_target = new_bone_pos
	new_bone_positions.reverse() # Return seequence to original order
	return new_bone_positions
	
func forward_pass(bone_positions,bone_lengths,target_position,first_bone_pos):
	bone_positions[0] = first_bone_pos # this is constrained!
	var new_bone_positions = [first_bone_pos]
	# for first bone, calculate target position as bone_length*(direction to next bone position).normalized()+bone[0]
	# for second in array, third bone's new position is target, repeat
	var current_target = bone_positions[1]
	var dummy_vector = Vector3.ZERO
	var new_bone_pos = Vector3.ZERO
	for i in range(1,len(bone_positions)): # Here we respect the constraint on the first bone
		current_target = bone_positions[i]
		dummy_vector =  current_target-bone_positions[i-1]
		new_bone_pos = bone_lengths[i-1]*dummy_vector.normalized()+current_target
		new_bone_positions.append(new_bone_pos)
		current_target = new_bone_pos
	return new_bone_positions

func get_positions_to_aim_chain_at_global_target(bone_positions,bone_lengths,target_position):
	var target_direction = (to_local(target_position) - bone_positions[0]).normalized() # direction is same for all
	var new_bone_positions = [bone_positions[0]] # start with position of anchor bone, which does not move
	for i in range(1,len(bone_positions)):
		# append each subsequent position as the previous + target vector*bone length
		new_bone_positions.append(new_bone_positions[i-1]+target_direction*bone_lengths[i])
	#print('last bone position old/new: ',bone_positions[-1],new_bone_positions[-1])
	
	return new_bone_positions

func apply_transforms(bone_idx_array,bone_positions,terminal_bone_idx,global_target_position):
	var global_positions = []
	bone_idx_array.append(terminal_bone_idx) # this guarantees that the last bone identified in the chain is also pointed.
	for each in bone_positions: # for each of the bone positions, formerly in the skeleton frame, get global position
		global_positions.append(to_global(each))
	for i in range(len(bone_idx_array)-2):
		# for each bone in in the array, point it at the location specified for its child
		#print(get_bone_name(bone_idx_array[i]),', ',get_bone_name(bone_idx_array[i+1]))
		point_bone_at_global_target(bone_idx_array[i],bone_idx_array[i+1],global_positions[i+1])#global_positions[i+1])
	# point the hand or last bone at the actual target itself!
	point_bone_at_global_target(bone_idx_array[-2],bone_idx_array[-1],global_target_position)


func FABRIK(bone_idx_array,target_node,threshold=0.01,max_passes = 10,clear_override=false):
	if clear_override:
		clear_bones_global_pose_override()
	# a better version of this won't depend on the previous line - should change to take existing
	# pose transforms and modify from those, or figure out some other means that allows interpolation
	var target_position = to_local(target_node.global_transform.origin)
	var modIdx_lengths_totalLength = interpret_bone_chain(bone_idx_array)
	var mod_idx_array = modIdx_lengths_totalLength[0] # the bones to be moved
	var bone_lengths = modIdx_lengths_totalLength[1] # the interpreted lengths
	var total_length = modIdx_lengths_totalLength[2] # the total length of the limb
	var current_bone_positions = get_bone_array_global_positions(mod_idx_array) # in skeleton frame
	var new_bone_positions = current_bone_positions.duplicate(true) # for starters!
	var first_bone_position = get_bone_global_pose(mod_idx_array[0]).origin
	if total_length < (target_position - current_bone_positions[0]).length():
		# new_bone_positions are always in skeleton frame 
		new_bone_positions = get_positions_to_aim_chain_at_global_target(current_bone_positions,bone_lengths,to_global(target_position))
	else: # execute FABRIK if final bone in chain not closer than threshold
		var passes = 0
		while (new_bone_positions[-1] - target_position).length() > threshold and passes < max_passes:
			new_bone_positions = backward_pass(new_bone_positions,bone_lengths,target_position)
			new_bone_positions = forward_pass(new_bone_positions,bone_lengths,target_position,first_bone_position)
			passes += 1
	var already_set = true
	for i in range(len(new_bone_positions)):
		if not new_bone_positions[i].is_equal_approx(current_bone_positions[i]):
			already_set = false
	if not already_set:
		print('new: ',new_bone_positions)
							#bone_idx_array,bone_positions,terminal_bone_idx,global_target_position
		apply_transforms(mod_idx_array,new_bone_positions,bone_idx_array[-1],target_node.global_transform.origin)
	
