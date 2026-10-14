# Run AFTER fitting: quartus_sta -t scripts/report_timing.tcl
# Revision 23: UART/PC only; every operating corner and internal clock pair.
package require ::quartus::project
package require ::quartus::sta
cd [file dirname [file dirname [file normalize [info script]]]]
project_open spectrum_streaming
file mkdir output_files
file delete -force output_files/timing_gate_pass.txt
source scripts/timing_gate.tcl
create_timing_netlist
read_sdc
update_timing_netlist
report_clocks -file output_files/clocks.txt
report_exceptions -file output_files/exceptions.txt
report_ucp -file output_files/unconstrained.txt
check_timing -include {no_clock multiple_clock generated_clock loops latches} -file output_files/constraint_checks.txt
rev20_gate_start
set timing_clock_names {}
foreach_in_collection timing_clk [get_clocks *] {
 lappend timing_clock_names [get_clock_info -name $timing_clk]
}
set corner_index [open output_files/corners.txt w]
set timing_index [open output_files/clock_pairs.txt w]
set corner_id 0
# Optimizations can absorb/rename individual registers. Record endpoint counts
# instead of silently treating an empty targeted report as a timing pass.
set rev23_index [open output_files/revision23_nodes.txt w]
proc report_rev23_path {prefix label from_pattern to_pattern} {
 global rev23_index
 set src_nodes [get_registers $from_pattern]
 set dst_nodes [get_registers $to_pattern]
 set ns [get_collection_size $src_nodes]
 set nd [get_collection_size $dst_nodes]
 puts $rev23_index "$prefix $label: from=$ns to=$nd ($from_pattern -> $to_pattern)"
 if {$ns==0 || $nd==0} {
  puts "WARNING: $label endpoints missing; inspect mapping and use full setup report."
  return
 }
 report_timing -setup -from $src_nodes -to $dst_nodes -npaths 30 \
  -detail full_path -file ${prefix}_${label}.txt
}
foreach_in_collection op [get_available_operating_conditions] {
 set_operating_conditions $op
 update_timing_netlist
 set prefix [format "output_files/corner_%02d" $corner_id]
 puts $corner_index "${prefix}: [get_operating_conditions_info -display_name $op]"
 foreach check {setup hold recovery removal} {
  report_timing -$check -npaths 200 -detail full_path -file ${prefix}_${check}.txt
 }
 report_min_pulse_width -nworst 20 -file ${prefix}_pulse_width.txt
 report_fmax_summary -file ${prefix}_fmax.txt
 # Setup and hold of each clock pair, even when another module dominates.
 set pair 0
 foreach src $timing_clock_names {
  foreach dst $timing_clock_names {
   puts $timing_index "$prefix pair $pair: $src -> $dst"
   foreach check {setup hold} {
    set output [format "%s_%s_pair_%02d.txt" $prefix $check $pair]
    report_timing -$check -from_clock $src -to_clock $dst -npaths 20 -detail full_path -file $output
   }
   incr pair
  }
 }
 report_timing -setup -from [get_registers {*ana|*}] -to [get_registers {*ana|*}] \
  -npaths 40 -detail full_path -file ${prefix}_analyzer.txt
 report_timing -setup -from [get_registers {*ana|*power_encoder|*}] \
  -npaths 20 -detail full_path -file ${prefix}_encoder.txt
 # Separate wide countdown logic from the registered start control so neither
 # is hidden by another module's top-N paths. Keep normal timing constraints.
 report_timing -setup -from [get_registers {*ana|cooldown*}] \
  -npaths 30 -detail full_path -file ${prefix}_cooldown.txt
 report_timing -setup -from [get_registers {*fft|*}] -to [get_registers {*fft|*}] \
  -npaths 50 -detail full_path -file ${prefix}_fft.txt
 report_timing -setup -from [get_registers {*src|*}] -to [get_registers {*src|*}] \
  -npaths 30 -detail full_path -file ${prefix}_source.txt
 foreach tw {t2 t5 t8 t11 t14 t17} {
  report_timing -setup -from [get_registers "*fft|*${tw}|*"] \
   -npaths 20 -detail full_path -file ${prefix}_twiddle_${tw}.txt
 }
 report_timing -setup -from [get_registers {*ana|time_*3}] \
  -npaths 30 -detail full_path -file ${prefix}_time_control.txt
 report_timing -setup -from [get_registers {*uart|*}] -to [get_registers {*uart|*}] \
  -npaths 20 -detail full_path -file ${prefix}_uart.txt
 # Rev16: report both sides of every newly registered control/prefix.
 report_rev23_path $prefix run_decision {*} {*ana|run_commit*}
 report_rev23_path $prefix run_candidate {*} {*ana|run_candidate*}
 report_rev23_path $prefix run_output {*} {*ana|longest_run*}
 report_rev23_path $prefix cooldown_output {*} {*ana|cooldown[*]}
 report_rev23_path $prefix uart_lane_decode {*} {*uart|lane_select*}
 report_rev23_path $prefix uart_header_data {*} {*uart|h*}
 report_rev23_path $prefix snapshot_release {*uart|sent} {*ana|state*}
 report_rev23_path $prefix uart_baud_terminal {*} {*uart|baud_last*}
 report_rev23_path $prefix uart_baud_fanout {*uart|baud_last*} {*uart|*}
 foreach tw {t2 t5 t8 t11 t14 t17} {
  report_rev23_path $prefix ${tw}_axis_a_prefix {*} "*fft|*${tw}|a_prefix2*"
  report_rev23_path $prefix ${tw}_axis_b_prefix {*} "*fft|*${tw}|b_prefix2*"
  report_rev23_path $prefix ${tw}_axis_real {*} "*fft|*${tw}|er3*"
  report_rev23_path $prefix ${tw}_axis_imag {*} "*fft|*${tw}|ei3*"
 }
 foreach peak {time_peak frequency_peak} {
  foreach group {gt0_q eq0_q gt1_q eq1_q gtm_q eqm_q} {
   report_rev23_path $prefix ${peak}_${group} {*} "*ana|*${peak}|${group}*"
  }
 }
 # Rev15: check both preparation and commit, as well as terminal flags.
 report_rev23_path $prefix address_lookahead {*} {*ana|addr_inc*}
 report_rev23_path $prefix address_lookback {*} {*ana|addr_dec*}
 report_rev23_path $prefix peak_right {*} {*ana|peak_right*}
 report_rev23_path $prefix peak_left {*} {*ana|peak_left*}
 report_rev23_path $prefix address_command {*} {*ana|addr_command*}
 report_rev23_path $prefix address_commit {*} {*ana|addr_commit*}
 report_rev23_path $prefix address_output {*} {*ana|addr[*]}
 report_rev23_path $prefix scan_terminal {*} {*ana|scan_last*}
 report_rev23_path $prefix bandwidth_terminal {*} {*ana|bw_last*}
 report_rev23_path $prefix peak_zero {*} {*ana|peak_zero*}
 # Rev14 registers merge control; keep reports for both sides of the register.
 report_rev23_path $prefix merge_control {*} {*ana|merge_peaks*}
 report_rev23_path $prefix merge_fanout {*ana|merge_peaks*} {*ana|*peak|*}
 # Track coefficient sign reconstruction separately from other FFT paths.
 foreach tw {t2 t5 t8 t11 t14 t17} {
  report_rev23_path $prefix ${tw}_cos_sign {*} "*fft|*${tw}|c3*"
  report_rev23_path $prefix ${tw}_sin_sign {*} "*fft|*${tw}|s3*"
 }
 # Lane feedback and pipeline inputs remain normal single-cycle checks.
 report_rev23_path $prefix peak_pipeline {*} {*ana|*frequency_peak|*}
 report_rev23_path $prefix peak_feedback {*ana|*frequency_peak|*} {*ana|*frequency_peak|*}
 report_rev23_path $prefix time_peak_pipeline {*} {*ana|*time_peak|*}
 report_rev23_path $prefix time_peak_feedback {*ana|*time_peak|*} {*ana|*time_peak|*}
 report_rev23_path $prefix time_write_control {*} {*ana|time_we}
 report_rev23_path $prefix uart_time_read {*ana|*times*} {*uart|time_word[*]}
 # Rev18: both sides of the WAIT comparisons and segmented power sums.
 foreach name {bw_hi_gt bw_hi_eq bw_lo_ge scan_hi_gt scan_hi_eq scan_lo_gt} {
  report_rev23_path $prefix ${name}_input {*} "*ana|${name}*"
  report_rev23_path $prefix ${name}_output "*ana|${name}*" {*ana|*}
 }
 # Revision19: report all square input/internal/output paths and BOTH sides
 # of the registered sums. Full hierarchy patterns tolerate DSP packing.
 foreach square {time_real_square time_imag_square fft_real_square fft_imag_square} {
  report_rev23_path $prefix ${square}_input {*} "*ana|*${square}|*"
  report_rev23_path $prefix ${square}_output "*ana|*${square}|*" {*ana|*}
 }
 foreach adder {time_sum frequency_sum} {
  report_rev23_path $prefix ${adder}_partial {*} "*ana|*${adder}|add*"
  report_rev23_path $prefix ${adder}_carry {*} "*ana|*${adder}|*q*"
  report_rev23_path $prefix ${adder}_output "*ana|*${adder}|*" {*ana|*}
 }
 foreach tw {t2 t5 t8 t11 t14 t17} {
  report_rev23_path $prefix ${tw}_cos_prefix {*} "*fft|*${tw}|cos_prefix2d*"
  report_rev23_path $prefix ${tw}_sin_prefix {*} "*fft|*${tw}|sin_prefix2d*"
 }
 report_rev23_path $prefix encoder_zero {*} {*ana|*power_encoder|zero1*}
 report_rev23_path $prefix encoder_one {*} {*ana|*power_encoder|one1*}
 # Revision20: do not judge only the old failing endpoints; verify both
 # the wider 8/8/9-bit group inputs and their shorter reduction outputs.
 foreach peak {time_peak frequency_peak} {
  foreach group {gt0_q eq0_q gt1_q eq1_q} {
   report_rev23_path $prefix ${peak}_${group}_fanout "*ana|*${peak}|${group}*" "*ana|*${peak}|*"
  }
 }
 report_rev23_path $prefix timer_carry_input {*} {*ana|timer_carry*}
 report_rev23_path $prefix timer_carry_output {*ana|timer_carry*} {*ana|timer*}
 report_rev23_path $prefix timer_feedback {*ana|timer*} {*ana|timer*}
 report_rev23_path $prefix latency_output {*} {*ana|latency_cycles*}
 report_rev23_path $prefix skip_partial {*} {*ana|skip_diff*}
 report_rev23_path $prefix skip_equal {*} {*ana|skip_eq*}
 report_rev23_path $prefix skip_pending {*} {*ana|skip_pending*}
 report_rev23_path $prefix skip_output {*} {*ana|frames_skipped*}
 report_rev23_path $prefix next_frame {*} {*ana|next_expected_frame*}
 # Rev21: inspect BOTH sides of every new D=8 pipeline boundary.
 # The small feedback store stays in logic; no M9K allocation is added.
 foreach regname {rd_low1 rd_high1 rd2 sum3 diff3 input3 delayed3 bank1 addr3 phase3} {
  report_rev23_path $prefix b13_${regname}_input {*} "*fft|*b13|*split_logic_delay.${regname}*"
  report_rev23_path $prefix b13_${regname}_output "*fft|*b13|*split_logic_delay.${regname}*" "*fft|*b13|*"
 }
 report_rev23_path $prefix b13_feedback_write {*} {*fft|*b13|*split_logic_delay.mem*}
 report_rev23_path $prefix b13_counter_fanout {*fft|*b13|count*} {*fft|*b13|*}
 # Keep the untouched shorter loops visible if placement moves the bottleneck.
 foreach bf {b15 b16 last} {
  report_rev23_path $prefix ${bf}_feedback "*fft|*${bf}|*" "*fft|*${bf}|*"
 }
 # Rev23: both high real candidates, direct low borrow and imaginary carry.
 # Inspect all six instances so a moved bottleneck is not hidden by t8.
 foreach tw {t2 t5 t8 t11 t14 t17} {
  foreach regname {real_hi6 real_hi_borrow6 real_borrow6 imag_hi6 imag_carry6} {
   report_rev23_path $prefix ${tw}_${regname}_input {*} "*fft|*${tw}|${regname}*"
   report_rev23_path $prefix ${tw}_${regname}_output "*fft|*${tw}|${regname}*" "*fft|*${tw}|*"
  }
  report_rev23_path $prefix ${tw}_real_output {*} "*fft|*${tw}|yr*"
  report_rev23_path $prefix ${tw}_imag_output {*} "*fft|*${tw}|yi*"
 }
 # Rev22 also exposed b16 feedback and source controls. Include all launch
 # registers: synthesis merged a source counter bit into top-level heartbeat.
 report_rev23_path $prefix b16_feedback_inputs {*} {*fft|*b16|*ram_delay.mem*}
 report_rev23_path $prefix source_phase_inputs {*} {*src|phase*}
 report_rev23_path $prefix source_frame_inputs {*} {*src|fid*}
 rev20_gate_corner $op
 incr corner_id
}
if {$corner_id==0} {error "No timing corners analyzed"}
close $corner_index
close $timing_index
close $rev23_index
rev20_gate_finish
delete_timing_netlist
project_close
puts "Revision 23 reports complete: inspect ALL corners, targeted paths/node counts, exceptions, and Fitter resources."
