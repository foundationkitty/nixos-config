import subprocess
import os

dispname = "DP-2"

query_cmd = "swaymsg -t get_outputs"
query = subprocess.check_output(query_cmd, shell=True, text=True)
query = query.split("DP-2")[1]
query = query.split("HDMI")[0]
query = query.split('"current_mode"')[1].split("}")[0] 

print(query)
if '180000' in query:
  os.system("swaymsg output " + dispname + " mode 2560x1440@119.998Hz;")
else:
  os.system("swaymsg output " + dispname + " mode 2560x1440@180.000Hz;")
