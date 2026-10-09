#Define all variables for the mesh

#r1 is the half-width of cruciform rod
#r2 is the length of that rod total
r1 = 1.5

#r2 is ideally 2r1 + 6*r4
r2 = 33.0
#n1 and n2 are the number of nodes per side on the short and long sides of the cruciform
n1 = 5.0
n2 = 20.0

#r3 is the offset of the bundle centers
# re is ideally distance between the edge of the bundle and the center(ideally 2 r1) plus 20 for the center of the bundle
r3 = 23.0

#r4 is the width of square pin
r4 = 5.0
#r5 is the width of a square bundle
r5 = 40
#r7 is half-width of bundle
r7 = 20

#r6 is the half-width of the whole quad structure, which would be 2 bundle half-widths plus 2 r3 or 40+2*r3
r6 = 44.0

#r11 is quarterwide of quad structure
r11 = 22.0

#r9 is the half-width of the cartesian boundary
r9 = 45.0

#r10 is the width of the cartestian boundary
r10 = 90.0

#r12 is the width of the quad structure
r12 = 88.0

#r-13 is the squaresze for dummy2
r13 = 44.5

#r8 is the number of sectors per side for dummys and bundles
r8 = 80.0

#Set pitch between nodes for all bundles and part bundles
nodal_pitch = 2

#Bound is how big the large core pattern boundary is
bound = '${fparse ((r12)*15)+16}'

#fpitch is distance between bundles for flex
fpitch = '${fparse (r3*2)}'

#pitch is the pitch of the centers of the blocks from each other (should be double half-width or 90)
pitch = '${fparse ((r6)*2)+1}'

#ppitch is the water pin polygon size, as polygon size is half equivalent square size
ppitch = '${fparse (r4/2)}'

#spitch is the boundary size for the mesh for 1 single bundle going into a core ready mesh
spitch = '${fparse r5+2}'

#dpitch is the offset used when making the polyline for creating dummy meshes for partial Bundles
dpitch = '${fparse r6-spitch}'

#gpitch is the pitch of the gap between two mirrored
gpitch = '${fparse (2*r1)-((spitch-r5)/2)}'

#Quad width divided by node pitch
quad_sectors = '${fparse r12/nodal_pitch}'

#Single width divided by node pitch
single_sectors = '${fparse spitch/nodal_pitch}'

#Dummy width divided by node pitch
dummy_sectors = '${fparse r12/nodal_pitch}'

#We need to get the double dumy up to quad_sectiors, but it starts with one node, so we add one less
double_dummy_added = '${fparse quad_sectors-1}'

#irad is the radius of the inner periphery. It is one more quad width than the real value of 15. Using r6 as this is radius, so we want the "half width" of quads, or r6
irad = '${fparse r6*16}'

[Functions]
  #Depreciated method of getting larger bundle size
  [ss]
    # fn
    type = ParsedFunction
    expression = '8 * side'
    symbol_names = 'side'
    symbol_values = ${r4}
  []
