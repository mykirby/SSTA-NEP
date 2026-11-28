'''
Overview:
This code will be able to make a parametrically defined open-lattice HTGR core for use in testing core geometry options

It just determines K-eff, not heating

Materials:
1. Fuel is UO2 (90% enriched)
2. Cladding is MoRe (41% Re by wt), using Mo-92 and Re-185
3. Coolant is HeXe (30% He to start)
4. Reflector is BeO
5. Control Drums are B4C, using B-10 
6. Control Drums cladding is Inconel 718

For the purposes of this study, there is vaccum above and below the core

Geometry:
1. Fuel pins distributed evenly across the core
2. Fuel surrounded by cladding
3. Reflector bounds core
4. Sizes of everything defined parametrically

Settings:
1. Batches
    a. 500 Minimum
    b. 1500 Maximum
    c. 250 inactive
2. 10000 particles per batch
3. k-eff within +/- 0.00045 every 5 batches
'''

# Imports
import openmc
import openmc.stats
import openmc.model
import numpy as np
import math
import gc
import openmc
import openmc.lib
import argparse
from pathlib import Path
import shutil
import csv

#Housekeeping
if openmc.lib.is_initialized:
    openmc.lib.finalize()
openmc.reset_auto_ids()
gc.collect()

#Clean-up old data
file_list=["materials.xml","model.xml","geometry.xml","materials.xml","plots.xml","settings.xml","plot.png","tallies.out","summary.h5"]+list(Path(".").glob("statepoint.*.h5"))
for i in file_list:
    path=Path(i)
    path.unlink(missing_ok=True)

# Setup args to parse
parser=argparse.ArgumentParser(description='Parametrically defined Open-Lattice HTGR k-eff test script')
#conditions arguments
conditiongroup=parser.add_argument_group(title="Conditions",description="Initial materials and problem settings")
conditiongroup.add_argument("-T","--Temp",type=float,default=1000,help="Operating Temp in K, default is 1000K")
conditiongroup.add_argument("-p","--Pressure",type=float,default=4,help="Operating Pressure in Mpa, default is 4Mpa")
conditiongroup.add_argument("-e","--Enrichment",type=float,default=90,help="Enrichment % of fuel, default is 90")
conditiongroup.add_argument("-go","--Geometryonly",type=bool,default=False,help="Whether to run in geometry-only mode, where the model is produced, but not run")

#Geometry arguments
geometrygroup=parser.add_argument_group(title="Geometry",description="Geometry settings (cm), capitals matter here")
geometrygroup.add_argument("-th","--Thickness",type=float,default=30,help="Thickness of the reflector surrounding the reactor, default 30")
geometrygroup.add_argument("-r","--Radius",type=float,default=220,help="Radius of the inner reactor cavity, default 220")
geometrygroup.add_argument("-H","--Height",type=float,default=1000,help="Height of reactor to be tested, default 1000")
geometrygroup.add_argument("-pr","--Pinr",type=float,default=2.5,help="Total radius of fuel pins, default 2.5")
geometrygroup.add_argument("-fr","--Fuelr",type=float,default=60,help="Percent of pin radius filled with fuel, default 60")
geometrygroup.add_argument("-pp","--Pinpitch",type=float,default=7.5,help="Pitch(distance) between centers of fuel pins, default 7.5")
geometrygroup.add_argument("-mc","--Mincoolant",type=float,default=2,help="Minimum width of coolant between reflector and edge pins, default 2")
geometrygroup.add_argument("-pl","--Pinlayout",default='h',choices=['h','s'],help="Pinlayout type for reactor: h for hexagonal, s for square ,default h")

controlgroup=parser.add_argument_group(title="Controls",description="Controls settings, including geometry (cm), and positions (%)")
controlgroup.add_argument("-dc","--Drumcount",type=float,default=6,help='Number of control drums')
controlgroup.add_argument("-dd","--Drumdiameter",type=float,default=15,help='Diameter of Control Drums, default 15')
controlgroup.add_argument("-dad","--Drumabsorberdiameter",type=float,default=13,help='Diameter of Absorber/reflector in control drum, default 13')
controlgroup.add_argument("-daid","--Drumabsorberinnerdiameter",type=float,default=11,help='Inner diameter(minimum) of absorber, default 11')
controlgroup.add_argument('-dr',"--Drumrotation",type=float,nargs='+',default=0,help='''Rotation(s) of Control Drums in degrees CCW, with 0 as reflector facing directly away from core. 
                                                                                        If one value is given, all drums rotated same amount, or give individual rotations sequentially for all drums.''')
