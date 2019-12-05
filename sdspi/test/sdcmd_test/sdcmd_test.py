# @Author: German Cano Quiveu <germancq>
# @Date:   2018-11-15T13:53:25+01:00
# @Email:  germancq@dte.us.es
# @Filename: sdcmd_test.py
# @Last modified by:   germancq
# @Last modified time: 2018-11-19T16:48:04+01:00

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


def generate_command_test_from_array(command_array):
    command_test = 0
    for i in range (0,6):
        command_test = command_test + (command_array[i] << (8*(5-i)))
    return command_test

def generate_response_test_from_array(response_array):
    response_test = 0
    for i in range (0,5):
        response_test = response_test + (response_array[i] << (8*(4-i)))
    return response_test


def generate_command_array_from_value(command_value):
    command_array =[]
    for i in range (0,6):
        byte_value = command_value & (0xFF<<(8*(5-i)))
        byte_value = byte_value >> (8*(5-i))
        command_array = np.append(command_array,int(byte_value))
    return command_array

def generate_response_array_from_value(response_value):
    response_array =[]
    for i in range (0,5):
        byte_value = response_value & (0xFF<<(8*(4-i)))
        byte_value = byte_value >> (8*(4-i))
        response_array = np.append(response_array,int(byte_value))
    response_array = np.append(response_array,0xFF)
    return response_array


@cocotb.coroutine
def run_test(dut, command_value = None, response_value = None):
    cocotb.fork(Clock(dut.clk, CLK_PERIOD).start())

    command = command_value
    command_array = generate_command_array_from_value(command)
    response_test = response_value
    response_array = generate_response_array_from_value(response_test)

    ###############################################
    '''
        IDLE State
            check current_state = 0
            check spi_in_sdcmd_out = 0xFF
    '''
    ###############################################
    dut.reset = 1
    dut.spi_out_sdcmd_in = 0xFF
    dut.spi_busy = 0
    #################
    yield n_cycles_clock(dut,10)
    #################
    if(int(dut.current_state.value) != 0x0):
        raise TestFailure("Error IDLE state, cause wrong current state = %i"
                          % int(dut.current_state.value))
    if(int(dut.spi_in_sdcmd_out) != 0xFF):
        raise TestFailure("Error IDLE state, cause wrong spi input = %i"
                          % int(dut.spi_in_sdcmd_out))

    dut.w_cmd = 1
    dut.reset = 0
    dut.command = command
    yield n_cycles_clock(dut,1)
    ##################################################
    '''
        bucle SEND_CMD - WAIT_SPI
            SEND_CMD State
                check current_state = 1
                check spi_in_sdcmd_out = command[i-1]
                check spi_in_0_i = command[i]
            WAIT_SPI
                check current_state =
                check spi_in_sdcmd_out = command[i]

    '''
    ###############################################
    

    for i in range(0,6):
        if(int(dut.current_state.value) != 0x1):
            raise TestFailure("Error SEND_CMD state, cause wrong current state = %i" % int(dut.current_state.value))

        #################
        yield n_cycles_clock(dut,1)
        #################
        if(int(dut.spi_in_sdcmd_out) != command_array[i]):
            raise TestFailure("Error SEND_CMD state, cause wrong command_i input = %i" % int(dut.spi_in_sdcmd_out))

        dut.spi_busy = 1
        ################
        yield n_cycles_clock(dut,1)
        #################
        if(int(dut.current_state.value) != 0x4):
            raise TestFailure("Error WAIT_SPI state, cause wrong current state = %i"
                              % int(dut.current_state.value))
        #################
        yield n_cycles_clock(dut,16)
        #################
        dut.spi_busy = 0
        ################
        yield n_cycles_clock(dut,1)
        #################

    ##################################################
    '''
        WAIT_RESP State
            check current_state
            check spi_in_sdcmd_out = FF
    '''
    ###############################################


    ###############
    dut.spi_busy = 1
    yield n_cycles_clock(dut,1)
    ###################
    if(int(dut.current_state.value) != 0x2):
        raise TestFailure("Error WAIT_RESP state, cause wrong current state = %i" % int(dut.current_state.value))

    if(int(dut.spi_in_sdcmd_out) != 0xFF):
        raise TestFailure("Error WAIT_RESP state, cause wrong spi input = %i"
                          % int(dut.spi_in_sdcmd_out))

    if(int(dut.spi_out_0_o) != 0xFF):
        raise TestFailure("Error WAIT_RESP state, cause wrong spi output = %i"
                          % int(dut.spi_out_0_o))
    ####################

    yield n_cycles_clock(dut,1)
    #####################
    if(int(dut.current_state.value) != 0x4):
        raise TestFailure("Error WAIT_SPI state, cause wrong current state = %i"
                          % int(dut.current_state.value))

    dut.spi_out_sdcmd_in = int(response_array[0])
    yield n_cycles_clock(dut,16)
    dut.spi_busy = 0
    ####################
    yield n_cycles_clock(dut,1)

    if(int(dut.current_state.value) != 0x2):
        raise TestFailure("Error WAIT_RESP state, cause wrong current state = %i"
                          % int(dut.current_state.value))



    ##################################################
    '''
        bucle READ_RESP - WAIT_SPI
            READ_RESP State
                check current_state =

            WAIT_SPI
                check current_state =
                check spi_in_sdcmd_out =

    '''
    ###############################################



    ###########################
    yield n_cycles_clock(dut,1)
    
    limite = 1
    if (response_array[0] == 0x48):
        limite = 5

    ############################
    for j in range (0,limite):
        print(j)
        dut.spi_out_sdcmd_in = int(response_array[j+1])
        
        ###################
        if(int(dut.current_state.value) != 0x3):
            raise TestFailure("Error READ_RESP state, cause wrong current state = %i" % int(dut.current_state.value))

        if(int(dut.spi_out_0_o) != int(response_array[j])):
            raise TestFailure("Error READ_RESP state, cause wrong spi output = %i" % int(dut.spi_out_0_o))
        ####################

        yield n_cycles_clock(dut,1)
        #####################
        if(int(dut.current_state.value) != 0x4):
            raise TestFailure("Error WAIT_SPI state, cause wrong current state = %i" % int(dut.current_state.value))
        ####################
        yield n_cycles_clock(dut,1)
        


    if(int(dut.current_state.value) != 0x3):
        raise TestFailure("Error last READ_RESP state, cause wrong current state = %i"
                          % int(dut.current_state.value))

    
    if(((int(dut.response.value)>>32) & 0xFF) != response_array[0]):
        raise TestFailure("""Error RESPONSE,wrong value = {0}, expected value is {1}""".format(hex(int(dut.response.value)),hex(response_test)))

    yield n_cycles_clock(dut,1)

    if(int(dut.current_state.value) != 0x0):
        raise TestFailure("Error IDLE state, cause wrong current state = %i"
                          % int(dut.current_state.value))



@cocotb.coroutine
def n_cycles_clock(dut,n):
    for i in range(0,n):
        yield RisingEdge(dut.clk)
        yield FallingEdge(dut.clk)   


factory = TestFactory(run_test)
factory.add_option("command_value", np.random.randint(low=0,high=(2**48)-1,size=10)) #array de 10 int aleatorios
factory.add_option("response_value", np.random.randint(low=0,high=(2**40)-1,size=10))
factory.generate_tests()