[]
[Mesh]
  #When debugging, we can stop the code early using this line
  #final_generator = Core_final

  #This is coded in the MOOSE framework to make a BWR-core mesh

  #basic code form:

  # Code is broken into generator blocks defined by sets of [] [], where the block name is put into the first block
  # Each generator block has a type, inputs, and the output is itself
  # Complex Meshes are created by chaining these generators together

  # To reference the output of a block "block1" into another block "block2", it looks like so:
  # [block1]
  # []
  # [block2]
  # type = sometype
  # input = block1
  # []

  #Most MOOSE basic mesh generators work in 2d only, so you create a 2D map of the reactor core, then extrude it into 3d

  # is the comment syntax, there are no multi-line comments in MOOSE

  #I will not explain what each thing does, just what I am accomplishing, or something interesting, read the MOOSE docs, found at the following link
  # MOOSE docs: https://mooseframework.inl.gov/syntax/index.html


  ####### Begin generating 2d map

  #Generates the Dummy pin for use in bundle mesh
  [Dummy_pin]
    type = CartesianConcentricCircleAdaptiveBoundaryMeshGenerator
    num_sectors_per_side = '${dummy_sectors} ${dummy_sectors} ${dummy_sectors} ${dummy_sectors}'
    square_size = ${r12}
    background_block_ids = 6
    background_block_names = 'Dummy'
  []

  ######## Begin Creating Control Rod Mesh


  #Center of Rod
  [central_hub]
    type = GeneratedMeshGenerator
    dim = 2
    nx = ${n1}
    ny = ${n1}
    xmin = -${r1}
    xmax = ${r1}
    ymin = -${r1}
    ymax = ${r1}
    subdomain_ids = 3
    subdomain_name = 'Control_Rod'
  []

  #One horizontal blade
  [blade_horizontal]
    type = GeneratedMeshGenerator
    dim = 2
    nx = ${n2}
    ny = ${n1}
    xmin = ${r1} # Starts outside center piece
    xmax = ${r2} # Total length of the arm
    ymin = -${r1} # Half-thickness of the blade
    ymax = ${r1} # Half-thickness of the blade
    subdomain_ids = 3
    subdomain_name = 'Control_Rod'
  []

  # Rotate the horizontal blade by 90 degrees to make the vertical blade
  [blade_vertical]
    type = GeneratedMeshGenerator
    dim = 2
    nx = ${n1}
    ny = ${n2}
    xmin = -${r1} # Half-thickness of the blade
    xmax = ${r1} # Half-thickness of the blade
    ymin = ${r1} # Starts outside center piece
    ymax = ${r2} # Total length of the arm
    subdomain_ids = 3
    subdomain_name = 'Control_Rod'
  []

  #Mirror the horizontal blade
  [blade_horizontal_flipped]

    type = SymmetryTransformGenerator
    input = blade_horizontal
    mirror_point = '0.0 0.0 0.0' # A point on the mirror plane/line
    mirror_normal_vector = '1.0 0.0 0.0' # Normal vector of the mirror plane (reflects across x=-y)
  []

  #Reassign boundaries so the left and right are "correct"
  [blade_horizontal_cross]
    type = RenameBoundaryGenerator
    input = blade_horizontal_flipped
    new_boundary = 'left right'
    old_boundary = 'right left'
  []

  #Mirror the vertical blade
  [blade_vertical_flipped]
    # Mirrors across both axes to complete the 4 arms
    type = SymmetryTransformGenerator
    input = blade_vertical
    mirror_point = '0.0 0.0 0.0' # A point on the mirror plane/line
    mirror_normal_vector = '0.0 1.0 0.0' # Normal vector of the mirror plane (reflects across x=-y)
  []

  #Reassign boundaries so the left and right are "correct"
  [blade_vertical_cross]
    type = RenameBoundaryGenerator
    input = blade_vertical_flipped
    new_boundary = 'top bottom'
    old_boundary = 'bottom top'
  []

  #Combine the two horizontal blades and the central hub
  [blade_horizontal_combo]
    type = StitchMeshGenerator
    inputs = 'blade_horizontal_cross central_hub blade_horizontal'
    stitch_boundaries_pairs = 'right left;
                               right left'
    merge_boundaries_with_same_name = true
    clear_stitched_boundary_ids = true
  []

  #Combine the vertical blades and the previous assembly to get final control rod
  [cruciform_mesh]
    type = StitchMeshGenerator
    # setup
    # blade v
    # blade h
    # blade v cross
    inputs = 'blade_vertical blade_horizontal_combo blade_vertical_cross'
    stitch_boundaries_pairs = 'bottom top;
                               bottom top'
    merge_boundaries_with_same_name = true
    clear_stitched_boundary_ids = true
    #inputs = 'blade_horizontal_cross blade_vertical_cross'
  []

  #Begin creating rest of fuel bundle

  #Create fuel pin
  [Fuel_pin]
    type = CartesianConcentricCircleAdaptiveBoundaryMeshGenerator
    num_sectors_per_side = '4 4 4 4'
    square_size = ${r4}
    ring_intervals = '1 1'
    ring_radii = '1.8 2'
    ring_block_ids = '1 2'
    ring_block_names = 'fuel cladding'
    background_intervals = 1
    background_block_ids = 4
    background_block_names = 'water'
  []

  #Create Water pin/Water Channel
  [Water_pin]
    type = PolygonConcentricCircleMeshGenerator
    num_sides = 4
    num_sectors_per_side = '4 4 4 4'
    polygon_size = ${ppitch}
    ring_intervals = '1 1'
    ring_radii = '1.8 2'
    ring_block_ids = '4 2'
    ring_block_names = 'water cladding'
    quad_center_elements = true
    flat_side_up = true
    background_intervals = 1
    background_block_ids = 4
    background_block_names = 'water'
    quad_element_type = QUAD4
  []

  #Create one combined bundle mesh
  #In a 4 fuel bundle assembly, this would be the top right bundle
  [Bundle_Mesh_gen]
    type = PatternedCartesianMeshGenerator
    inputs = 'Fuel_pin Water_pin'
    pattern = '0 0 0 0 0 0 0 0;
               0 0 0 0 0 0 0 0;
               0 0 0 0 0 0 0 0;
               0 0 0 1 0 0 0 0;
               0 0 0 0 1 0 0 0;
               0 0 0 0 0 0 0 0;
               0 0 0 0 0 0 0 0;
               0 0 0 0 0 0 0 0'
    square_size = ${r5}
    background_block_id = 4
    background_block_name = 'water'
  []

  #Begin some trickery to make parts of the bundle play nice

  #Pull out the water section of the bundle
  [Bundle_meshw]
    type = BlockToMeshConverterGenerator
    input = Bundle_Mesh_gen
    target_blocks = '4'
  []

  #Pull out the rest of the bundle mesh
  [Bundle_mesho]
    type = BlockToMeshConverterGenerator
    input = Bundle_Mesh_gen
    target_blocks = '1 2'
  []

  #Convert the water section to TRI3 mesh elements so it will place nice with later sections
  [Bundle_meshwconv]
    type = ElementsToSimplicesConverter
    input = Bundle_meshw
  []

  #Recombine the now TRI3 water and the other mesh sections
  [Bundle_Mesh_combined]
    type = CombinerGenerator
    inputs = 'Bundle_mesho Bundle_meshwconv'
  []
  #[Bundle_Mesh_internal_add_fuel_clad]
  #  type = SideSetsBetweenSubdomainsGenerator
  #  input = Bundle_Mesh_combined
  #  primary_block = '1'
  #  paired_block = '2'
  #  new_boundary = 'fuel_cladding_boundary'
  #[]

  #Redefine the boundaries of the Mesh for stitching later
  [Bundle_Mesh_add_outer_bounds]
    type = SideSetsFromNormalsGenerator
    input = Bundle_Mesh_combined
    normals = '1 0 0   -1 0 0   0 1 0   0 -1 0' # Right, Left, Top, Bottom
    new_boundary = 'outer_x_pos outer_x_neg outer_y_pos outer_y_neg'
  []

  #Now turn those 4 outer boundaries into 1 combined Mesh
  [Bundle_Mesh_merge_outer_bounds]
    type = RenameBoundaryGenerator
    input = Bundle_Mesh_add_outer_bounds
    old_boundary = 'outer_x_pos outer_x_neg outer_y_pos outer_y_neg'
    new_boundary = 'bundle_ext bundle_ext bundle_ext bundle_ext'
  []

  #Now fix any issues that arose during Stitching and boundary repair
  [Bundle_Mesh]
    type = MeshRepairGenerator
    input = Bundle_Mesh_merge_outer_bounds
    fix_node_overlap = true
    merge_boundary_ids_with_same_name = true
  []

  #Now begin making Assembly, containing four bundles and a control rod

  #Flip the bundle mesh to get the top left mesh
  [Bundle_flip]
    type = SymmetryTransformGenerator
    mirror_normal_vector = '0 1 0'
    mirror_point = '0 0 0'
    input = 'Bundle_Mesh'
  []

  #Construct the four bundle, control rod combined mesh
  [Bundle_quad]
    type = FlexiblePatternGenerator
    boundary_type = CARTESIAN
    boundary_size = ${r12} #Defined in terms of bundle sizes in variable section
    boundary_sectors = ${quad_sectors}
    inputs = 'Bundle_Mesh Bundle_flip cruciform_mesh'
    rect_patterns = '0;
                     1|
                     0;
                     1|
                     3 2 3'
                     #Define patterns of meshes, note the first one is repeated
                     #Notice the index 3 on the last pattern, putting any index higher than the max provided (we have 0-2) will be interpreted as blank space
    rect_origins = ' ${r3} 0 0
                    -${r3} 0 0
                        0  0 0'
                    #We then put one of those repeated meshes on the right, and one on the left
    rect_pitches_x = '${fpitch} ${fpitch} 1'
    rect_pitches_y = '${fpitch} ${fpitch} 1'
    rect_rotations = '0.0 180.0 0.0'
    desired_area = 5
    background_subdomain_id = 4
    background_subdomain_name = 'water'
  []


  # BWRS need some assemblies for the edges of the core that don't contain a control rod, and only one or tow bundles

  #Section of the edge assemblies with single fuel bundles

  #Create fuel bundle for top right
  [Bundle_singleRT_part]
    type = FlexiblePatternGenerator
    boundary_type = CARTESIAN
    boundary_size = ${spitch}
    boundary_sectors = ${single_sectors}
    inputs = 'Bundle_Mesh'
    rect_patterns = '0'
    rect_origins = '0 0 0'
    rect_pitches_x = '1'
    rect_pitches_y = '1'
    rect_rotations = '0.0'
    desired_area = 5
    background_subdomain_id = 4
    background_subdomain_name = 'water'
    external_boundary_name = "bundle_ext2"
    external_boundary_id = 999
  []

  #Then move it out of the center to it's correct spot in the "corner" of the space
  [Bundle_singleRT_mov]
    type = TransformGenerator
    input = Bundle_singleRT_part
    transform = TRANSLATE
    vector_value = '${r3} ${r3} 0'
  []

  #Do this for the Left side bundle as well by reflecting over the x axis
  [Bundle_singleLT_mov]
    type = SymmetryTransformGenerator
    mirror_normal_vector = '1 0 0'
    mirror_point = '0 0 0'
    input = 'Bundle_singleRT_mov'
  []

  #To properly make the core later, we need to fill the empty space in the assembly with dummy space

  #Generate boudnary for dummy space of single bundle in top right
  [Dummy_boundary_singleRT]
    # The two notch segments are 42 long; 20 added nodes -> 21 intervals of
    # exactly 2.0, which now matches the bundle patch node pitch.
    type = PolyLineMeshGenerator
    points = '${dpitch}  ${dpitch} 0
              ${dpitch}   ${r6} 0
              -${r6} ${r6} 0
              -${r6} -${r6} 0
              ${r6} -${r6} 0
              ${r6} ${dpitch} 0
    '
    loop = true
  []

  #Now fill in that dummy space
  [Dummy_fill_singleRT]
    type = XYDelaunayGenerator
    boundary = 'Dummy_boundary_singleRT'
    add_nodes_per_boundary_segment = 20
    refine_boundary = false
    desired_area = 10
    output_boundary = 'Dummy_boundRT'
    output_subdomain_id = 6
    output_subdomain_name = 'Dummy'
  []

  #Now combine the actual fuel bundle and the dummy area
  [Bundle_singleRT_combo]
    type = StitchMeshGenerator
    inputs = "Dummy_fill_singleRT Bundle_singleRT_mov"
    stitch_boundaries_pairs = 'Dummy_boundRT bundle_ext2'
    clear_stitched_boundary_ids = true
  []

  #Now flip over the x axis to get a single bundle in the bottom right
  [Bundle_singleRB_combo]
    type = SymmetryTransformGenerator
    mirror_normal_vector = '0 1 0'
    mirror_point = '0 0 0'
    input = 'Bundle_singleRT_combo'
  []

  #Flip single top right over y axis to get single top left
  [Bundle_singleLT_combo]
    type = SymmetryTransformGenerator
    mirror_normal_vector = '1 0 0'
    mirror_point = '0 0 0'
    input = 'Bundle_singleRT_combo'
  []

  #Flip single top left over x axis to get bottom left
  [Bundle_singleLB_combo]
    type = SymmetryTransformGenerator
    mirror_normal_vector = '0 1 0'
    mirror_point = '0 0 0'
    input = 'Bundle_singleLT_combo'
  []

  #The way we created these is incompatible with later tools, so we need to add metadata to make it usable by later generators
  [Bundle_singleRT]
    type = AddMetaDataGenerator
    input = Bundle_singleRT_combo

    # Define pitch for PatternedCartesianMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []

  #Add the MetaData for left top mesh
  [Bundle_singleLT]
    type = AddMetaDataGenerator
    input = Bundle_singleLT_combo

    # Define pitch for PatternedCartesianMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []

  #Add the MetaData for right bottom mesh
  [Bundle_singleRB]
    type = AddMetaDataGenerator
    input = Bundle_singleRB_combo

    # Define pitch for PatternedCartesianMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []

  #Add the MetaData for left bottom mesh
  [Bundle_singleLB]
    type = AddMetaDataGenerator
    input = Bundle_singleLB_combo

    # Define pitch for PatternedCartesianMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []


  #Now begin creating assemblies with two bundles next to each other, on top, bottom, on the right, and on the left

  #Create the boundary that exists between two single fuel bundles where a control rod normally is, as we need to fill that with water
  [Bundle_gapT_boundary]
    type = PolyLineMeshGenerator
    loop = true
    # We need to match the number of line segments on the edges of the fuel bundles with this filler, so we must define lots of points by hand : (
    points = '2 44 0
              0 44 0
              -2 44 0
              -2 42 0
              -2 40 0
              -2 38 0
              -2 36 0
              -2 34 0
              -2 32 0
              -2 30 0
              -2 28 0
              -2 26 0
              -2 24 0
              -2 22 0
              -2 20 0
              -2 18 0
              -2 16 0
              -2 14 0
              -2 12 0
              -2 10 0
              -2 8 0
              -2 6 0
              -2 4 0
              -2 2 0
              0 2 0
              2 2 0
              2 4 0
              2 6 0
              2 8 0
              2 10 0
              2 12 0
              2 14 0
              2 16 0
              2 18 0
              2 20 0
              2 22 0
              2 24 0
              2 26 0
              2 28 0
              2 30 0
              2 32 0
              2 34 0
              2 36 0
              2 38 0
              2 40 0
              2 42 0'
  []

  #Now we fill in that gap
  [Bundle_gapT_fill]
    type = XYDelaunayGenerator
    boundary = 'Bundle_gapT_boundary'
    add_nodes_per_boundary_segment = 0
    refine_boundary = false
    desired_area = 5
    output_boundary = 'bundle_bound_gapT'
    output_subdomain_id = 4
    output_subdomain_name = 'water'
  []

  #Now we combine the gap and the left top and right top fuel bundles to create a double bundle mesh for the top of an assembly
  [Bundle_doubleT_part]
    type = StitchMeshGenerator
    inputs = 'Bundle_singleLT_mov Bundle_gapT_fill Bundle_singleRT_mov'
    stitch_boundaries_pairs = 'bundle_ext2 bundle_bound_gapT;bundle_bound_gapT bundle_ext2'
    clear_stitched_boundary_ids = true
  []

  #Create dummy boundary for rest of assembly
  [Dummy_boundary_doubleT]
    type = PolyLineMeshGenerator
    points = '${r6}  -${r6} 0
              ${r6}   ${dpitch} 0
              -${r6} ${dpitch} 0
              -${r6} -${r6} 0
    '
    loop = true
  []

  #fill in dummy boundary
  [Dummy_fill_doubleT]
    type = XYDelaunayGenerator
    boundary = 'Dummy_boundary_doubleT'
    add_nodes_per_boundary_segment = ${double_dummy_added}
    refine_boundary = false
    desired_area = 10
    output_boundary = 'Dummy_boundT'
    output_subdomain_id = 6
    output_subdomain_name = 'Dummy'
  []

  #Now we stitch together top and bottom of assembly
  [Bundle_doubleT_combo]
    type = StitchMeshGenerator
    inputs = "Dummy_fill_doubleT Bundle_doubleT_part"
    stitch_boundaries_pairs = 'Dummy_boundT bundle_ext2'
    clear_stitched_boundary_ids = true
  []

  #Now we can just rotate the top double bundle to get the rest

  [Bundle_doubleL_combo]
    type = TransformGenerator
    input = Bundle_doubleT_combo
    transform = ROTATE
    vector_value = '0 0 90'
  []
  [Bundle_doubleB_combo]
    type = TransformGenerator
    input = Bundle_doubleL_combo
    transform = ROTATE
    vector_value = '0 0 90'
  []
  [Bundle_doubleR_combo]
    type = TransformGenerator
    input = Bundle_doubleB_combo
    transform = ROTATE
    vector_value = '0 0 90'
  []

  #We must once again attach metadata to all 4 meshes
  [Bundle_doubleT]
    type = AddMetaDataGenerator
    input = Bundle_doubleT_combo

    # Define pitch dimensions for CartesianPatternedMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []
  [Bundle_doubleR]
    type = AddMetaDataGenerator
    input = Bundle_doubleR_combo

    # Define pitch dimensions for CartesianPatternedMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []
  [Bundle_doubleB]
    type = AddMetaDataGenerator
    input = Bundle_doubleB_combo

    # Define pitch dimensions for CartesianPatternedMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []
  [Bundle_doubleL]
    type = AddMetaDataGenerator
    input = Bundle_doubleL_combo

    # Define pitch dimensions for CartesianPatternedMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []

  #We have now created all assemblies we need to make a core!!!


  #We want a core that is circular, but we must build a sqaure shape
  #We can do this by using that dummy fuel element we made earlier

  #Create Rough core shape
  [Core_rough]
    type = PatternedCartesianMeshGenerator
    # IDS
    # Quad=0
    # Singles: LB=1 RB=2 LT=3 RT=4
    # Doubles: R=5 L=6 T=7 B=8
    # Dummy=9
    pattern_boundary = none
    generate_core_metadata = true
    inputs = 'Bundle_quad Bundle_singleLB Bundle_singleRB Bundle_singleLT Bundle_singleRT Bundle_doubleR Bundle_doubleL Bundle_doubleT Bundle_doubleB Dummy_pin'
    pattern = '9 9 9 9 8 0 0 0 0 0 8 9 9 9 9;
               9 9 2 0 0 0 0 0 0 0 0 0 1 9 9;
               9 2 0 0 0 0 0 0 0 0 0 0 0 1 9;
               9 0 0 0 0 0 0 0 0 0 0 0 0 0 9;
               5 0 0 0 0 0 0 0 0 0 0 0 0 0 6;
               0 0 0 0 0 0 0 0 0 0 0 0 0 0 0;
               0 0 0 0 0 0 0 0 0 0 0 0 0 0 0;
               0 0 0 0 0 0 0 0 0 0 0 0 0 0 0;
               0 0 0 0 0 0 0 0 0 0 0 0 0 0 0;
               0 0 0 0 0 0 0 0 0 0 0 0 0 0 0;
               5 0 0 0 0 0 0 0 0 0 0 0 0 0 6;
               9 0 0 0 0 0 0 0 0 0 0 0 0 0 9;
               9 4 0 0 0 0 0 0 0 0 0 0 0 3 9;
               9 9 4 0 0 0 0 0 0 0 0 0 3 9 9;
               9 9 9 9 7 0 0 0 0 0 7 9 9 9 9'
  []

  #We assigned the same block ID and name to the dummy fuel elements, and the filled in space in the single and double bundle assemblies

  #Delete all dummy mesh area
  [Core_clean]
    type = BlockDeletionGenerator
    input = 'Core_rough'
    block = 'Dummy'
    new_boundary = 'Core_ext'
  []

  #We need to do boundary repair, just like with the bundles after converting the water
  [Core_clean_add_outer_bounds]
    type = SideSetsFromNormalsGenerator
    input = Core_clean
    normals = '1 0 0   -1 0 0   0 1 0   0 -1 0'
    new_boundary = 'outer_x_pos outer_x_neg outer_y_pos outer_y_neg'
  []

  #Now we cleanup that fixed core
  [Core_clean_repair]
    type = MeshRepairGenerator
    input = Core_clean_add_outer_bounds
    fix_node_overlap = true
    merge_boundary_ids_with_same_name = true
  []

  #The core is just in empty space, but we know there should be coolant flowing around the core in the circular containment

  #Make a periphery mesh around the core to add in that missing water
  [Core_periph1]
    type = PeripheralTriangleMeshGenerator
    input = Core_clean_repair
    peripheral_ring_num_segments = 100
    peripheral_ring_radius = ${irad}
    desired_area = 200
    peripheral_ring_block_name = 'water'
  []

  #We have completed a 2d core map!!!!


  #Now extend the 2d core into 3d

  # You will see commented out code, the vertical layers can be divided into different blocks to allow for better resolution when doin cfd
  [extrude]
    type = AdvancedExtruderGenerator
    input = Core_periph1
    heights = '2500'
    num_layers = '1'
    direction = '0 0 1'
    # Optional subdomain swap
    #  subdomain_swaps = '1 31 2 32 3 33 4 34;
    #                     1 21 2 22 3 23 4 24;
    #                     1 11 2 12 3 13 4 14'
  []
  #[Remap_names_multi_section]
  #  type = RenameBlockGenerator
  #  input = extrude
  #  old_block = '11 21 31 12 22 32 13 23 33 14 24 34'
  #  new_block = 'Fuel-lower Fuel-middle Fuel-upper Cladding-lower Cladding-middle Cladding-upper Control-rod-upper Control-rod-middle Control-rod-lower Water-upper Water-middle Water-lower'
  #[]


  #To see what it would look like with all the boundaries, uncomment that final_generator line, and change it to final_generator=extrude

  #We now setup the Mesh Boundaries for NEKRS CFD
  #To use a mesh like this in NEKRS, we want to make the boundaries as simple as possible, so we will leave only neccessary boundaries on the mesh

  #Make Bound between cladding and water
  [Core_add_clad_bound]
    type = SideSetsAroundSubdomainGenerator
    input = extrude
    block = 'cladding'
    new_boundary = 'clad_bound'
  []

  #Make Bound between control rod and water
  [Core_add_control_bound]
    type = SideSetsAroundSubdomainGenerator
    input = Core_add_clad_bound
    block = 'Control_Rod'
    new_boundary = 'control_bound'
  []

  #Make Bound between fuel and water
  [Core_add_fuel_bound]
    type = SideSetsAroundSubdomainGenerator
    input = Core_add_control_bound
    block = 'fuel'
    new_boundary = 'fuel_bound'
  []

  #Now we combine these three boundaries to make a total boundary around the water
  [Core_add_water_bound]
    type = RenameBoundaryGenerator
    input = Core_add_fuel_bound
    old_boundary = 'clad_bound control_bound fuel_bound'
    new_boundary = 'Fluid_Bound Fluid_Bound Fluid_Bound'
  []

  #Now we grab some other useful boundaries already in the mesh for any NEKRS CFD
  [Remap_names_for_pruning]
    type = RenameBoundaryGenerator
    input = Core_add_water_bound
    old_boundary = '10016 10017 10014'
    new_boundary = 'Fluid_input Fluid_output Fluid_wall'
  []

  #Now we remove all other unneccesary boundaries
  [Boundary_prune]
    type = BoundaryDeletionGenerator
    boundary_names = 'Fluid_Bound Fluid_input Fluid_output Fluid_wall'
    input = Remap_names_for_pruning
    operation = keep
  []

  #Now we reassign boundary IDS to make it easier to extract them in NEKRS
  [Core_final]
    type = RenameBoundaryGenerator
    input = Boundary_prune
    old_boundary = 'Fluid_Bound Fluid_input Fluid_output Fluid_wall'
    new_boundary = '4 1 2 3'
  []

  #We have now made a BWR Core Mesh we can use in NEKRS if we want!!
  # (Must convert the .e file with exo2nek to get a .re2 first)
[]
