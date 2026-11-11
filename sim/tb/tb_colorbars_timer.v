/*
 ============================================================================
 Name        : tb_colorbars_timer.v
 Target DUT  : HDMI_driver (rtl/ip/my_ip/HDMI_driver.v)
 Purpose     : (a) verify the eight vertical colour bars shown at power-up
               are correct at several sampled X positions, and that outside
               the active window the outputs are forced to black; (b) verify
               the exact cycle at which the driver switches permanently from
               colour bars to the text plane.
 Method      : Waiting 371,250,000 real pixel-clock cycles (5.000s at
               74.25 MHz) in Icarus Verilog is impractical, so this
               testbench uses the standard `force`/`release` technique to
               fast-forward the internal `mode_cnt` register to one cycle
               before the rollover point, then releases control back to the
               DUT and lets its own RTL logic complete the transition. This
               exercises the *real* comparator and the *real* constant
               (371,250,000), not a scaled-down stand-in for it.
 Self-check  : [PASS]/[FAIL] per check, single summary at the end.
 ============================================================================
 */
`timescale 1ns/1ps

module tb_colorbars_timer;

    reg         reset;
    reg         clk;
    reg  [7:0]  char_data;
    wire [11:0] char_addr;
    wire        h_sync, v_sync, video_de;
    wire [7:0]  red, green, blue;

    integer errors;
    integer checks;

    HDMI_driver dut (
        .reset     (reset),
        .clk       (clk),
        .char_data (char_data),
        .char_addr (char_addr),
        .h_sync    (h_sync),
        .v_sync    (v_sync),
        .video_de  (video_de),
        .red       (red),
        .green     (green),
        .blue      (blue)
    );

    // Nominal 74.25 MHz pixel clock (period ~13.468ns), used only so that
    // waveform timestamps in the .vcd correspond to real pixel-clock time.
    always #6.734 clk = ~clk;

    task automatic check(input cond, input [8*110-1:0] label);
        begin
            checks = checks + 1;
            if (cond) begin
                $display("[PASS] %0d: %0s", checks, label);
            end else begin
                $display("[FAIL] %0d: %0s", checks, label);
                errors = errors + 1;
            end
        end
    endtask

    // Waits until the (hierarchically observed) h_cnt counter has just
    // rolled past `target_x + 260` (260 = H_SYNC+H_BACK_PORCH, the start of
    // the active window), which is exactly the cycle at which color_bar_d /
    // red/green/blue reflect active_x == target_x (one-cycle output
    // pipeline, see PROJECT_ANALYSIS.md section 3).
    task automatic wait_for_active_x(input integer target_x);
        begin
            while (dut.h_cnt !== (target_x + 260 + 1)) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("tb_colorbars_timer.vcd");
        $dumpvars(0, tb_colorbars_timer);

        clk = 0;
        reset = 1;
        char_data = 8'h20;
        errors = 0;
        checks = 0;

        repeat (4) @(posedge clk);
        reset = 0;

        // --- Sanity check on the timing constant itself: 5.000s at the
        // real 74.25 MHz pixel clock this design generates.
        check(dut.COLOR_BARS_CYCLES == 29'd371_250_000,
              "COLOR_BARS_CYCLES constant equals 371,250,000 cycles");
        check((dut.COLOR_BARS_CYCLES * 1.0) / 74_250_000.0 == 5.0,
              "371,250,000 cycles / 74.25 MHz == exactly 5.000 seconds");

        // --- Colour bar content, sampled at the centre of each of the 8 stripes.
        // First fast-forward to the very start of the first active video
        // line (v_cnt == V_ACTIVE_START == 25, h_cnt == 0): before this
        // point the scan is still in the vertical blanking interval, where
        // video_de/active_d are forced low regardless of column.
        while (!(dut.v_cnt === 12'd25 && dut.h_cnt === 12'd0)) @(posedge clk);
        wait_for_active_x(80);   check(red == 8'hff && green == 8'hff && blue == 8'hff, "x=80  (band 1/8) is WHITE");
        wait_for_active_x(240);  check(red == 8'hff && green == 8'hff && blue == 8'h00, "x=240 (band 2/8) is YELLOW");
        wait_for_active_x(400);  check(red == 8'h00 && green == 8'hff && blue == 8'hff, "x=400 (band 3/8) is CYAN");
        wait_for_active_x(560);  check(red == 8'h00 && green == 8'hff && blue == 8'h00, "x=560 (band 4/8) is GREEN");
        wait_for_active_x(720);  check(red == 8'hff && green == 8'h00 && blue == 8'hff, "x=720 (band 5/8) is MAGENTA");
        wait_for_active_x(880);  check(red == 8'hff && green == 8'h00 && blue == 8'h00, "x=880 (band 6/8) is RED");
        wait_for_active_x(1040); check(red == 8'h00 && green == 8'h00 && blue == 8'hff, "x=1040 (band 7/8) is BLUE");
        wait_for_active_x(1200); check(red == 8'h00 && green == 8'h00 && blue == 8'h00, "x=1200 (band 8/8) is BLACK");

        // --- Blanking check: during H_SYNC (h_cnt < 40) video_de must be low
        // and outputs forced to 0, regardless of the colour-bar content.
        while (dut.h_cnt !== 12'd2) @(posedge clk);   // inside the sync pulse
        #1;
        check(video_de == 1'b0, "video_de is low during the horizontal sync pulse");
        check(red == 8'h00 && green == 8'h00 && blue == 8'h00, "RGB is forced to black outside the active window");

        // --- Colour-bars -> text transition, fast-forwarded via force/release
        @(posedge clk); #1;
        force dut.mode_cnt = dut.COLOR_BARS_CYCLES - 29'd2;
        #1;
        release dut.mode_cnt;

        @(posedge clk); #1;
        check(dut.text_mode == 1'b0,
              "one cycle before rollover: still in colour-bar mode");
        @(posedge clk); #1;
        check(dut.text_mode == 1'b1,
              "exactly at cycle 371,250,000: driver switches to text mode permanently");

        // Feed a printable character and confirm the display now reflects
        // text content (white-on-black) rather than the colour bars.
        char_data = 8'h41; // 'A'
        wait_for_active_x(0);
        check((red == 8'hff && green == 8'hff && blue == 8'hff) || (red == 8'h00 && green == 8'h00 && blue == 8'h00),
              "after the mode switch, active pixels are monochrome (white or black), never a colour-bar colour");

        $display("--------------------------------------------------");
        if (errors == 0) begin
            $display("[PASS] TB2 (Colour bars & 5s timer): ALL %0d CHECKS PASSED", checks);
            $finish(0);
        end else begin
            $display("[FAIL] TB2 (Colour bars & 5s timer): %0d OF %0d CHECKS FAILED", errors, checks);
            $finish(1);
        end
    end

    initial begin
        // Reaching the first active video line alone takes
        // V_ACTIVE_START * H_TOTAL = 25 * 1650 = 41,250 cycles (~555us at
        // 74.25 MHz); allow a generous margin beyond that.
        #2_000_000;
        $display("[FAIL] TB2: TIMEOUT - a wait condition was never satisfied");
        $finish(1);
    end

endmodule
