/*
 * @Author: German Cano Quiveu, germancq@gmail.com 
 * @Date: 2019-09-22 22:30:46 
 * @Last Modified by: German Cano Quiveu, germancq@gmail.com
 * @Last Modified time: 2019-09-22 22:37:28
 */
module counter
    #(parameter DATA_WIDTH = 8)
    (
        input clk,
        input rst,
        input up,
        input down,
        input [DATA_WIDTH-1 : 0] din,
        output logic [DATA_WIDTH -1 : 0] dout
    );



always_ff @(posedge clk) 
begin
    if(rst == 1)
        begin
            dout <= din;
        end
    else if (up == 1) 
        begin
            dout <= dout + 1;
        end    
    else if (down == 1) 
        begin
            dout <= dout - 1;
        end                
end

endmodule : counter