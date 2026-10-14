# Run from the project root with ModelSim-Altera supplied with Quartus II 13.1.
# First: python sim/model.py
# Requires the genuine altera_mf_ver simulation library and MIF/PLI support.
# This is an additional primitive-branch test, not part of portable Icarus tests.
onerror {quit -code 1}
vlib work
vlog -sv +define+USE_ALTERA_TDP_ROM +define+USE_ALTERA_FFT_DELAY_RAM +incdir+rtl rtl/fft_twiddle_rom.v rtl/fft_delay_ram.v rtl/sdf_butterfly.v rtl/r22_twiddle.v rtl/fft8192_stream.v sim/tb_fft.v
vsim -c -L altera_mf_ver work.tb_fft
run -all
quit -code 0
