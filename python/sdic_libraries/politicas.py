"""Políticas da SDIC publicadas pelo `gaia_nib/politicas_sdic` (só leitura).

O `gaia_nib` é o dono do conteúdo, da ordem e do que é permitido mostrar; aqui os JSON
publicados viram tabelas. Regras que a biblioteca respeita e quem usa também deve respeitar:

- a ordem é a do catálogo publicado; nenhuma função reordena políticas entre si;
- políticas têm unidades diferentes (R$, atendimentos, projetos): **não some nem compare
  valores de políticas ou de indicadores com unidades diferentes**;
- campo ausente fica nulo; nenhum texto é inventado aqui.

Origem `politicas` do catálogo (`SDIC_PAGES_URL`), ambiente de `SDIC_AMBIENTE`.
"""
from __future__ import annotations

import warnings
from typing import Any, List, Optional

import pandas as pd

from . import config
from .config import CATALOGO
from .publicados import _numero, unidade
from .transporte import NaoPublicado, ler_json_publicado

SCHEMA_MAIOR = "1"


def _colunas(funcao: str) -> List[str]:
    return [c[0] for c in CATALOGO["colunas"][funcao]]


def _catalogo(ambiente: Optional[str]) -> dict:
    amb = config.ambiente(ambiente)
    try:
        catalogo = ler_json_publicado("politicas", f"{amb}/politicas_catalogo.json")
    except NaoPublicado as e:
        raise NaoPublicado(f"As políticas não estão publicadas em {amb!r} ({e.endpoint}). "
                           "Em homologação elas podem existir: ambiente='homologacao'.",
                           status_code=e.status_code, endpoint=e.endpoint) from e
    versao = str(catalogo.get("schema_version", "1"))
    if versao.split(".")[0] != SCHEMA_MAIOR:
        raise ValueError(f"O catálogo de políticas está no esquema {versao}, que esta versão da biblioteca não lê. Atualize-a.")
    return catalogo


def _pasta(uf: Optional[str]) -> str:
    u = unidade(uf)
    return "nacional" if u == "BRASIL" else u


def listar_politicas(ambiente: Optional[str] = None) -> pd.DataFrame:
    """Políticas publicadas, na ordem do catálogo publicado pelo gaia_nib.

    Args:
        ambiente (str, optional): 'producao' ou 'homologacao'.

    Returns:
        pd.DataFrame: uma linha por política, com os campos do catálogo (`id`, `nome`, `sigla`,
        `departamento`, `categoria`, `regionalizavel`, `ordem`, `file`, e outros que o gaia_nib
        publicar) e `permitida` (se está em `politicas_permitidas.json`, o recorte dos subsídios).

    Example:
        >>> from sdic_libraries import listar_politicas
        >>> listar_politicas(ambiente="homologacao")[["id", "sigla", "permitida"]]
    """
    amb = config.ambiente(ambiente)
    entradas = _catalogo(amb).get("politicas_catalogo") or []
    permitidas = set(ler_json_publicado("politicas", f"{amb}/politicas_permitidas.json").get("politicas") or [])
    df = pd.DataFrame(entradas)
    for coluna in _colunas("listar_politicas")[:-1]:
        if coluna not in df.columns:
            df[coluna] = None
    df["permitida"] = df["id"].isin(permitidas)
    primeiras = _colunas("listar_politicas")[:-1]
    return df[primeiras + [c for c in df.columns if c not in primeiras]]


def get_politica_publicada(id: str, uf: Optional[str] = None, ambiente: Optional[str] = None) -> Optional[dict]:
    """JSON completo de uma política para uma UF, ou para o Brasil (`uf=None`).

    Baixo nível: devolve o dicionário como publicado (inclui `story`, `ressalvas`, `charts`).
    Devolve None quando a política não publica dado para essa unidade, o que é esperado
    (nem toda política é regionalizável).

    Example:
        >>> from sdic_libraries import get_politica_publicada
        >>> get_politica_publicada("b_mais_p", uf="SP", ambiente="homologacao")["ressalvas"]
    """
    amb = config.ambiente(ambiente)
    try:
        return ler_json_publicado("politicas", f"{amb}/{_pasta(uf)}/politicas/{id}.json")
    except NaoPublicado:
        return None


def _linhas_politica(payload: dict, uf: Optional[str]) -> List[dict]:
    comum = {"policy_id": payload.get("policy_id"), "nome": payload.get("nome"), "sigla": payload.get("sigla"),
             "uf": unidade(uf), "fonte": payload.get("source"), "referencia": payload.get("reference"),
             "atualizado_em": payload.get("updated_at")}
    itens = [("capa", payload.get("capa_kpi")), ("secundario", payload.get("capa_kpi_secundario"))]
    itens += [("modalidade", m) for m in payload.get("capa_kpi_modalidades") or []]
    return [{**comum, "papel": papel, "id": k.get("id"), "rotulo": k.get("label"), "valor": _numero(k.get("value")),
             "valor_exibido": k.get("display_value"), "unidade": k.get("unit") or None, "periodo": k.get("period"),
             "variacao_rotulo": (k.get("delta") or {}).get("label")}
            for papel, k in itens if isinstance(k, dict)]


def _tabela_politica(linhas: List[dict]) -> pd.DataFrame:
    df = pd.DataFrame(linhas, columns=_colunas("get_politica"))
    df["valor"] = pd.to_numeric(df["valor"], errors="coerce")
    return df


