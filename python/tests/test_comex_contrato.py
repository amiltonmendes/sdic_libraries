"""Contrato do esquema Comex (Python): `contrato/comex_amostras.json`, o mesmo lido pelo R."""
from __future__ import annotations

import inspect
import json
from pathlib import Path

import pandas as pd
import pytest

import sdic_libraries.dados.comex as comex
from sdic_libraries.dados.comex.api import Comex, _para_df

CASOS = json.loads((Path(__file__).resolve().parents[2] / "contrato" / "comex_amostras.json").read_text("utf-8"))["casos"]
TIPOS = {"int": pd.api.types.is_integer_dtype, "num": pd.api.types.is_numeric_dtype, "str": pd.api.types.is_string_dtype}


@pytest.mark.parametrize("caso", CASOS, ids=lambda c: c["metodo"] + ("-api_nova" if c.get("api_nova") else ""))
def test_esquema_padronizado(caso):
    df = _para_df([caso["linha"]], mapa=caso["mapa"])
    esperado = caso["colunas"]
    assert set(df.columns) == set(esperado)
    for col, tipo in esperado.items():
        if df[col].notna().any():
            assert TIPOS[tipo](df[col]), f"{col}: esperado {tipo}, veio {df[col].dtype}"
    for col, valor in caso["valores"].items():
        assert df[col].iloc[0] == valor


@pytest.mark.parametrize("caso", CASOS, ids=lambda c: c["metodo"] + ("-api_nova" if c.get("api_nova") else ""))
def test_funcao_solta_usa_metodo_da_classe(caso, monkeypatch):
    monkeypatch.setattr(Comex, caso["metodo"], lambda self, **kw: [caso["linha"]])
    funcao = getattr(comex, caso["metodo"])
    assert isinstance(funcao(), pd.DataFrame)
    assert "self" not in inspect.signature(funcao).parameters


def test_todo_metodo_get_tem_funcao_solta():
    metodos = {n for n, _ in inspect.getmembers(Comex, inspect.isfunction) if n.startswith("get_")}
    assert metodos <= set(dir(comex))


def test_resposta_vazia_devolve_dataframe_vazio():
    assert _para_df([]).empty


def test_filtro_por_secao_aceita_nome_letra_e_api_nova_ou_antiga():
    nova = [{"NCM": "01011010", "SecaoISIC": "Agropecuária", "CodigoSecaoISIC": "A", "NomeSecaoISIC": "Agropecuária"}]
    antiga = [{"NCM": 1011010, "SecaoISIC": "A", "NomeSecaoISIC": "Agropecuária"}]
    for mapa, ncm in ((nova, "01011010"), (antiga, 1011010)):
        cliente = Comex(api_key=None)
        cliente._ncm_isic_mapa_cache = mapa
        assert cliente._ncms_da_secao("A") == cliente._ncms_da_secao("Agropecuária") == {ncm}
