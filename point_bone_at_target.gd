extends Skeleton3D

var left_arm_indices = []
# we include shoulder through index - we will need shoulder and index to get lengths of bones we care about
var left_arm_names = ['DEF-shoulder.L','DEF-upper_arm.L','DEF-upper_arm.L.001','DEF-forearm.L','DEF-forearm.L.001','DEF-hand.L','DEF-f_index.01.L']
var left_arm_lengths = []

var right_arm_indices = []
# we include shoulder through index - we will need shoulder and index to get lengths of bones we care about
var right_arm_names = ['DEF-shoulder.R','DEF-upper_arm.R','DEF-upper_arm.R.001','DEF-forearm.R','DEF-forearm.R.001','DEF-hand.R','DEF-f_index.01.R']
var right_arm_lengths = []


# Called when the node enters the scene tree for the first time.
@onready var target = get_owner().get_node('Target')
#@onready var BAs = [$BA0,$BA1,$BA2,$BA3,$BA4,$BA5,$BA6]

# Bone/Skeleton notes
# to_global(get_bone_global_pose(bone index)) will yield the actual global transform of the bone.
# 
# Overall transform of a bone W.R.T. Skeleton is rest pose / custom pose / pose
# "Global pose" is overall transform of the pose W.R.T. Skeleton
#
# Seems like when modifying bone poses need to:
# Determine local pose modification
# Convert to to global pose
# set_bone_global_pose_override(int bone idx, Transform3D pose, float amount, persistent = false)

# To convert a world transform from a Node3D to a global bone pose, multiply Transform3D.affine_inverse 
# origin for my skeleton is between the feet - as assigned in Blender

# Move a bone to have the same global transform as the "target" i.e.
# set_bone_global_pose_override(left_arm_indices[6], global_transform.affine_inverse()*target.global_transform,1.0,true)


func _ready():
	for each in left_arm_names: # get the index of each bone for later reference
		left_arm_indices.append(find_bone(each))
	for each in right_arm_names:
		right_arm_indices.append(find_bone(each))
	for i in range(1,len(left_arm_indices)): # we need bone lengths
		var displacement_vec = to_global(get_bone_global_pose(left_arm_indices[i]).origin)-to_global(get_bone_global_pose(left_arm_indices[i-1]).origin)
		#[0.17684707045555, 0.1122579574585, 0.1122579574585, 0.11647792905569, 0.11647795140743, 0.08506638556719]
		left_arm_lengths.append(displacement_vec.length())
	for i in range(1,len(right_arm_indices)): # we need bone lengths
		var displacement_vec = to_global(get_bone_global_pose(right_arm_indices[i]).origin)-to_global(get_bone_global_pose(right_arm_indices[i-1]).origin)
		#[0.17684707045555, 0.1122579574585, 0.1122579574585, 0.11647792905569, 0.11647795140743, 0.08506638556719]
		right_arm_lengths.append(displacement_vec.length())
	#for i in range(1,len(left_arm_indices)):
	print(left_arm_indices)
	print(left_arm_lengths)
	print(global_transform.origin)
	for i in range(len(left_arm_indices)):
		var l = get_bone_global_pose(left_arm_indices[i])
		var r = get_bone_global_pose(right_arm_indices[i])
		print(l.basis)
		print(r.basis)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	point_bone_at_target(left_arm_indices[1],left_arm_indices[2],target.global_transform.origin)
	
	#print(get_bone_rest(left_arm_indices[1]).basis)
	#print(get_bone_pose(left_arm_indices[1]).basis)
	#print(get_bone_global_pose(left_arm_indices[1]).basis)

func point_bone_at_target(bone_index,child_index,target):
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
