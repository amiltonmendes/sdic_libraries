"""Transporte: erro com código e rota, paginação nos três formatos, cache por chave, repetição configurada."""
from __future__ import annotations

import warnings

import pytest
import requests

from sdic_libraries import NaoPublicado, SdicErro, ler_json_publicado
from sdic_libraries.dados.comex import Comex, ComexAPIError
from sdic_libraries.dados.emprego import Emprego, EmpregoAPIError
from sdic_libraries.transporte import ClienteAPI, nova_sessao

from conftest import Resposta


def _responde(monkeypatch, respostas):
    """`respostas`: lista consumida em ordem (Resposta ou exceção)."""
    fila, chamadas = list(respostas), []

    def get(self, url, params=None, timeout=None, **_):
        chamadas.append((url, dict(params or {})))
        r = fila.pop(0)
        if isinstance(r, Exception):
            raise r
        return r
    monkeypatch.setattr(requests.Session, "get", get)
    return chamadas


@pytest.mark.parametrize("status, trecho", [(401, "SDIC_API_KEY"), (403, "SDIC_API_KEY"), (404, "não encontrado"),
                                           (429, "Muitas requisições"), (503, "erro interno"), (422, "Parâmetros inválidos")])
def test_erro_decidido_pelo_codigo_http_com_rota_e_status(monkeypatch, status, trecho):
    # a URL contém "400" (código de município): não pode virar "parâmetros inválidos"
    _responde(monkeypatch, [Resposta(status, {"detail": "motivo da API"}, "https://x/rota?codigos_municipio=1400100")])
    with pytest.raises(EmpregoAPIError, match=trecho) as exc:
        Emprego(base_url="https://x")._make_request("/rota", {"codigos_municipio": 1400100})
    assert exc.value.status_code == status and exc.value.endpoint == "/rota"
    assert f"HTTP {status}" in str(exc.value)
    assert isinstance(exc.value, SdicErro) and exc.value.__cause__ is not None


def test_401_repassa_o_detalhe_da_api(monkeypatch):
    _responde(monkeypatch, [Resposta(401, {"detail": "Chave de API inválida ou ausente"}, "https://x/r")])
    with pytest.raises(ComexAPIError, match="Chave de API inválida ou ausente"):
        Comex(base_url="https://x")._make_request("/r")


def test_falha_de_rede_nao_expoe_url_nem_chave(monkeypatch):
    _responde(monkeypatch, [requests.exceptions.ConnectionError("https://x/r?token=segredo falhou")])
    with pytest.raises(EmpregoAPIError, match="Sem resposta") as exc:
        Emprego(base_url="https://x", api_key="segredo")._make_request("/r")
    assert "segredo" not in str(exc.value)


def test_paginacao_por_proxima_pagina(monkeypatch):
    chamadas = _responde(monkeypatch, [Resposta(200, {"items": [{"a": 1}], "proxima_pagina": 2}, "u"),
                                       Resposta(200, {"items": [{"a": 2}], "proxima_pagina": None}, "u")])
    assert ClienteAPI(base_url="https://x")._fetch_all_paginated_get("/series/s", {}) == [{"a": 1}, {"a": 2}]
    assert [c[1]["pagina"] for c in chamadas] == [1, 2]


def test_paginacao_por_count(monkeypatch):
    _responde(monkeypatch, [Resposta(200, {"count": 3, "items": [{"a": 1}, {"a": 2}]}, "u"),
                            Resposta(200, {"count": 3, "items": [{"a": 3}]}, "u")])
    itens = ClienteAPI(base_url="https://x")._fetch_all_paginated_get("/r", {"tamanho_pagina": 2})
    assert len(itens) == 3


def test_resultado_menor_que_o_count_avisa(monkeypatch):
    _responde(monkeypatch, [Resposta(200, {"count": 10, "items": [{"a": 1}]}, "u")])
    with pytest.warns(RuntimeWarning, match="informou 10 registros e vieram 1"):
        ClienteAPI(base_url="https://x")._fetch_all_paginated_get("/r", {"tamanho_pagina": 5})


