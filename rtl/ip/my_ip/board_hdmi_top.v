module board_hdmi_top (
    input             clk_in,
    input             erstn,
    input             tck,
    input             tms,
    input             tdi,
    output            tdo,
    input             dbgmode0_n,
    input             dbgmode1_n,
    input             dbgmode3_n,
    input             bootrom_n,
    input             aon_pmu_dwakeup_n,
    output            aon_pmu_padrst,
    output            aon_pmu_vddpaden,
    input      [31:0] gpio_in,
    output     [31:0] gpio_out,
    input      [3:0]  qspi_in,
    output     [3:0]  qspi_out,
    output            qspi_sck,
    output            qspi_cs,
    output            O_tmds_clk_p,
    output            O_tmds_clk_n,
    output     [2:0]  O_tmds_data_p,
    output     [2:0]  O_tmds_data_n,
    output     [3:0]  O_led
);

    wire        hsync;
    wire        vsync;
    wire        video_de;
    wire [7:0]  red;
    wire [7:0]  green;
    wire [7:0]  blue;

    wire serial_clk;
    wire pll_lock;
    wire hdmi_rst_n;
    wire pix_clk;

    e203_soc_demo u_soc_demo (
        .clk_in            (clk_in),
        .tck               (tck),
        .tms               (tms),
        .tdi               (tdi),
        .tdo               (tdo),
        .gpio_in           (gpio_in),
        .gpio_out          (gpio_out),
        .qspi_in           (qspi_in),
        .qspi_out          (qspi_out),
        .qspi_sck          (qspi_sck),
        .qspi_cs           (qspi_cs),
        .erstn             (erstn),
        .dbgmode0_n        (dbgmode0_n),
        .dbgmode1_n        (dbgmode1_n),
        .dbgmode3_n        (dbgmode3_n),
        .bootrom_n         (bootrom_n),
        .aon_pmu_dwakeup_n (aon_pmu_dwakeup_n),
        .aon_pmu_padrst    (aon_pmu_padrst),
        .aon_pmu_vddpaden  (aon_pmu_vddpaden),
        .Hsync             (hsync),
        .Vsync             (vsync),
        .VideoDE           (video_de),
        .Red               (red),
        .Green             (green),
        .Blue              (blue),
        .pixel_clk         (pix_clk)
    );

    TMDS_rPLL u_tmds_rpll (
        .clkin  (clk_in),
        .clkout (serial_clk),
        .lock   (pll_lock)
    );

    assign hdmi_rst_n = erstn & pll_lock;

    CLKDIV u_clkdiv (
        .RESETN(hdmi_rst_n),
        .HCLKIN(serial_clk),
        .CLKOUT(pix_clk),
        .CALIB (1'b1)
    );
    defparam u_clkdiv.DIV_MODE = "5";
    defparam u_clkdiv.GSREN = "false";

    DVI_TX_Top u_dvi_tx (
        .I_rst_n      (hdmi_rst_n),
        .I_serial_clk (serial_clk),
        .I_rgb_clk    (pix_clk),
        .I_rgb_vs     (vsync),
        .I_rgb_hs     (hsync),
        .I_rgb_de     (video_de),
        .I_rgb_r      (red),
        .I_rgb_g      (green),
        .I_rgb_b      (blue),
        .O_tmds_clk_p (O_tmds_clk_p),
        .O_tmds_clk_n (O_tmds_clk_n),
        .O_tmds_data_p(O_tmds_data_p),
        .O_tmds_data_n(O_tmds_data_n)
    );

    assign O_led[0] = pll_lock;
    assign O_led[1] = erstn;
    assign O_led[2] = hsync;
    assign O_led[3] = vsync;

endmodule
