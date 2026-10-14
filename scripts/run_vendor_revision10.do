# Run from the project root in ModelSim-Altera (Quartus II 13.1).
# Uses genuine altera_mf_ver for the new registered feedback RAM.
# This is NOT run by portable Icarus tests. Supply the real vendor library.
onerror {quit -code 1}
vlib work
vlog -sv +define+USE_ALTERA_FFT_DELAY_RAM rtl/fft_delay_ram.v rtl/sdf_butterfly.v sim/reference/sdf_butterfly_rev9.v sim/tb_butterfly_pipeline.v
foreach aw {4 5 6 7 8 9 10 11 12} {
 foreach rotate {0 1} {
  vsim -c -L altera_mf_ver -gAW=$aw -gROTATE=$rotate work.tb_butterfly_pipeline
  run -all
  quit -sim
 }
}
quit -code 0
