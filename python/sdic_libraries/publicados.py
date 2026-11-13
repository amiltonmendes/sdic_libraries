"""Seções publicadas em JSON (as mesmas que o portal e os subsídios mostram).

Os arquivos são gerados do BigQuery pelo job `publicar-dados` (`carga_base/publicacao`) no
contrato v1.1 e ficam na origem `dados` do catálogo. Aqui eles viram tabelas. O local e o
ambiente vêm de `sdic_libraries.config` (`SDIC_DADOS_URL`, `SDIC_AMBIENTE`).
"""
from __future__ import annotations

import re
from typing import Any, Dict, List, Optional

import pandas as pd

from . import config
from .config import CATALOGO
from .transporte import NaoPublicado, ler_json_publicado

SECOES: Dict[str, dict] = CATALOGO["secoes"]
UFS = ("AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA", "MG", "MS", "MT", "PA", "PB", "PE", "PI",
       "PR", "RJ", "RN", "RO", "RR", "RS", "SC", "SE", "SP", "TO")
SCHEMA_MAIOR = "1"  # contrato v1.x; uma versão 2 muda o formato e precisa de biblioteca nova


def _colunas(funcao: str) -> List[str]:
    return [c[0] for c in CATALOGO["colunas"][funcao]]


def unidade(uf: Optional[str]) -> str:
    """Normaliza a unidade: sigla da UF em maiúsculas, ou `BRASIL` para None, 'BR', 'brasil', 'nacional'."""
    u = (uf or "BRASIL").strip().upper()
    if u in ("BR", "BRASIL", "NACIONAL"):
        return "BRASIL"
    if u not in UFS:
        raise ValueError(f"UF inválida: {uf!r}. Use a sigla (ex.: 'SP') ou 'BRASIL'.")
    return u


def listar_secoes_publicadas() -> pd.DataFrame:
    """Seções publicadas em JSON e para quais unidades existem.

    Returns:
        pd.DataFrame: colunas `secao`, `titulo`, `unidades`, `fonte`.

    Example:
        >>> from sdic_libraries import listar_secoes_publicadas
        >>> listar_secoes_publicadas()
    """
    return pd.DataFrame([{"secao": nome, "titulo": s["titulo"], "unidades": s["unidades"], "fonte": s["fonte"]}
                         for nome, s in SECOES.items()], columns=_colunas("listar_secoes_publicadas"))


def get_secao_publicada(uf: Optional[str], secao: str, ambiente: Optional[str] = None) -> dict:
    """JSON completo de uma seção publicada (contrato v1.1).

    Baixo nível: devolve o dicionário como publicado. Para tabelas, use `get_kpis_publicados`,
    `get_series_publicadas`, `get_ranking_publicado`, `get_detalhamento_publicado` e
    `get_destaques_publicados`.

    Args:
        uf (str): sigla da UF, ou 'BRASIL' (ou None) para o país.
        secao (str): uma de `listar_secoes_publicadas()['secao']`.
        ambiente (str, optional): 'producao' ou 'homologacao' (padrão: `SDIC_AMBIENTE`, depois 'producao').

    Raises:
        NaoPublicado: o arquivo não existe nesse ambiente para essa unidade.
        ValueError: seção, UF ou ambiente inválidos; versão do contrato não suportada.

    Example:
        >>> from sdic_libraries import get_secao_publicada
        >>> get_secao_publicada("SP", "emprego", ambiente="homologacao")["reference"]
    """
    if secao not in SECOES:
        raise ValueError(f"Seção desconhecida: {secao!r}. Seções: {sorted(SECOES)}.")
    u, amb = unidade(uf), config.ambiente(ambiente)
    if SECOES[secao]["unidades"] == "BRASIL" and u != "BRASIL":
        raise ValueError(f"A seção {secao!r} só existe para o Brasil (uf='BRASIL').")
    try:
        payload = ler_json_publicado("dados", f"{amb}/{u}/{SECOES[secao]['arquivo']}.json")
    except NaoPublicado as e:
        raise NaoPublicado(f"A seção {secao!r} de {u} não está publicada em {amb!r} ({e.endpoint}). "
                           "Em homologação ela pode existir: ambiente='homologacao'.",
                           status_code=e.status_code, endpoint=e.endpoint) from e
    versao = str(payload.get("schema_version", "1"))
    if versao.split(".")[0] != SCHEMA_MAIOR:
        raise ValueError(f"A seção {secao!r} está no contrato {versao}, que esta versão da biblioteca não lê. Atualize-a.")
    return payload


