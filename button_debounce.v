module button_debounce #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer DEBOUNCE_MS = 20
) (
    input  wire clk,
    input  wire noisy_in,
    output reg  level = 1'b0,
    output reg  pulse = 1'b0
);

    function integer clog2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i = 0; value > 0; i = i + 1) begin
                value = value >> 1;
            end
            clog2 = i;
        end
    endfunction

    localparam integer COUNT_MAX = (CLK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer COUNT_W   = (COUNT_MAX > 1) ? clog2(COUNT_MAX) : 1;

    reg sync_ff0 = 1'b0;
    reg sync_ff1 = 1'b0;
    reg [COUNT_W-1:0] counter = {COUNT_W{1'b0}};

    always @(posedge clk) begin
        sync_ff0 <= noisy_in;
        sync_ff1 <= sync_ff0;
        pulse    <= 1'b0;

        if (sync_ff1 == level) begin
            counter <= {COUNT_W{1'b0}};
        end else begin
            if (counter == COUNT_MAX - 1) begin
                level   <= sync_ff1;
                counter <= {COUNT_W{1'b0}};

                if (sync_ff1) begin
                    pulse <= 1'b1;
                end
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end

endmodule
