
import json
import sys
from subprocess import check_call
from tempfile import mktemp

import yaml

SAMPLE_RATE = 12767


def main(conf_file):
	"""This tool takes a config file of where to find and how to process music,
	and prepares it into samples that the other tools can then process.

	The config file is a YAML file containing an object.
	Keys specify a track name (ie. it generates the file music/NAME.flac),
	and map to an object with keys:
		Exactly one of:
			file: Filepath to get track from
			url: URL to get track from. Uses youtube-dl to download.
		Optionally:
			start: start time to clip, in seconds. default track start.
			end: end time to clip, in seconds. default track end.
			loop: time to loop back to, in seconds. default same as start.
			compress: We try to make tracks louder by applying dynamic compression.
				This is important because they're otherwise very quiet.
				This factor controls how much to apply. Default 4. Set 0 to disable.
			fade: Seconds of fade out at end of track. Default 0. If fade is set, end must also be.
			filters: List of arbitrary ffmpeg filter strings.
	"""

	full_conf = yaml.safe_load(open(conf_file))

	loop_targets = {}
	for name, config in full_conf.items():
		loop_target = do_file(name, **config)
		loop_targets['music/{}.bin'.format(name)] = loop_target

	with open('music/loop_targets.json', 'w') as f:
		f.write(json.dumps(loop_targets) + '\n')


def do_file(name, file=None, url=None, start=0, end=None, loop=None, compress=4, fade=False, filters=[]):
	if url is not None:
		file = mktemp()
		check_call(['youtube-dl', '-o', file, '-x'])
	if file is None:
		raise ValueError("url or file is required")
	if loop is None:
		loop = start
	filters = list(filters)
	if compress:
		filters.append('acompressor=makeup={}'.format(compress))
	if fade:
		if not end:
			raise ValueError("Setting fade requires explicit end")
		length = end - start
		filters.append('afade=t=out:st={}:d={}'.format(length - fade, fade))
	check_call([
		'ffmpeg', '-ss', str(start), '-to', str(end), '-i', file,
		'-af', ','.join(filters), 'music/{}.flac'.format(name), '-y',
	])
	loop_samples = 2 * int((loop - start) * SAMPLE_RATE / 2) # needs to be even
	return loop_samples


if __name__ == '__main__':
	main(*sys.argv[1:])
