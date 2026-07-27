module UART_TX (
    input  wire       clk,
    input  wire       reset,
    input  wire       baud_tick,

    input  wire [1:0] stop_bits,  // configurable stop_bits (max stop bit supported is 3)
    input  wire       parity_en,  // set this to enable parity 
    input  wire       parity_odd, // set this for odd parity 

    input  wire [7:0] tx_data,    // Data to be transmitted serially
    input  wire       tx_valid,   // FIFO says data is available (or fifo is not empty)

    output reg        tx_ready,   // UART is ready to transmit another byte (read_en for fifo)
    output reg        tx
);

    localparam IDLE   = 3'b000,
               START  = 3'b001,
               DATA   = 3'b010,
               PARITY = 3'b011,
               STOP   = 3'b100;
    reg  [2:0] state;

    reg  [7:0] shift_reg;         // to shift the data on tx
    reg  [3:0] baudtick_counter;  // counts baudtick 
    reg  [2:0] data_counter;      // counts how many bits have been send till now 
    reg  [1:0] stopbit_counter;   // counter to count no. of stopbits 
    reg        parity_is_odd;     // if set, the data parity is odd

    wire   bit_tick;              // this wire actually ticks at baud rate
    assign bit_tick = (baud_tick == 1'b1) && (baudtick_counter == 4'b1111);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state            <= IDLE;
            tx               <= 1'b1;  // UART line idles HIGH
            tx_ready         <= 1'b1;
            shift_reg        <= 8'b0;
            baudtick_counter <= 4'b0;
            data_counter     <= 3'b0;
            stopbit_counter  <= 2'b0;
        end 
        else begin    
            if (baud_tick) begin
                baudtick_counter <= baudtick_counter + 4'b0001;
            end

            case (state)
                IDLE: begin
                    tx       <= 1'b1;
                    tx_ready <= 1'b1;

                    // tx_valid is connected to !empty
                    if (tx_valid) begin 
                        shift_reg        <= tx_data;
                        tx_ready         <= 1'b0;
                        baudtick_counter <= 4'b0; // Reset tick counter to ensure START bit is exactly 16 ticks
                        stopbit_counter  <= 2'b0;
                        state            <= START;
                    end
                end

                START: begin
                    tx            <= 1'b0; 
                    parity_is_odd <= ^(shift_reg);   
                    if (bit_tick) begin
                        data_counter <= 3'b0;
                        state        <= DATA; 
                    end
                end

                DATA: begin
                    tx <= shift_reg[0]; 
                    if (bit_tick) begin 
                        shift_reg    <= shift_reg >> 1'b1;
                        data_counter <= data_counter + 3'b1;
                        
                        if (data_counter == 3'b111) begin
                            if (parity_en) state <= PARITY;
                            else           state <= STOP;
                        end
                    end
                end

                PARITY: begin 
                    if (!parity_odd) tx <= parity_is_odd;
                    else             tx <= (~parity_is_odd);
                    if (bit_tick) state <= STOP;
                end

                STOP: begin
                    tx <= 1'b1; 
                    if (bit_tick) begin
                        stopbit_counter <= stopbit_counter + 2'b1; 
                        if (stopbit_counter == stop_bits - 1) begin 
                            state    <= IDLE;
                            tx_ready <= 1'b1;
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule