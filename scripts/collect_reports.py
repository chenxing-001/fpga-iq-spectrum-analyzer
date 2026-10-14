"""Collect current-project Quartus reports and source hashes after compilation."""
from pathlib import Path
import hashlib
import json
import zipfile

P = Path(__file__).resolve().parents[1]
files = []
for folder in (P, P / 'output_files'):
    if folder.exists():
        for p in sorted(folder.iterdir()):
            if p.is_file() and (p.suffix == '.tsv' or p.name.endswith(('.map.rpt', '.fit.rpt', '.sta.rpt', '.flow.rpt'))
                               or (p.suffix == '.txt' and (p.name.startswith(('corner_', 'setup', 'hold'))
                                   or p.stem in ('clocks', 'exceptions', 'unconstrained', 'clock_pairs',
                                                 'corners', 'revision23_nodes', 'constraint_checks', 'timing_gate_pass')))):
                files.append(p)
if not files:
    raise SystemExit('No reports found. Compile this revision in Quartus first.')
out = P / 'quartus_reports_rev23.zip'
config = [P / name for name in ('spectrum_streaming.qpf', 'spectrum_streaming.qsf',
          'spectrum_streaming.sdc', 'scripts/report_timing.tcl', 'scripts/timing_gate.tcl', 'docs/REVISION_23.md')]
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    for f in files + config:
        z.write(f, f.relative_to(P))
    sources = sorted([*P.glob('rtl/*.v'), *P.glob('data/*'), *config[:3]])
    z.writestr('source_sha256.json', json.dumps({str(f.relative_to(P)): hashlib.sha256(f.read_bytes()).hexdigest()
                                             for f in sources}, indent=2))
print(out)
