"""Bit-exact pipeline checks against frozen rev9 RTL; not vendor IP simulation."""
from pathlib import Path
import os, subprocess
P=Path(__file__).resolve().parents[1]
os.chdir(P)
def test(name, sources, params=(), suffix=''):
    out=f'sim/{name}{suffix}.vvp'
    subprocess.run(['iverilog','-g2012','-Wall','-s',name,*params,'-o',out,
                    *sources,f'sim/{name}.v'],check=True)
    subprocess.run(['vvp',out],check=True)
for aw in range(13):
    for rotate in (0,1):
        test('tb_butterfly_pipeline', ['rtl/fft_delay_ram.v','rtl/sdf_butterfly.v',
             'sim/reference/sdf_butterfly_rev9.v'],
             [f'-Ptb_butterfly_pipeline.AW={aw}',f'-Ptb_butterfly_pipeline.ROTATE={rotate}'],f'_{aw}_{rotate}')
test('tb_iq_pipeline',['rtl/iq_source.v','sim/reference/iq_source_rev9.v'])