def get_politica(id: str, uf: Optional[str] = None, ambiente: Optional[str] = None) -> pd.DataFrame:
    """Indicadores de uma política, um por linha: o de capa, o secundário e as modalidades.

    Args:
        id (str): id da política (veja `listar_politicas()['id']`), ex.: 'b_mais_p'.
        uf (str, optional): sigla da UF; None ou 'BRASIL' para o recorte nacional.
        ambiente (str, optional): 'producao' ou 'homologacao'.

    Returns:
        pd.DataFrame: colunas `policy_id`, `nome`, `sigla`, `uf`, `papel` ('capa', 'secundario'
        ou 'modalidade'), `id`, `rotulo`, `valor`, `valor_exibido`, `unidade`, `periodo`,
        `variacao_rotulo`, `fonte`, `referencia`, `atualizado_em`. Tabela vazia (com as colunas)
        se a política não publica dado para essa unidade. As unidades variam entre linhas:
        não some a coluna `valor`.

    Example:
        >>> from sdic_libraries import get_politica
        >>> get_politica("b_mais_p", uf="SP", ambiente="homologacao")[["papel", "rotulo", "valor_exibido"]]
    """
    payload = get_politica_publicada(id, uf, ambiente)
    return _tabela_politica(_linhas_politica(payload, uf) if payload else [])


def get_politicas_estado(uf: Optional[str], ambiente: Optional[str] = None, so_permitidas: bool = False) -> pd.DataFrame:
    """Indicadores de todas as políticas publicadas para uma UF (ou para o Brasil), na ordem do catálogo.

    Args:
        uf (str): sigla da UF; None ou 'BRASIL' para o recorte nacional.
        ambiente (str, optional): 'producao' ou 'homologacao'.
        so_permitidas (bool): só as políticas de `politicas_permitidas.json` (recorte dos subsídios).

    Returns:
        pd.DataFrame: as colunas de `get_politica`, política após política na ordem publicada.
        Políticas sem dado para a unidade ficam de fora. Não some nem ordene por `valor`:
        as unidades são diferentes.

    Example:
        >>> from sdic_libraries import get_politicas_estado
        >>> get_politicas_estado("SP", ambiente="homologacao")
    """
    catalogo = listar_politicas(ambiente)
    if so_permitidas:
        catalogo = catalogo[catalogo["permitida"]]
    linhas: List[dict] = []
    for pid in catalogo["id"]:
        payload = get_politica_publicada(pid, uf, ambiente)
        if payload:
            linhas += _linhas_politica(payload, uf)
    return _tabela_politica(linhas)


def get_resumo_politicas(uf: Optional[str] = None, ambiente: Optional[str] = None) -> pd.DataFrame:
    """Resumo publicado das políticas de uma UF ou do Brasil: uma linha.

    Returns:
        pd.DataFrame: colunas `uf`, `nome_uf`, `n_politicas`, `recursos`, `recursos_exibido`,
        `atendimentos`, `atendimentos_exibido`, `ranking_posicao`, `ranking_de`,
        `ranking_exibido`, `nota_agregacao`. Leia `nota_agregacao` antes de usar os totais.
        Tabela vazia se a unidade não tem resumo publicado.

    Example:
        >>> from sdic_libraries import get_resumo_politicas
        >>> get_resumo_politicas("SP", ambiente="homologacao")
    """
    amb = config.ambiente(ambiente)
    colunas = _colunas("get_resumo_politicas")
    try:
        r = ler_json_publicado("politicas", f"{amb}/{_pasta(uf)}/resumo_politicas.json")
    except NaoPublicado:
        return pd.DataFrame(columns=colunas)
    recursos, atend, rank = r.get("recursos") or {}, r.get("atendimentos") or {}, r.get("ranking_nacional") or {}
    return pd.DataFrame([{
        "uf": unidade(uf), "nome_uf": r.get("nome_uf"), "n_politicas": r.get("n_politicas"),
        "recursos": _numero(recursos.get("value")), "recursos_exibido": recursos.get("display_value"),
        "atendimentos": _numero(atend.get("value")), "atendimentos_exibido": atend.get("display_value"),
        "ranking_posicao": rank.get("posicao"), "ranking_de": rank.get("de"), "ranking_exibido": rank.get("display"),
        "nota_agregacao": r.get("nota_agregacao")}], columns=colunas)


def get_municipios_elegiveis(ambiente: Optional[str] = None) -> pd.DataFrame:
    """Municípios com políticas publicadas.

    Returns:
        pd.DataFrame: colunas `ibge` (texto, 7 dígitos), `municipio`, `uf`.

    Example:
        >>> from sdic_libraries import get_municipios_elegiveis
        >>> get_municipios_elegiveis(ambiente="homologacao").query("uf == 'AC'")
    """
    df = pd.DataFrame(_catalogo(ambiente).get("municipios_elegiveis") or [], columns=_colunas("get_municipios_elegiveis"))
    return df.astype("string")


def get_manifesto_politicas(ambiente: Optional[str] = None) -> pd.DataFrame:
    """Rótulo da fonte, diretorias exibidas e notas publicadas junto com as políticas.

    Returns:
        pd.DataFrame: colunas `campo` ('rotulo_fonte', 'diretoria' ou 'nota'), `id` (das notas), `valor`.
        Vazia se o catálogo publicado não tiver manifesto.

    Example:
        >>> from sdic_libraries import get_manifesto_politicas
        >>> get_manifesto_politicas(ambiente="homologacao")
    """
    m = _catalogo(ambiente).get("manifesto") or {}
    linhas: List[Any] = []
    if m.get("rotulo_fonte"):
        linhas.append(("rotulo_fonte", None, m["rotulo_fonte"]))
    linhas += [("diretoria", None, d) for d in m.get("diretorias_exibidas") or []]
    linhas += [("nota", n.get("id"), n.get("texto")) for n in m.get("notas") or [] if isinstance(n, dict)]
    return pd.DataFrame(linhas, columns=_colunas("get_manifesto_politicas"))
