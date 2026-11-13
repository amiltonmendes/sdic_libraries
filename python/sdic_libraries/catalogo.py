"""Catálogo das funções e das bases da biblioteca.

Tudo vem de `catalogo.json` (cópia de `contrato/catalogo.json`, a fonte única lida também
pelo pacote R). Não sabe qual função usar? `listar_bases()`. Quer saber de onde vem um dado
e que colunas ele tem? `descrever(nome)`.
"""
from __future__ import annotations

from typing import Optional

import pandas as pd

from .config import CATALOGO, ORIGENS

COLUNAS = ["tema", "subtema", "nivel", "funcao", "descricao", "exemplo"]


def listar_bases(tema: Optional[str] = None, subtema: Optional[str] = None) -> pd.DataFrame:
    """Catálogo das funções públicas da biblioteca, opcionalmente filtrado.

    Args:
        tema (str, optional): 'emprego', 'comex', 'series', 'publicados', 'politicas' ou 'utilitarios'.
        subtema (str, optional): veja ``listar_bases()['subtema'].unique()``.

    Returns:
        pd.DataFrame: colunas `tema`, `subtema`, `nivel`, `funcao`, `descricao`, `exemplo`,
        uma linha por função. Todas se importam de ``sdic_libraries`` (ou de
        ``sdic_libraries.dados.emprego`` / ``.comex``, como antes).

    Example:
        >>> from sdic_libraries import listar_bases
        >>> listar_bases(tema="publicados")
    """
    df = pd.DataFrame(CATALOGO["funcoes"]).rename(columns={"exemplo_py": "exemplo"})[COLUNAS]
    for coluna, valor in (("tema", tema), ("subtema", subtema)):
        if valor:
            if valor not in set(df[coluna]):
                raise ValueError(f"{coluna} desconhecido: {valor!r}. Valores: {sorted(set(df[coluna]))}.")
            df = df[df[coluna] == valor]
    return df.reset_index(drop=True)


def descrever(nome: str) -> pd.DataFrame:
    """Ficha de uma base ou de uma função do catálogo.

    Args:
        nome (str): nome de uma base (ex.: 'secoes_publicadas', 'comexstat', 'politicas') ou de
            uma função (ex.: 'get_kpis_publicados'). Para uma série da API, use `listar_series()`.

    Returns:
        pd.DataFrame: colunas `campo`, `valor`. Para uma função: descrição, exemplo, base que
        lê, origem, e uma linha `coluna: <nome>` por coluna devolvida (tipo e significado). Para
        uma base: título, origem e endereço em uso, fonte, periodicidade, carga e funções.

    Example:
        >>> from sdic_libraries import descrever
        >>> descrever("get_kpis_publicados")
    """
    from . import config

    funcoes = {f["funcao"]: f for f in CATALOGO["funcoes"]}
    bases = CATALOGO["bases"]
    linhas = []

    def ficha_base(nome_base: str) -> None:
        b = bases[nome_base]
        linhas.append(("base", f"{nome_base}: {b['titulo']}"))
        linhas.append(("origem", f"{b['origem']} ({ORIGENS[b['origem']]['descricao']})"))
        linhas.append(("endereço em uso", config.url(b["origem"]) + (b.get("caminho") or "")
                       if not (b.get("caminho") or "").startswith("{") else f"{config.url(b['origem'])}/{b['caminho']}"))
        for campo, chave in (("fonte", "fonte"), ("periodicidade", "periodicidade"), ("dataset no BigQuery", "dataset"),
                             ("carga (painel de cargas)", "carga"), ("documentação", "documentacao"),
                             ("esquema", "esquema"), ("depreciada", "depreciada")):
            if b.get(chave):
                linhas.append((campo, b[chave]))

    if nome in funcoes:
        f = funcoes[nome]
        linhas += [("função", nome), ("descrição", f["descricao"]), ("exemplo", f["exemplo_py"])]
        if f.get("base"):
            ficha_base(f["base"])
        for coluna, tipo, significado in CATALOGO["colunas"].get(nome, []):
            linhas.append((f"coluna: {coluna}", " — ".join(p for p in (tipo, significado) if p)))
    elif nome in bases:
        ficha_base(nome)
        linhas += [("função", f["funcao"]) for f in CATALOGO["funcoes"] if f.get("base") == nome]
    else:
        raise ValueError(f"{nome!r} não está no catálogo. Bases: {sorted(bases)}. "
                         "Funções: listar_bases(). Séries da API: listar_series().")
    return pd.DataFrame(linhas, columns=["campo", "valor"])
