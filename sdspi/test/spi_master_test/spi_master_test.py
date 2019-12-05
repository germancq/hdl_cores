# @Author: German Cano Quiveu <germancq>
# @Date:   2018-11-13T21:40:47+01:00
# @Email:  germancq@dte.us.es
# @Last modified by:   germancq
# @Last modified time: 2018-11-21T02:24:18+01:00

import cocotb
import numpy as np
import time
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






@cocotb.coroutine
def run_test(dut, data_test = 67, sclk_div = 9, mosi_test = 46):

    cocotb.fork(Clock(dut.clk, CLK_PERIOD).start())

    dut.data_in = sclk_div
    dut.w_conf = 1
    
    yield n_cycles_clock(dut,2)
    if(dut.sclk_div != sclk_div):
        raise TestFailure("Error sclk_div, wrong value = %i"
                          % int(dut.sclk_div.value))

                          

    dut.w_conf = 0  
    dut.ss = 1                    

    dut.data_in = 0      
    yield n_cycles_clock(dut,100)

    dut.ss = 0
    dut.w_data = 1
    dut.data_in = mosi_test
    dut.miso = data_test & 0x1
    yield n_cycles_clock(dut,1)
    if(dut.sclk != 0):
        raise TestFailure("""Error sclk in w_data, wrong_value = {0}""".format(hex(int(dut.sclk.value))))

    dut.w_data = 0
    yield n_cycles_clock(dut,1)
    if(dut.busy != 1):
        raise TestFailure("""Error busy in w_data, wrong_value = {0}""".format(hex(int(dut.busy.value))))

    

    for i in range(0,8):
        dut.miso = (data_test>>(7-i)) & 0x1
        

        while(dut.sclk == 0):
            yield n_cycles_clock(dut,1)
            
        

        if(dut.mosi != ((mosi_test>>(7-i)) & 0x1)):
            raise TestFailure("""Error mosi in w_data, wrong_value = {0}  """.format(hex(int(dut.mosi.value))))

        while(dut.sclk == 1):
            yield n_cycles_clock(dut,1)

            
        


            
    if(dut.data_out != data_test):
        raise TestFailure("""Error data_out in w_data, wrong_value = {0} expected value {1}""".format(hex(int(dut.data_out.value)),hex(data_test)))




@cocotb.coroutine
def n_cycles_clock(dut,n):
    for i in range(0,n):
        yield RisingEdge(dut.clk)
        yield FallingEdge(dut.clk)  

factory = TestFactory(run_test)
factory.add_option("data_test", np.random.randint(low=0,high=255,size=5)) #array de 10 int aleatorios entre 0 y 255
factory.add_option("sclk_div", np.random.randint(low=4,high=10,size=5))
factory.add_option("mosi_test", np.random.randint(low=0,high=255,size=5))
factory.generate_tests()
