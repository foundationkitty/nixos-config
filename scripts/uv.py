import sys, pynvml as n
n.nvmlInit()
h = n.nvmlDeviceGetHandleByIndex(0)

if sys.argv[1] == "reset":
    n.nvmlDeviceResetGpuLockedClocks(h)
    n.nvmlDeviceSetGpcClkVfOffset(h, 0)
    print("stock clocks restored")
else:
    max_clk, offset = int(sys.argv[1]), int(sys.argv[2])
    n.nvmlDeviceSetGpuLockedClocks(h, 210, max_clk)
    n.nvmlDeviceSetGpcClkVfOffset(h, offset)
    print(f"max {max_clk} MHz, offset +{offset} MHz")
