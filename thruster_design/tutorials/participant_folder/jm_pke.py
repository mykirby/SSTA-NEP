import scipy as sp
import numpy as np
import matplotlib.pyplot as pl

def PKE_euler(n0,b,p,A,lamb,dt,T):
  st = int(round(T/dt))
  t = np.arange(0,T,dt)

  n = np.zeros(st)
  c = np.zeros(st)

  c0=(b/(A*lamb))*n0

  n[0]=n0
  c[0]=c0
  #ifs=int((T/dt)+1)
  #t.appp
  for i in range(st-1):
    dn = ((p-b)*n[i]*1/A) + lamb*c[i]
    dc = (b/A) *n[i] + lamb*c[i]

    n[i+1] = n[i] + dn*dt
    c[i+1] = c[i] + dc*dt
    print(n)
    print(c)

  return t,n,c

dt=0.001
t=0.01
te,ne,ce = PKE_euler(1,0.0065,0.0001,0.0001,0.1,dt,t)
pl.figure(figsize=(10,10))
pl.plot(te,ne,label="Neutron Population Euler")
pl.xlabel("Time")
pl.ylabel("Population")
pl.title(f"PKE values over time (dt = {dt})")
pl.show()

pl.figure(figsize=(10,10))
pl.plot(te,ce,label="Delayed neutron consentation Euler")
pl.xlabel("Time")
pl.ylabel("Consentation")
pl.title(f"PKE values over time (dt = {dt})")
pl.show()
