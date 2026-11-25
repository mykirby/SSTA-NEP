# Geo-tester
This is a python script to iterate through variations of an open-lattice HTGR, and test them with openmc for k_eff

## Functions
1. Provides the user with all arguments for the tester, where they can set defaults and incremements for each argument
2. Creates a CSV file with the inputs, and the resulting k_eff, along with matching images of each core_geometry
3. Allows the user to heavily customize the tested geometry, from the layout type, to the size of fuel pins, to the thickness of the cladding, etc.

## Future
1. Potentially add the ability for more custom things, such as testing different materials, etc.
2. Look at how to create more automation to get a cardinal simulation running of this????