# we_have_FABRIK_at_home
This is a simple implementation of FABRIK (Forward And Backward Reaching Inverse Kinematics) to use before IK is reintroduced to Godot 4.

Absolutely nothing has been optimized, but it does work so far as I can tell - let me know if you find unexpected behavior.

Right now the main FABRIK function calls interpret_bone_chain(bone_idx_array) which assumes standard bone naming conventions in order to exclude bones that shouldn't rotate relative to their parents, so if your bones don't have such names you may need to tweak it a bit.

Also, it can handle multiple limbs simultaneously, but only the first limb should have FABRIK(...clear_override=true).  Otherwise only the final limb in the sequence will use FABRIK, as the others will have their custom poses cleared.
