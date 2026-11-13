"""Apoio dos testes: ambiente limpo e origens servidas pelas amostras de contrato/ (sem rede)."""
from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import parse_qsl, urlsplit

import pytest
import requests

CONTRATO = Path(__file__).resolve().parents[2] / "contrato"
_VARIAVEIS = ("SDIC_API_KEY", "SDIC_API_URL", "SDIC_DADOS_URL", "SDIC_PAGES_URL", "SDIC_AMBIENTE", "SDIC_TIMEOUT",
              "SDIC_CACHE_TTL", "EMPLOYMENT_API_KEY", "COMEX_API_KEY", "EMPLOYMENT_API_BASE_URL",
              "COMEX_API_BASE_URL", "PORTAL_EMPREGO_BASE_URL", "PORTAL_EMPREGO_AMBIENTE", "API_TIMEOUT")


def amostras(nome: str) -> dict:
    return json.loads((CONTRATO / f"{nome}_amostras.json").read_text(encoding="utf-8"))


@pytest.fixture(autouse=True)
def ambiente_limpo(monkeypatch, tmp_path):
    """Nenhum teste depende do ambiente ou do .env de quem roda."""
    for v in _VARIAVEIS:
        monkeypatch.delenv(v, raising=False)
    monkeypatch.chdir(tmp_path)
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("SDIC_CACHE_DIR", str(tmp_path / "cache"))


class Resposta(requests.Response):
    def __init__(self, status: int, corpo, url: str):
        super().__init__()
        self.status_code, self.url = status, url
        self._content = json.dumps(corpo).encode()


@pytest.fixture
def origem_falsa(monkeypatch):
    """Serve `arquivos` (caminho -> JSON) no lugar do HTTP; o resto responde 404. Devolve a lista de URLs pedidas."""
    def montar(arquivos: dict):
        pedidas = []

        def get(self, url, params=None, timeout=None, **_):
            partes = urlsplit(url)
            pedidas.append((url, dict(params or {})))
            for caminho, corpo in arquivos.items():
                if partes.path.endswith("/" + caminho.lstrip("/")):
                    return Resposta(200, corpo, url)
            return Resposta(404, {"detail": "Not Found"}, url)

        monkeypatch.setattr(requests.Session, "get", get)
        return pedidas
    return montar
