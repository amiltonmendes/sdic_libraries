"""Testes unitários do cliente Comex (sdic_libraries.dados.comex.api).

Mock de HTTP via `unittest.mock.patch.object` em `requests.Session` — sem
rede real, sem depender de uma sdic_api rodando.
"""
from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest
import requests

from sdic_libraries.dados.comex.api import Comex, ComexAPIError


def _mock_response(json_data, status_code=200):
    resposta = MagicMock()
    resposta.status_code = status_code
    resposta.json.return_value = json_data
    if status_code >= 400:
        erro = requests.exceptions.HTTPError(response=resposta)
        resposta.raise_for_status.side_effect = erro
    else:
        resposta.raise_for_status.return_value = None
    return resposta


@pytest.fixture
def cliente():
    return Comex(base_url="https://sdicapi.teste", api_key="chave-teste")


class TestConfiguracao:
    def test_api_key_configura_headers(self, cliente):
        assert cliente.session.headers["x-api-key"] == "chave-teste"
        assert cliente.session.headers["Authorization"] == "Bearer chave-teste"

    def test_base_url_default(self):
        cliente = Comex(api_key=None)
        assert cliente.base_url == "https://sdicapi.dados.ninja"

    def test_base_url_parametro_tem_precedencia(self, monkeypatch):
        monkeypatch.setenv("COMEX_API_BASE_URL", "https://env.exemplo")
        cliente = Comex(base_url="https://parametro.exemplo")
        assert cliente.base_url == "https://parametro.exemplo"

    def test_base_url_env_var_usada_sem_parametro(self, monkeypatch):
        monkeypatch.setenv("COMEX_API_BASE_URL", "https://env.exemplo")
        cliente = Comex()
        assert cliente.base_url == "https://env.exemplo"


class TestRequisicoesEUrl:
    def test_get_isic_divisao_nacional_monta_url_e_params(self, cliente):
        with patch.object(cliente.session, "get") as mock_get:
            mock_get.return_value = _mock_response({"count": 0, "items": []})
            cliente.get_exportacao_isic_divisao_nacional_mensal(ano_minimo=2023, secao="C")

        url_chamada, kwargs = mock_get.call_args
        assert url_chamada[0] == "https://sdicapi.teste/exportacao_isic_divisao_gcloud"
        assert kwargs["params"]["ano_minimo"] == 2023
        assert kwargs["params"]["secao"] == "C"
        assert kwargs["params"]["pagina"] == 1

    def test_get_uf_isic_divisao_repassa_bloco(self, cliente):
        with patch.object(cliente.session, "get") as mock_get:
            mock_get.return_value = _mock_response({"count": 0, "items": []})
            cliente.get_exportacao_isic_divisao_estadual_mensal(estado="São Paulo", bloco=22)

        _, kwargs = mock_get.call_args
        assert kwargs["params"]["bloco"] == 22
        assert kwargs["params"]["estado"] == "São Paulo"

    def test_get_pais_nacional_sem_bloco_nao_envia_parametro(self, cliente):
        with patch.object(cliente.session, "get") as mock_get:
            mock_get.return_value = _mock_response({"count": 0, "items": []})
            cliente.get_exportacao_pais_nacional_mensal(pais="Argentina")

        _, kwargs = mock_get.call_args
        assert "bloco" not in kwargs["params"]
        assert kwargs["params"]["pais"] == "Argentina"


class TestPaginacao:
    def test_fetch_all_paginated_get_consolida_paginas(self, cliente):
        pagina_1 = _mock_response({"count": 3, "items": [{"a": 1}, {"a": 2}]})
        pagina_2 = _mock_response({"count": 3, "items": [{"a": 3}]})

        with patch.object(cliente.session, "get", side_effect=[pagina_1, pagina_2]) as mock_get:
            itens = cliente._fetch_all_paginated_get("/exportacao_pais_gcloud", {"ano_minimo": 2023, "tamanho_pagina": 2})

        assert itens == [{"a": 1}, {"a": 2}, {"a": 3}]
        assert mock_get.call_count == 2

    def test_fetch_all_paginated_post_embute_pagina_no_corpo(self, cliente):
        pagina_1 = _mock_response({"count": 1, "items": [{"NCM": 123}]})

        with patch.object(cliente.session, "post", return_value=pagina_1) as mock_post:
            cliente._fetch_all_paginated_post("/exportacao_agregada_ncm", {"ano_minimo": 2023}, {})

        _, kwargs = mock_post.call_args
        assert kwargs["json"]["pagina"] == 1
        assert kwargs["json"]["ano_minimo"] == 2023


class TestErros:
    def test_erro_http_vira_comex_api_error(self, cliente):
        with patch.object(cliente.session, "get") as mock_get:
            mock_get.return_value = _mock_response({"detail": "erro"}, status_code=500)
            with pytest.raises(ComexAPIError):
                cliente.get_exportacao_pais_nacional_mensal()

    def test_erro_conexao_vira_comex_api_error(self, cliente):
        with patch.object(cliente.session, "get", side_effect=requests.exceptions.ConnectionError("falhou")):
            with pytest.raises(ComexAPIError):
                cliente.get_exportacao_pais_nacional_mensal()


class TestFiltroSecaoNcm:
    def test_secao_filtra_via_mapa_ncm_isic(self, cliente):
        resposta_mapa = _mock_response({
            "count": 2,
            "items": [
                {"NCM": 111, "DescricaoNCM": "x", "DivisaoISIC": 10, "NomeDivisaoISIC": "y", "SecaoISIC": "C", "NomeSecaoISIC": "Indústria de Transformação"},
                {"NCM": 222, "DescricaoNCM": "z", "DivisaoISIC": 1, "NomeDivisaoISIC": "w", "SecaoISIC": "A", "NomeSecaoISIC": "Agropecuária"},
            ],
        })
        resposta_ncm = _mock_response({
            "count": 2,
            "items": [
                {"Ano": 2023, "Mes": 1, "NCM": 111, "DescricaoNCM": "x", "VLFob": 100, "QTEstat": 1, "KgLiquido": 1},
                {"Ano": 2023, "Mes": 1, "NCM": 222, "DescricaoNCM": "z", "VLFob": 200, "QTEstat": 1, "KgLiquido": 1},
            ],
        })

        with patch.object(cliente.session, "get", return_value=resposta_mapa), \
             patch.object(cliente.session, "post", return_value=resposta_ncm):
            itens = cliente.get_exportacao_ncm_nacional_mensal(ano_minimo=2023, secao="C")

        assert len(itens) == 1
        assert itens[0]["NCM"] == 111

    def test_mapa_ncm_isic_cacheado_em_memoria(self, cliente):
        resposta_mapa = _mock_response({"count": 1, "items": [{"NCM": 1, "DescricaoNCM": "x", "DivisaoISIC": 1, "NomeDivisaoISIC": "y", "SecaoISIC": "A", "NomeSecaoISIC": "z"}]})
        with patch.object(cliente.session, "get", return_value=resposta_mapa) as mock_get:
            cliente.get_ncm_isic_mapa()
            cliente.get_ncm_isic_mapa()

        assert mock_get.call_count == 1


class TestContextManager:
    def test_fecha_sessao_ao_sair_do_with(self):
        with patch.object(requests.Session, "close") as mock_close:
            with Comex(api_key="x") as cliente:
                assert isinstance(cliente, Comex)
            mock_close.assert_called_once()
