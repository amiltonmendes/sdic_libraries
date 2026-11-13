"""Séries da sdic_api (`/series`): uma função para todas as bases publicadas lá.

`listar_series()` diz o que existe; `get_serie(nome, ...)` devolve os valores;
`get_dimensao_serie(nome, dimensao)` devolve os nomes dos códigos.
"""
from __future__ import annotations

from typing import Any, Optional

import pandas as pd

from .transporte import ClienteAPI, SdicErro

_TIPOS_PANDAS = {"STRING": "string", "INT64": "Int64", "BOOL": "boolean"}


def _texto(v: Any) -> str:
    if isinstance(v, dict):
        return ", ".join(v)
    if isinstance(v, (list, tuple)):
        return ", ".join(str(i) for i in v)
    return "" if v is None else str(v)


def _catalogo(cliente: ClienteAPI) -> list:
    return cliente._make_request("/series")


def listar_series() -> pd.DataFrame:
    """Séries que a sdic_api publica em `/series`.

    Returns:
        pd.DataFrame: uma linha por série, colunas `nome`, `descricao`, `fonte`, `colunas`,
        `filtros`, `obrigatorios`, `periodo`, `dimensoes` (listas como texto separado por vírgula).

    Example:
        >>> from sdic_libraries import listar_series
        >>> listar_series()[["nome", "descricao", "filtros"]]
    """
    colunas = ["nome", "descricao", "fonte", "colunas", "filtros", "obrigatorios", "periodo", "dimensoes"]
    with ClienteAPI() as cliente:
        linhas = _catalogo(cliente)
    return pd.DataFrame([{c: _texto(l.get(c)) for c in colunas} for l in linhas], columns=colunas)


def _como_lista(v: Any) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (list, tuple, set)):
        return ",".join(_como_lista(i) for i in v)
    return str(v)


def get_serie(nome: str, desde: Optional[Any] = None, ate: Optional[Any] = None,
              com_nomes: bool = False, **filtros: Any) -> pd.DataFrame:
    """Valores de uma série de `/series`, com todas as páginas.

    Args:
        nome (str): nome da série (veja `listar_series()`), ex.: 'sidra_producao'.
        desde, ate: início e fim do período, inclusive. Data 'AAAA-MM-DD' ou ano, conforme a
            coluna `periodo` da série.
        com_nomes (bool): junta, para cada código que tenha dimensão (`cod_variavel`,
            `cod_categoria`, `cod_localidade`, `cod_atividade`), a coluna `<dimensão>_nome`.
        **filtros: filtros pelos nomes das colunas (os de `listar_series()['filtros']`), com um
            valor ou uma lista: ``sg_uf=['SP', 'RJ']``, ``cod_tabela=8888``.

    Returns:
        pd.DataFrame: as colunas da série, na ordem publicada. Códigos de filtro do tipo texto
        ficam como texto (zeros à esquerda preservados); `valor`, quando existe, vira número
        (o SIDRA publica texto; `-` e `...` viram nulo, e o motivo fica em `simbolo`).
        Sem linhas: tabela vazia com as mesmas colunas.

    Raises:
        SdicErro: série desconhecida (404), filtro inválido ou obrigatório ausente (422), sem chave (401).

    Example:
        >>> from sdic_libraries import get_serie
        >>> get_serie("sidra_producao", cod_tabela=8888, cod_localidade="35", desde="2025-01-01")
        >>> get_serie("contas_regionais_vab", sg_uf="SP", com_nomes=True)
    """
    params = {k: _como_lista(v) for k, v in filtros.items() if v is not None}
    if desde is not None:
        params["desde"] = str(desde)
    if ate is not None:
        params["ate"] = str(ate)
    with ClienteAPI() as cliente:
        definicao = next((s for s in _catalogo(cliente) if s.get("nome") == nome), None)
        if definicao is None:
            raise SdicErro(f"Série desconhecida: {nome!r}. Veja listar_series().", status_code=404,
                           endpoint=f"/series/{nome}")
        itens = cliente._fetch_all_paginated_get(f"/series/{nome}", params)
        df = pd.DataFrame(itens, columns=definicao["colunas"])
        for coluna, tipo in (definicao.get("filtros") or {}).items():
            if coluna in df.columns and tipo in _TIPOS_PANDAS:
                df[coluna] = df[coluna].astype(_TIPOS_PANDAS[tipo])
        if "valor" in df.columns:
            df["valor"] = pd.to_numeric(df["valor"], errors="coerce")
        if com_nomes:
            for dimensao in definicao.get("dimensoes") or []:
                df = _juntar_nomes(df, dimensao, cliente._make_request(f"/series/{nome}/dimensoes/{dimensao}"))
    return df


def _juntar_nomes(df: pd.DataFrame, dimensao: str, linhas: list) -> pd.DataFrame:
    """Acrescenta `<dimensao>_nome` (e `unidade`, na dimensão de variáveis) pelas colunas em comum."""
    dim = pd.DataFrame(linhas)
    chaves = [c for c in dim.columns if c in df.columns]
    nome = "nome" if "nome" in dim.columns else dimensao
    if dimensao == "metadados" or not chaves or nome not in dim.columns or nome in chaves:
        return df
    extras = [c for c in ("unidade",) if c in dim.columns and c not in df.columns]
    dim = dim[chaves + [nome] + extras].drop_duplicates(chaves).rename(columns={nome: f"{dimensao}_nome"})
    for c in chaves:
        dim[c] = dim[c].astype(df[c].dtype)
    return df.merge(dim, on=chaves, how="left")


def get_dimensao_serie(nome: str, dimensao: str) -> pd.DataFrame:
    """Códigos e nomes de uma dimensão de uma série.

    Args:
        nome (str): nome da série.
        dimensao (str): uma das dimensões de `listar_series()['dimensoes']`
            (ex.: 'variavel', 'categoria', 'localidade', 'metadados', 'atividade').

    Returns:
        pd.DataFrame: as colunas da tabela de dimensão (códigos e nomes), como publicadas.

    Example:
        >>> from sdic_libraries import get_dimensao_serie
        >>> get_dimensao_serie("sidra_producao", "variavel")
    """
    with ClienteAPI() as cliente:
        return pd.DataFrame(cliente._make_request(f"/series/{nome}/dimensoes/{dimensao}"))


def listar_referencias() -> pd.DataFrame:
    """Tabelas de de-para disponíveis na API (dataset `referencias`, mantido em `carga_base/referencias`).

    Returns:
        pd.DataFrame: colunas `nome`, `descricao`.

    Example:
        >>> from sdic_libraries import listar_referencias
        >>> listar_referencias()
    """
    with ClienteAPI() as cliente:
        return pd.DataFrame(cliente._make_request("/referencias"), columns=["nome", "descricao"])


def get_referencia(nome: str) -> pd.DataFrame:
    """Uma tabela de de-para inteira: CNAE, ISIC, CNAE x ISIC, municípios, intensidade tecnológica, agrupamentos NCM.

    Args:
        nome (str): um dos nomes de `listar_referencias()`, ex.: 'cnae', 'isic_cnae', 'municipio'.

    Returns:
        pd.DataFrame: as colunas da tabela, todas como texto (códigos com zeros à esquerda preservados).

    Example:
        >>> from sdic_libraries import get_referencia
        >>> get_referencia("isic_cnae")
    """
    with ClienteAPI() as cliente:
        return pd.DataFrame(cliente._make_request(f"/referencias/{nome}")).astype("string")
