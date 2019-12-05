/**
 * @ Author: German Cano Quiveu, germancq
 * @ Create Time: 2019-12-05 13:02:53
 * @ Modified by: Your name
 * @ Modified time: 2019-12-05 13:29:29
 * @ Description:
 */

module pulse_button(
	input clk,
	input rst,
	input button,
	output pulse);

logic currentValue_q;
logic currentValue_not_q;
logic previousValue_q;
logic previousValue_not_q;

biestable_d currentValue(
	.clk(clk),
	.rst(rst),
	.d(button),
	.q(currentValue_q),
	.not_q(currentValue_not_q)
);

biestable_d previousValue(
	.clk(clk),
	.rst(rst),
	.d(currentValue_q),
	.q(previousValue_q),
	.not_q(previousValue_not_q)
);

assign pulse = currentValue_q & previousValue_not_q;


endmodule : pulse_button


module biestable_d(
	input clk,
	input rst,
	input d,
	output logic q,
	output not_q);

always_ff @(posedge clk)
begin
	if(rst == 1'b1)
		q <= 1'b0;
	else
		q <= d;
end

assign not_q = ~q;

endmodule : biestable_d