"""catalogo.py e catalogo.R têm que descrever as mesmas funções da mesma forma.

Reusa o gerador (`scripts/gerar_catalogo_md.py`) em vez de reimplementar a checagem —
ele já falha com uma mensagem útil quando diverge. Pula se `Rscript` não estiver
disponível (ambiente sem R instalado).
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

pytestmark = pytest.mark.skipif(shutil.which("Rscript") is None, reason="Rscript não disponível")


def test_catalogo_python_e_r_em_paridade():
    import gerar_catalogo_md as gerador

    gerador.conferir_paridade(gerador.catalogo_python(), gerador.catalogo_r())
