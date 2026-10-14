"""Compile isolated placement seeds; accept only a fresh all-corner timing pass.

Requires the actual Quartus II tools on PATH. Never changes the 200 MHz target.
The selected .sof remains with its exact sources, QSF, database and reports.
"""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import shutil
import subprocess
import sys

P = Path(__file__).resolve().parents[1]

def run_logged(command, cwd, logfile):
    with logfile.open('w', encoding='utf-8') as log:
        result = subprocess.run(command, cwd=cwd, stdout=log, stderr=subprocess.STDOUT)
    return result.returncode

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--seeds', default='1,2,3,4,5,6,7,8')
    args = parser.parse_args()
    seeds = list(dict.fromkeys(int(s) for s in args.seeds.split(',')))
    if not seeds or any(s < 1 or s > 99999 for s in seeds):
        parser.error('seeds must be integers in 1..99999')
    quartus_sh, quartus_sta = shutil.which('quartus_sh'), shutil.which('quartus_sta')
    if not quartus_sh or not quartus_sta:
        raise SystemExit('Quartus tools not found. Add quartus/bin64 (or bin) to PATH. No timing pass has been established.')
    stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    runs = P / 'timing_runs' / stamp
    runs.mkdir(parents=True)
    source_names = ['spectrum_streaming.qpf', 'spectrum_streaming.qsf', 'spectrum_streaming.sdc', 'README_zh.md']
    for folder in ('rtl', 'data', 'scripts', 'host', 'docs'):
        source_names.extend(str(f.relative_to(P)) for f in sorted((P/folder).rglob('*'))
                            if f.is_file() and '__pycache__' not in f.parts)
    source_names.extend(str(f.relative_to(P)) for f in sorted((P/'sim').rglob('*'))
                        if f.is_file() and f.suffix in ('.v', '.py', '.do'))
    results = []
    for seed in seeds:
        work = runs / f'seed_{seed:05d}'
        work.mkdir()
        for name in source_names:
            dest = work/name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(P/name, dest)
        qsf = work/'spectrum_streaming.qsf'
        text = qsf.read_text(encoding='utf-8')
        text = re.sub(r'^set_global_assignment -name SEED\s+\d+\s*$', '', text, flags=re.M)
        qsf.write_text(text + f'\nset_global_assignment -name SEED {seed}\n', encoding='utf-8')
        hashes = {name: hashlib.sha256((work/name).read_bytes()).hexdigest() for name in source_names}
        (work/'build_source_sha256.json').write_text(json.dumps(hashes, indent=2), encoding='utf-8')
        print(f'Seed {seed}: compiling at 200 MHz; log: {work / "compile.log"}', flush=True)
        compile_rc = run_logged([quartus_sh, '--flow', 'compile', 'spectrum_streaming'], work, work/'compile.log')
        row = dict(seed=seed, directory=str(work.relative_to(P)), compile_exit=compile_rc, timing_exit=None, passed=False)
        if compile_rc == 0:
            row['timing_exit'] = run_logged([quartus_sta, '-t', 'scripts/report_timing.tcl'], work, work/'timequest.log')
            marker = work/'output_files/timing_gate_pass.txt'
            sof = work/'output_files/spectrum_streaming.sof'
            row['passed'] = row['timing_exit'] == 0 and marker.is_file() and sof.is_file()
        results.append(row)
        (runs/'results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
        if row['passed']:
            print(f'PASS measured timing checks, seed {seed}.')
            print(f'Program this build: {sof}')
            print('Review constraint_checks.txt, unconstrained.txt, exceptions.txt and Fitter warnings in this build.')
            return 0
        print(f'Seed {seed}: no timing pass. Reports retained in {work}', flush=True)
    print(f'FAIL: none of {len(seeds)} seeds passed. Send {runs}/results.json and the failing reports for the next RTL iteration.')
    return 1

if __name__ == '__main__':
    sys.exit(main())
