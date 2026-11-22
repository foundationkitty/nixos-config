import argparse
import os
import signal
import sys
import threading
import time

FORMATS = {
    "rgb24": (3, (0, 1, 2)),
    "bgr24": (3, (2, 1, 0)),
    "bgr0": (4, (2, 1, 0)),
    "bgra": (4, (2, 1, 0)),
    "rgb0": (4, (0, 1, 2)),
    "rgba": (4, (0, 1, 2)),
}


def log(*args):
    print("xvsr-filter:", *args, file=sys.stderr, flush=True)


def size(s):
    try:
        w, h = s.lower().split("x")
        return int(w), int(h)
    except ValueError:
        raise argparse.ArgumentTypeError(f"bad size {s!r}, want WxH")


def read_frame(f, buf):
    view = memoryview(buf).cast("B")
    pos = 0
    while pos < len(view):
        n = f.readinto(view[pos:])
        if not n:
            return False
        pos += n
    return True


def write_frame(fd, buf):
    view = memoryview(buf).cast("B")
    pos = 0
    while pos < len(view):
        pos += os.write(fd, view[pos:])


class Reader(threading.Thread):
    def __init__(self, f, bufs):
        super().__init__(daemon=True)
        self.f = f
        self.bufs = bufs
        self.views = [b.numpy() for b in bufs]
        self.cond = threading.Condition()
        self.latest = None
        self.busy = None
        self.done = False
        self.dropped = 0

    def run(self):
        try:
            while True:
                with self.cond:
                    i = next(i for i in range(len(self.bufs)) if i not in (self.busy, self.latest))
                if not read_frame(self.f, self.views[i]):
                    break
                with self.cond:
                    if self.latest is not None:
                        self.dropped += 1
                    self.latest = i
                    self.cond.notify()
        finally:
            with self.cond:
                self.done = True
                self.cond.notify()

    def next(self):
        with self.cond:
            self.busy = None
            while self.latest is None and not self.done:
                self.cond.wait()
            if self.latest is None:
                return None
            self.busy, self.latest = self.latest, None
            return self.bufs[self.busy]


class Upscaler:
    def __init__(self, torch, VSR, args, dev):
        self.torch = torch
        self.VSR = VSR
        self.args = args
        self.dev = dev
        self.iw, self.ih = args.in_size
        self.ow, self.oh = args.out_size
        self.bpp, self.chans = FORMATS[args.in_fmt]
        self.quality = self.lookup(args.quality)
        self.bicubic = False
        self.flip = False

        try:
            self.load(args.render or args.out_size)
        except Exception as e:
            if args.render:
                raise
            log(f"{self.ow}x{self.oh} didn't work ({e}), trying 2x and scaling down")
            self.load((self.iw * 2, self.ih * 2))

        self.gpu_in = torch.empty(self.ih * self.iw * self.bpp, dtype=torch.uint8, device=dev)
        self.gpu_out = torch.empty((self.oh, self.ow, 3), dtype=torch.uint8, device=dev)
        self.host_out = torch.empty((self.oh, self.ow, 3), dtype=torch.uint8, pin_memory=dev.type == "cuda")

    def lookup(self, name):
        try:
            return getattr(self.VSR.QualityLevel, name.upper())
        except AttributeError:
            sys.exit(f"no quality {name!r}, options: " + ", ".join(q.name for q in self.VSR.QualityLevel))

    def load(self, render):
        self.rw, self.rh = render
        self.vsr = self.VSR(quality=self.quality, strength=self.args.strength, device=self.args.device)
        self.vsr.output_width, self.vsr.output_height = render
        self.vsr.load()
        self.upscale(self.torch.zeros((3, self.ih, self.iw), device=self.dev))
        msg = f"{self.iw}x{self.ih} -> {self.rw}x{self.rh}"
        if render != (self.ow, self.oh):
            msg += f" -> {self.ow}x{self.oh}"
        log(f"{msg}, {self.quality.name}, strength {self.args.strength}")

    def upscale(self, x):
        return self.torch.from_dlpack(self.vsr.run(x).image)

    def toggle(self):
        self.flip = False
        self.bicubic = not self.bicubic
        q = self.VSR.QualityLevel.BICUBIC if self.bicubic else self.quality
        self.vsr.quality = q
        if getattr(self.vsr, "needs_reload", False):
            self.vsr.load()
        log("quality", q.name)

    def process(self, frame):
        t = self.torch
        if self.flip:
            self.toggle()
        self.gpu_in.copy_(frame, non_blocking=True)
        img = self.gpu_in.view(self.ih, self.iw, self.bpp)
        r, g, b = self.chans
        x = t.stack((img[..., r], img[..., g], img[..., b])).float().div_(255)

        y = self.upscale(x)
        if (self.rw, self.rh) != (self.ow, self.oh):
            y = t.nn.functional.interpolate(y[None], size=(self.oh, self.ow), mode="bilinear",
                                            antialias=True, align_corners=False)[0]
        self.gpu_out.copy_(y.clamp(0, 1).mul(255).add(0.5).byte().permute(1, 2, 0))
        self.host_out.copy_(self.gpu_out)
        return self.host_out


