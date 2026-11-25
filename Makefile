# Prototype Makefile, cut down from Matrix Time's.
CIQ_HOME ?= $(HOME)/Library/Application Support/Garmin/ConnectIQ
SDK_BIN  ?= $(shell sed -e 's:/*$$::' "$(CIQ_HOME)/current-sdk.cfg" 2>/dev/null)/bin
# The key sits beside the repository's main checkout (~/dev/garmin/garmin-keys). Found through
# git's common directory, so the default holds in a worktree too, where ../ is somewhere else.
# Override with: make build DEV_KEY=/path/to/developer_key
MAIN_CHECKOUT := $(shell d=$$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && dirname "$$d")
DEV_KEY  ?= $(if $(MAIN_CHECKOUT),$(MAIN_CHECKOUT),.)/../garmin-keys/developer_key
# zsh leaves the ~ of DEV_KEY=~/... unexpanded, and the path is quoted below, so expand it here.
KEY      := $(patsubst ~/%,$(HOME)/%,$(DEV_KEY))
DEVICE   ?= epix2pro47mm
SIM_PORT ?= 1234
APP      := FerrataTime
# REPLAY=1: the replay build (#57, replay.jungle): the recording resources-replay/replay.json, made by
# make replay, played in the sensors' place in the simulator. Its own .prg, so it is never mistaken
# for the app; make sideload refuses it.
ifeq ($(REPLAY),1)
JUNGLE   := monkey.jungle;replay.jungle
OUTPUT   := $(APP)-replay.prg
else
JUNGLE   := monkey.jungle
OUTPUT   := $(APP).prg
endif
REPLAY_JSON := resources-replay/replay.json
PYTHON   ?= python3

MONKEYC   = "$(SDK_BIN)/monkeyc"
MONKEYDO  = "$(SDK_BIN)/monkeydo"
CONNECTIQ = "$(SDK_BIN)/connectiq"

.PHONY: all build sim run sideload clean routes replay fonts check-fonts font-sources check-ttf2bmp \
  install-ttf2bmp check-garmin-font-scaler install-garmin-font-scaler

all: build

## Build the .prg for DEVICE
build:
	@test -f "$(KEY)" || { echo "No developer key at $(KEY). Pass its path: make $(or $(MAKECMDGOALS),build) DEV_KEY=/path/to/developer_key"; exit 1; }
	@test "$(REPLAY)" != 1 || test -f $(REPLAY_JSON) || { echo "No recording at $(REPLAY_JSON). Make one: make replay FIT=/path/to/track.fit"; exit 1; }
	@echo "Building for $(DEVICE)$(if $(filter 1,$(REPLAY)), (replay))..."
	@$(MONKEYC) -f "$(JUNGLE)" -d $(DEVICE) -y "$(KEY)" -w -o $(OUTPUT)
	@echo "Build complete: $(OUTPUT)"

## Start the simulator unless it is running
sim:
	@if nc -z 127.0.0.1 $(SIM_PORT) 2>/dev/null; then echo "Simulator already running."; else \
	  $(CONNECTIQ) & n=0; until nc -z 127.0.0.1 $(SIM_PORT) 2>/dev/null; do \
	    n=$$((n+1)); test $$n -lt 60 || { echo "Simulator did not start."; exit 1; }; sleep 1; done; \
	  echo "Simulator ready."; fi

## Build and load into the simulator (stays attached; Ctrl-C to stop)
run: build sim
	@$(MONKEYDO) $(OUTPUT) $(DEVICE)

## Build for the connected watch and copy it over USB (MTP; brew install libmtp)
sideload:
	@test "$(REPLAY)" != 1 || { echo "The replay build is for the simulator only."; exit 1; }
	@watch=$$(CIQ_HOME="$(CIQ_HOME)" tools/sideload.sh detect) || exit 1; \
	echo "Watch detected: $$watch"; \
	grep -q '<iq:product id="'"$$watch"'"/>' manifest.xml || { echo "manifest.xml does not list $$watch."; exit 1; }; \
	$(MAKE) --no-print-directory build DEVICE=$$watch && tools/sideload.sh install $(OUTPUT)

