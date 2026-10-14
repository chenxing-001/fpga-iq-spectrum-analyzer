# Revision 20: measured timing checks, not a substitute for a fitted netlist.
# No clock period, timing exception, or multicycle constraint is changed here.
proc rev20_number {value label} {
 if {![string is double -strict $value] ||
     [regexp -nocase {nan|inf} $value]} {error "$label is not a finite number: $value"}
 return $value
}
proc rev20_gate_start {} {
 global rev20_gate_file rev20_failed rev20_fast rev20_slow rev20_corners
 file delete -force output_files/timing_gate_pass.txt
 set rev20_failed 0
 set rev20_fast 0
 set rev20_slow 0
 set rev20_corners 0
 set rev20_gate_file [open output_files/timing_gate.tsv w]
 puts $rev20_gate_file "corner\tcheck\tpaths\tworst_slack_ns"
 # A nonempty real 200 MHz PLL clock is mandatory. A 100/50 MHz fallback
 # or missing PLL constraint must never generate a successful result.
 set core_clocks 0
 set cf [open output_files/clock_periods.tsv w]
 puts $cf "clock\tperiod_ns"
 foreach_in_collection c [get_clocks *] {
  set name [get_clock_info -name $c]
  set period [rev20_number [get_clock_info -period $c] $name]
  puts $cf "$name\t$period"
  if {[string match {*pll*} $name] && abs($period-5.0)<0.000001} {incr core_clocks}
 }
 close $cf
 if {$core_clocks==0} {error "No 5.000 ns PLL clock found; 200 MHz was not checked"}
}
proc rev20_gate_corner {op} {
 global rev20_gate_file rev20_failed rev20_fast rev20_slow rev20_corners
 set name [get_operating_conditions_info -display_name $op]
 if {[regexp -nocase {fast} $name]} {incr rev20_fast}
 if {[regexp -nocase {slow} $name]} {incr rev20_slow}
 foreach kind {setup hold recovery removal} {
  set paths [get_timing_paths -$kind -npaths 1]
  set count [get_collection_size $paths]
  if {$count==0} {
   puts $rev20_gate_file "$name\t$kind\t0\tNA"
   if {$kind eq "setup" || $kind eq "hold"} {set rev20_failed 1}
  } else {
   foreach_in_collection p $paths {
    set slack [rev20_number [get_path_info -slack $p] "$name $kind"]
    puts $rev20_gate_file "$name\t$kind\t$count\t$slack"
    if {$slack<0.0} {set rev20_failed 1}
   }
  }
 }
 # This API returns a Tcl list of rows, not a TimeQuest collection.
 set pulse [get_min_pulse_width -nworst 1]
 if {[llength $pulse]==0} {
  puts $rev20_gate_file "$name\tpulse_width\t0\tNA"
  set rev20_failed 1
 } else {
  set slack [rev20_number [lindex [lindex $pulse 0] 0] "$name pulse width"]
  puts $rev20_gate_file "$name\tpulse_width\t1\t$slack"
  if {$slack<0.0} {set rev20_failed 1}
 }
 flush $rev20_gate_file
 incr rev20_corners
}
proc rev20_gate_finish {} {
 global rev20_gate_file rev20_failed rev20_fast rev20_slow rev20_corners
 close $rev20_gate_file
 if {$rev20_corners==0 || $rev20_fast==0 || $rev20_slow==0} {
  error "Incomplete corner coverage: fast=$rev20_fast slow=$rev20_slow"
 }
 if {$rev20_failed} {error "200 MHz timing checks FAILED; see output_files/timing_gate.tsv"}
 set f [open output_files/timing_gate_pass.txt w]
 puts $f "PASS: 5.000 ns PLL clock; all $rev20_corners available corners checked."
 puts $f "Setup, hold, recovery/removal where present, and pulse width are nonnegative."
 puts $f "Review constraint_checks.txt, unconstrained.txt, exceptions.txt and Fitter warnings."
 close $f
 puts "PASS revision20 measured 200 MHz timing checks"
}
