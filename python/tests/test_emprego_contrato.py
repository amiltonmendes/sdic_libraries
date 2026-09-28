"""Contrato do esquema de emprego (Python): `contrato/emprego_amostras.json`, o mesmo lido pelo R.

Passa a linha da API pelo caminho real (sessão HTTP mockada -> cliente -> função de módulo).
"""
from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock

import pandas as pd
import pytest
import requests

import sdic_libraries.dados.emprego as emprego

CASOS = json.loads((Path(__file__).resolve().parents[2] / "contrato" / "emprego_amostras.json").read_text("utf-8"))["casos"]
TIPOS = {"int": pd.api.types.is_integer_dtype, "num": pd.api.types.is_numeric_dtype, "str": pd.api.types.is_string_dtype}


@pytest.mark.parametrize("caso", CASOS, ids=lambda c: c["funcao"])
def test_esquema_padronizado(caso, monkeypatch):
    resposta = MagicMock(status_code=200)
    resposta.json.return_value = {"count": 1, "items": [caso["linha"]]}
    resposta.raise_for_status.return_value = None
    monkeypatch.setattr(requests.Session, "get", lambda self, *a, **k: resposta)

    df = getattr(emprego, caso["funcao"])(**caso["kwargs"])

    esperado = caso["colunas"]
    assert set(df.columns) == set(esperado)
    for col, tipo in esperado.items():
        if df[col].notna().any():
            assert TIPOS[tipo](df[col]), f"{col}: esperado {tipo}, veio {df[col].dtype}"


def test_faixa_de_anos_vale_mesmo_se_a_api_implantada_ignorar_o_filtro(monkeypatch):
    linhas = [{"ano": a, "divisao_cnae_cod": "10", "estoque_trabalhadores": 1} for a in (2023, 2024, 2025)]
    resposta = MagicMock(status_code=200)
    resposta.json.return_value = {"count": 3, "items": linhas}  # API antiga: devolve tudo
    resposta.raise_for_status.return_value = None
    monkeypatch.setattr(requests.Session, "get", lambda self, *a, **k: resposta)

    df = emprego.get_estoque_emprego_nacional(nivel_cnae=2, agregado=True, ano_minimo=2024, ano_maximo=2024)
    assert df["ano"].tolist() == [2024]
    assert emprego.get_estoque_emprego_nacional(nivel_cnae=2, agregado=True, ano_minimo=2024)["ano"].tolist() == [2024, 2025]
    assert len(emprego.get_estoque_emprego_nacional(nivel_cnae=2, agregado=True)) == 3
