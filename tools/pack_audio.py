
import json
import logging
import os
import string
import sys


BANK_SIZE = 16*1024
MIN_REUSE_SIZE = 16


def main(bank_range, loop_targets, *tracks):
	"""Splits up all given track bins into the given range of banks.
	Bank range is made up of comma-seperated bank specs.
	Bank specs are either a range like M-N (inclusive), or a single
	bank N, or a part of a bank N:O[:L] (number, offset, length),
	with length defaulting to "to end".
	eg. "30-39,40:4096:1024,41" would mean our available banks are:
		all of banks 30, 31, 32, 33, 34, 35, 36, 37, 38, 39 and 41
		the bytes from 4096 to 5120 of bank 40.

	It will output an asm file to be included that defines all these sections.

	Each track should be a filepath.
	"""
	logging.basicConfig(level=logging.INFO)

	banks = [] # [(bank number, offset, length)]
	for spec in bank_range.split(","):
		if "-" in spec:
			start, end = map(int, spec.split("-"))
			for bank in range(start, end + 1):
				banks.append((bank, 0, BANK_SIZE))
			continue
		parts = map(int, spec.split(":"))
		if len(parts) == 1:
			bank, = parts
			offset = 0
			length = BANK_SIZE
		elif len(parts) == 2:
			bank, offset = parts
			length = BANK_SIZE
		else:
			bank, offset, length = parts
		banks.append((bank, offset, length))

	loop_targets = json.load(open(loop_targets))

	track_lengths = {track: os.stat(track).st_size for track in tracks}

	# Some early reporting on whether this is even going to work.
	needed = sum(track_lengths.values())
	available = sum(length for bank, offset, length in banks)
	logging.info("Attempting to fit {} tracks ({} B) into {} banks ({} B). Expected fill {:.2f}%.".format(
		len(track_lengths),
		needed,
		len(banks),
		available,
		100. * needed / available,
	))

	# Simple greedy algorithm. Biggest tracks first, filling biggest banks first.
	for track, track_length in sorted(track_lengths.items(), key=lambda (t, l): l, reverse=True):
		logging.info("Placing track {!r}".format(track))
		with open(track) as track_file:
			track_pos = 0
			# ident is name that we can use in an identifier
			track_ident = 'WaveData_' + ''.join(
				c for c in os.path.splitext(os.path.basename(track))[0]
				if c in string.letters + string.digits
			)
			while track_pos < track_length:
				if not banks:
					raise ValueError("Ran out of space while trying to place track {!r}".format(track))

				# Pick biggest bank range left
				bank, offset, bank_length = max(banks, key=lambda (b, o, l): l)
				banks.remove((bank, offset, bank_length))

				# Use either entire bank or entire remaining track, whichever is smaller.
				# Note it must be an even number.
				# Note we leave 4 bytes for the jump at the end
				part_length = 2 * (min(track_length - track_pos, bank_length - 4) / 2)
				used = part_length + 4

				logging.debug("Putting {} B into bank {}, {} B remaining".format(
					part_length,
					bank,
					track_length - (track_pos + part_length),
				))

				# Check if there's any remaining space in bank. If so,
				# split the bank and return the unused part (unless it's too small).
				if bank_length - used > MIN_REUSE_SIZE:
					logging.debug("Reusing remaining {} B of bank".format(bank_length - used))
					banks.append((bank, offset + used, bank_length - used))

				part_name = "{}_{}".format(track_ident, track_pos)

				# If this isn't the first part, write the jump pointer to the end
				# of the previous part.
				if track_pos > 0:
					sys.stdout.write("\tWaveJump {}\n".format(part_name))

				# Write section header
				sys.stdout.write('SECTION "{}: {} to {}", ROMX[{}], BANK[{}]\n'.format(
					track, track_pos, track_pos + part_length,
					0x4000 + offset, bank
				))

				# Write part identifier
				sys.stdout.write("{}:\n".format(part_name))

				# Write data
				for pos in xrange(track_pos, track_pos + part_length, 2):
					if pos == loop_targets.get(track, 0):
						# This is our loop target. Add a label.
						sys.stdout.write("{}_Loop:\n".format(track_ident))
					data = map(ord, track_file.read(2))
					sys.stdout.write("\tdb ${:02x}, ${:02x}\n".format(*data))

				# Update pos and loop
				track_pos += part_length

			# We've finished this track. Add final loop jump.
			sys.stdout.write("\tWaveJump {}_Loop\n".format(track_ident))


if __name__ == '__main__':
	main(*sys.argv[1:])
