"""Independent four-product reference for the three-multiplier RTL pipeline."""
from pathlib import Path
import math
import random


def wrap(value):
    return ((value + 2048) & 4095) - 2048


def rotate(a, b, count, logn):
    n = 1 << logn
    q = n // 4
    exponent = (0, 2, 1, 3)[count // q] * (count % q)
    quadrant, offset = divmod(exponent, q)
    # Direct trig reference, independent of the RTL sine/reverse-address ROM.
    co = min(2047, round(2048 * math.cos(2 * math.pi * offset / n)))
    sn = min(2047, round(2048 * math.sin(2 * math.pi * offset / n)))
    c, s = ((co, -sn), (-sn, -co), (-co, sn), (sn, co))[quadrant]
    if offset == 0:
        r, i = ((a, b), (b, -a), (-a, -b), (-b, a))[quadrant]
    else:
        r, i = (a * c - b * s) >> 11, (a * s + b * c) >> 11
    return wrap(r), wrap(i)


def generate():
    root = Path(__file__).resolve().parent
    rng = random.Random(6011)
    extremes = (-2048, 2047, 0, -1, 1, -1024, 1023, 900)
    for logn in (13, 11, 9, 7, 5, 3):
        n = 1 << logn
        inputs, expected = [], []
        for sweep in range(3):
            for count in range(n):
                if sweep == 0:
                    a, b = extremes[count % 8], extremes[(count // 8) % 8]
                else:
                    a, b = rng.randrange(-2048, 2048), rng.randrange(-2048, 2048)
                r, i = rotate(a, b, count, logn)
                inputs.append(f"{a & 4095:03x}{b & 4095:03x}\n")
                expected.append(f"{r & 4095:03x}{i & 4095:03x}\n")
        (root / f"twiddle_input_{n}.hex").write_text("".join(inputs))
        (root / f"twiddle_expected_{n}.hex").write_text("".join(expected))


if __name__ == "__main__":
    generate()
