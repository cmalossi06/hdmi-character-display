//=====================================================================
//
// Description:
//  ICB register block for the HDMI text terminal.
//
// Register map, base 0x1001_4000:
//   0x00 RO : [15:8]=rows, [7:0]=columns
//   0x04 WO : ASCII character data
//   0x08 WO : [15:8]=cursor_y, [7:0]=cursor_x
//   0x0c WO : bit0 clear, bit1 newline, bit2 carriage return, bit3 backspace
//
//=====================================================================

module HDMI_icb_bus (
    input         clk,
    input         rst_n,

    input         HDMI_icb_cmd_valid,
    output        HDMI_icb_cmd_ready,
    input  [31:0] HDMI_icb_cmd_addr,
    input         HDMI_icb_cmd_read,
    input  [31:0] HDMI_icb_cmd_wdata,

    output        HDMI_icb_rsp_valid,
    input         HDMI_icb_rsp_ready,
    output [31:0] HDMI_icb_rsp_rdata,

    output        HDMI_io_interrupts_0_0,

    output reg        HDMI_data_valid,
    output reg [7:0]  HDMI_data_char,
    output reg        HDMI_cursor_valid,
    output reg [6:0]  HDMI_cursor_x,
    output reg [5:0]  HDMI_cursor_y,
    output reg        HDMI_command_valid,
    output reg [3:0]  HDMI_command
);

    localparam [11:0] REG_INFO   = 12'h000;
    localparam [11:0] REG_DATA   = 12'h004;
    localparam [11:0] REG_CURSOR = 12'h008;
    localparam [11:0] REG_CMD    = 12'h00c;

    localparam [7:0] TEXT_COLS = 8'd80;
    localparam [7:0] TEXT_ROWS = 8'd45;

    reg [31:0] rsp_data_r;
    reg        rsp_valid_r;
    reg [7:0]  last_char_r;

    wire reset = ~rst_n;
    wire [11:0] reg_addr = HDMI_icb_cmd_addr[11:0];
    wire cmd_fire = HDMI_icb_cmd_valid && HDMI_icb_cmd_ready;
    wire wr_fire = cmd_fire && ~HDMI_icb_cmd_read;
    wire rsp_fire = HDMI_icb_rsp_valid && HDMI_icb_rsp_ready;

    assign HDMI_icb_cmd_ready = ~rsp_valid_r || HDMI_icb_rsp_ready;
    assign HDMI_icb_rsp_valid = rsp_valid_r;
    assign HDMI_icb_rsp_rdata = rsp_data_r;
    assign HDMI_io_interrupts_0_0 = 1'b0;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rsp_data_r <= 32'h0;
            rsp_valid_r <= 1'b0;
            last_char_r <= 8'h20;
            HDMI_data_valid <= 1'b0;
            HDMI_data_char <= 8'h20;
            HDMI_cursor_valid <= 1'b0;
            HDMI_cursor_x <= 7'd0;
            HDMI_cursor_y <= 6'd0;
            HDMI_command_valid <= 1'b0;
            HDMI_command <= 4'h0;
        end else begin
            HDMI_data_valid <= 1'b0;
            HDMI_cursor_valid <= 1'b0;
            HDMI_command_valid <= 1'b0;

            if (rsp_fire) begin
                rsp_valid_r <= 1'b0;
            end

            if (cmd_fire) begin
                case (reg_addr)
                    REG_INFO:   rsp_data_r <= {16'h0, TEXT_ROWS, TEXT_COLS};
                    REG_DATA:   rsp_data_r <= {24'h0, last_char_r};
                    REG_CURSOR: rsp_data_r <= {18'h0, HDMI_cursor_y, HDMI_cursor_x};
                    default:    rsp_data_r <= 32'h0;
                endcase
                rsp_valid_r <= 1'b1;
            end

            if (wr_fire) begin
                case (reg_addr)
                    REG_DATA: begin
                        HDMI_data_char <= HDMI_icb_cmd_wdata[7:0];
                        HDMI_data_valid <= 1'b1;
                        last_char_r <= HDMI_icb_cmd_wdata[7:0];
                        rsp_data_r <= {24'h0, HDMI_icb_cmd_wdata[7:0]};
                    end
                    REG_CURSOR: begin
                        HDMI_cursor_x <= HDMI_icb_cmd_wdata[6:0];
                        HDMI_cursor_y <= HDMI_icb_cmd_wdata[13:8];
                        HDMI_cursor_valid <= 1'b1;
                        rsp_data_r <= {18'h0, HDMI_icb_cmd_wdata[13:8], HDMI_icb_cmd_wdata[6:0]};
                    end
                    REG_CMD: begin
                        HDMI_command <= HDMI_icb_cmd_wdata[3:0];
                        HDMI_command_valid <= 1'b1;
                        rsp_data_r <= {28'h0, HDMI_icb_cmd_wdata[3:0]};
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