def _contexto(payload: dict, secao: str, uf: Optional[str]) -> dict:
    return {"secao": secao, "uf": unidade(uf)}


def _numero(v: Any) -> Optional[float]:
    return v if isinstance(v, (int, float)) and not isinstance(v, bool) else None


def _tabela(linhas: List[dict], funcao: str, numericas=("valor",)) -> pd.DataFrame:
    df = pd.DataFrame(linhas, columns=_colunas(funcao))
    for c in numericas:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")
    return df


def get_kpis_publicados(uf: Optional[str], secao: str, ambiente: Optional[str] = None) -> pd.DataFrame:
    """Indicadores de uma seção publicada, um por linha (o de capa primeiro).

    Args:
        uf (str): sigla da UF, ou 'BRASIL'.
        secao (str): ex.: 'emprego', 'comercio', 'pib_estadual', 'producao_industrial'.
        ambiente (str, optional): 'producao' ou 'homologacao'.

    Returns:
        pd.DataFrame: colunas `secao`, `uf`, `id`, `rotulo`, `valor`, `valor_exibido`, `unidade`,
        `periodo`, `capa`, `variacao_direcao`, `variacao_rotulo`, `fonte`, `referencia`,
        `atualizado_em`. `valor_exibido` é o texto formatado que o portal mostra.

    Example:
        >>> from sdic_libraries import get_kpis_publicados
        >>> get_kpis_publicados("SP", "emprego")[["rotulo", "valor_exibido", "periodo"]]
    """
    p = get_secao_publicada(uf, secao, ambiente)
    comum = {**_contexto(p, secao, uf), "fonte": p.get("source"), "referencia": p.get("reference"),
             "atualizado_em": p.get("updated_at")}
    itens = ([(p["capa_kpi"], True)] if isinstance(p.get("capa_kpi"), dict) else []) + [(k, False) for k in p.get("kpis") or []]
    linhas = []
    for k, capa in itens:
        delta = k.get("delta") or {}
        linhas.append({**comum, "id": k.get("id"), "rotulo": k.get("label"), "valor": _numero(k.get("value")),
                       "valor_exibido": k.get("display_value"), "unidade": k.get("unit"), "periodo": k.get("period"),
                       "capa": capa, "variacao_direcao": delta.get("dir"), "variacao_rotulo": delta.get("label")})
    return _tabela(linhas, "get_kpis_publicados")


def get_series_publicadas(uf: Optional[str], secao: str, ambiente: Optional[str] = None) -> pd.DataFrame:
    """Séries dos gráficos de uma seção publicada, em formato longo.

    Returns:
        pd.DataFrame: colunas `secao`, `uf`, `grafico`, `grafico_titulo`, `unidade`, `serie`,
        `serie_rotulo`, `t` (período como publicado), `v` (valor).

    Example:
        >>> from sdic_libraries import get_series_publicadas
        >>> s = get_series_publicadas("SP", "emprego")
        >>> s[s["grafico"] == "saldo_mensal_serie"]
    """
    p = get_secao_publicada(uf, secao, ambiente)
    ctx = _contexto(p, secao, uf)
    linhas = []
    for g in p.get("charts") or []:
        for s in g.get("series") or []:
            for ponto in s.get("points") or []:
                linhas.append({**ctx, "grafico": g.get("id"), "grafico_titulo": g.get("title"), "unidade": g.get("unit"),
                               "serie": s.get("id"), "serie_rotulo": s.get("label"),
                               "t": None if ponto.get("t") is None else str(ponto.get("t")), "v": _numero(ponto.get("v"))})
    return _tabela(linhas, "get_series_publicadas", numericas=("v",))


def get_ranking_publicado(uf: Optional[str], secao: str, ambiente: Optional[str] = None) -> pd.DataFrame:
    """Listas ordenadas de uma seção publicada, um item por linha, na ordem publicada.

    Returns:
        pd.DataFrame: colunas `secao`, `uf`, `lista`, `titulo`, `metrica`, `unidade`, `tom`,
        `posicao`, `nome`, `valor`, `valor_exibido`.

    Example:
        >>> from sdic_libraries import get_ranking_publicado
        >>> get_ranking_publicado("SP", "emprego")
    """
    p = get_secao_publicada(uf, secao, ambiente)
    ctx = _contexto(p, secao, uf)
    linhas = [{**ctx, "lista": l.get("id"), "titulo": l.get("title"), "metrica": l.get("metric_label"),
               "unidade": l.get("unit"), "tom": l.get("tone"), "posicao": n, "nome": i.get("name"),
               "valor": _numero(i.get("value")), "valor_exibido": i.get("display_value")}
              for l in p.get("ranked_lists") or [] for n, i in enumerate(l.get("items") or [], start=1)]
    df = _tabela(linhas, "get_ranking_publicado")
    df["posicao"] = df["posicao"].astype("Int64")
    return df