# The font tools, as Climber Time's (#62; wkusnierczyk/garmin-climber-time#17): ttf2bmp turns a TTF into bitmap fonts, garmin-font-scaler drives
# it once per resolution. Neither comes with the SDK. The check looks on PATH, where
# garmin-font-scaler looks too; the install puts each in BIN_DIR, which must be on PATH.
## Where the install targets put the font tools; must be on PATH
BIN_DIR ?= $(HOME)/.local/bin
# The lowest ttf2bmp the fonts build with (--stroke came in 0.3.0), and the release
# install-ttf2bmp fetches (wkusnierczyk/garmin-climber-time#31). Each release carries a .tar.gz of one binary for
# darwin-arm64, darwin-amd64 and linux-amd64; the binary's name inside varies (linux-amd64
# holds ttf2bmp-linux), so the install takes the one file the archive holds.
TTF2BMP_VERSION := 0.3.0
TTF2BMP_RELEASES := https://github.com/wkusnierczyk/ttf2bmp/releases/download

# Exits 1 when $(1)'s version, MAJOR.MINOR.PATCH, is below $(2)'s, or is not one.
version_at_least = awk -v have="$(1)" -v need="$(2)" 'BEGIN { \
  if (have !~ /^[0-9]+\.[0-9]+\.[0-9]+$$/) exit 1; split(have, h, "."); split(need, n, "."); \
  for (i = 1; i <= 3; i++) { if (h[i] + 0 != n[i] + 0) exit (h[i] + 0 < n[i] + 0) } }'

# "ttf2bmp --version" prints "ttf2bmp version v0.3.0".
define require_ttf2bmp
@have=$$(ttf2bmp --version 2>/dev/null | head -n 1 | sed -nE 's/.*version v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'); \
  $(call version_at_least,$$have,$(TTF2BMP_VERSION)) || { \
  if command -v ttf2bmp >/dev/null; then \
    echo "make $@ needs ttf2bmp $(TTF2BMP_VERSION) or newer; $$(command -v ttf2bmp) is $${have:-of no known version}."; \
  else echo "make $@ needs ttf2bmp $(TTF2BMP_VERSION) or newer, and there is none on PATH."; fi; \
  echo "Install it into $(BIN_DIR) with: make install-ttf2bmp"; exit 1; }
endef

## Check that PATH has ttf2bmp, new enough for the fonts
check-ttf2bmp:
	$(require_ttf2bmp)
	@echo "ttf2bmp $$(ttf2bmp --version | sed -nE 's/.*version v?//p') at $$(command -v ttf2bmp)."