def setup(args):
    try:
        import torch
        from nvvfx import VideoSuperRes
    except ImportError as e:
        sys.exit(f"{e}, run xvsr setup")

    if torch.cuda.is_available():
        dev = torch.device("cuda", args.device)
        torch.cuda.set_device(dev)
    elif os.environ.get("XVSR_ALLOW_CPU") == "1":
        dev = torch.device("cpu")
    else:
        sys.exit("no CUDA, check nvidia-smi and that /run/opengl-driver/lib is in LD_LIBRARY_PATH")
    torch.set_grad_enabled(False)
    return torch, VideoSuperRes, dev


def bench(torch, VSR, args, dev):
    up = Upscaler(torch, VSR, args, dev)
    frame = torch.randint(0, 256, (up.ih * up.iw * up.bpp,), dtype=torch.uint8)
    for _ in range(5):
        up.process(frame)
    start = time.perf_counter()
    for _ in range(60):
        up.process(frame)
    ms = (time.perf_counter() - start) * 1000 / 60
    log(f"{ms:.2f} ms/frame (~{1000 / ms:.0f} fps)")
    if ms > 16.6:
        log("too slow for 60fps, try --quality STREAMING_MEDIUM")


def main():
    p = argparse.ArgumentParser(prog="xvsr-filter")
    p.add_argument("--in", dest="in_size", type=size, default=(1920, 1080))
    p.add_argument("--in-fmt", choices=sorted(FORMATS), default="bgr0")
    p.add_argument("--out", dest="out_size", type=size, default=(2560, 1440))
    p.add_argument("--render", type=size)
    p.add_argument("--quality", default="STREAMING_ULTRA")
    p.add_argument("--strength", type=float, default=1.0)
    p.add_argument("--device", type=int, default=0)
    p.add_argument("--stats", type=float, default=0)
    p.add_argument("--selftest", action="store_true")
    p.add_argument("--list-qualities", action="store_true")
    args = p.parse_args()

    torch, VSR, dev = setup(args)

    if args.list_qualities:
        for q in VSR.QualityLevel:
            print(f"{q.name} ({int(q)})")
        return
    if args.selftest:
        bench(torch, VSR, args, dev)
        return

    up = Upscaler(torch, VSR, args, dev)
    signal.signal(signal.SIGUSR1, lambda *_: setattr(up, "flip", True))

    n = up.iw * up.ih * up.bpp
    bufs = [torch.empty(n, dtype=torch.uint8, pin_memory=dev.type == "cuda") for _ in range(3)]
    reader = Reader(open(sys.stdin.fileno(), "rb", buffering=0, closefd=False), bufs)
    reader.start()
    out = sys.stdout.fileno()

    frames, busy, last = 0, 0.0, time.monotonic()
    try:
        while (frame := reader.next()) is not None:
            t0 = time.perf_counter()
            res = up.process(frame)
            busy += time.perf_counter() - t0
            write_frame(out, res.numpy())
            frames += 1

            now = time.monotonic()
            if args.stats and now - last >= args.stats:
                log(f"{frames / (now - last):.1f} fps, {busy * 1000 / frames:.2f} ms/frame, {reader.dropped} dropped")
                frames, busy, last = 0, 0.0, now
    except (BrokenPipeError, KeyboardInterrupt):
        pass
    finally:
        signal.signal(signal.SIGUSR1, signal.SIG_IGN)
        try:
            up.vsr.close()
        except Exception:
            pass


if __name__ == "__main__":
    main()
