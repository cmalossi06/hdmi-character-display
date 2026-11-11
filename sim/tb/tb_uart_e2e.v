/*
 ============================================================================
 Name        : tb_uart_e2e.v
 Target DUT  : e203_soc_demo (rtl/core/e203_soc_demo.v) - the full RISC-V
               SoC, running the real compiled firmware (ram.hex), exactly as
               it would on the FPGA.
 Purpose     : End-to-end regression covering macro-steps 1, 5 and 7 of
               PROJECT_ANALYSIS.md together: a byte sent on UART0 must be
               picked up by the firmware's polling loop, written through the
               ICB bus to HDMI_icb_bus, and land in HDMI_top's text buffer
               at the correct cursor position - the complete path this
               project was built to implement.
 Method      : Bit-bangs a real UART frame (8N1) onto gpio_in[16] (UART0 RX,
               board pin T13) exactly as an external USB-UART adapter would,
               and observes the effect through HDMI_top's own write-path
               registers, reached via one hierarchical path through the SoC
               (u_subsys_main -> u_perips -> u_HDMI_icb_bus / HDMI_top).
 Self-check  : [PASS]/[FAIL] per check, single summary at the end.
 ============================================================================
 */
`timescale 1ns/10ps
`define USING_IVERILOG

module tb_uart_e2e;

    reg  clk;
    reg  rst_n;
    reg  uart_tx_drive;

    wire [31:0] gpio_out;
    wire [31:0] gpio_in;
    wire        uart_rx_from_dut = gpio_out[17]; // SoC's UART0 TX, observed by the testbench
    wire        hsync, vsync, video_de;
    wire [7:0]  red, green, blue;

    assign gpio_in[16]    = uart_tx_drive; // SoC's UART0 RX, driven by the testbench
    assign gpio_in[31:17] = 15'b0;
    assign gpio_in[15:0]  = 16'b0;

    GSR GSR(.GSRI(rst_n));

    integer errors;
    integer checks;

    task automatic check(input cond, input [8*120-1:0] label);
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

    // real 27 MHz board clock (period 37.037ns)
    always #18.5185 clk = ~clk;

    // 115200 baud, 8N1, matches firmware's uart_init(115200)
    localparam real BAUD_PERIOD = 8680.5556; // ns

    task automatic uart_tx_byte(input [7:0] tx_data);
        integer i;
        begin
            uart_tx_drive = 1'b0;             // start bit
            #(BAUD_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                uart_tx_drive = tx_data[i];   // LSB first
                #(BAUD_PERIOD);
            end
            uart_tx_drive = 1'b1;             // stop bit
            #(BAUD_PERIOD);
        end
    endtask

    e203_soc_demo dut (
        .clk_in            (clk),
        .tck               (1'b1),
        .tms               (1'b1),
        .tdi               (1'b1),
        .tdo               (),
        .gpio_in           (gpio_in),
        .gpio_out          (gpio_out),
        .qspi_in           (4'b0),
        .qspi_out          (),
        .qspi_sck          (),
        .qspi_cs           (),
        .erstn             (rst_n),
        .dbgmode0_n        (1'b1),
        .dbgmode1_n        (1'b1),
        .dbgmode3_n        (1'b1),
        .bootrom_n         (1'b0),
        .aon_pmu_dwakeup_n (1'b0),
        .aon_pmu_padrst    (),
        .aon_pmu_vddpaden  (),
        .Hsync             (hsync),
        .Vsync             (vsync),
        .VideoDE           (video_de),
        .Red               (red),
        .Green             (green),
        .Blue              (blue),
        .pixel_clk         (clk)
    );

    // Hierarchical path down to the HDMI text-terminal core inside the SoC,
    // used only to observe internal state for verification (never forced).
    // u_subsys_main / u_perips names follow e203_subsys_main.v / e203_subsys_perips.v.
    `define HDMI_TOP_PATH dut.u_e203_soc_top.u_e203_subsys_top.u_e203_subsys_main.u_e203_subsys_perips.u_HDMI_icb_bus

    reg [6:0] cur_x_before;
    reg [5:0] cur_y_before;
    reg       prompt_seen;

    // Time given to the firmware to read a received byte from the UART and
    // write it to the peripheral before the cursor state is checked. The
    // polling loop needs only a few microseconds; 50 us leaves a wide margin.
    localparam integer SETTLE_NS = 50_000;

    `define PERIPH dut.u_e203_soc_top.u_e203_subsys_top.u_e203_subsys_main.u_e203_subsys_perips

`ifdef TB6_TRACE
    // Optional trace of every character written to the peripheral.
    always @(posedge `PERIPH.hdmi_data_valid)
        #1 $display("  t=%0t  char 0x%02h '%c'", $time, `PERIPH.hdmi_data_char, `PERIPH.hdmi_data_char);
`endif

    initial begin
`ifndef NO_VCD
        $dumpfile("tb_uart_e2e.vcd");
        // Scoped on purpose: dumping the whole SoC recurses into the RISC-V
        // pipeline and produces a multi-gigabyte VCD. Only the testbench
        // signals and the two HDMI modules under test are dumped.
        $dumpvars(1, tb_uart_e2e);
        $dumpvars(0, `PERIPH.u_HDMI_icb_bus);
        $dumpvars(0, `PERIPH.u_HDMI_top);
`endif

        clk = 0;
        rst_n = 0;
        uart_tx_drive = 1'b1; // UART idle level
        errors = 0;
        checks = 0;
        prompt_seen = 1'b0;

        #320_000; // hold reset, matching the timing used by the project's own system testbench
        rst_n = 1;

        // Wait for the firmware to finish booting. After reset it clears the
        // screen, busy-waits, prints two banner lines and finally the "> "
        // prompt. Typing must start only after the prompt, otherwise the
        // banner characters are mistaken for the echoed input.
        while (!prompt_seen) begin
            @(posedge `PERIPH.hdmi_data_valid);
            #1;
            if (`PERIPH.hdmi_data_char == ">") begin
                @(posedge `PERIPH.hdmi_data_valid); // the space after '>'
                prompt_seen = 1'b1;
            end
        end
        #(SETTLE_NS);
        $display("  boot banner complete at t=%0t", $time);

        check(`PERIPH.hdmi_command_valid !== 1'bx,
              "SoC has booted far enough for the HDMI command bus to be driven (not X)");

        cur_x_before = `PERIPH.u_HDMI_top.cur_x;
        cur_y_before = `PERIPH.u_HDMI_top.cur_y;

        // Send "Hi" and check that both characters reach the peripheral in order.
        fork
            begin
                uart_tx_byte("H");
                uart_tx_byte("i");
            end
            begin
                @(posedge `PERIPH.hdmi_data_valid);
                #1;
                check(`PERIPH.hdmi_data_char == "H",
                      "first UART byte ('H') reaches HDMI_icb_bus as HDMI_data_char");
                @(posedge `PERIPH.hdmi_data_valid);
                #1;
                check(`PERIPH.hdmi_data_char == "i",
                      "second UART byte ('i') reaches HDMI_icb_bus as HDMI_data_char");
            end
        join
        #(SETTLE_NS);

        check(`PERIPH.u_HDMI_top.cur_x == cur_x_before + 7'd2,
              "after typing \"Hi\", the on-screen cursor column advanced by exactly 2");
        check(`PERIPH.u_HDMI_top.cur_y == cur_y_before,
              "the row is unchanged after \"Hi\" (no newline was sent)");

        // Enter (CR) must move the cursor to the start of the next row.
        uart_tx_byte(8'h0d);
        #(SETTLE_NS);
        check(`PERIPH.u_HDMI_top.cur_x == 7'd0,
              "Enter (CR) resets the column to 0");
        check(`PERIPH.u_HDMI_top.cur_y == cur_y_before + 6'd1,
              "Enter (CR) advances the row by exactly 1");

        // A character followed by Backspace must leave the cursor where it was.
        uart_tx_byte("X");
        #(SETTLE_NS);
        uart_tx_byte(8'h7f);
        #(SETTLE_NS);
        check(`PERIPH.u_HDMI_top.cur_x == 7'd0,
              "typing 'X' then Backspace leaves the column back at 0 (net no-op)");

        $display("--------------------------------------------------");
        if (errors == 0) begin
            $display("[PASS] TB6 (End-to-end UART -> screen): ALL %0d CHECKS PASSED", checks);
            $finish(0);
        end else begin
            $display("[FAIL] TB6 (End-to-end UART -> screen): %0d OF %0d CHECKS FAILED", errors, checks);
            $finish(1);
        end
    end

    initial begin
        #200_000_000;
        $display("[FAIL] TB6: TIMEOUT - a wait condition was never satisfied (boot too slow or path wrong)");
        $finish(1);
    end

endmodule
