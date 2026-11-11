/*
 ============================================================================
 Name        : tb_font_rom.v
 Target DUT  : HDMI_font_rom (rtl/ip/my_ip/HDMI_driver.v)
 Purpose     : Verify glyph rasterisation for a representative subset of the
               ASCII table. Expected bit patterns were derived independently
               by decoding the raw FONT_ROM constant with an external Python
               script (see PROJECT_ANALYSIS.md / report, testbench section),
               NOT by reading them back through the DUT itself, so this is a
               genuine oracle check rather than a tautological one.
 Self-check  : [PASS]/[FAIL] per row per character, single summary at the end.
 ============================================================================
 */
`timescale 1ns/1ps

module tb_font_rom;

    reg  [7:0]  ascii;
    reg  [3:0]  row;
    wire [15:0] pixels;

    integer errors;
    integer checks;

    HDMI_font_rom dut (
        .ascii  (ascii),
        .row    (row),
        .pixels (pixels)
    );

    task automatic check_row(input [15:0] expected, input [8*96-1:0] label);
        begin
            checks = checks + 1;
            if (pixels === expected) begin
                $display("[PASS] %0d: %0s (got %016b)", checks, label, pixels);
            end else begin
                $display("[FAIL] %0d: %0s (expected %016b, got %016b)", checks, label, expected, pixels);
                errors = errors + 1;
            end
        end
    endtask

    // Ground truth for 'A' (0x41), all 16 rows - a recognisable capital "A".
    reg [15:0] glyph_A [0:15];
    // Ground truth for '0' (0x30), all 16 rows.
    reg [15:0] glyph_0 [0:15];

    integer r;

    initial begin
        glyph_A[0]  = 16'b0000000000000000;
        glyph_A[1]  = 16'b0000110000000000;
        glyph_A[2]  = 16'b0000110000000000;
        glyph_A[3]  = 16'b0001111000000000;
        glyph_A[4]  = 16'b0011001100000000;
        glyph_A[5]  = 16'b0011001100000000;
        glyph_A[6]  = 16'b0011001100000000;
        glyph_A[7]  = 16'b0111111110000000;
        glyph_A[8]  = 16'b0110000110000000;
        glyph_A[9]  = 16'b1100000011000000;
        glyph_A[10] = 16'b1100000011000000;
        glyph_A[11] = 16'b0000000000000000;
        glyph_A[12] = 16'b0000000000000000;
        glyph_A[13] = 16'b0000000000000000;
        glyph_A[14] = 16'b0000000000000000;
        glyph_A[15] = 16'b0000000000000000;

        glyph_0[0]  = 16'b0000000000000000;
        glyph_0[1]  = 16'b0001111000000000;
        glyph_0[2]  = 16'b0011001100000000;
        glyph_0[3]  = 16'b0110000110000000;
        glyph_0[4]  = 16'b0110000110000000;
        glyph_0[5]  = 16'b0110000110000000;
        glyph_0[6]  = 16'b0110000110000000;
        glyph_0[7]  = 16'b0110000110000000;
        glyph_0[8]  = 16'b0110000110000000;
        glyph_0[9]  = 16'b0011001100000000;
        glyph_0[10] = 16'b0001111000000000;
        glyph_0[11] = 16'b0000000000000000;
        glyph_0[12] = 16'b0000000000000000;
        glyph_0[13] = 16'b0000000000000000;
        glyph_0[14] = 16'b0000000000000000;
        glyph_0[15] = 16'b0000000000000000;

        $dumpfile("tb_font_rom.vcd");
        $dumpvars(0, tb_font_rom);

        errors = 0;
        checks = 0;

        // --- 'A' (0x41): all 16 rows must match the independently decoded glyph
        ascii = 8'h41;
        for (r = 0; r < 16; r = r + 1) begin
            row = r[3:0];
            #1;
            check_row(glyph_A[r], "glyph 'A' row matches independently-decoded ROM content");
        end

        // --- '0' (0x30): all 16 rows
        ascii = 8'h30;
        for (r = 0; r < 16; r = r + 1) begin
            row = r[3:0];
            #1;
            check_row(glyph_0[r], "glyph '0' row matches independently-decoded ROM content");
        end

        // --- space (0x20): every row must be fully blank
        ascii = 8'h20;
        for (r = 0; r < 16; r = r + 1) begin
            row = r[3:0];
            #1;
            check_row(16'h0000, "glyph ' ' (space) is blank on every row");
        end

        // --- non-printable below range (0x01): must be forced blank
        ascii = 8'h01;
        row = 4'd5;
        #1;
        check_row(16'h0000, "ASCII 0x01 (below printable range) forces a blank row");

        // --- non-printable above range (0xFF): must be forced blank
        ascii = 8'hFF;
        row = 4'd5;
        #1;
        check_row(16'h0000, "ASCII 0xFF (above printable range) forces a blank row");

        // --- boundary character 127 (DEL): the DUT's `printable` condition
        // is `ascii <= 127`, one past the conventional ASCII printable
        // range (32-126); DEL is not normally considered printable. We
        // document this as a minor range-check detail: it has no visible
        // effect because the ROM's glyph slot for index 95 (ascii 127) is
        // itself empty, so the ambiguity is harmless in practice.
        ascii = 8'd127;
        row = 4'd5;
        #1;
        check_row(16'h0000, "ASCII 127 (DEL) renders blank (glyph slot 95 is empty in the ROM)");

        $display("--------------------------------------------------");
        if (errors == 0) begin
            $display("[PASS] TB3 (Font ROM): ALL %0d CHECKS PASSED", checks);
            $finish(0);
        end else begin
            $display("[FAIL] TB3 (Font ROM): %0d OF %0d CHECKS FAILED", errors, checks);
            $finish(1);
        end
    end

endmodule
