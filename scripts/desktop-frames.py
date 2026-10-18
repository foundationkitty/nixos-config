import subprocess
import os

dispname = "DP-3"

query_cmd = "swaymsg -t get_outputs"
query = subprocess.check_output(query_cmd, shell=True, text=True)
query = query.split("DP-3")[1]
query = query.split("HDMI")[0]
query = query.split('"current_mode"')[1].split("}")[0] 

print(query)
if '200000' in query:
  os.system("swaymsg output " + dispname + " mode 2560x1440@119.998Hz;")
else:
  os.system("swaymsg output " + dispname + " mode 2560x1440@200.000Hz;")
