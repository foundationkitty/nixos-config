import subprocess
import os

normal = '1 0 0 0 1 0 0 0 1'
inverted = '-1 0 1 0 -1 1 0 0 1'
right = '0 1 0 -1 0 1 0 0 1'
left = '0 -1 1 1 0 0 0 0 1'

devname = '"MosArt MosArt 10.1"'
prop_cmd = "xinput set-prop " + devname + ' "Coordinate Transformation Matrix" '

query_cmd = "xrandr -q"
query = subprocess.check_output(query_cmd, shell=True, text=True)

trim = query.split(" (")[0]
if "right" in trim:
  os.system("xrandr -o inverted")
  os.system(prop_cmd + inverted)
elif "inverted" in trim:
  os.system("xrandr -o left")
  os.system(prop_cmd + left)
elif "left" in trim:
  os.system("xrandr -o normal")
  os.system(prop_cmd + normal)
else:
  os.system("xrandr -o right")
  os.system(prop_cmd + right)
