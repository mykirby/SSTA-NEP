#this is a simple code for practcing my python for applied aerospace;
#F = thrust ; m_fr = mass flow rate ; I_sp = speficic impluse ; g_0 is standard gravity constant ;
# t_b= burn time ;m_prop = mass propellenat ; 
# equations include F= m_fr * I_sp * g_0 ; t_b = m_prop/m_fr

import sys

G_0 = 9.80665 # m/s^2 & standard grav

#all the relvant imputs
try:
	I_sp = float(input(" Enter Specific Impluse, Isp(s) : ")) 
	m_prop = float(input(" Enter the Mass of Propellant, kg : ")) 
	m_fr = float(input(" Enter the Mass Flow Rate, kg/s : "))
except ValueError:
	print("Error: all imputs must be a number.")
	sys.exit(1)

#required validation of inputs
for name, value in [("Isp", I_sp), ("Propellant Mass", m_prop), ("Mass Flow Rate", m_fr)]:
	if value <= 0:
		print(f"Error: {name} must be greater than 0.")
		sys.exit(1)

#run equations
F= I_sp * m_fr * G_0
t_b = m_prop / m_fr
v_e = I_sp * G_0

#print answers
print(f"Thrust  : {F:,.5f} N")
print(f"Burn Time  : {t_b:,.5f} s") 
print(f"Exhaust Velocity  : {v_e:,.5f} m/s") 