args=parser.parse_args()

# Setup variables

#Condition variables

#Conditions
Go=args.Geometryonly

#To test new stuff, uncomment this block
#Go=True

T=args.Temp # pyright: ignore[reportArgumentType] #Kelvin
P=args.Pressure # pyright: ignore[reportArgumentType] #Mpa, this is pressure in reactor vessel

#Materials
enrich=args.Enrichment # pyright: ignore[reportArgumentType] #Enrichment, this is % enrichment of fuel

#Geometry variables
#All in cm

#Reactor
reflectthick=args.Thickness #Thickness of the reflector
reactr=args.Radius #Radius of inside of reactor vessel
height=args.Height #Height of reactor in m
#Fuel
pinr=args.Pinr #Radius of total fuel pin
fuelr=pinr*args.Fuelr/100 #Radius of fuel section of fuel pin

#Pinlayout
pinp=args.Pinpitch #distance between the center of each fuel pin horizontally
coolmin=args.Mincoolant #minimum area between edge of pin and end of coolant
layout_type=args.Pinlayout # 's' or 'h' for square, or hexagonal layout 

#Controllayout
dcount=args.Drumcount
drumr=args.Drumdiameter/2
drumir=args.Drumabsorberdiameter/2
drumiar=args.Drumabsorberinnerdiameter/2
    


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

b4c = openmc.Material()
b4c.set_density('g/cm3',2.3700)
b4c.add_nuclide('B10',4)
b4c.add_element('C',1)

inc = openmc.Material(name="Inconel 718")
inc.set_density("g/cm3", 8.19)  # Typical ~8.19–8.2 g/cm3
inc.add_element("Ni", 0.5250, "wo")
inc.add_element("Cr", 0.1900, "wo")
inc.add_element("Fe", 0.1800, "wo")
inc.add_element("Nb", 0.0510, "wo")
inc.add_element("Mo", 0.0300, "wo")
inc.add_element("Ti", 0.0090, "wo")
inc.add_element("Al", 0.0050, "wo")

mats=openmc.Materials([uo2,more,hexe,beo,b4c,inc])
mats.export_to_xml()

#Geometry Code

# Surfaces with Vacuum Boundary Conditions
reflectbound = openmc.ZCylinder(0, 0, reactr + reflectthick, boundary_type='vacuum')
coolant_bound = openmc.ZCylinder(0, 0, reactr)
top = openmc.ZPlane(height, boundary_type='vacuum')
bottom = openmc.ZPlane(0, boundary_type='vacuum')
hreg = -top & +bottom

# Control Drums setup
drumcr = reactr + (reflectthick / 2)
drum_centers = []
drumpos = np.array([drumcr, 0.0, 0.0])

# Fix 1: range(dcount) instead of range(0, dcount - 1)
for n in range(dcount):
    dpos = openmc.get_rotation_matrix((0, 0, n * 360.0 / dcount)) @ drumpos
    drum_centers.append(dpos)

# Create the Drums
t1 = np.radians(30.0)
t2 = np.radians(150.0)
a_plane = openmc.Plane(a=np.sin(t1), b=np.cos(t1), c=0.0, d=0.0)
b_plane = openmc.Plane(a=np.sin(t2), b=np.cos(t2), c=0.0, d=0.0)

drum_boundl = []
drum_clad_boundl = []
reflect_boundl = []
absorb_boundl = []

for n, c in enumerate(drum_centers):
    da_plane = a_plane.translate((c[0], c[1], 0.0), inplace=False)
    db_plane = b_plane.translate((c[0], c[1], 0.0), inplace=False)
    darc = +da_plane & -db_plane # pyright: ignore[reportOperatorIssue]

    ddrumbound = openmc.ZCylinder(x0=c[0], y0=c[1], r=drumr)
    didrumbound = openmc.ZCylinder(x0=c[0], y0=c[1], r=drumir)
    dabound = openmc.ZCylinder(x0=c[0], y0=c[1], r=drumiar)

    dcladbound = -ddrumbound & +didrumbound
    dabsorb_bound = darc & +dabound & -didrumbound
    dreflect_bound = -didrumbound & ~dabsorb_bound

    drum_boundl.append(-ddrumbound)
    drum_clad_boundl.append(dcladbound)
    absorb_boundl.append(dabsorb_bound)
    reflect_boundl.append(dreflect_bound)

    # Combined outer boundary to exclude from the surrounding reflector cell
    drum_bound = -ddrumbound if n == 0 else (drum_bound | -ddrumbound) # pyright: ignore[reportOperatorIssue, reportPossiblyUnboundVariable]

if np.ndim(args.Drumrotation) == 0:
    rotations_deg = [float(args.Drumrotation)] * len(drum_centers)
else:
    rotations_deg = [float(a) for a in args.Drumrotation]
    assert len(rotations_deg) == len(drum_centers), "Drumrotation count must match dcount"

Drum_cells = []
for idx, (c, rb, ab, cb, rot_deg) in enumerate(
    zip(drum_centers, reflect_boundl, absorb_boundl, drum_clad_boundl, rotations_deg)
):
    pivot = (c[0], c[1], 0.0)
    d0 =-90.0
    dr = np.degrees(np.arctan2(-c[1], -c[0]))
    angles = (0.0, 0.0, rot_deg + (dr - d0))

    rb_rot = rb.rotate(angles, pivot=pivot)
    ab_rot = ab.rotate(angles, pivot=pivot)

    Drum_reflect_cell = openmc.Cell(name=f"Drum_reflector_{idx+1}", fill=beo, region=rb_rot)
    Drum_absorb_cell = openmc.Cell(name=f"Drum_absorber_{idx+1}", fill=b4c, region=ab_rot)
    Drum_clad_cell = openmc.Cell(name=f"Drum_cladding_{idx+1}", fill=inc, region=cb)

    Drum_cells.extend([Drum_reflect_cell, Drum_absorb_cell, Drum_clad_cell])




# Depends on layout_type
max_pin_r = reactr - pinr - coolmin #How far "away" can pin centers be from the center
pin_centers = []
if layout_type == 's':
    n_steps = int(np.ceil(max_pin_r / pinp))
    coords = [pinp / 2 + i * pinp for i in range(-n_steps, n_steps)]
    
    for x in coords:
        for y in coords:
            # Keep pin only if its center is within the allowed radius
            if np.hypot(x, y) < max_pin_r:
                pin_centers.append([x, y])
    pass
if layout_type == 'h':
    d = pinp * math.sin(math.pi / 3)  # sqrt(3)/2 * pinp

    nx = int(np.ceil(max_pin_r / pinp)) + 1
    ny = int(np.ceil(max_pin_r / d)) + 1

    for row in range(-ny, ny + 1):
        y = row * d
        # Shift every odd row by half a pitch to form equilateral triangles
        x_offset = 0.5 * pinp if (row % 2 != 0) else 0.0
        
        for col in range(-nx, nx + 1):
            x = col * pinp + x_offset
            if np.hypot(x, y) < max_pin_r:
                pin_centers.append([x, y])
# Create Fuel Pin Cells
pin_cells = []
clad_regs = []

for idx, (px, py) in enumerate(pin_centers, start=1):
    fuel_bound = openmc.ZCylinder(px, py, fuelr)
    clad_bound = openmc.ZCylinder(px, py, pinr)

    fuelreg = -fuel_bound & hreg
    cladreg = -clad_bound & +fuel_bound & hreg
    clad_regs.append(-clad_bound) # Track outer pin footprint

    # Omit cell_id so OpenMC automatically assigns unique IDs
    fuel_cell = openmc.Cell(name=f"fuel_{idx}", fill=uo2, region=fuelreg)
    clad_cell = openmc.Cell(name=f"clad_{idx}", fill=more, region=cladreg)
    pin_cells.extend([fuel_cell, clad_cell])

print(f'{len(pin_centers)} pins ({len(pin_cells)} cells) created')

# Create Reflector and Coolant Cells
Reflectreg = -reflectbound & +coolant_bound & hreg & ~drum_bound # pyright: ignore[reportOperatorIssue, reportPossiblyUnboundVariable]
Coolantreg = -coolant_bound & hreg

for reg in clad_regs:
    Coolantreg &= ~reg

Coolant_cell = openmc.Cell(name="coolant", fill=hexe, region=Coolantreg)
Reflect_cell = openmc.Cell(name="Reflector", fill=beo, region=Reflectreg)

geo = openmc.Geometry([Coolant_cell, Reflect_cell] + pin_cells + Drum_cells)
geo.export_to_xml()

#Look at geometry
plot1 = openmc.Plot()
plot1.filename = "plot"
plot1.basis = "xy"
plot1.origin = (0.0, 0.0, height/2)  # Required for openmc.Plot() if not centered at origin
plot1.width = [(reflectthick + reactr) * 2, (reflectthick + reactr) * 2]
plot1.pixels = [1500, 1500]
plot1.color_by = "material"
plot1.colors = {
    uo2: (32, 250, 94),
    hexe: (181, 31, 98),
    more: (173, 179, 174),
    beo: (230, 240, 232),
    b4c: (43, 42, 37),
    inc: (184, 177, 173)
}

