roms := pokered.gbc pokeblue.gbc

pokered_obj := audio_red.o main_red.o text_red.o wram_red.o
pokeblue_obj := audio_blue.o main_blue.o text_blue.o wram_blue.o


### Build tools

MD5 := md5sum -c

RGBDS ?=
RGBASM  ?= $(RGBDS)rgbasm
RGBFIX  ?= $(RGBDS)rgbfix
RGBGFX  ?= $(RGBDS)rgbgfx
RGBLINK ?= $(RGBDS)rgblink


### Build targets

.SUFFIXES:
.SECONDEXPANSION:
.PRECIOUS:
.SECONDARY:
.PHONY: all red blue clean tidy compare tools gambatte gambatte_debug bgb

all: $(roms)
red: pokered.gbc
blue: pokeblue.gbc

gambatte: pokered.gbc
	gambatte_sdl "$<"

gambatte_debug: pokered.gbc
	cd ../gambatte && ./build_sdl.sh
	../gambatte/gambatte_sdl/gambatte_sdl "$<"

bgb: pokered.gbc
	bgb "$<"

# For contributors to make sure a change didn't affect the contents of the rom.
compare: $(roms)
	@$(MD5) roms.md5

clean:
	rm -f $(roms) $(pokered_obj) $(pokeblue_obj) $(roms:.gbc=.sym)
	find . \( -iname '*.1bpp' -o -iname '*.2bpp' -o -iname '*.pic' \) -exec rm {} +
	rm -f music/*.bin
	$(MAKE) clean -C tools/

tidy:
	rm -f $(roms) $(pokered_obj) $(pokeblue_obj) $(roms:.gbc=.sym)
	$(MAKE) clean -C tools/

tools:
	$(MAKE) -C tools/


# Build tools when building the rom.
# This has to happen before the rules are processed, since that's when scan_includes is run.
ifeq (,$(filter clean tools,$(MAKECMDGOALS)))
$(info $(shell $(MAKE) -C tools))
endif


%.asm: ;

%_red.o: dep = $(shell tools/scan_includes $(@D)/$*.asm)
$(pokered_obj): %_red.o: %.asm $$(dep)
	$(RGBASM) -D _RED -h -o $@ $*.asm

%_blue.o: dep = $(shell tools/scan_includes $(@D)/$*.asm)
$(pokeblue_obj): %_blue.o: %.asm $$(dep)
	$(RGBASM) -D _BLUE -h -o $@ $*.asm

pokered_opt  = -C -jsv -k 01 -l 0x33 -m 0x1b -p 0 -r 03 -t "POKEMON RED"
pokeblue_opt = -C -jsv -k 01 -l 0x33 -m 0x1b -p 0 -r 03 -t "POKEMON BLUE"

%.gbc: $$(%_obj)
	$(RGBLINK) -d -n $*.sym -l pokered.link -o $@ $^
	$(RGBFIX) $($*_opt) $@
	sort $*.sym -o $*.sym


### Misc file-specific graphics rules

gfx/blue/intro_purin_1.2bpp: $(RGBGFX) += -h
gfx/blue/intro_purin_2.2bpp: $(RGBGFX) += -h
gfx/blue/intro_purin_3.2bpp: $(RGBGFX) += -h
gfx/red/intro_nido_1.2bpp: $(RGBGFX) += -h
gfx/red/intro_nido_2.2bpp: $(RGBGFX) += -h
gfx/red/intro_nido_3.2bpp: $(RGBGFX) += -h

gfx/game_boy.2bpp: tools/gfx += --remove-duplicates
gfx/theend.2bpp: tools/gfx += --interleave --png=$<
gfx/tilesets/%.2bpp: tools/gfx += --trim-whitespace


### Catch-all graphics rules

%.png: ;

%.2bpp: %.png
	$(RGBGFX) $(rgbgfx) -o $@ $<
	$(if $(tools/gfx),\
		tools/gfx $(tools/gfx) -o $@ $@)

%.1bpp: %.png
	$(RGBGFX) -d1 $(rgbgfx) -o $@ $<
	$(if $(tools/gfx),\
		tools/gfx $(tools/gfx) -d1 -o $@ $@)

%.pic:  %.2bpp
	tools/pkmncompress $< $@


### Wave music rules

ORIGINALS := $(wildcard music/*.flac)
MUSIC_BINS := $(ORIGINALS:.flac=.bin)
# TODO: might be able to reclaim some space from unused bits of other banks
MUSIC_BANKS := "45-512"

music/%.bin: music/%.flac
	tools/process_audio $< > $@

music/wave_data.asm: $(MUSIC_BINS)
	python tools/pack_audio.py $(MUSIC_BANKS) $^ > $@
