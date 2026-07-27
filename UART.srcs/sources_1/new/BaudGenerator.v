module BaudGenerator (
    input  wire        clk,
    input  wire        reset,
    input  wire [15:0] divisor, // if divisor is set to 4 it means for every four clock signals there would be one baud_tick

    output reg         baud_tick
);

    reg [15:0] counter; 

    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            baud_tick <= 1'b0;
            counter   <= 16'b0;
        end

        else begin 
            if (counter == divisor - 1) begin 
                baud_tick <= 1'b1;
                counter   <= 16'b0;
            end
            else begin 
                baud_tick <= 1'b0;
                counter   <= counter + 16'b1;
            end
        end
    end

endmodule