# Export to plots.xml and generate the image file
plots = openmc.Plots([plot1])
plots.export_to_xml()
openmc.plot_geometry()


settings=openmc.Settings()
settings.particles=10000
settings.batches=750
settings.inactive=250

upperr=[(reflectthick+reactr),(reflectthick+reactr),height]
lowerl=[-(reflectthick+reactr),-(reflectthick+reactr),0]
uniform_dist = openmc.stats.Box(lowerl, upperr)
settings.source = openmc.IndependentSource(space=uniform_dist,constraints={'fissionable': True})

settings.temperature = {'default': 280.0 + 273.15,
                        'method': 'interpolation',
                        'range': (250.0, 3000.0),
                        'tolerance': 1000.0}

settings.keff_trigger={'type':'std_dev','threshold':0.00045}
settings.trigger_active=True
settings.trigger_batch_interval=5
settings.trigger_max_batches=1500

settings.export_to_xml()

mod=openmc.Model(geometry=geo,materials=mats,settings=settings)
mod.export_to_model_xml()

if not Go:
    try:
        openmc.run(geometry_debug=True,path_input="model.xml")

        #Print Report to user

        #Find report file
        matches = list(Path(".").glob("statepoint.*.h5"))
        if matches:
            s_str = matches[0] 
        else:
            raise ValueError("No report file found")
        s=openmc.StatePoint(s_str)
        assert s.keff is not None
        keff=s.keff.nominal_value
        keffdev=s.keff.std_dev
        print(f"Final k-eff: {s.keff.nominal_value:.5f} +/- {s.keff.std_dev:.5f}")
        k_per_gen = s.k_generation
        print("k-eff for each generation:", np.array2string(k_per_gen, precision=5, floatmode='fixed')) # pyright: ignore[reportArgumentType]

        #Add to CSV

        #Setup arg list for use
        argnames=["Temp","Pressure","Enrichment","Thickness","Radius","Height","Pinr","Fuelr","Pinpitch","Mincoolant","Pinlayout"]
        argl=[args.Temp,args.Pressure,args.Enrichment,args.Thickness,args.Radius,args.Height,args.Pinr,args.Fuelr,args.Pinpitch,args.Mincoolant,args.Pinlayout]
        ps='report/results.csv'
        oe=False
        if Path(ps).exists():
            oe=True
        o=open(ps,'a+',newline='')
        with o as file:
            dialect='excel'
            vl=[]
            file.seek(0)
            r=1
            if oe:
                reader = csv.DictReader(file, dialect)
                for row in reader:
                    vl.append(row)
                    r+=1
                r=r-1
            fnames=["Trial #","k_eff","dev"]+argnames
            fl=[r,keff,keffdev]+argl
            vl.append(fl)
            vdict={}
            for i in range(0,len(fnames)):
                vdict[fnames[i]]=fl[i]
            writer = csv.DictWriter(f=file, dialect=dialect,fieldnames=fnames)
            if not oe:
                writer.writeheader()
            writer.writerow(vdict)
    except Exception as error:
        #Setup arg list for use
            argnames=["Temp","Pressure","Enrichment","Thickness","Radius","Height","Pinr","Fuelr","Pinpitch","Mincoolant","Pinlayout"]
            argl=[args.Temp,args.Pressure,args.Enrichment,args.Thickness,args.Radius,args.Height,args.Pinr,args.Fuelr,args.Pinpitch,args.Mincoolant,args.Pinlayout]
            ps='report/results.csv'
            oe=False
            if Path(ps).exists():
                oe=True 
            o=open(ps,'a+',newline='')  
            with o as file:
                dialect='excel'
                vl=[]
                file.seek(0)
                r=1
                if oe:
                    reader = csv.DictReader(file, dialect)
                    for row in reader:
                        vl.append(row)
                        r+=1
                    r=r-1
                fnames=["Trial #","k_eff","dev"]+argnames
                fl=[r,'fail','']+argl
                vl.append(fl)
                vdict={}
                for i in range(0,len(fnames)):
                    vdict[fnames[i]]=fl[i]
                writer = csv.DictWriter(f=file, dialect=dialect,fieldnames=fnames)
                if not oe:
                    writer.writeheader()
                writer.writerow(vdict)
            raise RuntimeError(f"OpenMC run failure: {error}")
    






            



























