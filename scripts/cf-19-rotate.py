import subprocess
import os

normal = '"1 0 0 0 1 0"'
inverted = '" -1 0 1 0 -1 1"'
right = '"0 1 0 -1 0 1"'
left = '"0 -1 1 1 0 0"'

dispname = "LVDS-1"
prop_cmd = "swaymsg input '*' calibration_matrix "

query_cmd = "swaymsg -t get_outputs"
query = subprocess.check_output(query_cmd, shell=True, text=True)

if '"transform": "normal"' in query:
  os.system("swaymsg output " + dispname + " transform 90 ;")
  os.system(prop_cmd + right)
elif '"transform": "90"' in query:
  os.system("swaymsg output " + dispname + " transform 180 ;")
  os.system(prop_cmd + inverted)
elif '"transform": "180"' in query:
  os.system("swaymsg output " + dispname + " transform 270 ;")
  os.system(prop_cmd + left)
else:
  os.system("swaymsg output " + dispname + " transform 0 ;")
  os.system(prop_cmd + normal)