# Replaces a ttf2bmp already in BIN_DIR, even a newer one, but only with a binary that runs and
# reports TTF2BMP_VERSION or newer. curl and tar are on macOS and on the CI image.
## Install ttf2bmp's release binary into BIN_DIR [BIN_DIR]
install-ttf2bmp:
	@os=$$(uname -s | tr '[:upper:]' '[:lower:]'); arch=$$(uname -m); \
	case $$arch in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; esac; \
	case $$os-$$arch in darwin-arm64|darwin-amd64|linux-amd64) ;; \
	  *) echo "ttf2bmp $(TTF2BMP_VERSION) has no release binary for $$os-$$arch."; exit 1 ;; esac; \
	url="$(TTF2BMP_RELEASES)/v$(TTF2BMP_VERSION)/ttf2bmp-$$os-$$arch.tar.gz"; \
	tmp=$$(mktemp -d) || exit 1; trap 'rm -rf "$$tmp"' EXIT; \
	echo "Downloading $$url..."; \
	curl -fsSL -o "$$tmp/ttf2bmp.tar.gz" "$$url" || { echo "Download failed."; exit 1; }; \
	mkdir "$$tmp/x" && tar -xzf "$$tmp/ttf2bmp.tar.gz" -C "$$tmp/x" || exit 1; \
	set -- "$$tmp"/x/*; test $$# -eq 1 && test -f "$$1" || { \
	  echo "The archive does not hold one file: $$(ls "$$tmp/x" | tr '\n' ' ')"; exit 1; }; \
	chmod 755 "$$1"; got=$$("$$1" --version 2>/dev/null | head -n 1 | sed -nE 's/.*version v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'); \
	$(call version_at_least,$$got,$(TTF2BMP_VERSION)) || { \
	  echo "The downloaded file does not run as ttf2bmp $(TTF2BMP_VERSION); nothing installed."; exit 1; }; \
	mkdir -p "$(BIN_DIR)" && install -m 755 "$$1" "$(BIN_DIR)/ttf2bmp" || exit 1; \
	echo "Installed $$("$(BIN_DIR)/ttf2bmp" --version) at $(BIN_DIR)/ttf2bmp."; \
	case ":$$PATH:" in *":$(BIN_DIR):"*) ;; \
	  *) echo "$(BIN_DIR) is not on PATH: add it, or make check-ttf2bmp will not find ttf2bmp." ;; esac

# The lowest garmin-font-scaler the fonts build with (stroke="W" came in 0.3.0), and the
# tag install-garmin-font-scaler installs (wkusnierczyk/garmin-climber-time#32). It is not on PyPI, so pip takes it from
# the tag, into a virtual environment of its own, linked into BIN_DIR.
FONT_SCALER_VERSION := 0.3.0
FONT_SCALER_REPO := https://github.com/wkusnierczyk/garmin-font-scaler.git
## The scaler's virtual environment, which install-garmin-font-scaler replaces
FONT_SCALER_VENV ?= $(HOME)/.local/share/venvs/garmin-font-scaler
# Not whichever python3 is first on PATH: on the owner's Mac, Homebrew's (3.13, 3.15)
# cannot bootstrap pip in a new environment, as platform.mac_ver() returns empty strings
# there and pip's vendored truststore fails parsing them (wkusnierczyk/garmin-climber-time#32). Apple's /usr/bin/python3
# (3.9, older pip) works, so it is tried first, then python3 on PATH (Linux, where
# /usr/bin/python3 may lack venv); the first that makes an environment with pip is kept.
# pip is not upgraded in the environment, which would bring truststore back. On macOS
# /usr/bin/python3 is tried only with the developer tools installed, or it opens a dialog.
## The Python to build the scaler's environment on; empty tries /usr/bin/python3, then python3
FONT_SCALER_PYTHON ?=

# "garmin-font-scaler --version" prints "garmin-font-scaler 0.3.0".
define require_font_scaler
@have=$$(garmin-font-scaler --version 2>/dev/null | head -n 1 | sed -nE 's/^garmin-font-scaler v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'); \
  $(call version_at_least,$$have,$(FONT_SCALER_VERSION)) || { \
  if command -v garmin-font-scaler >/dev/null; then \
    echo "make $@ needs garmin-font-scaler $(FONT_SCALER_VERSION) or newer; $$(command -v garmin-font-scaler) is $${have:-of no known version}."; \
  else echo "make $@ needs garmin-font-scaler $(FONT_SCALER_VERSION) or newer, and there is none on PATH."; fi; \
  echo "Install it into $(BIN_DIR) with: make install-garmin-font-scaler"; exit 1; }
endef

## Check that PATH has garmin-font-scaler, new enough for the fonts
check-garmin-font-scaler:
	$(require_font_scaler)
	@echo "$$(garmin-font-scaler --version) at $$(command -v garmin-font-scaler)."

# A working environment is moved aside, not deleted, and put back if the new one fails or the
# run is interrupted; an environment left aside by an interrupted run stays the backup. The
# environment's path is made absolute, so the link into BIN_DIR resolves from anywhere.
# make_venv is that shell: $(1) the
# environment, $(2) the Python to build it on (empty tries /usr/bin/python3, then python3),
# $(3) that Python's variable. It leaves $$venv made, with pip, and the traps set; restore
# puts the previous one back. After the install is checked: trap - INT TERM; rm -rf "$$old".
make_venv = venv="$(1)"; case $$venv in /*) ;; *) venv="$$PWD/$$venv" ;; esac; old="$$venv.old"; \
  nodev=; if test "$$(uname -s)" = Darwin && ! xcode-select -p >/dev/null 2>&1; then nodev=1; fi; \
  if test -e "$$venv"; then rm -rf "$$old" && mv "$$venv" "$$old" || exit 1; fi; \
  restore() { rm -rf "$$venv"; if test -e "$$old"; then mv "$$old" "$$venv"; echo "Kept the previous $$venv."; fi; }; \
  trap 'restore; exit 1' INT TERM; \
  try() { p=$$(command -v "$$1") || { echo "No $$1."; return 1; }; \
    if test -n "$$nodev" && test "$$p" = /usr/bin/python3; then \
      echo "Skipping $$p: without the developer tools it opens their install dialog."; return 1; fi; \
    echo "Making $$venv with $$p ($$("$$p" --version 2>&1))..."; \
    if "$$p" -m venv "$$venv" && "$$venv/bin/python" -m pip --version >/dev/null; then return 0; fi; \
    echo "$$p cannot make a virtual environment with pip."; rm -rf "$$venv"; return 1; }; \
  if test -n "$(2)"; then try "$(2)"; \
  else try /usr/bin/python3 || try python3; fi || { \
    echo "No Python made one; pick one with $(3)=/path/to/python3."; restore; exit 1; }

## Install garmin-font-scaler in its own environment, linked into BIN_DIR [BIN_DIR FONT_SCALER_VENV FONT_SCALER_PYTHON]
install-garmin-font-scaler:
	@$(call make_venv,$(FONT_SCALER_VENV),$(FONT_SCALER_PYTHON),FONT_SCALER_PYTHON); \
	echo "Installing garmin-font-scaler $(FONT_SCALER_VERSION) from $(FONT_SCALER_REPO)..."; \
	"$$venv/bin/python" -m pip install --quiet --disable-pip-version-check \
	  "git+$(FONT_SCALER_REPO)@v$(FONT_SCALER_VERSION)" || { echo "pip install failed."; restore; exit 1; }; \
	got=$$("$$venv/bin/garmin-font-scaler" --version 2>/dev/null | head -n 1 | sed -nE 's/^garmin-font-scaler v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'); \
	$(call version_at_least,$$got,$(FONT_SCALER_VERSION)) || { \
	  echo "The installed garmin-font-scaler does not run as $(FONT_SCALER_VERSION) or newer."; restore; exit 1; }; \
	trap - INT TERM; rm -rf "$$old"; \
	mkdir -p "$(BIN_DIR)" && ln -sf "$$venv/bin/garmin-font-scaler" "$(BIN_DIR)/garmin-font-scaler" || exit 1; \
	"$(BIN_DIR)/garmin-font-scaler" --version >/dev/null 2>&1 || { \
	  echo "$(BIN_DIR)/garmin-font-scaler does not run."; exit 1; }; \
	echo "Installed garmin-font-scaler $$got at $(BIN_DIR)/garmin-font-scaler."; \
	case ":$$PATH:" in *":$(BIN_DIR):"*) ;; \
	  *) echo "$(BIN_DIR) is not on PATH: add it, or make check-garmin-font-scaler will not find the scaler." ;; esac


# The bitmap fonts (#62): garmin-font-scaler writes resources-round-416x416/fonts/ from
# resources/fonts/ (fonts.xml, charsets.json, resolutions.json), and fonts.md. It does not
# refresh resources/fonts/'s own bitmaps, which the compiler reads for a product with no
# directory of its own, so they are copied from the reference resolution's; the reference is
# read from resolutions.json. README.md's size table is copied from fonts.md, and the
# typeface's and the bitmaps' SHA-256 recorded in fonts.sha256; then all of it is checked.
# Six pixels between glyphs in the atlas, not ttf2bmp's two: a glyph whose ink starts left of
# its origin (Barlow's j) spills a column into the gap, cut off, and with two the watch drew
# that column as a faint mark after an i. Six keeps a two-column spill clear of the column after.
FONT_PADDING := 6
# The size table, resources/fonts/sizes.json, is the one source: tools/font-config.py writes
# fonts.xml, charsets.json and source/FontSizes.mc from it first, and after the scaler sets each
# bitmap's advances to the font's own, rounded to the nearest pixel (ttf2bmp rounds them up).
## Regenerate the font configuration from the size table, the bitmap fonts, fonts.md, fonts.sha256 and README.md's tables (needs ttf2bmp and garmin-font-scaler)
fonts:
	$(require_ttf2bmp)
	$(require_font_scaler)
	@python3 tools/font-config.py write
	@for d in resources-*-*x*/fonts; do test -d "$$d" && rm -f "$$d"/*.fnt "$$d"/*.png; done; true
	@garmin-font-scaler --padding $(FONT_PADDING) --table fonts.md
	@python3 tools/font-config.py advances resources-*-*x*/fonts
	@rm -f resources/fonts/*.fnt resources/fonts/*.png
	@ref=$$(python3 -c 'import json; r = json.load(open("resources/fonts/resolutions.json"))["reference"]; print("resources-%s-%dx%d" % (r["shape"], *r["resolution"]))') && \
	  for f in $$(sed -nE 's/.*filename="([^"]+)\.fnt".*/\1/p' resources/fonts/fonts.xml); do \
	    cp "$$ref/fonts/$$f.fnt" "$$ref/fonts/$$f.png" resources/fonts/ || exit 1; done
	@python3 tools/check-font-config.py --write

