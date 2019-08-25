
import sys
import os

values = {(x+1) * (y - 7.5) + 60: (x, y) for x in range(8) for y in range(16)}
ceil = max(values)

RAW_OUTPUT = os.environ.get("RAW_OUTPUT", "").lower() == "true"


def main():
	"""Takes 8-bit samples on stdin, writes 16-bit pairs (volume pair, sample pair) to stdout.
	This output is suitable to be directly put into a ROM, or sliced up to fit in banks.
	If env var RAW_OUTPUT=true given, instead output in format suitable for conversion back
	to an audio file.
	"""
	xs = []
	ys = []
	while True:
		c = sys.stdin.read(1)
		if not c:
			break
		i = ord(c)
		i = quantize(i)
		assert i in values
		if RAW_OUTPUT:
			sys.stdout.write(chr(int(i * 2)))
		else:
			x, y = values[i]
			xs.append(x)
			ys.append(y)

	if RAW_OUTPUT:
		return

	if len(xs) % 2 == 1:
		# even it up with a neutral value. easier than handling special case of odd total samples.
		x, y = values[quantize(128)]
		xs.append(x)
		ys.append(y)

	# ys is delayed by 30 so we pad xs with 30 zeroes at start and y with 30 7s at end
	xs = [0] * 30 + xs
	ys = ys + [7] * 30

	for (x1, x2), (y1, y2) in zip(zip(xs[::2], xs[1::2]), zip(ys[::2], ys[1::2])):
		# pair of volumes first, then pair of samples. in both cases first sample is most signifigant nibble
		sys.stdout.write(chr(x1 * 16 + x2) + chr(y1 * 16 + y2))


def quantize(i):
	i = i * ceil / 256.

	lower = max(x for x in values if x <= i)
	upper = [x for x in values if x >= i]
	if not upper:
		return lower
	upper = min(upper) if upper else None

	if i - lower <= upper - i:
		# lower is closer or tied
		return lower
	return upper


if __name__ == '__main__':
	main()