def test_pagina_sem_lista_de_itens_e_erro_e_nao_fim(monkeypatch):
    _responde(monkeypatch, [Resposta(200, {"count": 5000, "items": [{"a": 1}] * 2}, "u"),
                            Resposta(200, {"mensagem": "algo deu errado"}, "u")])
    with pytest.raises(SdicErro, match="sem a lista de itens"):
        ClienteAPI(base_url="https://x")._fetch_all_paginated_get("/r", {"tamanho_pagina": 2})


def test_falha_no_meio_da_paginacao_propaga(monkeypatch):
    _responde(monkeypatch, [Resposta(200, {"count": 4, "items": [{"a": 1}, {"a": 2}]}, "u"), Resposta(503, {}, "u")])
    with pytest.raises(SdicErro) as exc:
        ClienteAPI(base_url="https://x")._fetch_all_paginated_get("/r", {"tamanho_pagina": 2})
    assert exc.value.status_code == 503


def test_cache_nao_serve_resposta_de_uma_chave_a_outra(monkeypatch):
    monkeypatch.setenv("SDIC_CACHE_TTL", "60")
    chamadas = _responde(monkeypatch, [Resposta(200, {"v": 1}, "u"), Resposta(200, {"v": 2}, "u")])
    assert ClienteAPI(base_url="https://x", api_key="chave-a")._make_request("/r") == {"v": 1}
    assert ClienteAPI(base_url="https://x", api_key="chave-a")._make_request("/r") == {"v": 1}  # do cache
    assert ClienteAPI(base_url="https://x")._make_request("/r") == {"v": 2}  # sem chave: vai à API
    assert len(chamadas) == 2


def test_cache_em_disco_nao_contem_a_chave(monkeypatch, tmp_path):
    monkeypatch.setenv("SDIC_CACHE_TTL", "60")
    _responde(monkeypatch, [Resposta(200, {"v": 1}, "u")])
    ClienteAPI(base_url="https://x", api_key="segredo-no-cache")._make_request("/r")
    gravado = "".join(p.read_text() + p.name for p in (tmp_path / "cache").iterdir())
    assert gravado and "segredo-no-cache" not in gravado


def test_sessao_repete_em_falha_transitoria_e_so_envia_bearer():
    sessao = nova_sessao("k")
    repeticao = sessao.get_adapter("https://x").max_retries
    assert repeticao.total == 3 and {429, 502, 503, 504} <= set(repeticao.status_forcelist)
    assert sessao.headers["Authorization"] == "Bearer k" and "x-api-key" not in sessao.headers
    assert "Authorization" not in nova_sessao().headers


def test_arquivo_publicado_ausente_vira_nao_publicado(origem_falsa):
    origem_falsa({"homologacao/SP/emprego.json": {"ok": True}})
    assert ler_json_publicado("dados", "homologacao/SP/emprego.json") == {"ok": True}
    with pytest.raises(NaoPublicado, match="producao/SP/emprego.json") as exc:
        ler_json_publicado("dados", "producao/SP/emprego.json")
    assert exc.value.status_code == 404


def test_arquivo_publicado_nunca_leva_a_chave(monkeypatch, origem_falsa):
    monkeypatch.setenv("SDIC_API_KEY", "k")
    import sdic_libraries.transporte as t
    t._sessao_arquivos = None
    origem_falsa({"a.json": {}})
    ler_json_publicado("dados", "a.json")
    assert "Authorization" not in t._sessao_arquivos.headers


def test_estoque_estimado_agrupado_nao_engole_falha_de_um_ano(monkeypatch):
    import sdic_libraries.dados.emprego.api as api

    def falha(**_):
        raise EmpregoAPIError("503", status_code=503)
    monkeypatch.setattr(api, "get_saldo_emprego_nacional_mensal_agrupado", falha)
    with pytest.raises(EmpregoAPIError, match="saldo de 2024"):
        api._obter_saldo_anual_agrupado(nome_grupo="g", lista_cnae=["10"], ano_inicio=2024, ano_limite=2024)
