"""listar_bases(): toda função catalogada precisa existir de verdade (senão o catálogo mente)."""
from __future__ import annotations

import sdic_libraries.dados.comex as comex
import sdic_libraries.dados.emprego as emprego
import sdic_libraries.utils as utils
from sdic_libraries import listar_bases

_MODULOS = {"emprego": emprego, "comex": comex, "utilitarios": utils}


def test_nao_vazio_e_colunas_esperadas():
    df = listar_bases()
    assert len(df) > 0
    assert list(df.columns) == ["tema", "subtema", "nivel", "funcao", "descricao", "exemplo"]


def test_toda_funcao_catalogada_existe_e_e_chamavel():
    df = listar_bases()
    for _, linha in df.iterrows():
        modulo = _MODULOS[linha["tema"]]
        assert hasattr(modulo, linha["funcao"]), f"{linha['funcao']} catalogada em {linha['tema']} mas não existe"
        assert callable(getattr(modulo, linha["funcao"]))


def test_filtro_por_tema_e_subtema():
    assert set(listar_bases(tema="comex")["tema"]) == {"comex"}
    assert len(listar_bases(tema="comex")) < len(listar_bases())
    assert set(listar_bases(subtema="saldo_caged")["subtema"]) == {"saldo_caged"}
    assert len(listar_bases(tema="inexistente")) == 0


def test_sem_linha_duplicada():
    df = listar_bases()
    assert not df.duplicated(subset=["tema", "funcao"]).any()
