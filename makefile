# Makefile for GPU Cocotb Verification
# Usage:
#   make build          # Compile RTL with Verilator
#   make test_decoder   # Run a single test (replace with any test_*.py)
#   make regression     # Run all tests
#   make coverage       # Generate coverage report after tests
#   make clean          # Cleanup

# Config vars
SIM = verilator  # Default simulator
RTL_DIR = src    # RTL sources
TEST_DIR = tests  # Test scripts
HELPERS_DIR = helpers  # Reusable classes
TOP = gpu        # Top-level module
VFLAGS = --cc --trace --coverage -Wno-fatal  # Verilator flags: coverage enabled, traces for debug
COCOTB_RESULTS = results  # Output dir

# Build RTL with Verilator
build:
	verilator $(VFLAGS) -I$(RTL_DIR) --top-module $(TOP) $(RTL_DIR)/*.sv $(RTL_DIR)/*.svh

# Run a single test (e.g., make test_decoder)
test_%: build
	mkdir -p $(COCOTB_RESULTS)
	COCOTB_RESULTS_FILE=$(COCOTB_RESULTS)/$@.xml \
	python3 -m pytest $(TEST_DIR)/$@.py -v --junitxml=$(COCOTB_RESULTS)/$@.xml

# Full regression: Run all tests
regression: build
	mkdir -p $(COCOTB_RESULTS)
	python3 -m pytest $(TEST_DIR) -v --junitxml=$(COCOTB_RESULTS)/regression.xml

# Generate coverage report (after running tests)
coverage:
	verilator_coverage -extract $(COCOTB_RESULTS)/*.dat -write $(COCOTB_RESULTS)/coverage_report.txt
	@echo "Coverage report in $(COCOTB_RESULTS)/coverage_report.txt"

# Clean up
clean:
	rm -rf sim_build $(COCOTB_RESULTS) __pycache__ *.dat *.xml
