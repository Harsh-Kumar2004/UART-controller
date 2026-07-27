module UART_RX (
    input  wire       clk,
    input  wire       reset,
    input  wire       baud_tick, 

    input wire        parity_check, // set this to check for parity bit
    input wire        parity_odd,   // set this if the expected parity is odd

    input  wire       rx,           // Asynchronous incoming serial line

    output reg  [7:0] rx_data,      // The received byte
    output reg        rx_valid,     // Pulses HIGH for 1 cycle when data is ready (connects to wr_en)
    output reg        parity_error
);

    localparam IDLE   = 3'b000,
               START  = 3'b001,
               DATA   = 3'b010,
               PARITY = 3'b011,
               STOP   = 3'b100;
    reg  [2:0] state;

    reg [3:0] baudtick_counter; // Counts for 16x oversampling phase alignment
    reg [2:0] bit_counter;      // Counts 0 to 7 for the 8 data bits
    reg [7:0] shift_reg;        // Holds the data as it streams in
    reg       data_parity;


    // 2FF based synchronizer to prevent metastability
    reg rx_sync_1, rx_sync_2;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_sync_1 <= 1'b1; // since UART lines remain HIGH in IDLE state
            rx_sync_2 <= 1'b1;
        end 
        else begin
            rx_sync_1 <= rx;
            rx_sync_2 <= rx_sync_1;
        end
    end


    // to detect the start of data tranmission (actually it detects falling edge on rx)
    reg  rx_sync_delay;
    wire start_bit_detected;

    always @(posedge clk or posedge reset) begin
        if (reset) rx_sync_delay <= 1'b1;
        else       rx_sync_delay <= rx_sync_2;
    end

    assign start_bit_detected = (rx_sync_delay) && (!rx_sync_2);


    // FSM implementation of reciever
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            baudtick_counter <= 4'b0;
            bit_counter      <= 3'b0;
            shift_reg        <= 8'b0;
            rx_data          <= 8'b0;
            rx_valid         <= 1'b0;
            parity_error     <= 1'b0;
        end 
        else begin
            rx_valid <= 1'b0;

            case (state)
                IDLE: begin
                    if (start_bit_detected) begin 
                        baudtick_counter <= 4'b0;
                        parity_error     <= 1'b0;
                        state <= START; 
                    end  
                end

                START: begin
                    if (baud_tick) begin
                        baudtick_counter <= baudtick_counter + 4'b0001;
                        if (baudtick_counter == 4'b0111) begin 
                            if (rx_sync_2 == 1'b0) begin 
                                state            <= DATA;
                                baudtick_counter <= 4'b0;
                            end
                            else state <= IDLE;
                        end
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        baudtick_counter <= baudtick_counter + 4'b0001;
                        if (baudtick_counter == 4'b1111) begin 
                            bit_counter <= bit_counter + 3'b001;
                            shift_reg   <= {rx_sync_2, shift_reg[7:1]};
                            if (bit_counter == 3'b111) begin
                                if (parity_check) state <= PARITY;
                                else              state <= STOP;
                            end
                        end
                    end
                end

                PARITY: begin 
                    data_parity <= ^shift_reg;
                    if (baud_tick) begin 
                        baudtick_counter <= baudtick_counter + 4'b0001;
                        if (baudtick_counter == 4'b1111) begin 
                            if (!parity_odd) parity_error <=  (data_parity ^ rx_sync_2);
                            else             parity_error <= ~(data_parity ^ rx_sync_2);
                            state <= STOP;
                        end 
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        baudtick_counter <= baudtick_counter + 4'b0001;
                        if (baudtick_counter == 4'b1111) begin 
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                            state    <= IDLE;
                        end 
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule