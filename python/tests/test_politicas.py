"""Políticas do gaia_nib. Arquivos reais (recortados) em contrato/politicas_amostras.json, o mesmo dos testes em R."""
from __future__ import annotations

import pytest

import sdic_libraries as s
from sdic_libraries import NaoPublicado

from conftest import amostras

C = amostras("politicas")
E = C["esperado"]


@pytest.fixture(autouse=True)
def origem(origem_falsa):
    return origem_falsa(C["arquivos"])


def test_listar_politicas_na_ordem_publicada_com_permitida():
    e = E["listar_politicas"]
    df = s.listar_politicas(**e["args"])
    assert list(df.columns[:len(e["colunas_iniciais"])]) == e["colunas_iniciais"]
    assert list(df["id"]) == e["ids"]  # ordem do catálogo, nunca reordenada
    assert list(df.loc[df["permitida"], "id"]) == e["permitidas"]


def test_get_politica_uma_linha_por_indicador():
    e = E["get_politica"]
    df = s.get_politica(**e["args"])
    assert list(df.columns) == e["colunas"] and len(df) == e["linhas"]
    assert df.iloc[0]["papel"] == "capa" and df.iloc[0]["valor_exibido"] == e["capa_valor_exibido"]
    assert df["uf"].eq("SP").all()


def test_get_politica_nacional():
    e = E["get_politica_nacional"]
    df = s.get_politica(**e["args"])
    assert list(df["papel"]) == e["papeis"] and df["uf"].eq("BRASIL").all()


def test_politica_sem_dado_para_a_unidade_devolve_vazio_com_colunas():
    df = s.get_politica(**E["get_politica_ausente"]["args"])
    assert df.empty and list(df.columns) == E["get_politica"]["colunas"]
    assert s.get_politica_publicada(**E["get_politica_ausente"]["args"]) is None


def test_get_politicas_estado():
    e = E["get_politicas_estado"]
    df = s.get_politicas_estado(**e["args"])
    assert len(df) == e["linhas"] and list(df["policy_id"].unique()) == e["policy_ids"]


def test_get_resumo_politicas():
    e = E["get_resumo_politicas"]
    df = s.get_resumo_politicas(**e["args"])
    assert list(df.columns) == e["colunas"] and len(df) == 1
    assert df.iloc[0]["n_politicas"] == e["n_politicas"] and df.iloc[0]["recursos_exibido"] == e["recursos_exibido"]
    assert s.get_resumo_politicas("AC", ambiente="homologacao").empty


def test_municipios_e_manifesto():
    m = s.get_municipios_elegiveis(**E["get_municipios_elegiveis"]["args"])
    assert list(m.columns) == E["get_municipios_elegiveis"]["colunas"] and len(m) == E["get_municipios_elegiveis"]["linhas"]
    assert m["ibge"].str.len().eq(7).all()
    e = E["get_manifesto_politicas"]
    man = s.get_manifesto_politicas(**e["args"])
    assert list(man.columns) == e["colunas"] and len(man) == e["linhas"]
    assert man.loc[man["campo"] == "rotulo_fonte", "valor"].item() == e["rotulo_fonte"]


def test_producao_sem_politicas_da_erro_que_diz_o_que_fazer():
    with pytest.raises(NaoPublicado, match="não estão publicadas em 'producao'"):
        s.listar_politicas()
