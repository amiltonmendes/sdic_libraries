"""Séries (/series). As respostas vêm de contrato/series_amostras.json, o mesmo arquivo dos testes em R."""
from __future__ import annotations

import pytest
import requests

from sdic_libraries import (SdicErro, get_dimensao_serie, get_referencia, get_serie, listar_referencias,
                            listar_series)

from conftest import Resposta, amostras

C = amostras("series")


@pytest.fixture
def api(monkeypatch):
    chamadas = []

    def get(self, url, params=None, timeout=None, **_):
        caminho = "/" + url.split("/", 3)[3]
        params = dict(params or {})
        chamadas.append((caminho, params))
        chave = f"{caminho}?pagina={params['pagina']}" if "pagina" in params else caminho
        if chave in C["respostas"]:
            return Resposta(200, C["respostas"][chave], url)
        return Resposta(404, {"detail": f"Série desconhecida: {caminho}"}, url)
    monkeypatch.setattr(requests.Session, "get", get)
    return chamadas


def test_listar_series(api):
    df = listar_series()
    assert list(df.columns) == C["esperado"]["listar_series"]["colunas"]
    assert list(df["nome"]) == C["esperado"]["listar_series"]["nomes"]
    assert df.loc[0, "filtros"] == "cod_tabela, cod_variavel, nivel, cod_localidade, cod_categoria"


def test_get_serie_junta_paginas_tipa_e_envia_filtros(api):
    e = C["esperado"]["get_serie"]
    df = get_serie(**e["args"])
    assert list(df.columns) == e["colunas"] and len(df) == e["linhas"]
    assert df["valor"].tolist()[:2] == e["valores"][:2] and df["valor"].isna().tolist() == [False, False, True]
    assert df["cod_localidade"].tolist() == [e["cod_localidade"]] * 3  # texto, não número
    paginas = [p for c, p in api if c == "/series/sidra_producao"]
    assert len(paginas) == e["paginas"]
    assert {k: paginas[0][k] for k in e["query_esperada"]} == e["query_esperada"]


def test_get_serie_lista_de_valores_vira_filtro_separado_por_virgula(api):
    get_serie("sidra_producao", cod_tabela=8888, cod_localidade=["35", "33"])
    assert [p for c, p in api if c == "/series/sidra_producao"][0]["cod_localidade"] == "35,33"


def test_get_serie_com_nomes(api):
    e = C["esperado"]["get_serie_com_nomes"]
    df = get_serie("sidra_producao", cod_tabela=8888, com_nomes=True)
    assert set(e["colunas_extras"]) <= set(df.columns) and len(df) == 3
    assert df["variavel_nome"].iloc[0] == e["variavel_nome"] and df["localidade_nome"].iloc[0] == e["localidade_nome"]


def test_get_serie_vazia_mantem_as_colunas(api, monkeypatch):
    monkeypatch.setitem(C["respostas"], "/series/sidra_producao?pagina=1", {"items": [], "proxima_pagina": None})
    df = get_serie("sidra_producao", cod_tabela=1)
    assert df.empty and list(df.columns) == C["esperado"]["get_serie"]["colunas"]


def test_get_serie_desconhecida(api):
    with pytest.raises(SdicErro, match="listar_series"):
        get_serie("nao_existe")


def test_get_dimensao_serie(api):
    e = C["esperado"]["get_dimensao_serie"]
    df = get_dimensao_serie(**e["args"])
    assert list(df.columns) == e["colunas"] and len(df) == e["linhas"]


def test_referencias(api):
    lista = listar_referencias()
    assert list(lista.columns) == C["esperado"]["listar_referencias"]["colunas"]
    e = C["esperado"]["get_referencia"]
    df = get_referencia(**e["args"])
    assert len(df) == e["linhas"] and df.iloc[0, 0] == e["primeiro_codigo"]  # texto: zero à esquerda preservado
