"""Seções publicadas. Arquivos reais em contrato/publicados_amostras.json, o mesmo dos testes em R."""
from __future__ import annotations

import pytest

import sdic_libraries as s
from sdic_libraries import NaoPublicado

from conftest import amostras

C = amostras("publicados")
E = C["esperado"]


@pytest.fixture(autouse=True)
def origem(origem_falsa):
    return origem_falsa(C["arquivos"])


@pytest.mark.parametrize("funcao", ["get_kpis_publicados", "get_series_publicadas", "get_ranking_publicado",
                                    "get_detalhamento_publicado", "get_destaques_publicados", "get_atualizacao_publicada"])
def test_colunas_e_linhas_do_contrato(funcao):
    df = getattr(s, funcao)(**E[funcao]["args"])
    assert list(df.columns) == E[funcao]["colunas"]
    assert len(df) == E[funcao]["linhas"]


def test_kpis_capa_primeiro_com_fonte_e_referencia():
    df = s.get_kpis_publicados(**E["get_kpis_publicados"]["args"])
    primeira = E["get_kpis_publicados"]["primeira"]
    assert {k: df.iloc[0][k] for k in primeira} == primeira
    assert df["capa"].sum() == 1 and df["uf"].eq("SP").all() and df["secao"].eq("emprego").all()
    assert str(df["valor"].dtype) == "float64" or str(df["valor"].dtype).startswith("int")


def test_destaques_trocam_os_marcadores_pelos_valores():
    textos = " ".join(s.get_destaques_publicados(**E["get_destaques_publicados"]["args"])["texto"])
    assert "{{" not in textos


def test_ranking_numera_na_ordem_publicada():
    df = s.get_ranking_publicado(**E["get_ranking_publicado"]["args"])
    assert df.groupby("lista")["posicao"].first().eq(1).all()


def test_brasil_e_sinonimos():
    for uf in ("BRASIL", "br", None):
        assert len(s.get_kpis_publicados(uf, "pib_nacional", ambiente="homologacao")) == E["brasil"]["linhas_kpis"]
    with pytest.raises(ValueError, match="só existe para o Brasil"):
        s.get_secao_publicada("SP", "pib_nacional", ambiente="homologacao")


def test_ambiente_vem_da_variavel_quando_nao_informado(monkeypatch, origem):
    monkeypatch.setenv("SDIC_AMBIENTE", "homologacao")
    s.get_kpis_publicados("SP", "emprego")
    assert "/homologacao/SP/emprego.json" in origem[-1][0]


def test_producao_vazia_da_erro_que_diz_o_que_fazer():
    with pytest.raises(NaoPublicado, match="não está publicada em 'producao'.*homologacao"):
        s.get_kpis_publicados("SP", "emprego")


def test_troca_de_local_e_transparente(monkeypatch, origem):
    monkeypatch.setenv("SDIC_DADOS_URL", "https://dados.exemplo.gov.br/novo-bucket/")
    df = s.get_kpis_publicados("SP", "emprego", ambiente="homologacao")
    assert len(df) == E["get_kpis_publicados"]["linhas"]
    assert origem[-1][0] == "https://dados.exemplo.gov.br/novo-bucket/homologacao/SP/emprego.json"


def test_entradas_invalidas():
    with pytest.raises(ValueError, match="Seção desconhecida"):
        s.get_secao_publicada("SP", "pib")
    with pytest.raises(ValueError, match="UF inválida"):
        s.get_secao_publicada("XX", "emprego")


def test_contrato_de_versao_maior_e_recusado(origem_falsa):
    origem_falsa({"homologacao/SP/emprego.json": {"schema_version": "2.0"}})
    with pytest.raises(ValueError, match="contrato 2.0"):
        s.get_secao_publicada("SP", "emprego", ambiente="homologacao")


def test_listar_secoes():
    df = s.listar_secoes_publicadas()
    assert {"emprego", "pib_estadual", "comercio", "comercio_ue", "producao_industrial", "pib_nacional"} == set(df["secao"])
