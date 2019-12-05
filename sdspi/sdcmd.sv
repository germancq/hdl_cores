/**
 * @Author: German Cano Quiveu <germancq>
 * @Date:   2019-03-01T13:23:52+01:00
 * @Email:  germancq@dte.us.es
 * @Filename: sdcmd.v
 * @Last modified by:   germancq
 * @Last modified time: 2019-03-01T13:25:09+01:00
 */


 module sdcmd(
   input clk,
   input reset,
   input w_cmd,
   input[47:0] command,
   output [39:0] response,
   output logic busy,

   /////////SPI signals////////
   input[7:0] spi_out_sdcmd_in,
   output[7:0] spi_in_sdcmd_out,
   input spi_busy,
   output logic w_spi_data,
   output logic cs_spi,


   output[31:0] debug
 );

 //Command
 // bit 47 : start bit, must be '0'
 // bit 46 : transmission bit, must be '1'
 // bit 45-40: cmd_index + bits de inicio
 // bit 39-8: argument
 // bit 7-1: crc
 // bit 0 : end bit, must be '1'
 //Responses
 //R1 : 8 bits
 //  bit 0 : in idle state
 //  bit 1 : erase reset
 //  bit 2 : ilegal command
 //  bit 3 : com crc error
 //  bit 4 : erase sequence error
 //  bit 5 : address error
 //  bit 6 : parameter error
 //  bit 7 : '0'
 //R3 : 40 bits
 //  bit 39-32 : R1
 //  bit 31-0 : OCR
 //R7 : 40 bits
 //  bit 39-32 : R1
 //  bit 31-28 : command version
 //  bit 27-12 : reserved
 //  bit 11-8 : voltage accepted
 //  bit 7-0 : echo-back


 



 logic up;
 logic [2:0] counter_o;
 logic rst_counter;
 counter #(.DATA_WIDTH(3)) counter(
    .clk(clk),
    .rst(rst_counter),
    .up(up),
    .down(1'b0),
    .din(3'h0),
    .dout(counter_o)
 );


 logic [7:0] spi_in_0_i;
 logic spi_in_0_cl;
 logic spi_in_0_w;
 register #(.DATA_WIDTH(8)) r_spi_in_sdcmd_out(
 	.clk(clk),
 	.cl(spi_in_0_cl),
 	.w(spi_in_0_w),
 	.din(spi_in_0_i),
 	.dout(spi_in_sdcmd_out)
 );


 logic [7:0] spi_out_0_o;
 logic spi_out_0_cl;
 logic spi_out_0_w;
 register #(.DATA_WIDTH(8)) r_spi_out_sdcmd_in(
 	.clk(clk),
 	.cl(spi_out_0_cl),
 	.w(spi_out_0_w),
 	.din(spi_out_sdcmd_in),
 	.dout(spi_out_0_o)
 );



 logic [0:0] response_cl[4:0];
 logic [0:0] response_w[4:0];
 genvar i;
 generate
    for (i = 0;i<5 ;i=i+1 ) begin
      register #(.DATA_WIDTH(8)) r_response_i(
        .clk(clk),
        .cl(response_cl[i]),
        .w(response_w[i]),
        .din(spi_out_0_o),
        .dout(response[(i<<3)+7:(i<<3)])
      );
    end
 endgenerate



 


 logic [2:0] current_state;
 logic [2:0] next_state;
 parameter IDLE = 4'h0;
 parameter SEND_CMD = 4'h1;
 parameter WAIT_RESP = 4'h2;
 parameter READ_RESP = 4'h3;
 parameter WAIT_SPI = 4'h4;

 wire [2:0] reg_state_prev;
 reg r_state_prev_cl;
 reg r_state_prev_w;
 register #(.DATA_WIDTH(3)) r_state_prev_0(
     .clk(clk),
     .cl(r_state_prev_cl),
     .w(r_state_prev_w),
     .din(current_state),
     .dout(reg_state_prev)
 );

 //maquina de estados
 /*
   Suponemos que el proceso de inicializacion lo realiza el top_module
   tratar comandos
     - enviar command empezando por MSB
     - esperar respuesta , data_spi_out /= 0xFF
 */
 always_comb
 begin
   next_state = current_state;

   busy = 1'b1;
   cs_spi = 1'b0; // seleccionado por defecto
   w_spi_data = 1'b0;

   rst_counter = 1'b0;
   up = 1'b0;

   spi_in_0_cl = 1'b0;
   spi_in_0_w = 1'b0;
   spi_in_0_i = 8'hFF;

   spi_out_0_cl = 1'b0;
   spi_out_0_w = 1'b0;

   response_w[4] = 1'b0;
   response_cl[4] = 1'b0;
   response_w[3] = 1'b0;
   response_cl[3] = 1'b0;
   response_w[2] = 1'b0;
   response_cl[2] = 1'b0;
   response_w[1] = 1'b0;
   response_cl[1] = 1'b0;
   response_w[0] = 1'b0;
   response_cl[0] = 1'b0;

   r_state_prev_cl = 1'b0;
   r_state_prev_w = 1'b0;

   case(current_state)
     IDLE:
       begin
         busy = 1'b0;
         rst_counter = 1'b1;
         spi_in_0_w = 1'b1;
         spi_out_0_cl = 1'b1;
         if(w_cmd == 1'b1)
           next_state = SEND_CMD;
       end
     SEND_CMD:
       begin
         response_cl[4] = 1;
         response_cl[3] = 1;
         response_cl[2] = 1;
         response_cl[1] = 1;
         response_cl[0] = 1;

         cs_spi = 1'b0;
         next_state = WAIT_SPI;
         r_state_prev_w = 1'b1;
         up = 1'b1;
         spi_in_0_w = 1'b1;
         w_spi_data = 1'b1;
         case(counter_o)
           0:  spi_in_0_i = command[47:40];
           1:  spi_in_0_i = command[39:32];
           2:  spi_in_0_i = command[31:24];
           3:  spi_in_0_i = command[23:16];
           4:  spi_in_0_i = command[15:8];
           5:  spi_in_0_i = command[7:0];
           default: next_state = WAIT_RESP;
         endcase
       end
     WAIT_RESP:
       begin
         cs_spi = 1'b0;
         spi_in_0_i = 8'hFF;
         spi_in_0_w = 1'b1;
         w_spi_data = 1'b1;
         r_state_prev_w = 1'b1;
         rst_counter = 1'b1;
         next_state = WAIT_SPI;
         if(spi_out_0_o != 8'hFF)
           begin
             spi_out_0_w = 1'b1;
             next_state = READ_RESP;
           end
       end
     READ_RESP:
       begin
         up = 1'b1;
         cs_spi = 1'b0;
         next_state = WAIT_SPI;
         r_state_prev_w = 1'b1;
         w_spi_data = 1'b1;


         if(command[47:40] == 8'b01001000) //CMD8
             begin
                 case(counter_o)
                       0:  response_w[4] = 1'b1;
                       1:  response_w[3] = 1'b1;
                       2:  response_w[2] = 1'b1;
                       3:  response_w[1] = 1'b1;
                       4:  response_w[0] = 1'b1;
                       default: next_state = IDLE;
                 endcase
             end
         else
             begin
                 case(counter_o)
                       0:  response_w[4] = 1'b1;
                       default:
                       begin
                         next_state = IDLE;
                         w_spi_data = 0;
                       end
                 endcase
             end

       end
     WAIT_SPI:
       begin
         cs_spi = 1'b0;
         if(spi_busy == 1'b0)
         begin
           next_state = reg_state_prev;
           spi_out_0_w = 1'b1;
         end
       end

   endcase
 end

 //Generate Next State
 //CS <= NS
 always_ff @(posedge clk)
 begin
 	if(reset)
 		current_state <= IDLE;
 	else
 		current_state <= next_state;
 end

 assign debug = {reg_state_prev,current_state,spi_out_0_o,spi_in_sdcmd_out};

 endmodule
