import sys

for line in sys.stdin:
    if 'Exit' == line.rstrip():
        break
    if "longitude" in line:
        long = line.split(": ")[1][:-6]
        print(long)
    if "latitude" in line:
        lat = line.split(": ")[1][:-6]
        print(lat)
