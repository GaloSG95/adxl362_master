restart -f -nowave
config wave -signalnamewidth 1

add wave clk
add wave rst
add wave xdout
add wave xvalid
add wave cs      
add wave mosi
add wave miso
add wave sclk

add wave -divider internal
add wave -radix unsigned dut/state_machine/bit_counter
add wave dut/state

run -all

view signals wave