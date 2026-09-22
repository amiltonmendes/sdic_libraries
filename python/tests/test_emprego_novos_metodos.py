"""Testes de integração dos métodos novos e corrigidos de emprego (RAIS/CAGED).

Ao contrário de `test_comex_api.py` (que mocka HTTP), estes testes batem
numa sdic_api real, apontada por `EMPLOYMENT_API_BASE_URL` (padrão:
http://127.0.0.1:8123, uma instância local de desenvolvimento). Se a API não
estiver acessível ou ainda não tiver os endpoints novos (ex.: produção antes
do deploy), a suíte inteira é pulada em vez de falhar — não há mock aqui
porque o objetivo é validar o contrato real (schema, paginação, dados).

Endpoints cobertos:
- Novos: estoque por porte/setor (nacional/estadual), estoque por classe CNAE
  (nacional/estadual), estoque por UF+CBO, renda média, índice Potec.
- Corrigidos: get_estoque_emprego_nacional (antes retornava quebrado por UF
  por padrão) e get_date_bases (antes omitia a linha "RAIS" silenciosamente).
"""
from __future__ import annotations

import os

import pytest

from sdic_libraries.dados.emprego.api import Emprego, EmpregoAPIError

_BASE_URL = os.environ.get("EMPLOYMENT_API_BASE_URL", "http://127.0.0.1:8123")


@pytest.fixture(scope="module")
def api():
    cliente = Emprego(base_url=_BASE_URL)
    try:
        cliente.get_date_bases()
    except EmpregoAPIError as exc:
        pytest.skip(f"sdic_api indisponível ou sem os endpoints novos em {_BASE_URL}: {exc}")
    yield cliente
    cliente.close()


class TestEstoquePorteSetor:
    def test_nacional_agrega_sem_quebra_por_uf(self, api):
        dados = api.get_estoque_emprego_porte_nacional(nivel_cnae="divisao", codigos_cnae=["47"])
        assert dados
        anos = {item["ano"] for item in dados}
        assert len(dados) == len(anos) * len({item["porte"] for item in dados})
        assert all(item.get("sigla_uf") in (None,) for item in dados)
        assert all(item["setor"] == "Comércio e Serviços" for item in dados)

    def test_estadual_filtra_por_uf_informada(self, api):
        dados = api.get_estoque_emprego_porte_estadual(ufs=["SP", "RJ"], nivel_cnae="classe", codigos_cnae=["4711"])
        assert dados
        assert {item["sigla_uf"] for item in dados} <= {"SP", "RJ"}

    def test_nivel_cnae_invalido_leva_a_value_error(self, api):
        with pytest.raises(ValueError):
            api.get_estoque_emprego_porte_nacional(nivel_cnae="subclasse")


class TestEstoqueClasseCnae:
    def test_nacional_traz_descricao(self, api):
        dados = api.get_estoque_emprego_classe_cnae_nacional(codigos_classe=["4711"])
        assert dados
        assert any(item.get("classe_cnae_desc") for item in dados)

    def test_estadual_pagina_ate_o_fim_sem_erro(self, api):
        # Volume alto de linhas (~13k para SP) — cobre a regressão de
        # ResponseValidationError em classe_cnae_cod nulo em páginas tardias.
        dados = api.get_estoque_emprego_classe_cnae_estadual(ufs="SP")
        assert len(dados) > 1000
        assert all(item["sigla_uf"] == "SP" for item in dados)


class TestEstoqueUfCbo:
    def test_filtra_por_uf_e_classe(self, api):
        dados = api.get_estoque_emprego_uf_cbo(siglas_uf=["SP"], codigos_classe=["4711"])
        assert dados
        assert all(item["sigla_uf"] == "SP" for item in dados)


class TestRendaMediaEPotec:
    def test_renda_media_geral(self, api):
        dados = api.get_renda_media_emprego(tipos=["Geral"])
        assert dados
        assert all(item["tipo"] == "Geral" for item in dados)
        assert all(isinstance(item["remuneracao_media"], (int, float)) for item in dados)

    def test_potec_por_classe(self, api):
        dados = api.get_potec_emprego(codigos_classe=["7210"])
        assert dados
        assert all(item["classe_cnae_cod"] == "7210" for item in dados)


class TestBugsCorrigidos:
    def test_estoque_nacional_sempre_agrega_mesmo_com_default(self, api):
        """Regressão: /get_estoque_emprego_nacional/ devolvia quebrado por UF
        quando `agregado` não era informado (o default). Agora sempre agrega."""
        dados_default = api.get_estoque_emprego_nacional(codigos_cnae=["47"], nivel_cnae=2)
        dados_explicito = api.get_estoque_emprego_nacional(codigos_cnae=["47"], nivel_cnae=2, agregado=True)

        anos_default = sorted(item["ano"] for item in dados_default)
        anos_explicito = sorted(item["ano"] for item in dados_explicito)
        assert anos_default == anos_explicito
        assert len(dados_default) == len(set(anos_default))  # 1 linha por ano, sem quebra por UF

    def test_date_bases_inclui_rais(self, api):
        """Regressão: get_date_bases omitia a linha 'RAIS' por um AttributeError
        silencioso (EstoqueEmprego.Ano em vez de .ano)."""
        bases = api.get_date_bases()
        nomes = {item["Base"] for item in bases}
        assert "RAIS" in nomes
        assert "CAGED" in nomes
