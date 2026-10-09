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
  [ss]
    type = ParsedFunction
    expression = '8 * side'
    symbol_names = 'side'
    symbol_values = ${r4} # MOOSE will evaluate this mathematically
  []
[]
[Mesh]
  #final_generator = Core_final
  [Dummy_pin]
    type = CartesianConcentricCircleAdaptiveBoundaryMeshGenerator
    num_sectors_per_side = '${dummy_sectors} ${dummy_sectors} ${dummy_sectors} ${dummy_sectors}'
    square_size = ${r12}
    background_block_ids = 6
    background_block_names = 'Dummy'
  []

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

  # 2. Rotate the horizontal blade by 90 degrees to make the vertical blade (Top arm)
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
  [blade_horizontal_flipped]
    # Mirrors across both axes to complete the 4 arms
    type = SymmetryTransformGenerator
    input = blade_horizontal
    mirror_point = '0.0 0.0 0.0' # A point on the mirror plane/line
    mirror_normal_vector = '1.0 0.0 0.0' # Normal vector of the mirror plane (reflects across x=-y)
  []
  [blade_horizontal_cross]
    type = RenameBoundaryGenerator
    input = blade_horizontal_flipped
    new_boundary = 'left right'
    old_boundary = 'right left'
  []
  [blade_vertical_flipped]
    # Mirrors across both axes to complete the 4 arms
    type = SymmetryTransformGenerator
    input = blade_vertical
    mirror_point = '0.0 0.0 0.0' # A point on the mirror plane/line
    mirror_normal_vector = '0.0 1.0 0.0' # Normal vector of the mirror plane (reflects across x=-y)
  []
  [blade_vertical_cross]
    type = RenameBoundaryGenerator
    input = blade_vertical_flipped
    new_boundary = 'top bottom'
    old_boundary = 'bottom top'
  []
  [blade_horizontal_combo]
    type = StitchMeshGenerator
    inputs = 'blade_horizontal_cross central_hub blade_horizontal'
    stitch_boundaries_pairs = 'right left;
                               right left'
    merge_boundaries_with_same_name = true
    clear_stitched_boundary_ids = true
  []
  # 4. Combine the two arms
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
  #default is the top right
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
  [Bundle_meshw]
    type = BlockToMeshConverterGenerator
    input = Bundle_Mesh_gen
    target_blocks = '4'
  []
  [Bundle_mesho]
    type = BlockToMeshConverterGenerator
    input = Bundle_Mesh_gen
    target_blocks = '1 2'
  []
  [Bundle_meshwconv]
    type = ElementsToSimplicesConverter
    input = Bundle_meshw
  []
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
  [Bundle_Mesh_add_outer_bounds]
    type = SideSetsFromNormalsGenerator
    input = Bundle_Mesh_combined
    normals = '1 0 0   -1 0 0   0 1 0   0 -1 0' # Right, Left, Top, Bottom
    new_boundary = 'outer_x_pos outer_x_neg outer_y_pos outer_y_neg'
  []
  [Bundle_Mesh_merge_outer_bounds]
    type = RenameBoundaryGenerator
    input = Bundle_Mesh_add_outer_bounds
    old_boundary = 'outer_x_pos outer_x_neg outer_y_pos outer_y_neg'
    new_boundary = 'bundle_ext bundle_ext bundle_ext bundle_ext'
  []
  [Bundle_Mesh]
    type = MeshRepairGenerator
    input = Bundle_Mesh_merge_outer_bounds
    fix_node_overlap = true
    merge_boundary_ids_with_same_name = true
  []
  [Bundle_flip]
    type = SymmetryTransformGenerator
    mirror_normal_vector = '0 1 0'
    mirror_point = '0 0 0'
    input = 'Bundle_Mesh'
  []
  [Bundle_quad]
    type = FlexiblePatternGenerator
    boundary_type = CARTESIAN
    boundary_size = ${r12}
    # 88 / nodal_pitch(2) = 44 -> nodes every 2 units on the cell edge
    boundary_sectors = ${quad_sectors}
    inputs = 'Bundle_Mesh Bundle_flip cruciform_mesh'
    rect_patterns = '0;
                     1|
                     0;
                     1|
                     3 2 3'
    rect_origins = ' ${r3} 0 0
                    -${r3} 0 0
                        0  0 0'
    rect_pitches_x = '${fpitch} ${fpitch} 1'
    rect_pitches_y = '${fpitch} ${fpitch} 1'
    rect_rotations = '0.0 180.0 0.0'
    desired_area = 5
    background_subdomain_id = 4
    background_subdomain_name = 'water'
  []
  [Bundle_singleRT_part]
    type = FlexiblePatternGenerator
    boundary_type = CARTESIAN
    #we want a boundary that is one quad width plus 1 for "near" to other bundle spacing, plus another 1 for far spacing, and then move it to origin to fit that
    boundary_size = ${spitch}
    # 42 / nodal_pitch(2) = 21 -> after translation nodes sit at y = 2,4,...,44,
    # which is a SUBSET of the full cell's node set. This is what makes the
    # stair-step core boundary a valid single loop.
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
  [Bundle_singleRT_mov]
    type = TransformGenerator
    input = Bundle_singleRT_part
    transform = TRANSLATE
    vector_value = '${r3} ${r3} 0'
  []
  [Bundle_singleLT_mov]
    type = SymmetryTransformGenerator
    mirror_normal_vector = '1 0 0'
    mirror_point = '0 0 0'
    input = 'Bundle_singleRT_mov'
  []
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
  [Bundle_singleRT_combo]
    type = StitchMeshGenerator
    inputs = "Dummy_fill_singleRT Bundle_singleRT_mov"
    stitch_boundaries_pairs = 'Dummy_boundRT bundle_ext2'
    clear_stitched_boundary_ids = true
  []
  [Bundle_singleRB_combo]
    type = SymmetryTransformGenerator
    mirror_normal_vector = '0 1 0'
    mirror_point = '0 0 0'
    input = 'Bundle_singleRT_combo'
  []
  [Bundle_singleLT_combo]
    type = SymmetryTransformGenerator
    mirror_normal_vector = '1 0 0'
    mirror_point = '0 0 0'
    input = 'Bundle_singleRT_combo'
  []
  [Bundle_singleLB_combo]
    type = SymmetryTransformGenerator
    mirror_normal_vector = '0 1 0'
    mirror_point = '0 0 0'
    input = 'Bundle_singleLT_combo'
  []
  [Bundle_singleRT]
    type = AddMetaDataGenerator
    input = Bundle_singleRT_combo

    # Define pitch for PatternedCartesianMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []
  [Bundle_singleLT]
    type = AddMetaDataGenerator
    input = Bundle_singleLT_combo

    # Define pitch for PatternedCartesianMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []
  [Bundle_singleRB]
    type = AddMetaDataGenerator
    input = Bundle_singleRB_combo

    # Define pitch for PatternedCartesianMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []
  [Bundle_singleLB]
    type = AddMetaDataGenerator
    input = Bundle_singleLB_combo

    # Define pitch for PatternedCartesianMeshGenerator
    real_scalar_metadata_names = 'pattern_pitch_meta'
    real_scalar_metadata_values = ${r12}

    boolean_scalar_metadata_names = 'is_control_drum_meta peripheral_trimmability center_trimmability'
    boolean_scalar_metadata_values = 'false false true'
  []

  # Points are listed EXPLICITLY at the 2-unit pitch with add_nodes_per_boundary_segment = 0, because a single added nodes cannot give pitch 2 on both the 4-long horizontal segments and the 42-long vertical segments.
  [Bundle_gapT_boundary]
    type = PolyLineMeshGenerator
    loop = true
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
  [Bundle_doubleT_part]
    type = StitchMeshGenerator
    inputs = 'Bundle_singleLT_mov Bundle_gapT_fill Bundle_singleRT_mov'
    stitch_boundaries_pairs = 'bundle_ext2 bundle_bound_gapT;bundle_bound_gapT bundle_ext2'
    clear_stitched_boundary_ids = true
  []
  [Dummy_boundary_doubleT]
    type = PolyLineMeshGenerator
    points = '${r6}  -${r6} 0
              ${r6}   ${dpitch} 0
              -${r6} ${dpitch} 0
              -${r6} -${r6} 0
    '
    loop = true
  []
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
  [Bundle_doubleT_combo]
    type = StitchMeshGenerator
    inputs = "Dummy_fill_doubleT Bundle_doubleT_part"
    stitch_boundaries_pairs = 'Dummy_boundT bundle_ext2'
    clear_stitched_boundary_ids = true
  []
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
  [Core_clean]
    type = BlockDeletionGenerator
    input = 'Core_rough'
    block = 'Dummy'
    new_boundary = 'Core_ext'
  []
  [Core_clean_add_outer_bounds]
    type = SideSetsFromNormalsGenerator
    input = Core_clean
    normals = '1 0 0   -1 0 0   0 1 0   0 -1 0'
    new_boundary = 'outer_x_pos outer_x_neg outer_y_pos outer_y_neg'
  []
  [Core_clean_repair]
    type = MeshRepairGenerator
    input = Core_clean_add_outer_bounds
    fix_node_overlap = true
    merge_boundary_ids_with_same_name = true
  []
  [Core_periph1]
    type = PeripheralTriangleMeshGenerator
    input = Core_clean_repair
    peripheral_ring_num_segments = 100
    peripheral_ring_radius = ${irad}
    desired_area = 200
    peripheral_ring_block_name = 'water'
  []
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
  [Core_add_clad_bound]
    type = SideSetsAroundSubdomainGenerator
    input = extrude
    block = 'cladding'
    new_boundary = 'clad_bound'
  []
  [Core_add_control_bound]
    type = SideSetsAroundSubdomainGenerator
    input = Core_add_clad_bound
    block = 'Control_Rod'
    new_boundary = 'control_bound'
  []
  [Core_add_fuel_bound]
    type = SideSetsAroundSubdomainGenerator
    input = Core_add_control_bound
    block = 'fuel'
    new_boundary = 'fuel_bound'
  []
  [Core_add_water_bound]
    type = RenameBoundaryGenerator
    input = Core_add_fuel_bound
    old_boundary = 'clad_bound control_bound fuel_bound'
    new_boundary = 'Fluid_Bound Fluid_Bound Fluid_Bound'
  []
  [Remap_names_for_pruning]
    type = RenameBoundaryGenerator
    input = Core_add_water_bound
    old_boundary = '10016 10017 10014'
    new_boundary = 'Fluid_input Fluid_output Fluid_wall'
  []
  [Boundary_prune]
    type = BoundaryDeletionGenerator
    boundary_names = 'Fluid_Bound Fluid_input Fluid_output Fluid_wall'
    input = Remap_names_for_pruning
    operation = keep
  []
  [Core_final]
    type = RenameBoundaryGenerator
    input = Boundary_prune
    old_boundary = 'Fluid_Bound Fluid_input Fluid_output Fluid_wall'
    new_boundary = '4 1 2 3'
  []
[]
