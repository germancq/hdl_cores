# @Author: German Cano Quiveu <germancq>
# @Date:   2018-11-19T17:59:54+01:00
# @Email:  germancq@dte.us.es
# @Filename: sdspihost_test.py
# @Last modified by:   germancq
# @Last modified time: 2018-11-20T15:47:53+01:00


import cocotb
import numpy as np
from cocotb.triggers import Timer, RisingEdge, FallingEdge, ReadOnly, ClockCycles
from cocotb.regression import TestFactory
from cocotb.result import TestFailure, ReturnValue
from cocotb.clock import Clock


#the keyword yield
#   Testbenches built using Cocotb use coroutines.
#   While the coroutine is executing the simulation is paused.
#   The coroutine uses the yield keyword
#   to pass control of execution back to
#   the simulator and simulation time can advance again.
#
#   yield return when the 'Trigger' is resolve
#
#   Coroutines may also yield a list of triggers
#   to indicate that execution should resume if any of them fires

#default unit time is nanosecond
CLK_PERIOD = 20 # 50 MHz


def setup_function(dut):
    cocotb.fork(Clock(dut.clk, CLK_PERIOD).start())
    dut.reset = 1
    dut.r_block = 0
    dut.r_multi_block = 0
    dut.r_byte = 0
    dut.w_byte = 0
    dut.w_block = 0
    dut.block_addr = 0
    dut.data_in = 0xFF
    dut.miso = 1
    dut.sclk_speed = 6
    


@cocotb.coroutine
def from_reset_to_idle(dut):
    dut.reset = 1
    yield n_cycles_clock(dut,4)
      
    yield check_INITIALIZATION(dut)
    yield check_CMD_0(dut)

    '''
    yield check_WAIT_250_ms(dut)
    yield check_WAIT_74_CYC(dut)
    yield check_CMD_0(dut)
    yield check_CMD_8(dut)
    yield check_CMD_55(dut)
    yield check_ACMD_41(dut)
    yield check_IDLE(dut)
    '''

@cocotb.coroutine
def check_CMD_0(dut):

    print("check CMD0")
    #bloquea la signal w_cmd = 1, buscar el motivo
    #signal w_cmd = 1 stops the simulation, why?

    yield n_cycles_clock(dut,1)

    if(dut.current_state != 0x3):
        raise TestFailure("Error CMD0_0 ,wrong current_state value = %s"
                          % hex(int(dut.current_state.value))) 


@cocotb.coroutine
def check_INITIALIZATION(dut):

    dut.reset = 0

    if(dut.current_state != 0x0):
        raise TestFailure("Error INIT_0 ,wrong current_state value = %s"
                          % hex(int(dut.current_state.value)))  

    '''
        control de spi_master de sdspihost
    '''              
    if(dut.spi_mux_ctl != 0):
         raise TestFailure("""Error INIT_0, wrong mux_ctl value = {0}, expected value = 0""".format(hex(int(dut.spi_mux_ctl.value))))       

    '''
        contadores a 0
    '''    
    if(dut.counter_o != 0):
         raise TestFailure("""Error INIT_0, wrong counter_o value = {0}, expected value = 0""".format(hex(int(dut.counter_o.value)))) 

    

    yield n_cycles_clock(dut,1)


    '''
        spi_in  a velocidad de inicio 0x7B
    '''       
    if(dut.spi_module.sclk_div != 0xEB):
        raise TestFailure("""Error INIT_0, wrong sclk_div value = {0}, expected value = 0xEB""".format(hex(int(dut.spi_module.sclk_div.value))))

    ############################################################################

    if(dut.current_state != 0x1):
        raise TestFailure("Error WAIT_250_ms ,wrong current_state value = %s"
                          % hex(int(dut.current_state.value))) 

    if(dut.spi_mux_ctl != 0):
         raise TestFailure("""Error WAIT_250_ms, wrong mux_ctl value = {0}, expected value = 0""".format(hex(int(dut.spi_mux_ctl.value))))

    if(dut.spi_module.ss_in != 0x1):
        raise TestFailure("""Error WAIT_250_ms, wrong cs spi value = {0}, expected value = 1""".format(hex(int(dut.spi_module.ss_in.value))))  

    while(dut.counter_o != 25):
        yield n_cycles_clock(dut,1)   
        

    yield n_cycles_clock(dut,1)                          

       

    ############################################################################

    for k in range (0,16):
    
        
        if(dut.current_state != 0x2):
            raise TestFailure("Error WAIT_74_CYC ,wrong current_state value = %s" % hex(int(dut.current_state.value)))

        if(dut.spi_mux_ctl != 0):
            raise TestFailure("""Error WAIT_74_CYC, wrong mux_ctl value = {0}, expected value = 0""".format(hex(int(dut.spi_mux_ctl.value))))

        if(dut.counter_o != k):
            raise TestFailure("""Error WAIT_74_CYC, wrong counter_o value = {0}, expected value = {1}""".format(int(dut.counter_o.value),k))

        dut.busy_spi = 1

        yield n_cycles_clock(dut,1)     

        if(dut.spi_mux_ctl != 0):
            raise TestFailure("""Error WAIT_74_CYC, wrong mux_ctl value = {0}, expected value = 0""".format(hex(int(dut.spi_mux_ctl.value))))

        if(dut.spi_module.data_in != 0xFF):                 
            raise TestFailure("""Error WAIT_74_CYC, wrong spi data in value = {0}, expected value = 0xFF""".format(hex(int(dut.spi_module.data_in.value))))

        if(dut.current_state != 0x1E):
            raise TestFailure("Error WAIT_SPI ,wrong current_state value = %s" % hex(int(dut.current_state.value)))

        yield n_cycles_clock(dut,6)

        dut.busy_spi = 0

        if(dut.current_state != 0x1E):
            raise TestFailure("Error WAIT_SPI ,wrong current_state value = %s" % hex(int(dut.current_state.value)))

        yield n_cycles_clock(dut,1)

    

    

    if(dut.current_state != 0x2):
            raise TestFailure("Error WAIT_74_CYC ,wrong current_state value = %s" % hex(int(dut.current_state.value))) 

    if(dut.next_state != 0x3):
            raise TestFailure("Error WAIT_74_CYC ,wrong next_state value = %s" % hex(int(dut.next_state.value)))    

    if(dut.counter_o != 16):
            raise TestFailure("""Error WAIT_74_CYC, wrong counter_o value = {0}, expected value = {1}""".format(int(dut.counter_o.value),16)) 

    
           
    





@cocotb.coroutine
def n_cycles_clock(dut,n):
    for i in range(0,n):
        yield RisingEdge(dut.clk)
        yield FallingEdge(dut.clk)  
        

@cocotb.test()
def run_test(dut,n=0):
    setup_function(dut)
    yield from_reset_to_idle(dut)



n = 10
factory = TestFactory(run_test)

factory.add_option("n", np.random.randint(low=0,high=(2**32)-1,size=n)) #array de 10 int aleatorios entre 0 y 31
factory.generate_tests() 