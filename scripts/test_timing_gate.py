"""Test timing-gate failure handling with synthetic Tcl API fixtures.
This is NOT Quartus execution and is NOT evidence of FPGA timing closure.
"""
from pathlib import Path
import os
import tempfile
import tkinter

P = Path(__file__).resolve().parents[1]
print('SYNTHETIC TESTS ONLY: fabricated slack values, no Quartus run.', flush=True)
mock = r'''
rename puts real_puts
proc puts {args} {
 if {[llength $args]==1} {real_puts [format {SYNTHETIC FIXTURE ONLY: %s} [lindex $args 0]]} else {uplevel 1 [linsert $args 0 real_puts]}
}

proc foreach_in_collection {var values body} {uplevel 1 [list foreach $var $values $body]}
proc get_clocks {args} {return {core}}
proc get_clock_info {option object} {
 if {$option eq "-name"} {return {u_pll|pll|clk[0]}}
 return $::period
}
proc get_operating_conditions_info {option object} {return $object}
proc get_timing_paths {args} {
 set kind [string trimleft [lindex $args 0] -]
 if {[dict get $::slacks $kind] eq "NONE"} {return {}}
 return [list $kind]
}
proc get_collection_size {values} {return [llength $values]}
proc get_path_info {option object} {return [dict get $::slacks $object]}
proc get_min_pulse_width {args} {
 set slack [dict get $::slacks pulse_width]
 if {$slack eq "NONE"} {return {}}
 return [list [list $slack 2.5 1.2 High clk rise target]]
}
'''
cases = [('nonnegative', {}, 5, True, True)]
for kind in ('setup', 'hold', 'recovery', 'removal', 'pulse_width'):
    cases.append((f'negative_{kind}', {kind: '-0.001'}, 5, True, False))
for kind in ('setup', 'hold', 'pulse_width'):
    cases.append((f'missing_{kind}', {kind: 'NONE'}, 5, True, False))
cases += [('wrong_clock', {}, 10, True, False),
          ('missing_fast_corner', {}, 5, False, False),
          ('invalid_number', {'setup': 'NaN'}, 5, True, False),
          ('no_async_paths', {'recovery': 'NONE', 'removal': 'NONE'}, 5, True, True)]
original = Path.cwd()
try:
    for name, overrides, period, fast, expect_pass in cases:
        with tempfile.TemporaryDirectory(dir=P/'sim') as folder:
            os.chdir(folder)
            Path('output_files').mkdir()
            marker = Path('output_files/timing_gate_pass.txt')
            marker.write_text('STALE PASS MUST NOT SURVIVE')
            t = tkinter.Tcl()
            t.eval(mock)
            t.call('source', str(P/'scripts/timing_gate.tcl'))
            t.setvar('period', period)
            values = dict.fromkeys(('setup', 'hold', 'recovery', 'removal', 'pulse_width'), '0.2')
            values.update(overrides)
            t.setvar('slacks', t.call('dict', 'create', *sum(([k, v] for k, v in values.items()), [])))
            try:
                t.call('rev20_gate_start')
                t.call('rev20_gate_corner', 'Slow 1200mV 85C Model')
                if fast:
                    t.call('rev20_gate_corner', 'Fast 1200mV 0C Model')
                t.call('rev20_gate_finish')
                passed = True
            except tkinter.TclError:
                passed = False
                t.eval('if {[info exists rev20_gate_file]} {catch {close $rev20_gate_file}}')
            assert passed == expect_pass, (name, passed)
            assert marker.exists() == expect_pass, ('stale or missing marker', name)
            assert t.call('info', 'complete', (P/'scripts/report_timing.tcl').read_text())
            print('PASS synthetic timing-gate case:', name, flush=True)
            os.chdir(original)
finally:
    os.chdir(original)
print('PASS 13 synthetic gate cases; actual FPGA timing remains unmeasured here.')
