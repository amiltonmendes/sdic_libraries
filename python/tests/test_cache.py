"""Cache local das respostas da sdic_api (utils/cache.py) — sem rede."""
from __future__ import annotations

import os
import time
from unittest.mock import MagicMock, patch

import pytest
import requests

from sdic_libraries.dados.comex.api import Comex, ComexAPIError
from sdic_libraries.dados.emprego.api import Emprego


def _resposta(json_data, erro=False):
    r = MagicMock(status_code=500 if erro else 200)
    r.json.return_value = json_data
    if erro:
        r.raise_for_status.side_effect = requests.exceptions.HTTPError(response=r)
    return r


@pytest.fixture(autouse=True)
def pasta_cache(tmp_path, monkeypatch):
    monkeypatch.setenv("SDIC_CACHE_DIR", str(tmp_path))
    monkeypatch.delenv("SDIC_CACHE_TTL", raising=False)
    return tmp_path


def test_desligado_por_padrao_nao_grava_nada(pasta_cache):
    api = Comex(base_url="https://sdicapi.teste", api_key=None)
    with patch.object(api.session, "get", return_value=_resposta({"count": 0, "items": []})) as get:
        api._make_request("/x", {"a": 1})
        api._make_request("/x", {"a": 1})
    assert get.call_count == 2 and list(pasta_cache.iterdir()) == []


@pytest.mark.parametrize("cls", [Comex, Emprego])
def test_repete_get_vem_do_cache_e_params_diferentes_nao(cls, monkeypatch):
    monkeypatch.setenv("SDIC_CACHE_TTL", "60")
    api = cls(base_url="https://sdicapi.teste", api_key=None)
    with patch.object(api.session, "get", return_value=_resposta({"count": 1, "items": [{"Ano": 2026}]})) as get:
        assert api._make_request("/x", {"a": 1}) == api._make_request("/x", {"a": 1})
        assert get.call_count == 1
        api._make_request("/x", {"a": 2})
        assert get.call_count == 2


def test_post_considera_o_corpo(monkeypatch):
    monkeypatch.setenv("SDIC_CACHE_TTL", "60")
    api = Comex(base_url="https://sdicapi.teste", api_key=None)
    with patch.object(api.session, "post", return_value=_resposta({"count": 0, "items": []})) as post:
        api._make_post_request("/x", {"anos": [2025]})
        api._make_post_request("/x", {"anos": [2025]})
        api._make_post_request("/x", {"anos": [2026]})
    assert post.call_count == 2


def test_host_faz_parte_da_chave(monkeypatch):
    monkeypatch.setenv("SDIC_CACHE_TTL", "60")
    a = Comex(base_url="https://a.teste", api_key=None)
    b = Comex(base_url="https://b.teste", api_key=None)
    with patch.object(a.session, "get", return_value=_resposta({"v": "a"})), patch.object(b.session, "get", return_value=_resposta({"v": "b"})):
        assert a._make_request("/x") == {"v": "a"}
        assert b._make_request("/x") == {"v": "b"}


def test_erro_nao_e_gravado(monkeypatch, pasta_cache):
    monkeypatch.setenv("SDIC_CACHE_TTL", "60")
    api = Comex(base_url="https://sdicapi.teste", api_key=None)
    with patch.object(api.session, "get", return_value=_resposta({}, erro=True)):
        with pytest.raises(ComexAPIError):
            api._make_request("/x")
    assert list(pasta_cache.iterdir()) == []


def test_expirado_busca_de_novo(monkeypatch, pasta_cache):
    monkeypatch.setenv("SDIC_CACHE_TTL", "60")
    api = Comex(base_url="https://sdicapi.teste", api_key=None)
    with patch.object(api.session, "get", return_value=_resposta({"v": 1})) as get:
        api._make_request("/x")
        antigo = time.time() - 3600
        for arquivo in pasta_cache.iterdir():
            os.utime(arquivo, (antigo, antigo))
        api._make_request("/x")
    assert get.call_count == 2


def test_cache_corrompido_e_ignorado(monkeypatch, pasta_cache):
    monkeypatch.setenv("SDIC_CACHE_TTL", "60")
    api = Comex(base_url="https://sdicapi.teste", api_key=None)
    with patch.object(api.session, "get", return_value=_resposta({"v": 1})) as get:
        api._make_request("/x")
        for arquivo in pasta_cache.iterdir():
            arquivo.write_text("{quebrado", encoding="utf-8")
        assert api._make_request("/x") == {"v": 1}
    assert get.call_count == 2
