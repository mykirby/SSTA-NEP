#File to use to run iterations of Open_latiic_openmc_maker to test various geometries

import sys
import subprocess
import time

t1=time.time()

#Starting points
Temp=900
Pressure=4
Enrichment=90

Thickness=30
Radius=220
Height=1000

Pinr=2.5
Fuelr=60
Pinpitch=7.5
Mincoolant=2

Layout="h"
#Increments

#Dict of increments per variable
inc={
    Temp:0,
    Pressure:0,
    Enrichment:0,
    Thickness:0,
    Radius:0,
    Height:0,
    Pinr:0,
    Fuelr:0,
    Pinpitch:2.5,
    Mincoolant:0,
    Layout:""
}

#Count of times to iterate
count=10


#List of variables to iterate through
vl=[Temp,Pressure,Enrichment,Thickness,Radius,Height,Pinr,Fuelr,Pinpitch,Mincoolant,Layout]

argdict = {
    Temp:"-T",
    Pressure:"-p",
    Enrichment:"-e",
    Thickness:"-th",
    Radius:"-r",
    Height:"-H",
    Pinr:"-pr",
    Fuelr:"-fr",
    Pinpitch:"-pp",
    Mincoolant:"-mc",
    Layout:"-l"
}
f=0
for n in range(0,count-1):
    al=[]
    for i in vl:
        i=i+n*inc[i]
        al.extend([argdict[i],i])
    try:    
        res=subprocess.run(
            ([sys.executable,"Open_lattice_openmc_maker.py"]+al),
            capture_output=True,
            text=True,
            check=True
        )
    except:
        print(f"Run number {n} failed, continuing")
        f+=1
t2=time.time()
dt=t2-t1
d=0
h=0
s=0
if dt%60 is not None:
    s=dt%60
    dt=dt-s
    dt=dt/60
    if dt%24 is not None:
        h=dt%24
        dt=dt-h
        d=dt/24
    else:
        d=dt/24
elif (dt/60)%24 is not None:
    h=(dt%60)%24
    dt=dt-h
    d=dt/24
else:
    d=dt/24
print(f"Completed {count} runs, with {f} failures")
print(f"\nin {d} days, {h} hours, and {s} seconds")
        


