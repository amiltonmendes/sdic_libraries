"""listar_bases(): toda função catalogada precisa existir de verdade (senão o catálogo mente)."""
from __future__ import annotations

import pytest

import sdic_libraries
from sdic_libraries import descrever, listar_bases


def test_nao_vazio_e_colunas_esperadas():
    df = listar_bases()
    assert len(df) > 0
    assert list(df.columns) == ["tema", "subtema", "nivel", "funcao", "descricao", "exemplo"]


def test_toda_funcao_catalogada_existe_e_e_chamavel():
    df = listar_bases()
    for _, linha in df.iterrows():
        # toda função do catálogo se importa da raiz do pacote
        assert callable(getattr(sdic_libraries, linha["funcao"])), f"{linha['funcao']} catalogada mas não existe"


def test_filtro_por_tema_e_subtema():
    assert set(listar_bases(tema="comex")["tema"]) == {"comex"}
    assert len(listar_bases(tema="comex")) < len(listar_bases())
    assert set(listar_bases(subtema="saldo_caged")["subtema"]) == {"saldo_caged"}
    with pytest.raises(ValueError, match="tema desconhecido"):
        listar_bases(tema="inexistente")


def test_sem_linha_duplicada():
    df = listar_bases()
    assert not df.duplicated(subset=["tema", "funcao"]).any()


def test_descrever_funcao_base_e_nome_desconhecido():
    ficha = descrever("get_kpis_publicados")
    assert list(ficha.columns) == ["campo", "valor"]
    assert "coluna: valor_exibido" in set(ficha["campo"])
    assert "get_kpis_publicados" in set(descrever("secoes_publicadas")["valor"])
    with pytest.raises(ValueError, match="não está no catálogo"):
        descrever("nao_existe")


def test_toda_funcao_publica_nova_esta_no_catalogo():
    catalogadas = set(listar_bases()["funcao"])
    faltam = [f for f in sdic_libraries._NOVAS if f not in catalogadas and f != "listar_bases"]
    assert not faltam, f"exportadas na raiz e fora do catálogo: {faltam}"
