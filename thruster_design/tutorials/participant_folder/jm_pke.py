import scipy as sp
import numpy as np
import matplotlib.pyplot as pl

def PKE_euler(n0,b,p,A,lamb,dt,T):
  st = int(round(T/dt))
  t = np.arange(st+1)*dt

  n = np.zeros(st+1)
  c = np.zeros(st+1)

  c0=(b/(A*lamb))*n0

  n[0]=n0
  c[0]=c0
  #ifs=int((T/dt)+1)
  #t.appp
  for i in range(st):
    dn = ((p-b)*n[i]*1/A) + lamb*c[i]
    dc = (b/A) *n[i] + lamb*c[i]

    n[i+1] = n[i] + dn*dt
    c[i+1] = c[i] + dc*dt
    print(n)
    print(c)

  return t,n,c

def PKE_rk4(n0,b,p,A,lamb,dt,T):
  st = int(round(T/dt))
  t = np.arange(st+1)*dt

  n = np.zeros(st+1)
  c = np.zeros(st+1)

  c0=(b/(A*lamb))*n0

  n[0]=n0
  c[0]=c0

  def f(n,c):
    return ((p-b)*n*1/A) + lamb*c, (b/A) *n + lamb*c

  for i in range(st):
    k1n, k1c = f(n[i],c[i])
    k2n, k2c = f(n[i] + 0.5*dt*k1n, c[i] + 0.5*dt*k1c)
    k3n, k3c = f(n[i] + 0.5*dt*k2n, c[i] + 0.5*dt*k2c)
    k4n, k4c = f(n[i] + dt*k3n, c[i] + dt*k3c)

    n[i+1]=n[i]+(dt/6)*(k1n+2*k2n+2*k3n+k4n)
    c[i+1]=c[i]+(dt/6)*(k1c+2*k2c+2*k3c+k4c)
  return t,n,c

dt=0.001
t=6

n=1
b=0.0065
p=-0.0001
A=0.0001
lamb=0.1


te,ne,ce = PKE_euler(n,b,p,A,lamb,dt,t)
tr,nr,cr = PKE_rk4(n,b,p,A,lamb,dt,t)
pl.figure(figsize=(10,10))
pl.plot(te,ne,label="Neutron Population Euler")
pl.plot(tr,nr,label="Neutron Population Rk4")
pl.xlabel("Time(s)")
pl.ylabel("Population")
pl.title(f"PKE values over time (dt = {dt})")
pl.legend()
pl.show()

pl.figure(figsize=(10,10))
pl.plot(te,ce,label="Delayed neutron consentation Euler")
pl.plot(tr,cr,label="Delayed neutron consentation RK4")
pl.xlabel("Time(s)")
pl.ylabel("Consentation")
pl.title(f"PKE values over time (dt = {dt})")
pl.legend()
pl.show()
