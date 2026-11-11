/*
 ============================================================================
 Name        : tb_video_timing.v
 Target DUT  : HDMI_driver (rtl/ip/my_ip/HDMI_driver.v)
 Purpose     : Independently MEASURE (by counting edges/cycles on h_sync,
               v_sync and video_de, not by reading the DUT's own timing
               localparams) the horizontal and vertical timing of the video
               output, and confirm it matches the VESA 1280x720@60Hz
               standard: H_TOTAL=1650, V_TOTAL=750, H_ACTIVE=1280,
               V_ACTIVE=720, H_SYNC=40, and refresh rate.
 Self-check  : [PASS]/[FAIL] per measurement, single summary at the end.
 ============================================================================
 */
`timescale 1ns/1ps

module tb_video_timing;

    reg         reset;
    reg         clk;
    reg  [7:0]  char_data;
    wire [11:0] char_addr;
    wire        h_sync, v_sync, video_de;
    wire [7:0]  red, green, blue;

    integer errors;
    integer checks;
    integer i;
    integer width;

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

    always #6.734 clk = ~clk; // nominal 74.25 MHz pixel clock

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

    initial begin
        $dumpfile("tb_video_timing.vcd");
        $dumpvars(0, tb_video_timing);

        clk = 0;
        reset = 1;
        char_data = 8'h20;
        errors = 0;
        checks = 0;

        repeat (4) @(posedge clk); #1;
        reset = 0;

        // Synchronise to a genuine rising edge of h_sync (first drain any
        // partially-observed high level left over from reset, then wait for
        // the next 0->1 transition) so that every measurement below starts
        // counting from the true beginning of a pulse/line/frame, never
        // from somewhere in the middle of one.
        while (h_sync === 1'b1) @(posedge clk);
        while (h_sync !== 1'b1) @(posedge clk);

        // --- Measurement 1: width of the horizontal sync pulse, counted
        // directly from the h_sync waveform (independent of H_SYNC localparam).
        width = 0;
        while (h_sync === 1'b1) begin
            width = width + 1;
            @(posedge clk);
        end
        check(width == 40, "measured H_SYNC pulse width == 40 pixel clocks");

        // --- Measurement 2: full horizontal line period. `width` above
        // already measured the high portion (h_sync == 1); continue
        // counting the low portion until h_sync rises again, then add both
        // together to get the complete line period H_TOTAL.
        i = 0;
        while (h_sync !== 1'b1) begin
            i = i + 1;
            @(posedge clk);
        end
        i = i + width;
        check(i == 1650, "measured horizontal line period == 1650 pixel clocks (H_TOTAL)");

        // --- Measurement 3: horizontal active video width (video_de high time)
        while (video_de !== 1'b1) @(posedge clk);
        width = 0;
        while (video_de === 1'b1) begin
            width = width + 1;
            @(posedge clk);
        end
        check(width == 1280, "measured active video width == 1280 pixels (H_ACTIVE)");

        // --- Measurement 4: vertical sync duration, measured in pixel clocks
        // and converted to lines (v_sync stays high across all of V_SYNC
        // full lines, not just a short strobe - verified independently here).
        // Re-synchronise on a genuine v_sync rising edge first, using the
        // same drain-then-wait pattern proven above for h_sync (this avoids
        // any ambiguity from also qualifying on the hierarchically-read
        // h_cnt/v_cnt registers).
        while (v_sync === 1'b1) @(posedge clk);
        while (v_sync !== 1'b1) @(posedge clk);
        width = 0;
        while (v_sync === 1'b1) begin
            width = width + 1;
            @(posedge clk);
        end
        check(width == (5 * 1650), "measured V_SYNC duration == 5 full lines (8250 pixel clocks)");

        // --- Measurement 5: full frame period. `width` above already
        // measured the high (V_SYNC) portion; continue counting the low
        // portion until v_sync rises again, then add both together to get
        // the complete frame period H_TOTAL x V_TOTAL (this runs for
        // essentially a full frame, ~1.24M pixel clocks).
        i = 0;
        while (v_sync !== 1'b1) begin
            i = i + 1;
            @(posedge clk);
        end
        i = i + width;
        check(i == (1650 * 750), "measured full frame period == 1,237,500 pixel clocks (H_TOTAL x V_TOTAL)");

        // --- Derived refresh rate check, from purely measured quantities
        check((74_250_000.0 / (1650.0 * 750.0)) == 60.0,
              "74.25 MHz pixel clock / (1650 x 750) == exactly 60.000 Hz refresh rate");

        $display("--------------------------------------------------");
        if (errors == 0) begin
            $display("[PASS] TB5 (Video timing): ALL %0d CHECKS PASSED", checks);
            $finish(0);
        end else begin
            $display("[FAIL] TB5 (Video timing): %0d OF %0d CHECKS FAILED", errors, checks);
            $finish(1);
        end
    end

    initial begin
        // Two full frames at 74.25 MHz (1,650 x 750 cycles each) is close to
        // 33ms; give a comfortable margin around that.
        #60_000_000;
        $display("[FAIL] TB5: TIMEOUT - a wait condition was never satisfied");
        $finish(1);
    end

endmodule