# Pure Python, no SDK and no font tools.
## Check that the fonts agree with their configuration, Draw.mc's sizes and README.md
check-fonts:
	@echo "Checking the fonts..."
	@python3 tools/check-font-config.py

# The typeface (#62, #109): Barlow Semi Condensed SemiBold and Bold, the static weights in
# google/fonts (ofl/barlowsemicondensed/), fetched at the commit below and held to their SHA-256,
# then given tabular figures by tools/tabular-figures.py, which needs fontTools (pip install
# fonttools) in FONTTOOLS_PYTHON. Writes resources/fonts/BarlowSemiCondensedTabular-*.ttf and the
# licence beside them, and source/DigitInk.mc, the number glyphs' ink (tools/digit-ink.py, #109);
# make fonts then makes the bitmaps from them.
GOOGLE_FONTS_COMMIT := 60824dce48f7dd28fe7d65559f2da1f6e04e585b
GOOGLE_FONTS_RAW := https://raw.githubusercontent.com/google/fonts/$(GOOGLE_FONTS_COMMIT)/ofl/barlowsemicondensed
BARLOW_SHA256 := \
  bd299f4bc5b44d30be8d42e9bad3a5df7d66af1cd55d0ed72a8b8916360a1424:BarlowSemiCondensed-SemiBold.ttf \
  5bd6757e459a110da81b44532f0f43058e2dab2401688abca84f2fdbde193cbb:BarlowSemiCondensed-Bold.ttf \
  186d750eb496a4c17a76385f82be6aea2ac1cf2de074a811d63786cf374ea73f:OFL.txt
