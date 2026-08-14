import subprocess
import os

dispname = "DP-2"

query_cmd = "swaymsg -t get_outputs"
query = subprocess.check_output(query_cmd, shell=True, text=True)
query = query.split("DP-2")[1]
query = query.split("HDMI")[0]

if '"transform": "normal"' in query:
  os.system("swaymsg output " + dispname + " 'transform 270 position 1920 -640 ;'")
  os.system(prop_cmd + right)
else:
  os.system("swaymsg output " + dispname + " transform 0 position 1920 0 ;")
  os.system(prop_cmd + normal)
