module sevenseg_mux (
    input  wire        clk,
    input  wire [15:0] hex_word,
    output reg  [3:0]  digit,
    output reg  [7:0]  Seven_Seg
);

    localparam DIGIT_ACTIVE_LOW = 1'b0;
    localparam SEG_ACTIVE_LOW   = 1'b1;

    reg [15:0] scan_div = 16'd0;
    reg [3:0] current_nibble;
    reg [3:0] digit_raw;
    reg [7:0] seg_raw;

    function [7:0] seg_lut;
        input [3:0] value;
        begin
            case (value)
                4'h0: seg_lut = 8'b1100_0000;
                4'h1: seg_lut = 8'b1111_1001;
                4'h2: seg_lut = 8'b1010_0100;
                4'h3: seg_lut = 8'b1011_0000;
                4'h4: seg_lut = 8'b1001_1001;
                4'h5: seg_lut = 8'b1001_0010;
                4'h6: seg_lut = 8'b1000_0010;
                4'h7: seg_lut = 8'b1111_1000;
                4'h8: seg_lut = 8'b1000_0000;
                4'h9: seg_lut = 8'b1001_0000;
                4'hA: seg_lut = 8'b1000_1000;
                4'hB: seg_lut = 8'b1000_0011;
                4'hC: seg_lut = 8'b1100_0110;
                4'hD: seg_lut = 8'b1010_0001;
                4'hE: seg_lut = 8'b1000_0110;
                4'hF: seg_lut = 8'b1000_1110;
                default: seg_lut = 8'b1111_1111;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        scan_div <= scan_div + 16'd1;
    end

    always @(*) begin
        case (scan_div[15:14])
            2'b00: begin
                digit_raw      = 4'b0001;
                current_nibble = hex_word[3:0];
            end
            2'b01: begin
                digit_raw      = 4'b0010;
                current_nibble = hex_word[7:4];
            end
            2'b10: begin
                digit_raw      = 4'b0100;
                current_nibble = hex_word[11:8];
            end
            default: begin
                digit_raw      = 4'b1000;
                current_nibble = hex_word[15:12];
            end
        endcase

        seg_raw = seg_lut(current_nibble);

        if (DIGIT_ACTIVE_LOW) begin
            digit = ~digit_raw;
        end else begin
            digit = digit_raw;
        end

        if (SEG_ACTIVE_LOW) begin
            Seven_Seg = seg_raw;
        end else begin
            Seven_Seg = ~seg_raw;
        end
    end

endmodule