# The committed TTFs were made with fontTools 4.60.2 (Barlow Condensed's gave the same bytes with
# 4.68.0); older ones are refused. Build its environment on Apple's /usr/bin/python3, as for the scaler (Homebrew's
# Python cannot bootstrap pip on the owner's Mac): /usr/bin/python3 -m venv <dir> &&
# <dir>/bin/pip install fonttools==4.60.2, then FONTTOOLS_PYTHON=<dir>/bin/python.
FONTTOOLS_VERSION := 4.60.2
## The Python with fontTools that font-sources runs tools/tabular-figures.py with
FONTTOOLS_PYTHON ?= python3
## Fetch Barlow Semi Condensed from google/fonts and give it tabular figures (needs fontTools) [FONTTOOLS_PYTHON]
font-sources:
	@have=$$("$(FONTTOOLS_PYTHON)" -c 'import fontTools; print(fontTools.version)' 2>/dev/null); \
	  $(call version_at_least,$$have,$(FONTTOOLS_VERSION)) || { \
	  echo "make $@ needs fontTools $(FONTTOOLS_VERSION) or newer in $(FONTTOOLS_PYTHON) (found $${have:-none})."; \
	  echo "See the Makefile's FONTTOOLS_VERSION for an environment; pass FONTTOOLS_PYTHON=/path/to/python."; exit 1; }
	@tmp=$$(mktemp -d) || exit 1; trap 'rm -rf "$$tmp"' EXIT; \
	for pair in $(BARLOW_SHA256); do \
	  sum=$${pair%%:*}; f=$${pair#*:}; \
	  echo "Fetching $(GOOGLE_FONTS_RAW)/$$f"; \
	  curl -fsSL -o "$$tmp/$$f" "$(GOOGLE_FONTS_RAW)/$$f" || { echo "Download failed."; exit 1; }; \
	  got=$$( (shasum -a 256 "$$tmp/$$f" 2>/dev/null || sha256sum "$$tmp/$$f") | cut -d' ' -f1); \
	  test "$$got" = "$$sum" || { echo "$$f: SHA-256 $$got, expected $$sum."; exit 1; }; \
	done; \
	for w in SemiBold Bold; do \
	  "$(FONTTOOLS_PYTHON)" tools/tabular-figures.py "$$tmp/BarlowSemiCondensed-$$w.ttf" \
	    "resources/fonts/BarlowSemiCondensedTabular-$$w.ttf" || exit 1; \
	done; \
	cp "$$tmp/OFL.txt" resources/fonts/OFL-BarlowSemiCondensed.txt; \
	"$(FONTTOOLS_PYTHON)" tools/digit-ink.py resources/fonts/BarlowSemiCondensedTabular-SemiBold.ttf source/DigitInk.mc

## Run the unit tests in the simulator (source/tests/; Toybox.Test, built with --unit-test); REPLAY=1
## runs them in the replay build, on resources-replay/replay.json
# monkeydo exits 1 whether the suite passes or not, so the anchored summary line is the gate, as in
# Matrix Time (playbook, reference/testing.md). A run that cannot reach the simulator prints no
# summary and fails the same way. Only one monkeydo session at a time: a second one hangs.
.PHONY: test
TEST_OUTPUT := test_build.prg
# The key is checked before the simulator is started, so a missing key does not leave one running.
test:
	@test -f "$(KEY)" || { echo "No developer key at $(KEY). Pass its path: make test DEV_KEY=/path/to/developer_key"; exit 1; }
	@test "$(REPLAY)" != 1 || test -f $(REPLAY_JSON) || { echo "No recording at $(REPLAY_JSON). Make one: make replay FIT=/path/to/track.fit"; exit 1; }
	@$(MAKE) --no-print-directory sim
	@echo "Building the unit tests for $(DEVICE)$(if $(filter 1,$(REPLAY)), (replay))..."
	@$(MONKEYC) -f "$(JUNGLE)" -d $(DEVICE) -y "$(KEY)" -w --unit-test -o $(TEST_OUTPUT)
	@echo "Running the unit tests in the simulator..."
	@output=$$($(MONKEYDO) $(TEST_OUTPUT) $(DEVICE) -t 2>&1); \
	  echo "$$output"; \
	  echo "$$output" | grep -qE '^PASSED \(' || { echo "Unit tests did not report PASSED."; exit 1; }

## Rebuild every route file, resources/routes/<id>.json, from its source, routes/<id>.src.json, with
## the coordinates from its track, routes/<id>.gpx, when there is one. Fails on a route file with no
## source.
routes:
	@for out in resources/routes/*.json; do \
	  test -e "$$out" || continue; id=$$(basename "$$out" .json); \
	  test -f "routes/$$id.src.json" || { echo "$$out has no source, routes/$$id.src.json" >&2; exit 1; }; \
	done
	@for src in routes/*.src.json; do \
	  id=$$(basename "$$src" .src.json); out=resources/routes/$$id.json; \
	  gpx=; test -f "routes/$$id.gpx" && gpx="--gpx routes/$$id.gpx"; \
	  python3 tools/route.py build "$$src" -o "$$out" $$gpx || exit 1; echo "$$out"; \
	done

## Turn a recorded climb into the replay build's recording: make replay FIT=/path/to/track.fit, then
## make run REPLAY=1. Needs the FIT SDK (pip install -r tools/requirements.txt; PYTHON= names the
## interpreter that has it). The recording stays out of git.
replay:
	@test -n "$(FIT)" || { echo "Name the recording: make replay FIT=/path/to/track.fit"; exit 1; }
	@$(PYTHON) tools/fit2replay.py "$(FIT)" -o $(REPLAY_JSON) && echo "$(REPLAY_JSON)"

## Remove build output
clean:
	rm -f $(APP).prg $(APP).prg.debug.xml $(APP)-replay.prg $(APP)-replay.prg.debug.xml $(TEST_OUTPUT) $(TEST_OUTPUT).debug.xml
