#File to use to run iterations of Open_latiic_openmc_maker to test various geometries

import sys
import subprocess
import time
from pathlib import Path
import shutil

t1=time.time()

#Clear previous results
imgpath=Path("report/images")
rdir=Path("report")
try:
    rdir.mkdir(exist_ok=False)
except:
    pass
try:
    imgpath.mkdir(exist_ok=False)
except:
    pass
csvpath=Path("report/results.csv")
csvpath.unlink(missing_ok=True)
for item in imgpath.iterdir():
    item.unlink(missing_ok=True)

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
"Layout":"h",
"Drumcount":6,
"Drumdiamter":15,
"Drumabsorberdiameter":13,
"Drumabsorberinnerdiameter":11,
"Drumrotation":0,
"Geometryonly":False
}
#Increments

#Dict of increments per variable
inc={
    "Temp":None,
    "Pressure":None,
    "Enrichment":None,
    "Thickness":None,
    "Radius":-5,
    "Height":None,
    "Pinr":None,
    "Fuelr":None,
    "Pinpitch":None,
    "Mincoolant":None,
    "Layout": None,
    "Drumcount":None,
    "Drumdiamter":None,
    "Drumabsorberdiameter":None,
    "Drumabsorberinnerdiameter":None,
    "Drumrotation":None,
    "Geometryonly": None
}

#Count of times to iterate, meaning you will get count+1 results, as it does initial, then initial+one increment,+another increment, until it has added count increments. For count=10, it gives initial value, then 10 increments, for a total of 11 results, where starting conditions are trial #0
count=10


#List of variables to iterate through
vl=["Temp","Pressure","Enrichment","Thickness","Radius","Height","Pinr","Fuelr","Pinpitch","Mincoolant","Layout","Geometryonly"]

vdict=dict(start)

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
    "Layout":"-pl",
    "Drumcount":"-dc",
    "Drumdiamter":"-dd",
    "Drumabsorberdiameter":"-dad",
    "Drumabsorberinnerdiameter":"-daid",
    "Drumrotation":"-dr",
    "Geometryonly":"-go"
}
f=0
el=[]
for n in range(count + 1):
    al = []
    for i in vl:
        if n > 0 and inc[i] is not None:
            vdict[i] = vdict[i] + inc[i]
        al.extend([argdict[i],str(vdict[i])])
    print(al)
    try:    
        res=subprocess.run(
            [sys.executable,"-u","Open_lattice_openmc_maker.py"]+al,
            check=True
        )
        #Save-images for later
        img=Path("plot.png")

        img_fold=Path("report/images")
        try: 
            img_fold.mkdir(parents=True,exist_ok=True)
        except:
            pass
        img_new=Path(f"report/images/plot{n}.png")
        shutil.copy(img,img_new)
        print(f"Image saved as plot{n}.png")
    except Exception as error:
        print(f"Run number {n} failed, continuing")
        print(f"Error was {error}")
        el.append((n, repr(error)))
        f+=1
t2=time.time()
dt=t2-t1

#Calculate time
m, s = divmod(dt, 60)
h, m = divmod(m, 60)
print(f"Completed {count} runs, with {f} failures")
print(f"\nin {h} hours, {m} minutes, and {s} seconds")
print(f"\nErrors were: {el}")



#Save results
n=1
while True:
        rfold=Path(f"report/run{n}")
        if rfold.exists():
            n+=1
        else:
            rfold.mkdir()
            (rfold/"images").mkdir()
            break
startfold=Path('report')
csvpath=Path('report/results.csv')
startfoldimg=Path('report/images')
if not start["Geometryonly"]:
    shutil.copy(csvpath,rfold / csvpath.name)
for item in startfoldimg.iterdir():
    shutil.copy(item,rfold / "images" / item.name)
try:
    Path("report/images").mkdir(exist_ok=False)
except:
    pass
print(f"Results saved in report/run{n}")
        


