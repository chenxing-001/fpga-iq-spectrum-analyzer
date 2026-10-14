# Run from project root after python scripts/generate.py, sim/model.py,
# and sim/twiddle_vectors.py. Requires Quartus II 13.1 ModelSim-Altera libraries.
# Real altsyncram for FFT feedback/coefficient/power RAM; no fitted timing here.
# No PLL or board timing is verified by this RAM-focused script.
# This script has not been executed in the delivery environment.
onerror {quit -code 1}
vlib work
eval vlog -sv +define+USE_ALTERA_TDP_ROM+USE_ALTERA_POWER_RAM+USE_ALTERA_FFT_DELAY_RAM [glob rtl/*.v] sim/tb_fft.v sim/tb_analyzer.v sim/tb_twiddle.v sim/reference/sdf_butterfly_rev20.v sim/reference/fft8192_stream_rev20.v sim/tb_butterfly_rev21.v sim/tb_fft_rev21.v sim/reference/r22_twiddle_rev21.v sim/reference/fft8192_stream_rev21.v sim/tb_fft_rev22.v sim/tb_twiddle_rev22.v
foreach rotate {0 1} {
 vsim -c -L altera_mf_ver -gROTATE=$rotate work.tb_butterfly_rev21
 run -all
 quit -sim
}
vsim -c -L altera_mf_ver work.tb_fft_rev21
run -all
quit -sim
vsim -c -L altera_mf_ver work.tb_fft_rev22
run -all
quit -sim
vsim -c -L altera_mf_ver work.tb_fft
run -all
quit -sim
vsim -c -L altera_mf_ver work.tb_analyzer
run -all
quit -sim
foreach logn {13 11 9 7 5 3} {
 set n [expr {1 << $logn}]
 vsim -c -L altera_mf_ver -gLOGN=$logn -gROM_FILE=data/sin_tw_${n}.hex -gMIF_FILE=data/sin_tw_${n}.mif work.tb_twiddle_rev22
 run -all
 quit -sim
}
quit -code 0
