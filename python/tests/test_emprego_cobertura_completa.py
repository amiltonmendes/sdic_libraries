"""Cobertura completa dos métodos da API de emprego (RAIS/CAGED) via sdic_libraries.

Objetivo: garantir que TODO endpoint com a tag "Emprego" na sdic_api (mais
`/data_bases`, tag "Domínio" mas ligado ao bug do RAIS já corrigido) tem pelo
menos um método na biblioteca que o exercita com sucesso contra uma API real.

Bate numa sdic_api real (`EMPLOYMENT_API_BASE_URL`, padrão
http://127.0.0.1:8123) e pula a suíte inteira se ela não estiver acessível —
mesma convenção de `test_emprego_novos_metodos.py`. Inclui explicitamente o
nível municipal do saldo CAGED (`codigos_municipio`), que só passou a
funcionar depois da correção do cast STRING/INT64 em `_aplicar_filtros_base`.
"""
from __future__ import annotations

import os

import pytest

from sdic_libraries.dados.emprego.api import Emprego, EmpregoAPIError

_BASE_URL = os.environ.get("EMPLOYMENT_API_BASE_URL", "http://127.0.0.1:8123")

# São Paulo — usado nos testes de nível estadual/municipal.
_UF = "SP"
_CODIGO_UF = "35"
_CODIGO_MUNICIPIO = 3550308  # município de São Paulo


@pytest.fixture(scope="module")
def api():
    cliente = Emprego(base_url=_BASE_URL)
    try:
        cliente.get_date_bases()
    except EmpregoAPIError as exc:
        pytest.skip(f"sdic_api indisponível em {_BASE_URL}: {exc}")
    yield cliente
    cliente.close()


def _tem_dados(resultado):
    return isinstance(resultado, list) and len(resultado) > 0


class TestEstoqueRaisBasico:
    """6 endpoints: nacional/estadual × básico/lista_cnae/grupos_cnae."""

    def test_nacional(self, api):
        assert _tem_dados(api.get_estoque_emprego_nacional(codigos_cnae=["47"]))

    def test_estadual(self, api):
        assert _tem_dados(api.get_estoque_emprego_estadual(ufs=_UF, codigos_cnae=["47"]))

    def test_nacional_lista_cnae(self, api):
        assert _tem_dados(api.get_estoque_emprego_nacional_lista_cnae(codigos_cnae=["47"]))

    def test_nacional_grupos_cnae(self, api):
        grupos = [{"nome_grupo": "Comercio", "codigos_cnae": ["47"]}]
        assert _tem_dados(api.get_estoque_emprego_nacional_grupos_cnae(grupos_cnae=grupos))

    def test_estadual_lista_cnae(self, api):
        assert _tem_dados(
            api.get_estoque_emprego_estadual_lista_cnae(ufs=_UF, codigos_cnae=["47"])
        )

    def test_estadual_grupos_cnae(self, api):
        grupos = [{"nome_grupo": "Comercio", "codigos_cnae": ["47"]}]
        assert _tem_dados(
            api.get_estoque_emprego_estadual_grupos_cnae(ufs=_UF, grupos_cnae=grupos)
        )


class TestEstoquePorteClasseUfCboRendaPotec:
    """7 endpoints novos: porte×2, classe_cnae×2, uf_cbo, renda_media, potec."""

    def test_porte_nacional(self, api):
        assert _tem_dados(api.get_estoque_emprego_porte_nacional(codigos_cnae=["47"]))

    def test_porte_estadual(self, api):
        assert _tem_dados(api.get_estoque_emprego_porte_estadual(ufs=_UF, codigos_cnae=["47"]))

    def test_classe_cnae_nacional(self, api):
        assert _tem_dados(api.get_estoque_emprego_classe_cnae_nacional(codigos_classe=["4711"]))

    def test_classe_cnae_estadual(self, api):
        assert _tem_dados(
            api.get_estoque_emprego_classe_cnae_estadual(ufs=_UF, codigos_classe=["4711"])
        )

    def test_uf_cbo(self, api):
        assert _tem_dados(api.get_estoque_emprego_uf_cbo(siglas_uf=[_UF], codigos_classe=["4711"]))

    def test_renda_media(self, api):
        assert _tem_dados(api.get_renda_media_emprego(tipos=["Geral"]))

    def test_potec(self, api):
        assert _tem_dados(api.get_potec_emprego(codigos_classe=["7210"]))


