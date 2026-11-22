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
OUTPUT   := $(APP).prg

MONKEYC   = "$(SDK_BIN)/monkeyc"
MONKEYDO  = "$(SDK_BIN)/monkeydo"
CONNECTIQ = "$(SDK_BIN)/connectiq"

.PHONY: all build sim run sideload clean routes

all: build

## Build the .prg for DEVICE
build:
	@test -f "$(KEY)" || { echo "No developer key at $(KEY). Pass its path: make $(or $(MAKECMDGOALS),build) DEV_KEY=/path/to/developer_key"; exit 1; }
	@echo "Building for $(DEVICE)..."
	@$(MONKEYC) -f monkey.jungle -d $(DEVICE) -y "$(KEY)" -w -o $(OUTPUT)
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
	@watch=$$(CIQ_HOME="$(CIQ_HOME)" tools/sideload.sh detect) || exit 1; \
	echo "Watch detected: $$watch"; \
	grep -q '<iq:product id="'"$$watch"'"/>' manifest.xml || { echo "manifest.xml does not list $$watch."; exit 1; }; \
	$(MAKE) --no-print-directory build DEVICE=$$watch && tools/sideload.sh install $(OUTPUT)

## Run the unit tests in the simulator (source/tests/; Toybox.Test, built with --unit-test)
# monkeydo exits 1 whether the suite passes or not, so the anchored summary line is the gate, as in
# Matrix Time (playbook, reference/testing.md). A run that cannot reach the simulator prints no
# summary and fails the same way. Only one monkeydo session at a time: a second one hangs.
.PHONY: test
TEST_OUTPUT := test_build.prg
# The key is checked before the simulator is started, so a missing key does not leave one running.
test:
	@test -f "$(KEY)" || { echo "No developer key at $(KEY). Pass its path: make test DEV_KEY=/path/to/developer_key"; exit 1; }
	@$(MAKE) --no-print-directory sim
	@echo "Building the unit tests for $(DEVICE)..."
	@$(MONKEYC) -f monkey.jungle -d $(DEVICE) -y "$(KEY)" -w --unit-test -o $(TEST_OUTPUT)
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

## Remove build output
clean:
	rm -f $(OUTPUT) $(OUTPUT).debug.xml $(TEST_OUTPUT) $(TEST_OUTPUT).debug.xml
