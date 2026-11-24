'''
Overview:
This code will be able to make a parametrically defined open-lattice HTGR core for use in testing core geometry options

It just determines K-eff, not heating

Materials:
1. Fuel is UO2 (90% enriched)
2. Cladding is MoRe (41% Re by wt), using Mo-92 and Re-185
3. Coolant is HeXe (30% He to start)
4. Reflector is BeO

For the purposes of this study, there is vaccum above and below the core

Geometry:
1. Fuel pins distributed evenly across the core
2. Fuel surrounded by cladding
3. Reflector bounds core
4. Sizes of everything defined parametrically

Settings:
1. 1500 batches
    a. 250 inactive
2. 10000 particles per batch
3. k-eff within +/- 0.0005 trigger
'''

# Imports
import openmc
import openmc.stats
import openmc.model
import numpy as np


# Setup variables

#Materials
enrich=90

#Conditions
T=900 #Kelvin
P=4 #Mpa, this is pressure in reactor vessel


# Materals Code
uo2 = openmc.Material()
uo2.set_density('g/cm3',10.9200)
uo2.add_nuclide('U235',enrich)
uo2.add_nuclide('U238',(100-enrich))

more = openmc.Material()
more.set_density('g/cm3',12.5200)
more.add_nuclide('Mo92',59.0,'wo')
more.add_nuclide('Re185',41.0,'wo')

hexe = openmc.Material()
#Density at 900K
#Second coefficient for PV=NRT
B=39.18-(2.911*10**4)/T - (2.069*10**6)/(T**2)
#density
dens=(93.106*P)/(8.3145*T+B*P)
hexe.set_density('g/cm3', dens)
hexe.add_element('He',70)
hexe.add_element('Xe',30)

beo = openmc.Material()
beo.set_density('g/cm3',3.010)
beo.add_element('Be',1)
beo.add_element('O',1)


#Geometry variables
#All in cm

#Reactor
reflectthick=30 #Thickness of the reflector
reactr=220 #Radius of inside of reactor vessel

#Fuel
pinr=2.5 #Radius of total fuel pin
fuelr=0.6*pinr #Radius of fuel section of fuel pin

#Layout
pind=7.5 #distance between the center of each fuel pin horizontally
coolmin=2 #minimum area between edge of pin and end of coolant
layout_type='s' # 's', 'h', or 'c' for square, hexagonal, or criss-cross layout 

#Geometry Code

#Construct main vessel and coolant shell
reflectbound=openmc.ZCylinder(0,0,reactr+reflectthick)
coolant_bound=openmc.ZCylinder(0,0,reactr)

#Now this part depends on pattern

#Starting with making 's' or square layout
pin_c0=np.array([pind/2,pind/2,0])
pin_cl=[]
pin_inc=np.array([pind,pind,0])
i=0
while (i*pind+pin_c0[0])<(reactr-pinr-coolmin):
    pin_cl.append(pin_c0+i*pin_inc )
    i+=1
i=0
while (pin_c0[0]-i*pind)>-(reactr-pinr-coolmin):
    pin_cl.append((pin_c0+(-i)*pin_inc))
    i+=1
print(pin_cl)








