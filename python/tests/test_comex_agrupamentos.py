"""Comex "agrupamentos" (Python) — monta a URL/params certos; sem rede real.

Pendente de deploy na sdic_api (2026-09-29, ver TODO.md) — estes testes fixam o contrato
que o cliente já implementa, para não regredir enquanto a API não sobe.
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from sdic_libraries.dados.comex.api import Comex


def _mock_response(json_data, status_code=200):
    resposta = MagicMock()
    resposta.status_code = status_code
    resposta.json.return_value = json_data
    resposta.raise_for_status.return_value = None
    return resposta


@pytest.fixture
def cliente():
    return Comex(base_url="https://sdicapi.teste", api_key=None)


class TestAgrupamentos:
    def test_exportacao_agrupamentos_monta_url_e_params(self, cliente):
        with patch.object(cliente.session, "get") as mock_get:
            mock_get.return_value = _mock_response({"count": 0, "items": []})
            cliente.get_exportacao_agrupamentos("Moda", ano_minimo=2024, anos=[2024, 2025], departamento="Dep. X", cg="CG Y")

        url, kwargs = mock_get.call_args
        assert url[0] == "https://sdicapi.teste/exportacao_agrupamentos"
        assert kwargs["params"]["agrupamento"] == "Moda"
        assert kwargs["params"]["ano_minimo"] == 2024
        assert kwargs["params"]["anos"] == "2024,2025"
        assert kwargs["params"]["departamento"] == "Dep. X"
        assert kwargs["params"]["cg"] == "CG Y"

    def test_importacao_agrupamentos_sem_filtros_opcionais(self, cliente):
        with patch.object(cliente.session, "get") as mock_get:
            mock_get.return_value = _mock_response({"count": 0, "items": []})
            cliente.get_importacao_agrupamentos("Moda")

        _, kwargs = mock_get.call_args
        assert kwargs["params"] == {"agrupamento": "Moda", "pagina": 1, "tamanho_pagina": 5000}

    def test_agrupamentos_pais_ncm_repassa_nivel_agregacao_e_posicao(self, cliente):
        with patch.object(cliente.session, "get") as mock_get:
            mock_get.return_value = _mock_response({"count": 0, "items": []})
            cliente.get_exportacao_agrupamentos_pais_ncm("Moda", nivel_agregacao="setor", posicao=5, agregado_ano=True)

        _, kwargs = mock_get.call_args
        assert kwargs["params"]["nivel_agregacao"] == "setor"
        assert kwargs["params"]["posicao"] == 5
        assert kwargs["params"]["agregado_ano"] is True

    def test_agrupamentos_disponiveis_e_uma_chamada_so_com_filtro_opcional(self, cliente):
        with patch.object(cliente.session, "get") as mock_get:
            mock_get.return_value = _mock_response([{"Agrupamento": "Moda", "Departamento": "Dep. X", "CoordenacaoGeral": "CG Y"}])
            resultado = cliente.get_agrupamentos_disponiveis(departamento="Dep. X")

        url, kwargs = mock_get.call_args
        assert url[0] == "https://sdicapi.teste/agrupamentos_disponiveis"
        assert kwargs["params"] == {"departamento": "Dep. X"}
        assert mock_get.call_count == 1  # não pagina — é um catálogo pequeno
        assert resultado == [{"Agrupamento": "Moda", "Departamento": "Dep. X", "CoordenacaoGeral": "CG Y"}]

    def test_funcoes_de_modulo_devolvem_dataframe_com_departamento_e_cg(self, monkeypatch):
        import sdic_libraries.dados.comex as comex

        linha = {"Ano": 2026, "Agrupamento": "Moda", "Setor": "Têxtil", "Subsetor": "Fios", "Produto": "Algodão",
                 "Departamento": "Dep. X", "CoordenacaoGeral": "CG Y", "VLFob": 1, "QTEstat": 1, "KGLiquido": 1}
        monkeypatch.setattr(Comex, "get_exportacao_agrupamentos", lambda self, **kw: [linha])
        df = comex.get_exportacao_agrupamentos(agrupamento="Moda")
        assert list(df.columns) == ["ano", "agrupamento", "setor", "subsetor", "produto",
                                     "departamento", "coordenacao_geral", "vl_fob",
                                     "quantidade_estatistica", "kg_liquido", "mes"]

        monkeypatch.setattr(Comex, "get_agrupamentos_disponiveis", lambda self, **kw: [
            {"Agrupamento": "Moda", "Departamento": "Dep. X", "CoordenacaoGeral": "CG Y"}])
        catalogo = comex.get_agrupamentos_disponiveis()
        assert list(catalogo.columns) == ["agrupamento", "departamento", "coordenacao_geral"]
