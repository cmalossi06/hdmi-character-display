/*
 ============================================================================
 Name        : HDMI_top.v
 Description : Dual-clock 80x45 ASCII terminal buffer for 1280x720 HDMI
 ============================================================================
 */

module HDMI_top (
    input        cpu_clk,
    input        pixel_clk,
    input        rst_n,

    input        data_valid,
    input  [7:0] data_char,
    input        cursor_valid,
    input  [6:0] cursor_x,
    input  [5:0] cursor_y,
    input        command_valid,
    input  [3:0] command,

    output       h_sync,
    output       v_sync,
    output       video_de,
    output [7:0] red,
    output [7:0] green,
    output [7:0] blue
);

    localparam integer TEXT_COLS = 80;
    localparam integer TEXT_ROWS = 45;
    localparam integer TEXT_CELLS = TEXT_COLS * TEXT_ROWS;
    localparam [6:0] LAST_COL = 7'd79;
    localparam [5:0] LAST_ROW = 6'd44;

    localparam OP_IDLE  = 1'b0;
    localparam OP_CLEAR = 1'b1;

    reg [6:0] cur_x;
    reg [5:0] cur_y;

    reg        op_state;
    reg [12:0] op_idx;
    reg [14:0] ram_wr_addr;
    reg [15:0] ram_wr_data;
    reg        ram_wr_en;

    wire reset = ~rst_n;
    wire [11:0] scan_addr;
    wire [14:0] ram_rd_addr = {3'b000, scan_addr};
    wire [15:0] ram_rd_data;
    wire [15:0] ram_cpu_data;
    wire [14:0] ram_cpu_addr = ram_wr_addr;
    reg  [7:0]  scan_char;

    function [14:0] cell_addr;
        input [6:0] x;
        input [5:0] y;
        begin
            cell_addr = (y * TEXT_COLS) + x;
        end
    endfunction

    task do_backspace;
        begin
            if (cur_x != 7'd0) begin
                cur_x <= cur_x - 1'b1;
                ram_wr_addr <= cell_addr(cur_x - 1'b1, cur_y);
                ram_wr_data <= 16'h0020;
                ram_wr_en <= 1'b1;
            end else if (cur_y != 6'd0) begin
                cur_x <= LAST_COL;
                cur_y <= cur_y - 1'b1;
                ram_wr_addr <= cell_addr(LAST_COL, cur_y - 1'b1);
                ram_wr_data <= 16'h0020;
                ram_wr_en <= 1'b1;
            end
        end
    endtask

    task do_newline;
        begin
            cur_x <= 7'd0;
            if (cur_y == LAST_ROW) begin
                cur_y <= 6'd0;
            end else begin
                cur_y <= cur_y + 1'b1;
            end
        end
    endtask

    always @(posedge cpu_clk or posedge reset) begin
        if (reset) begin
            cur_x <= 7'd0;
            cur_y <= 6'd0;
            op_state <= OP_CLEAR;
            op_idx <= 13'd0;
            ram_wr_addr <= 15'd0;
            ram_wr_data <= 16'h0020;
            ram_wr_en <= 1'b0;
        end else begin
            ram_wr_en <= 1'b0;

            case (op_state)
                OP_CLEAR: begin
                    ram_wr_addr <= op_idx;
                    ram_wr_data <= 16'h0020;
                    ram_wr_en <= 1'b1;
                    if (op_idx == TEXT_CELLS - 1) begin
                        op_idx <= 13'd0;
                        op_state <= OP_IDLE;
                        cur_x <= 7'd0;
                        cur_y <= 6'd0;
                    end else begin
                        op_idx <= op_idx + 1'b1;
                    end
                end

                default: begin
                    if (cursor_valid) begin
                        cur_x <= (cursor_x > LAST_COL) ? LAST_COL : cursor_x;
                        cur_y <= (cursor_y > LAST_ROW) ? LAST_ROW : cursor_y;
                    end else if (command_valid) begin
                        if (command[0]) begin
                            op_state <= OP_CLEAR;
                            op_idx <= 13'd0;
                            cur_x <= 7'd0;
                            cur_y <= 6'd0;
                        end else if (command[3]) begin
                            do_backspace();
                        end else if (command[1]) begin
                            do_newline();
                        end else if (command[2]) begin
                            cur_x <= 7'd0;
                        end
                    end else if (data_valid) begin
                        if ((data_char == 8'h08) || (data_char == 8'h7f)) begin
                            do_backspace();
                        end else if (data_char == 8'h0a) begin
                            do_newline();
                        end else if (data_char == 8'h0d) begin
                            cur_x <= 7'd0;
                        end else if ((data_char >= 8'd32) && (data_char <= 8'd127)) begin
                            ram_wr_addr <= cell_addr(cur_x, cur_y);
                            ram_wr_data <= {8'h00, data_char};
                            ram_wr_en <= 1'b1;
                            if (cur_x == LAST_COL) begin
                                cur_x <= 7'd0;
                                if (cur_y == LAST_ROW) begin
                                    cur_y <= 6'd0;
                                end else begin
                                    cur_y <= cur_y + 1'b1;
                                end
                            end else begin
                                cur_x <= cur_x + 1'b1;
                            end
                        end
                    end
                end
            endcase
        end
    end

    always @(posedge pixel_clk) begin
        scan_char <= ram_rd_data[7:0];
    end

    Gowin_DPB u_text_dpb (
        .douta (ram_cpu_data),
        .doutb (ram_rd_data),
        .clka  (cpu_clk),
        .ocea  (1'b1),
        .cea   (1'b1),
        .reseta(reset),
        .wrea  (ram_wr_en),
        .clkb  (pixel_clk),
        .oceb  (1'b1),
        .ceb   (1'b1),
        .resetb(reset),
        .wreb  (1'b0),
        .ada   (ram_cpu_addr),
        .dina  (ram_wr_data),
        .adb   (ram_rd_addr),
        .dinb  (16'h0000)
    );

    HDMI_driver u_HDMI_driver (
        .reset     (reset),
        .clk       (pixel_clk),
        .char_data (scan_char),
        .char_addr (scan_addr),
        .h_sync    (h_sync),
        .v_sync    (v_sync),
        .video_de  (video_de),
        .red       (red),
        .green     (green),
        .blue      (blue)
    );

endmodule
