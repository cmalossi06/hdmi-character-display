#!/bin/bash
# ============================================================================
# Runs the full targeted testbench suite (TB1-TB6), one Icarus Verilog
# compile+run per test, in isolation from each other. Each testbench is
# self-checking: it prints [PASS]/[FAIL] per assertion and a final summary
# line, and exits with a non-zero status on failure.
#
# Usage:
#   ./run_all.sh            # run every testbench
#   ./run_all.sh tb1 tb5    # run only the named testbenches
#
# Waveforms: every testbench dumps its own tb_<name>.vcd in this directory,
# viewable with: gtkwave tb_<name>.vcd
#
# Extra compile defines can be passed through IVERILOG_DEFS, for example
#   IVERILOG_DEFS="-DNO_VCD -DTB6_TRACE" ./run_all.sh tb6
# runs TB6 without waveform dumping (much faster) and prints every character
# written to the HDMI peripheral.
# ============================================================================
set -e
cd "$(dirname "$0")"

ROOT=../..
CORE=$ROOT/rtl/core
IP=$ROOT/rtl/ip/my_ip
SIMLIB=../gowin_sim_lib/gw2a/prim_sim.v

declare -A TESTS
TESTS[tb1]="tb_icb_register.v $IP/HDMI_icb_bus.v"
TESTS[tb2]="tb_colorbars_timer.v $IP/HDMI_driver.v"
TESTS[tb3]="tb_font_rom.v $IP/HDMI_driver.v"
TESTS[tb4]="tb_cursor_terminal.v $SIMLIB $IP/HDMI_top.v $IP/HDMI_driver.v $IP/gowin_dpb.v"
TESTS[tb5]="tb_video_timing.v $IP/HDMI_driver.v"
TESTS[tb6]="tb_uart_e2e.v $SIMLIB $CORE/*.v $IP/HDMI_icb_bus.v $IP/HDMI_top.v $IP/HDMI_driver.v $IP/gowin_dpb.v"

declare -A NAMES
NAMES[tb1]="TB1 - ICB register interface (HDMI_icb_bus)"
NAMES[tb2]="TB2 - Colour bars & 5s timer (HDMI_driver)"
NAMES[tb3]="TB3 - Font ROM (HDMI_font_rom)"
NAMES[tb4]="TB4 - Cursor / terminal behaviour (HDMI_top)"
NAMES[tb5]="TB5 - Video timing, VESA 1280x720@60Hz (HDMI_driver)"
NAMES[tb6]="TB6 - End-to-end UART -> screen (full SoC + firmware)"

# Top-level module for each test, passed explicitly via -s. This is required
# whenever prim_sim.v is part of the compile (TB4, TB6): without -s, Icarus
# treats every module in prim_sim.v that nothing else instantiates (dozens
# of unrelated Gowin primitives such as ALU54D, MULT18X18, OSER8...) as an
# extra top-level root of its own, and each of those fails to elaborate
# because the GSR instance only exists inside the real testbench's hierarchy.
declare -A TOPS
TOPS[tb1]="tb_icb_register"
TOPS[tb2]="tb_colorbars_timer"
TOPS[tb3]="tb_font_rom"
TOPS[tb4]="tb_cursor_terminal"
TOPS[tb5]="tb_video_timing"
TOPS[tb6]="tb_uart_e2e"

RUN_LIST=("$@")
if [ ${#RUN_LIST[@]} -eq 0 ]; then
    RUN_LIST=(tb1 tb2 tb3 tb4 tb5 tb6)
fi

FAILED=0
for t in "${RUN_LIST[@]}"; do
    echo "===================================================================="
    echo "Running ${NAMES[$t]}"
    echo "===================================================================="
    # shellcheck disable=SC2086
    if iverilog -g2005-sv -DUSING_IVERILOG ${IVERILOG_DEFS:-} -I "$CORE" -s "${TOPS[$t]}" -o "${t}.out" ${TESTS[$t]}; then
        if ! vvp "${t}.out"; then
            FAILED=1
        fi
    else
        echo "[FAIL] $t: COMPILATION ERROR"
        FAILED=1
    fi
    echo ""
done

if [ $FAILED -ne 0 ]; then
    echo "==== ONE OR MORE TESTBENCHES FAILED ===="
    exit 1
else
    echo "==== ALL REQUESTED TESTBENCHES PASSED ===="
    exit 0
fi
