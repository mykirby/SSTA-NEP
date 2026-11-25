#File to use to run iterations of Open_latiic_openmc_maker to test various geometries

import sys
import subprocess
import time

t1=time.time()

#Starting points
start={
"Temp":900,
"Pressure":4,
"Enrichment":90,
"Thickness":30,
"Radius":220,
"Height":1000,
"Pinr":2.5,
"Fuelr":60,
"Pinpitch":7.5,
"Mincoolant":2,
"Layout":"h"
}
#Increments

#Dict of increments per variable
inc={
   "Temp":0,
   "Pressure":0,
   "Enrichment":0,
   "Thickness":0,
   "Radius":0,
   "Height":0,
   "Pinr":0,
   "Fuelr":0,
   "Pinpitch":2.5,
   "Mincoolant":0,
   "Layout":""
}

#Count of times to iterate
count=10


#List of variables to iterate through
vl=["Temp","Pressure","Enrichment","Thickness","Radius","Height","Pinr","Fuelr","Pinpitch","Mincoolant","Layout"]

vdict=start

argdict = {
   "Temp":"-T",
   "Pressure":"-p",
   "Enrichment":"-e",
   "Thickness":"-th",
   "Radius":"-r",
   "Height":"-H",
   "Pinr":"-pr",
   "Fuelr":"-fr",
   "Pinpitch":"-pp",
   "Mincoolant":"-mc",
   "Layout":"-l"
}
f=0
el=[]
for n in range(0,count-1):
    al=[]
    for i in vl:
        vdict[i]=vdict[i]+n*inc[i]
        al.extend([argdict[i],str(vdict[i])])
    print(al)
    try:    
        res=subprocess.run(
            [sys.executable,"-u","Open_lattice_openmc_maker.py"]+al,
            check=True
        )
    except Exception as error:
        print(f"Run number {n} failed, continuing")
        print(f"Error was {error}")
        el.append(n)
        el.append(error)
        f+=1
t2=time.time()
dt=t2-t1
h=0
m=0
s=0
if dt%60 is not None:
    s=dt%60
    dt=dt-s
    dt=dt/60
    if dt%60 is not None:
        m=dt%60
        dt=dt-m
        h=dt/60
    else:
        h=dt/60
elif (dt/60)%60 is not None:
    m=(dt/60)%60
    dt=dt-m
    h=dt/60
else:
    h=(dt/60)/60
print(f"Completed {count} runs, with {f} failures")
print(f"\nin {h} hours, {m} minutes, and {s} seconds")
print(f"Errors were: {el}")
        


