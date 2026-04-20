module atm_top (
    input  wire       clk,
    input  wire [3:0] sw,
    input  wire [4:0] pb,
    output reg  [15:0] led,
    output wire [3:0] digit,
    output wire [7:0] Seven_Seg
);

    localparam [3:0] ST_LOCKED    = 4'd0;
    localparam [3:0] ST_MENU      = 4'd1;
    localparam [3:0] ST_BALANCE   = 4'd2;
    localparam [3:0] ST_DEPOSIT   = 4'd3;
    localparam [3:0] ST_WITHDRAW  = 4'd4;
    localparam [3:0] ST_PINCHANGE = 4'd5;
    localparam [3:0] ST_HISTORY   = 4'd6;
    localparam [3:0] ST_ERROR     = 4'd7;
    localparam [3:0] ST_LOCKOUT   = 4'd8;

    localparam [1:0] TX_NONE     = 2'd0;
    localparam [1:0] TX_DEPOSIT  = 2'd1;
    localparam [1:0] TX_WITHDRAW = 2'd2;

    localparam [15:0] DISP_LOCKED   = 16'h1111;
    localparam [15:0] DISP_MENU     = 16'h2222;
    localparam [15:0] DISP_PINCHG   = 16'h5555;
    localparam [15:0] DISP_ERROR    = 16'hEEEE;
    localparam [15:0] DISP_LOCKOUT  = 16'hDEAD;

    localparam integer ERROR_HOLD_CYCLES   = 50_000_000;
    localparam integer LOCKOUT_HOLD_CYCLES = 250_000_000;

    reg [3:0]  state = ST_LOCKED;
    reg [3:0]  state_after_error = ST_LOCKED;
    reg [2:0]  digit_count = 3'd0;
    reg [1:0]  failed_attempts = 2'd0;
    reg [1:0]  last_tx_type = TX_NONE;
    reg [15:0] stored_pin = 16'h1234;
    reg [15:0] pin_shift = 16'h0000;
    reg [15:0] amount_entry_bcd = 16'h0000;
    reg [15:0] display_word = DISP_LOCKED;
    reg [13:0] balance = 14'd0;
    reg [13:0] last_tx_amount = 14'd0;
    reg [27:0] hold_counter = 28'd0;

    wire enter_level;
    wire enter_pulse;
    wire back_level;
    wire back_pulse;
    wire clear_level;
    wire clear_pulse;
    wire logout_level;
    wire logout_pulse;

    wire        valid_digit;
    wire [15:0] next_pin_word;
    wire [15:0] next_amount_bcd;
    wire [13:0] next_amount_bin;

    function [13:0] bcd4_to_bin;
        input [15:0] bcd_value;
        begin
            bcd4_to_bin =
                (bcd_value[15:12] * 14'd1000) +
                (bcd_value[11:8]  * 14'd100)  +
                (bcd_value[7:4]   * 14'd10)   +
                bcd_value[3:0];
        end
    endfunction

    function [15:0] bin_to_bcd4;
        input [13:0] value;
        integer thousands;
        integer hundreds;
        integer tens;
        integer ones;
        integer rem;
        begin
            thousands = value / 1000;
            rem       = value % 1000;
            hundreds  = rem / 100;
            rem       = rem % 100;
            tens      = rem / 10;
            ones      = rem % 10;

            bin_to_bcd4 = {
                thousands[3:0],
                hundreds[3:0],
                tens[3:0],
                ones[3:0]
            };
        end
    endfunction

    assign valid_digit    = (sw <= 4'd9);
    assign next_pin_word  = {pin_shift[11:0], sw};
    assign next_amount_bcd = {amount_entry_bcd[11:0], sw};
    assign next_amount_bin = bcd4_to_bin(next_amount_bcd);

    button_debounce #(
        .CLK_HZ(50_000_000),
        .DEBOUNCE_MS(20)
    ) enter_btn (
        .clk(clk),
        .noisy_in(pb[4]),
        .level(enter_level),
        .pulse(enter_pulse)
    );

    button_debounce #(
        .CLK_HZ(50_000_000),
        .DEBOUNCE_MS(20)
    ) back_btn (
        .clk(clk),
        .noisy_in(pb[1]),
        .level(back_level),
        .pulse(back_pulse)
    );

    button_debounce #(
        .CLK_HZ(50_000_000),
        .DEBOUNCE_MS(20)
    ) clear_btn (
        .clk(clk),
        .noisy_in(pb[2]),
        .level(clear_level),
        .pulse(clear_pulse)
    );

    button_debounce #(
        .CLK_HZ(50_000_000),
        .DEBOUNCE_MS(20)
    ) logout_btn (
        .clk(clk),
        .noisy_in(pb[0]),
        .level(logout_level),
        .pulse(logout_pulse)
    );

    always @(posedge clk) begin
        if (logout_pulse) begin
            state             <= ST_LOCKED;
            state_after_error <= ST_LOCKED;
            digit_count       <= 3'd0;
            pin_shift         <= 16'h0000;
            amount_entry_bcd  <= 16'h0000;
            hold_counter      <= 28'd0;
        end else if (clear_pulse) begin
            case (state)
                ST_LOCKED,
                ST_PINCHANGE: begin
                    digit_count <= 3'd0;
                    pin_shift   <= 16'h0000;
                end

                ST_DEPOSIT,
                ST_WITHDRAW: begin
                    digit_count      <= 3'd0;
                    amount_entry_bcd <= 16'h0000;
                end

                default: begin
                end
            endcase
        end else if (back_pulse) begin
            case (state)
                ST_MENU: begin
                    state            <= ST_LOCKED;
                    digit_count      <= 3'd0;
                    pin_shift        <= 16'h0000;
                    amount_entry_bcd <= 16'h0000;
                end

                ST_BALANCE,
                ST_HISTORY: begin
                    state <= ST_MENU;
                end

                ST_DEPOSIT,
                ST_WITHDRAW,
                ST_PINCHANGE: begin
                    state            <= ST_MENU;
                    digit_count      <= 3'd0;
                    pin_shift        <= 16'h0000;
                    amount_entry_bcd <= 16'h0000;
                end

                default: begin
                end
            endcase
        end else begin
            case (state)
                ST_LOCKED: begin
                    if (enter_pulse) begin
                        if (valid_digit) begin
                            if (digit_count == 3'd3) begin
                                if (next_pin_word == stored_pin) begin
                                    state           <= ST_MENU;
                                    failed_attempts <= 2'd0;
                                end else if (failed_attempts == 2'd2) begin
                                    state           <= ST_LOCKOUT;
                                    hold_counter    <= LOCKOUT_HOLD_CYCLES - 1;
                                    failed_attempts <= 2'd0;
                                end else begin
                                    state             <= ST_ERROR;
                                    state_after_error <= ST_LOCKED;
                                    hold_counter      <= ERROR_HOLD_CYCLES - 1;
                                    failed_attempts   <= failed_attempts + 1'b1;
                                end

                                digit_count <= 3'd0;
                                pin_shift   <= 16'h0000;
                            end else begin
                                digit_count <= digit_count + 1'b1;
                                pin_shift   <= next_pin_word;
                            end
                        end else begin
                            state             <= ST_ERROR;
                            state_after_error <= ST_LOCKED;
                            hold_counter      <= ERROR_HOLD_CYCLES - 1;
                            digit_count       <= 3'd0;
                            pin_shift         <= 16'h0000;
                        end
                    end
                end

                ST_MENU: begin
                    if (enter_pulse) begin
                        case (sw)
                            4'd1: state <= ST_BALANCE;
                            4'd2: begin
                                state            <= ST_DEPOSIT;
                                digit_count      <= 3'd0;
                                amount_entry_bcd <= 16'h0000;
                            end
                            4'd3: begin
                                state            <= ST_WITHDRAW;
                                digit_count      <= 3'd0;
                                amount_entry_bcd <= 16'h0000;
                            end
                            4'd4: begin
                                state       <= ST_PINCHANGE;
                                digit_count <= 3'd0;
                                pin_shift   <= 16'h0000;
                            end
                            4'd5: state <= ST_HISTORY;
                            default: begin
                                state             <= ST_ERROR;
                                state_after_error <= ST_MENU;
                                hold_counter      <= ERROR_HOLD_CYCLES - 1;
                            end
                        endcase
                    end
                end

                ST_BALANCE: begin
                    if (enter_pulse) begin
                        state <= ST_MENU;
                    end
                end

                ST_DEPOSIT: begin
                    if (enter_pulse) begin
                        if (valid_digit) begin
                            if (digit_count == 3'd3) begin
                                if ((next_amount_bin == 14'd0) ||
                                    (({1'b0, balance} + {1'b0, next_amount_bin}) > 15'd9999)) begin
                                    state             <= ST_ERROR;
                                    state_after_error <= ST_DEPOSIT;
                                    hold_counter      <= ERROR_HOLD_CYCLES - 1;
                                end else begin
                                    balance        <= balance + next_amount_bin;
                                    last_tx_amount <= next_amount_bin;
                                    last_tx_type   <= TX_DEPOSIT;
                                    state          <= ST_BALANCE;
                                end

                                digit_count      <= 3'd0;
                                amount_entry_bcd <= 16'h0000;
                            end else begin
                                digit_count      <= digit_count + 1'b1;
                                amount_entry_bcd <= next_amount_bcd;
                            end
                        end else begin
                            state             <= ST_ERROR;
                            state_after_error <= ST_DEPOSIT;
                            hold_counter      <= ERROR_HOLD_CYCLES - 1;
                            digit_count       <= 3'd0;
                            amount_entry_bcd  <= 16'h0000;
                        end
                    end
                end

                ST_WITHDRAW: begin
                    if (enter_pulse) begin
                        if (valid_digit) begin
                            if (digit_count == 3'd3) begin
                                if ((next_amount_bin == 14'd0) ||
                                    (next_amount_bin > balance)) begin
                                    state             <= ST_ERROR;
                                    state_after_error <= ST_WITHDRAW;
                                    hold_counter      <= ERROR_HOLD_CYCLES - 1;
                                end else begin
                                    balance        <= balance - next_amount_bin;
                                    last_tx_amount <= next_amount_bin;
                                    last_tx_type   <= TX_WITHDRAW;
                                    state          <= ST_BALANCE;
                                end

                                digit_count      <= 3'd0;
                                amount_entry_bcd <= 16'h0000;
                            end else begin
                                digit_count      <= digit_count + 1'b1;
                                amount_entry_bcd <= next_amount_bcd;
                            end
                        end else begin
                            state             <= ST_ERROR;
                            state_after_error <= ST_WITHDRAW;
                            hold_counter      <= ERROR_HOLD_CYCLES - 1;
                            digit_count       <= 3'd0;
                            amount_entry_bcd  <= 16'h0000;
                        end
                    end
                end

                ST_PINCHANGE: begin
                    if (enter_pulse) begin
                        if (valid_digit) begin
                            if (digit_count == 3'd3) begin
                                stored_pin  <= next_pin_word;
                                state       <= ST_MENU;
                                digit_count <= 3'd0;
                                pin_shift   <= 16'h0000;
                            end else begin
                                digit_count <= digit_count + 1'b1;
                                pin_shift   <= next_pin_word;
                            end
                        end else begin
                            state             <= ST_ERROR;
                            state_after_error <= ST_PINCHANGE;
                            hold_counter      <= ERROR_HOLD_CYCLES - 1;
                            digit_count       <= 3'd0;
                            pin_shift         <= 16'h0000;
                        end
                    end
                end

                ST_HISTORY: begin
                    if (enter_pulse) begin
                        state <= ST_MENU;
                    end
                end

                ST_ERROR: begin
                    if (hold_counter != 28'd0) begin
                        hold_counter <= hold_counter - 1'b1;
                    end else begin
                        state <= state_after_error;
                    end
                end

                ST_LOCKOUT: begin
                    if (hold_counter != 28'd0) begin
                        hold_counter <= hold_counter - 1'b1;
                    end else begin
                        state       <= ST_LOCKED;
                        digit_count <= 3'd0;
                        pin_shift   <= 16'h0000;
                    end
                end

                default: begin
                    state <= ST_LOCKED;
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            ST_LOCKED: begin
                display_word = DISP_LOCKED;
            end

            ST_MENU: begin
                display_word = DISP_MENU;
            end

            ST_BALANCE: begin
                display_word = bin_to_bcd4(balance);
            end

            ST_DEPOSIT: begin
                display_word = amount_entry_bcd;
            end

            ST_WITHDRAW: begin
                display_word = amount_entry_bcd;
            end

            ST_PINCHANGE: begin
                display_word = DISP_PINCHG;
            end

            ST_HISTORY: begin
                display_word = bin_to_bcd4(last_tx_amount);
            end

            ST_ERROR: begin
                display_word = DISP_ERROR;
            end

            ST_LOCKOUT: begin
                display_word = DISP_LOCKOUT;
            end

            default: begin
                display_word = DISP_LOCKED;
            end
        endcase
    end

    always @(*) begin
        case (state)
            ST_LOCKED: begin
                led = pin_shift;
            end

            ST_BALANCE: begin
                led = bin_to_bcd4(balance);
            end

            ST_DEPOSIT,
            ST_WITHDRAW: begin
                led = amount_entry_bcd;
            end

            ST_PINCHANGE: begin
                led = pin_shift;
            end

            ST_HISTORY: begin
                led = bin_to_bcd4(last_tx_amount);
            end

            default: begin
                led = 16'h0000;
            end
        endcase
    end

    sevenseg_mux display_driver (
        .clk(clk),
        .hex_word(display_word),
        .digit(digit),
        .Seven_Seg(Seven_Seg)
    );

endmodule
