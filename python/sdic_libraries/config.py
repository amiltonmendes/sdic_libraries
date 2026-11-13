"""Configuração da biblioteca: o único lugar que lê variável de ambiente e arquivo `.env`.

Cada valor é resolvido nesta ordem: argumento da função, variável de ambiente, `.env.local`,
`.env` (diretório atual), `~/.env`, `/etc/sdic/.env`, padrão do catálogo. Os arquivos são só
lidos: nada é gravado em `os.environ`, e só os nomes desta biblioteca são considerados.
`sdic_config()` mostra o que está valendo e de onde veio.
"""
from __future__ import annotations

import json
import os
import warnings
from pathlib import Path
from typing import Dict, Optional, Tuple
from urllib.parse import urlparse

import pandas as pd

CATALOGO = json.loads((Path(__file__).with_name("catalogo.json")).read_text(encoding="utf-8"))
ORIGENS: Dict[str, dict] = CATALOGO["origens"]
AMBIENTES = tuple(CATALOGO["ambientes"])

# nome atual -> nomes antigos ainda aceitos (com aviso de depreciação)
LEGADOS = {
    "SDIC_API_KEY": ("EMPLOYMENT_API_KEY", "COMEX_API_KEY"),
    "SDIC_API_URL": ("EMPLOYMENT_API_BASE_URL", "COMEX_API_BASE_URL"),
    "SDIC_PAGES_URL": ("PORTAL_EMPREGO_BASE_URL",),
    "SDIC_AMBIENTE": ("PORTAL_EMPREGO_AMBIENTE",),
    "SDIC_TIMEOUT": ("API_TIMEOUT",),
}
PADROES = {"SDIC_TIMEOUT": "30", "SDIC_CACHE_TTL": "0", "SDIC_AMBIENTE": "producao"}
_avisados: set = set()


def _arquivos() -> Tuple[Path, ...]:
    return (Path.cwd() / ".env.local", Path.cwd() / ".env", Path.home() / ".env", Path("/etc/sdic/.env"))


def _ler_env(arquivo: Path) -> Dict[str, str]:
    valores: Dict[str, str] = {}
    try:
        linhas = arquivo.read_text(encoding="utf-8").splitlines()
    except OSError:
        return valores
    for linha in linhas:
        linha = linha.strip()
        if not linha or linha.startswith("#") or "=" not in linha:
            continue
        nome, valor = (p.strip() for p in linha.split("=", 1))
        nome = nome[7:].strip() if nome.startswith("export ") else nome
        if len(valor) >= 2 and valor[0] == valor[-1] and valor[0] in "\"'":
            valor = valor[1:-1]
        valores[nome] = valor
    return valores


def valor(nome: str, explicito: Optional[str] = None) -> Tuple[Optional[str], str]:
    """Valor de uma configuração e de onde veio (`argumento`, `variável`, caminho do arquivo ou `padrão`)."""
    if explicito is not None and str(explicito) != "":
        return str(explicito), "argumento"
    nomes = (nome,) + LEGADOS.get(nome, ())
    fontes = [("variável de ambiente", dict(os.environ))] + [(str(a), _ler_env(a)) for a in _arquivos()]
    for de_onde, valores in fontes:
        for candidato in nomes:
            if valores.get(candidato):
                if candidato != nome and candidato not in _avisados:
                    _avisados.add(candidato)
                    warnings.warn(f"{candidato} foi substituída por {nome}; a antiga continua valendo por enquanto.",
                                  DeprecationWarning, stacklevel=3)
                return valores[candidato], f"{de_onde} ({candidato})"
    return PADROES.get(nome), "padrão"


def url(origem: str, explicita: Optional[str] = None) -> str:
    """URL base de uma origem do catálogo (`api`, `dados`, `politicas`), sem barra no fim."""
    if origem not in ORIGENS:
        raise ValueError(f"Origem desconhecida: {origem!r}. Origens: {sorted(ORIGENS)}.")
    base, _ = valor(ORIGENS[origem]["variavel"], explicita)
    return (base or ORIGENS[origem]["url"]).rstrip("/")


def chave(explicita: Optional[str] = None) -> Optional[str]:
    """Chave individual da sdic_api (`SDIC_API_KEY`); None se não houver."""
    return valor("SDIC_API_KEY", explicita)[0] or None


def ambiente(explicito: Optional[str] = None) -> str:
    """`producao` ou `homologacao` (`SDIC_AMBIENTE`; padrão `producao`)."""
    amb = (valor("SDIC_AMBIENTE", explicito)[0] or "producao").strip().lower()
    if amb not in AMBIENTES:
        raise ValueError(f"Ambiente inválido: {amb!r}. Use {' ou '.join(AMBIENTES)}.")
    return amb


def _inteiro(nome: str, explicito=None) -> int:
    texto, de_onde = valor(nome, None if explicito is None else str(explicito))
    try:
        return int(float(texto))
    except (TypeError, ValueError):
        raise ValueError(f"{nome} deve ser um número de segundos; veio {texto!r} ({de_onde}).") from None


def timeout(explicito: Optional[int] = None) -> int:
    return _inteiro("SDIC_TIMEOUT", explicito)


def cache_ttl() -> int:
    return _inteiro("SDIC_CACHE_TTL")


def conferir_destino_da_chave(base_url: str) -> None:
    """A chave só viaja por HTTPS (ou para a própria máquina, em teste)."""
    partes = urlparse(base_url)
    if partes.scheme != "https" and partes.hostname not in ("localhost", "127.0.0.1", "::1"):
        raise ValueError(f"A chave da API não é enviada para {base_url!r}: a URL precisa ser https://. "
                         "Confira SDIC_API_URL (sdic_config() mostra de onde o valor veio).")


def sdic_config() -> pd.DataFrame:
    """O que a biblioteca está usando agora e de onde veio cada valor.

    Returns:
        pd.DataFrame: colunas `item`, `valor`, `variavel`, `de_onde`. A chave nunca é mostrada: só se existe.

    Example:
        >>> from sdic_libraries import sdic_config
        >>> sdic_config()
    """
    linhas = []
    for origem, dados in ORIGENS.items():
        v, de_onde = valor(dados["variavel"])
        linhas.append((f"origem {origem}", (v or dados["url"]).rstrip("/"), dados["variavel"], de_onde))
    k, de_onde = valor("SDIC_API_KEY")
    linhas.append(("chave da API", "definida" if k else "não definida", "SDIC_API_KEY", de_onde if k else "-"))
    for item, nome in (("ambiente", "SDIC_AMBIENTE"), ("timeout (s)", "SDIC_TIMEOUT"), ("cache (s)", "SDIC_CACHE_TTL")):
        v, de_onde = valor(nome)
        linhas.append((item, v, nome, de_onde))
    v, de_onde = valor("SDIC_CACHE_DIR")
    linhas.append(("pasta do cache", v or str(Path.home() / ".cache" / "sdic_libraries"), "SDIC_CACHE_DIR", de_onde))
    return pd.DataFrame(linhas, columns=["item", "valor", "variavel", "de_onde"])