def get_detalhamento_publicado(uf: Optional[str], secao: str, ambiente: Optional[str] = None) -> pd.DataFrame:
    """Composições de uma seção publicada (ex.: emprego por intensidade tecnológica).

    Returns:
        pd.DataFrame: colunas `secao`, `uf`, `detalhamento`, `titulo`, `dimensao`, `unidade`,
        `periodo`, `nome`, `valor`, `valor_exibido`, `participacao` (fração de 0 a 1, se publicada).

    Example:
        >>> from sdic_libraries import get_detalhamento_publicado
        >>> get_detalhamento_publicado("SP", "emprego")
    """
    p = get_secao_publicada(uf, secao, ambiente)
    ctx = _contexto(p, secao, uf)
    linhas = [{**ctx, "detalhamento": b.get("id"), "titulo": b.get("title"), "dimensao": b.get("dimension_label"),
               "unidade": b.get("unit"), "periodo": b.get("period"), "nome": i.get("name"),
               "valor": _numero(i.get("value")), "valor_exibido": i.get("display_value"),
               "participacao": _numero(i.get("share"))}
              for b in p.get("breakdowns") or [] for i in b.get("items") or []]
    return _tabela(linhas, "get_detalhamento_publicado", numericas=("valor", "participacao"))


_MARCADOR = re.compile(r"\{\{\s*kpis\[([^\]]+)\]\.(\w+)\s*\}\}")


def _preencher(texto: Any, payload: dict) -> Optional[str]:
    """Troca `{{kpis[id].campo}}` pelo valor do indicador; marcador sem valor fica como está."""
    if not isinstance(texto, str):
        return None
    kpis = {k.get("id"): k for k in payload.get("kpis") or []}
    return _MARCADOR.sub(lambda m: str(kpis.get(m.group(1), {}).get(m.group(2), m.group(0))), texto)


def get_destaques_publicados(uf: Optional[str], secao: str, ambiente: Optional[str] = None) -> pd.DataFrame:
    """Título, linha de apoio e destaques do texto de uma seção publicada.

    Returns:
        pd.DataFrame: colunas `secao`, `uf`, `tipo` ('titulo', 'apoio' ou 'destaque'), `tom`, `texto`
        (com os marcadores `{{kpis[...]}}` já trocados pelos valores).

    Example:
        >>> from sdic_libraries import get_destaques_publicados
        >>> get_destaques_publicados("SP", "emprego")["texto"].tolist()
    """
    p = get_secao_publicada(uf, secao, ambiente)
    ctx, historia = _contexto(p, secao, uf), p.get("story") or {}
    linhas = [{**ctx, "tipo": tipo, "tom": None, "texto": _preencher(historia.get(campo), p)}
              for tipo, campo in (("titulo", "headline"), ("apoio", "lede")) if historia.get(campo)]
    linhas += [{**ctx, "tipo": "destaque", "tom": h.get("tone"), "texto": _preencher(h.get("text"), p)}
               for h in historia.get("highlights") or [] if isinstance(h, dict)]
    return _tabela(linhas, "get_destaques_publicados", numericas=())


def get_atualizacao_publicada(ambiente: Optional[str] = None) -> pd.DataFrame:
    """Quando cada carga foi publicada pela última vez nos JSON do ambiente.

    Returns:
        pd.DataFrame: colunas `carga`, `publicado_em` (data e hora UTC da carga publicada), `ambiente`.

    Example:
        >>> from sdic_libraries import get_atualizacao_publicada
        >>> get_atualizacao_publicada(ambiente="homologacao")
    """
    amb = config.ambiente(ambiente)
    marcas = ler_json_publicado("dados", f"{amb}/_publicado.json")
    return pd.DataFrame([{"carga": c, "publicado_em": quando, "ambiente": amb} for c, quando in sorted(marcas.items())],
                        columns=_colunas("get_atualizacao_publicada"))
