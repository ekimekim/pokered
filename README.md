# Pokémon Red and Blue, Real Music Edition

This is a ROM hack of Pokemon Red and Blue to include arbitrary waveform audio
(which is not meant to be possible on a Gameboy).

You can include your own music by editing `music/sources.yaml`.

See `tools/prepare_music.py` for docs on that file.

## Build instructions

* Update `music/sources.yaml` with whatever music you want. The default currently has
  hard-coded paths to local files on my computer, so it won't work.
  Keep in mind that you only have 10 minutes of audio total.

* Install python, `youtube-dl`, PyYAML, and ffmpeg. This will let you generate the music.

* Install RGBDS as per normal instructions in `INSTALL.md`

* `make`. You may need to touch `music/sources.yaml` then re-`make` multiple times,
because of problems with the makefile that I ran out of time to diagnose.

# Original README:

This is a disassembly of Pokémon Red and Blue.

It builds the following roms:

* Pokemon Red (UE) [S][!].gb  `md5: 3d45c1ee9abd5738df46d2bdda8b57dc`
* Pokemon Blue (UE) [S][!].gb `md5: 50927e843568814f7ed45ec4f944bd8b`

To set up the repository, see [**INSTALL.md**](INSTALL.md).


## See also

* Disassembly of [**Pokémon Yellow**][pokeyellow]
* Disassembly of [**Pokémon Gold**][pokegold]
* Disassembly of [**Pokémon Crystal**][pokecrystal]
* Disassembly of [**Pokémon Pinball**][pokepinball]
* Disassembly of [**Pokémon TCG**][poketcg]
* Disassembly of [**Pokémon Ruby**][pokeruby]
* Disassembly of [**Pokémon Fire Red**][pokefirered]
* Disassembly of [**Pokémon Emerald**][pokeemerald]
* Discord: [**pret**][Discord]
* irc: **irc.freenode.net** [**#pret**][irc]

[pokeyellow]: https://github.com/pret/pokeyellow
[pokegold]: https://github.com/pret/pokegold
[pokecrystal]: https://github.com/pret/pokecrystal
[pokepinball]: https://github.com/pret/pokepinball
[poketcg]: https://github.com/pret/poketcg
[pokeruby]: https://github.com/pret/pokeruby
[pokefirered]: https://github.com/pret/pokefirered
[pokeemerald]: https://github.com/pret/pokeemerald
[Discord]: https://discord.gg/6EuWgX9
[irc]: https://kiwiirc.com/client/irc.freenode.net/?#pret
