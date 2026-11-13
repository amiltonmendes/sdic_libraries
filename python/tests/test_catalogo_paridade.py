"""Um catálogo só: as cópias dentro dos pacotes têm que ser iguais a contrato/catalogo.json,
e toda função catalogada tem que existir nas duas linguagens (Python: raiz do pacote; R: NAMESPACE)."""
from __future__ import annotations

import json
import re
from pathlib import Path

import sdic_libraries

RAIZ = Path(__file__).resolve().parents[2]
FONTE = RAIZ / "contrato" / "catalogo.json"


def test_copias_do_catalogo_iguais_a_fonte():
    for copia in (RAIZ / "python" / "sdic_libraries" / "catalogo.json", RAIZ / "r" / "inst" / "catalogo.json"):
        assert copia.read_bytes() == FONTE.read_bytes(), f"{copia} difere de contrato/catalogo.json: rode python scripts/documentar.py"


def test_funcoes_do_catalogo_existem_em_python_e_em_r():
    exportadas_r = set(re.findall(r"^export\((\w+)\)", (RAIZ / "r" / "NAMESPACE").read_text(), flags=re.M))
    for f in json.loads(FONTE.read_text(encoding="utf-8"))["funcoes"]:
        assert callable(getattr(sdic_libraries, f["funcao"])), f"{f['funcao']} não existe em Python"
        assert f["funcao"] in exportadas_r, f"{f['funcao']} não é exportada pelo pacote R (r/NAMESPACE)"


def test_toda_base_do_catalogo_tem_origem_valida_e_toda_funcao_aponta_para_base_existente():
    cat = json.loads(FONTE.read_text(encoding="utf-8"))
    for nome, base in cat["bases"].items():
        assert base["origem"] in cat["origens"], nome
    for f in cat["funcoes"]:
        assert f["base"] is None or f["base"] in cat["bases"], f["funcao"]
    for funcao in cat["colunas"]:
        assert funcao in {f["funcao"] for f in cat["funcoes"]}, funcao


def test_tudo_que_e_gerado_do_catalogo_esta_em_dia():
    import subprocess
    import sys
    r = subprocess.run([sys.executable, str(RAIZ / "scripts" / "documentar.py"), "--conferir"], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
