"""Testes offline: wrappers de estoque agrupado e coerência README x pacote."""
from __future__ import annotations

import ast
import re
from pathlib import Path

import pytest

import sdic_libraries.dados.emprego as emprego
from sdic_libraries.dados.emprego import api as api_mod

README = Path(__file__).resolve().parents[2] / "README.md"


def _imports_do_readme():
    """(modulo, nome) de cada 'from sdic_libraries... import ...' em blocos ```python."""
    pares = []
    for bloco in re.findall(r"```python\n(.*?)```", README.read_text(encoding="utf-8"), re.S):
        try:
            arvore = ast.parse(bloco)
        except SyntaxError:
            continue  # trecho ilustrativo incompleto
        for no in ast.walk(arvore):
            if isinstance(no, ast.ImportFrom) and (no.module or "").startswith("sdic_libraries"):
                pares += [(no.module, a.name) for a in no.names]
    return pares


@pytest.mark.parametrize("modulo,nome", sorted(set(_imports_do_readme())))
def test_import_documentado_no_readme_existe(modulo, nome):
    mod = __import__(modulo, fromlist=[nome])
    assert hasattr(mod, nome), f"README importa {nome} de {modulo}, mas não existe"


@pytest.fixture
def captura(monkeypatch):
    chamadas = {}

    def falso_post(self, endpoint, body, params):
        chamadas.update(endpoint=endpoint, body=body, params=params)
        return [{"ano": 2023, "nome_grupo": "TI", "estoque_trabalhadores": 10,
                 "grupo_cnae_cod": None, "sigla_uf": "SP"}]

    monkeypatch.setattr(api_mod.Emprego, "_fetch_all_paginated_post", falso_post)
    return chamadas


def test_estoque_nacional_agrupado_detecta_nivel_e_agrega(captura):
    df = emprego.get_estoque_emprego_nacional_agrupado("TI", ["620", "631"])
    assert captura["endpoint"] == "/get_estoque_emprego_nacional_grupos_cnae"
    assert captura["params"]["nivel_cnae"] == 3 and captura["params"]["agregado"] is True
    assert captura["body"] == [{"nome_grupo": "TI", "codigos_cnae": ["620", "631"]}]
    assert "sigla_uf" not in df.columns and "grupo_cnae_cod" not in df.columns


def test_estoque_estadual_agrupado_mantem_uf(captura):
    df = emprego.get_estoque_emprego_estadual_agrupado("SP", "TI", ["62", "63"])
    assert captura["params"]["ufs"] == "SP" and captura["params"]["nivel_cnae"] == 2
    assert "sigla_uf" in df.columns


def test_estoque_agrupado_rejeita_subclasse():
    with pytest.raises(ValueError):
        emprego.get_estoque_emprego_nacional_agrupado("TI", ["6201501"])
