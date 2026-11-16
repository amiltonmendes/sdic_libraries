"""Configuração da biblioteca: o único lugar que lê variável de ambiente e arquivo `.env`.

Cada valor é resolvido nesta ordem: argumento da função, variável de ambiente, `.env.local`,
`.env` (diretório atual), o arquivo do usuário gravado por `salvar_chave()` (`~/.config/sdic/.env`),
`~/.env`, `/etc/sdic/.env`, padrão do catálogo. Fora `salvar_chave()`, os arquivos são só lidos: nada é gravado
em `os.environ`, e só os nomes desta biblioteca são considerados.
`sdic_config()` mostra o que está valendo e de onde veio.
"""
from __future__ import annotations

import json
import os
import re
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


def arquivo_do_usuario() -> Path:
    """Arquivo de configuração do usuário, o que `salvar_chave()` grava. O mesmo em Python e em R:
    `%APPDATA%/sdic/.env` no Windows; `$XDG_CONFIG_HOME/sdic/.env` (padrão `~/.config/sdic/.env`) nos demais."""
    if os.name == "nt" and os.environ.get("APPDATA"):
        return Path(os.environ["APPDATA"]) / "sdic" / ".env"
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "sdic" / ".env"


def _arquivos() -> Tuple[Path, ...]:
    return (Path.cwd() / ".env.local", Path.cwd() / ".env", arquivo_do_usuario(), Path.home() / ".env",
            Path("/etc/sdic/.env"))


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


def _gravar_privado(arquivo: Path, conteudo: str) -> None:
    """Grava `conteudo` legível só pelo dono (pasta 700, arquivo 600), trocando o arquivo de uma vez."""
    arquivo.parent.mkdir(parents=True, exist_ok=True)
    if os.name != "nt":
        os.chmod(arquivo.parent, 0o700)
    temporario = arquivo.with_name(arquivo.name + ".tmp")
    descritor = os.open(temporario, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descritor, "w", encoding="utf-8") as f:
        f.write(conteudo)
    os.replace(temporario, arquivo)
    if os.name != "nt":
        os.chmod(arquivo, 0o600)


def _testar_chave(chave: str) -> None:
    from .transporte import SdicErro, nova_sessao  # import tardio: transporte importa config
    base = url("api")
    conferir_destino_da_chave(base)
    try:
        resposta = nova_sessao(chave).get(f"{base}/series", timeout=timeout())
    except Exception as erro:  # noqa: BLE001 - a mensagem original pode trazer a URL; não a chave
        raise SdicErro(f"Não foi possível falar com a API ({base}) para conferir a chave: {type(erro).__name__}. "
                       "Nada foi salvo. Sem rede, use salvar_chave(..., testar=False).", endpoint="/series") from None
    if resposta.status_code in (401, 403):
        raise ValueError(f"A API recusou a chave (HTTP {resposta.status_code}). Nada foi salvo.")
    if resposta.status_code >= 400:
        raise SdicErro(f"A API respondeu HTTP {resposta.status_code} ao conferir a chave. Nada foi salvo.",
                       status_code=resposta.status_code, endpoint="/series")


def salvar_chave(chave: Optional[str] = None, testar: bool = True) -> str:
    """Guarda a chave da sdic_api no arquivo de configuração do usuário, legível só por ele.

    Sem `chave`, pergunta sem mostrar o que é digitado (melhor do que escrever a chave no código, que fica no
    histórico). Com `testar=True`, confere a chave na API antes de gravar: chave recusada não é salva. O arquivo é
    `~/.config/sdic/.env` (`%APPDATA%\\sdic\\.env` no Windows), com permissão só do dono, e vale para Python e
    para R. Chamar de novo troca a chave. Uma `SDIC_API_KEY` em variável de ambiente ou no `.env.local`/`.env`
    da pasta atual continua tendo precedência (há aviso quando isso acontece).

    Args:
        chave: a chave individual; se omitida, é pedida no terminal.
        testar: conferir a chave na API antes de salvar.

    Returns:
        str: o caminho do arquivo gravado.

    Example:
        >>> from sdic_libraries import salvar_chave, sdic_config
        >>> salvar_chave()          # pergunta a chave
        >>> sdic_config()           # "chave da API: definida", com o arquivo de onde veio
    """
    if chave is None:
        import getpass
        chave = getpass.getpass("Chave da sdic_api (não aparece na tela): ")
    chave = (chave or "").strip()
    if len(chave) < 16 or any(c.isspace() or c in "=#\"'" for c in chave):
        raise ValueError("Chave inválida: esperava o texto recebido do dono do projeto, sem espaços. Nada foi salvo.")
    if testar:
        _testar_chave(chave)
    arquivo = arquivo_do_usuario()
    try:
        linhas = arquivo.read_text(encoding="utf-8").splitlines()
    except OSError:
        linhas = []
    linhas = [l for l in linhas if re.sub(r"^\s*export\s+", "", l).split("=", 1)[0].strip() != "SDIC_API_KEY"]
    _gravar_privado(arquivo, "\n".join(linhas + [f"SDIC_API_KEY={chave}"]) + "\n")
    _, de_onde = valor("SDIC_API_KEY")
    if not de_onde.startswith(str(arquivo)):
        warnings.warn(f"Chave salva em {arquivo}, mas vale a de {de_onde}, que tem precedência. Apague-a de lá para "
                      "usar a salva.", UserWarning, stacklevel=2)
    return str(arquivo)


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