class TestSaldoCagedPorNivel:
    """9 endpoints: {nacional,estadual,municipal} x {divisao,grupo,subclasse}.

    O nível municipal é o que estava quebrado (500) até a correção do cast
    de cod_municipio — é o caso mais importante desta suíte.
    """

    def test_nacional_divisao(self, api):
        assert _tem_dados(api.get_saldo_caged_nacional_divisao(codigos_divisao=["47"]))

    def test_nacional_grupo(self, api):
        assert _tem_dados(api.get_saldo_caged_nacional_grupo(codigos_grupo=["471"]))

    def test_nacional_subclasse(self, api):
        assert _tem_dados(api.get_saldo_caged_nacional_subclasse(codigos_subclasse=["4711301"]))

    def test_estadual_divisao(self, api):
        assert _tem_dados(
            api.get_saldo_caged_estadual_divisao(siglas_uf=[_UF], codigos_divisao=["47"])
        )

    def test_estadual_grupo(self, api):
        assert _tem_dados(
            api.get_saldo_caged_estadual_grupo(siglas_uf=[_UF], codigos_grupo=["471"])
        )

    def test_estadual_subclasse(self, api):
        assert _tem_dados(
            api.get_saldo_caged_estadual_subclasse(siglas_uf=[_UF], codigos_subclasse=["4711301"])
        )

    def test_municipal_divisao(self, api):
        """REGRESSÃO: quebrava com 500 (IN UNNEST STRING vs ARRAY<INT64>)."""
        dados = api.get_saldo_caged_municipal_divisao(
            siglas_uf=[_UF], codigos_municipio=[_CODIGO_MUNICIPIO], codigos_divisao=["47"]
        )
        assert _tem_dados(dados)
        assert all(item.get("cod_municipio") == _CODIGO_MUNICIPIO for item in dados)

    def test_municipal_grupo(self, api):
        dados = api.get_saldo_caged_municipal_grupo(
            siglas_uf=[_UF], codigos_municipio=[_CODIGO_MUNICIPIO], codigos_grupo=["471"]
        )
        assert _tem_dados(dados)

    def test_municipal_subclasse(self, api):
        dados = api.get_saldo_caged_municipal_subclasse(
            siglas_uf=[_UF], codigos_municipio=[_CODIGO_MUNICIPIO], codigos_subclasse=["4711301"]
        )
        assert _tem_dados(dados)


class TestSaldoCagedListaEGruposCodigos:
    """6 combinações: {nacional,estadual,municipal} x {lista_codigos,grupos_codigos}
    via os métodos genéricos, que cobrem as 8 rotas POST de /saldo_caged/... no servidor."""

    @pytest.mark.parametrize("nivel_agregacao,extra", [
        ("nacional", {}),
        ("estadual", {"siglas_uf": [_UF]}),
        ("municipal", {"codigos_municipio": [_CODIGO_MUNICIPIO]}),
    ])
    def test_lista_codigos(self, api, nivel_agregacao, extra):
        dados = api.get_saldo_caged_lista_codigos(
            nivel_agregacao=nivel_agregacao, nivel_cnae="divisao", codigos=["47"], **extra
        )
        assert _tem_dados(dados)

    @pytest.mark.parametrize("nivel_agregacao,extra", [
        ("nacional", {}),
        ("estadual", {"siglas_uf": [_UF]}),
        ("municipal", {"codigos_municipio": [_CODIGO_MUNICIPIO]}),
    ])
    def test_grupos_codigos(self, api, nivel_agregacao, extra):
        grupos = [{"nome_grupo": "Comercio", "codigos": ["47"]}]
        dados = api.get_saldo_caged_grupos_codigos(
            nivel_agregacao=nivel_agregacao, nivel_cnae="divisao", grupos=grupos, **extra
        )
        assert _tem_dados(dados)


class TestMetadados:
    def test_date_bases_inclui_todas_as_bases(self, api):
        bases = {item["Base"] for item in api.get_date_bases()}
        assert {"ComexStat", "CAGED", "RAIS"} <= bases
