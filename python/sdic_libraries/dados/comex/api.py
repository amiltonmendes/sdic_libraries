"""
Comex API client para acessar dados de comércio exterior brasileiro

Cliente Python para os endpoints de comércio exterior (comex) da sdic_api,
centralizando o acesso que hoje está espalhado em chamadas diretas à API
pública do MDIC (ComexStat) em múltiplos consumidores da unidade.

Mesma estrutura de `dados.emprego.api` (mesmo padrão de configuração via
`.env`, tratamento de erro e paginação automática) — ver aquele módulo para
o desenho original.
"""

from __future__ import annotations

import inspect
import logging
import os
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

import pandas as pd
import requests

from ...transporte import ClienteAPI, SdicErro


class ComexAPIError(SdicErro):
    """Erro da API de Comex (tem `status_code` e `endpoint`)."""


class Comex(ClienteAPI):
    """
    Cliente para acessar dados de comércio exterior (comex) via sdic_api.

    Attributes:
        base_url (str): URL base da sdic_api
        timeout (int): Timeout das requisições em segundos
        session (requests.Session): Sessão HTTP para pool de conexões
    """

    erro = ComexAPIError
    _paginacao_no_corpo = True  # `/exportacao_agregada_ncm` espera `pagina` também no corpo

    def __init__(self, base_url: Optional[str] = None, timeout: Optional[int] = None, api_key: Optional[str] = None):
        """
        Args:
            base_url (str, optional): URL da sdic_api (padrão: `SDIC_API_URL` ou o endereço público).
            timeout (int, optional): segundos por requisição (padrão: `SDIC_TIMEOUT` ou 30).
            api_key (str, optional): chave individual (padrão: `SDIC_API_KEY`).
        """
        super().__init__(base_url=base_url, timeout=timeout, api_key=api_key)
        self._ncm_isic_mapa_cache: Optional[List[Dict[str, Any]]] = None

    # ========== NCM (nacional) ==========

    def _ncms_da_secao(self, secao: str) -> set:
        """Códigos NCM pertencentes a uma seção ISIC (aceita a letra, ex. `C`,
        ou o nome por extenso, ex. `Indústria de Transformação`)."""
        mapa = self.get_ncm_isic_mapa()
        return {
            linha['NCM'] for linha in mapa
            if secao in (linha.get('SecaoISIC'), linha.get('NomeSecaoISIC'), linha.get('CodigoSecaoISIC'))
        }

    def _get_ncm_nacional_mensal(self, endpoint: str, ano_minimo: int = None, mes_maximo: int = None,
                                  anos: List[int] = None, lista_ncms: List[Union[int, str]] = None,
                                  secao: str = None, agregado_ano: bool = False) -> List[Dict[str, Any]]:
        body: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'anos': anos or [],
            # NCM como texto de 8 dígitos (CO_NCM é STRING no BigQuery desde 08/10/2026);
            # aceita 4032000 ou "04032000" e funciona com a sdic_api 2.x e 3.x.
            'lista_ncms': [str(int(str(n).strip())).zfill(8) for n in (lista_ncms or [])],
            'agregado_ano': agregado_ano,
        }
        items = self._fetch_all_paginated_post(endpoint, body, {})
        if secao:
            ncms_da_secao = self._ncms_da_secao(secao)
            items = [item for item in items if item.get('NCM') in ncms_da_secao]
        return items

    def get_exportacao_ncm_nacional_mensal(self, ano_minimo: int = None, mes_maximo: int = None,
                                            anos: List[int] = None, lista_ncms: List[Union[int, str]] = None,
                                            secao: str = None, agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Exportações nacionais agregadas por NCM (`/exportacao_agregada_ncm`).

        `secao`, quando informada, filtra os NCMs pela seção ISIC correspondente
        (usando `get_ncm_isic_mapa`, cacheado em memória na instância) — o
        endpoint de origem não carrega essa informação. `agregado_ano`, quando
        `True`, soma no próprio BigQuery e devolve 1 linha por (ano, NCM) em vez
        de 1 por (ano, mês, NCM) — bem mais barato quando o consumidor só quer o
        total anual (é o caso mais comum; evita paginar e somar mês a mês aqui).
        """
        return self._get_ncm_nacional_mensal('/exportacao_agregada_ncm', ano_minimo, mes_maximo, anos, lista_ncms, secao, agregado_ano)

    def get_importacao_ncm_nacional_mensal(self, ano_minimo: int = None, mes_maximo: int = None,
                                            anos: List[int] = None, lista_ncms: List[Union[int, str]] = None,
                                            secao: str = None, agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Importações nacionais agregadas por NCM (`/importacao_agregada_ncm`). Ver `get_exportacao_ncm_nacional_mensal`."""
        return self._get_ncm_nacional_mensal('/importacao_agregada_ncm', ano_minimo, mes_maximo, anos, lista_ncms, secao, agregado_ano)

    # ========== ISIC DIVISÃO (nacional) ==========

    def get_exportacao_isic_divisao_nacional_mensal(self, ano_minimo: int = None, mes_maximo: int = None,
                                                      secao: str = None, divisao: int = None,
                                                      agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Exportações nacionais por divisão ISIC (`/exportacao_isic_divisao`)."""
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'secao': secao or '',
            'agregado_ano': agregado_ano,
        }
        if divisao is not None:
            params['divisao'] = divisao
        return self._fetch_all_paginated_get('/exportacao_isic_divisao', params)

    def get_importacao_isic_divisao_nacional_mensal(self, ano_minimo: int = None, mes_maximo: int = None,
                                                      secao: str = None, divisao: int = None,
                                                      agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Importações nacionais por divisão ISIC (`/importacao_isic_divisao`)."""
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'secao': secao or '',
            'agregado_ano': agregado_ano,
        }
        if divisao is not None:
            params['divisao'] = divisao
        return self._fetch_all_paginated_get('/importacao_isic_divisao', params)

    # ========== ISIC DIVISÃO (estadual, por país) ==========

    def get_exportacao_isic_divisao_estadual_mensal(self, estado: str = None, pais: str = None,
                                                       ano_minimo: int = None, mes_maximo: int = None,
                                                       secao: str = None, divisao: int = None,
                                                       bloco: int = None, agregado_ano: bool = False,
                                                       agregado_pais: bool = False) -> List[Dict[str, Any]]:
        """Exportações por UF, país e divisão ISIC (`/exportacao_uf_isic_divisao`).

        `bloco`: código de bloco econômico (`pais_bloco.CO_BLOCO`, ex. `22`
        para União Europeia) para filtrar por um recorte de países sem listar
        cada um manualmente. `agregado_pais`, quando `True`, soma o FOB entre
        países no próprio BigQuery e não devolve a coluna `Pais` — bem mais
        barato quando o consumidor só quer o total por UF/divisão (o item
        `Pais` some da resposta em vez de vir repetido por país).
        """
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'estado': estado or '',
            'pais': pais or '',
            'secao': secao or '',
            'agregado_ano': agregado_ano,
            'agregado_pais': agregado_pais,
        }
        if divisao is not None:
            params['divisao'] = divisao
        if bloco is not None:
            params['bloco'] = bloco
        return self._fetch_all_paginated_get('/exportacao_uf_isic_divisao', params)

    def get_importacao_isic_divisao_estadual_mensal(self, estado: str = None, pais: str = None,
                                                       ano_minimo: int = None, mes_maximo: int = None,
                                                       secao: str = None, divisao: int = None,
                                                       bloco: int = None, agregado_ano: bool = False,
                                                       agregado_pais: bool = False) -> List[Dict[str, Any]]:
        """Importações por UF, país e divisão ISIC (`/importacao_uf_isic_divisao`). Ver `get_exportacao_isic_divisao_estadual_mensal`."""
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'estado': estado or '',
            'pais': pais or '',
            'secao': secao or '',
            'agregado_ano': agregado_ano,
            'agregado_pais': agregado_pais,
        }
        if divisao is not None:
            params['divisao'] = divisao
        if bloco is not None:
            params['bloco'] = bloco
        return self._fetch_all_paginated_get('/importacao_uf_isic_divisao', params)

    # ========== PAÍS (nacional) ==========

    def get_exportacao_pais_nacional_mensal(self, pais: str = None, secao: str = None,
                                             ano_minimo: int = None, mes_maximo: int = None,
                                             agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Exportações nacionais por país (`/exportacao_pais`)."""
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'pais': pais or '',
            'secao': secao or '',
            'agregado_ano': agregado_ano,
        }
        return self._fetch_all_paginated_get('/exportacao_pais', params)

    def get_importacao_pais_nacional_mensal(self, pais: str = None, secao: str = None,
                                             ano_minimo: int = None, mes_maximo: int = None,
                                             agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Importações nacionais por país (`/importacao_pais`)."""
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'pais': pais or '',
            'secao': secao or '',
            'agregado_ano': agregado_ano,
        }
        return self._fetch_all_paginated_get('/importacao_pais', params)

    # ========== CATÁLOGO NCM -> ISIC ==========

    def get_ncm_isic_mapa(self) -> List[Dict[str, Any]]:
        """Catálogo NCM -> ISIC (divisão e seção), `/ncm_isic_mapa`.

        Catálogo estático (~13 mil códigos) — buscado uma vez e cacheado em
        memória na instância; chamadas seguintes não fazem nova requisição.
        """
        if self._ncm_isic_mapa_cache is None:
            self._ncm_isic_mapa_cache = self._fetch_all_paginated_get('/ncm_isic_mapa', {})
        return self._ncm_isic_mapa_cache

    # ========== AGRUPAMENTOS ==========
    #
    # `agrupamento` é um nome de estudo setorial pré-definido no BigQuery
    # (`parametros_unidade`), com um Departamento e Coordenação-Geral (CG) responsáveis
    # — não um filtro livre. Descubra o nome com `get_agrupamentos_disponiveis()`. O
    # mesmo nome pode existir sob departamentos/CGs diferentes (não ocorre hoje nos
    # dados, mas o retorno sempre traz as duas colunas para desambiguar no seu código;
    # filtre por `departamento`/`cg` se já souber qual).
    # PENDENTE DE DEPLOY (2026-09-29): a sdic_api ainda não tem essas colunas/parâmetros
    # em produção — ver TODO.md.

    def get_exportacao_agrupamentos(self, agrupamento: str, ano_minimo: int = None,
                                     anos: List[int] = None, departamento: str = None,
                                     cg: str = None) -> List[Dict[str, Any]]:
        """Exportações anuais por Agrupamento/Setor/Subsetor/Produto (`/exportacao_agrupamentos`)."""
        return self._get_movimentacoes_agrupamentos('/exportacao_agrupamentos', agrupamento, ano_minimo, anos, departamento, cg)

    def get_importacao_agrupamentos(self, agrupamento: str, ano_minimo: int = None,
                                     anos: List[int] = None, departamento: str = None,
                                     cg: str = None) -> List[Dict[str, Any]]:
        """Importações anuais por Agrupamento/Setor/Subsetor/Produto (`/importacao_agrupamentos`)."""
        return self._get_movimentacoes_agrupamentos('/importacao_agrupamentos', agrupamento, ano_minimo, anos, departamento, cg)

    def _get_movimentacoes_agrupamentos(self, endpoint: str, agrupamento: str, ano_minimo: int,
                                         anos: List[int], departamento: str, cg: str) -> List[Dict[str, Any]]:
        params: Dict[str, Any] = {'agrupamento': agrupamento}
        if ano_minimo is not None:
            params['ano_minimo'] = ano_minimo
        if anos:
            params['anos'] = ','.join(str(ano) for ano in anos)
        if departamento:
            params['departamento'] = departamento
        if cg:
            params['cg'] = cg
        return self._fetch_all_paginated_get(endpoint, params)

    def get_exportacao_agrupamentos_pais_ncm(self, agrupamento: str, ano_minimo: int = None,
                                              mes_maximo: int = None, nivel_agregacao: str = None,
                                              agregado_ano: bool = False, posicao: int = None,
                                              departamento: str = None, cg: str = None) -> List[Dict[str, Any]]:
        """Exportações por Agrupamento, desagregadas por país e NCM (`/exportacao_agrupamentos_pais_ncm`).

        `nivel_agregacao`: None/'' (detalhe completo, com país e NCM) ou 'setor'/'subsetor'/'produto'
        (soma nesse nível, sem país nem NCM). `posicao`: ranking por VLFob dentro de cada grupo.
        """
        return self._get_movimentacoes_agrupamentos_pais_ncm(
            '/exportacao_agrupamentos_pais_ncm', agrupamento, ano_minimo, mes_maximo,
            nivel_agregacao, agregado_ano, posicao, departamento, cg)

    def get_importacao_agrupamentos_pais_ncm(self, agrupamento: str, ano_minimo: int = None,
                                              mes_maximo: int = None, nivel_agregacao: str = None,
                                              agregado_ano: bool = False, posicao: int = None,
                                              departamento: str = None, cg: str = None) -> List[Dict[str, Any]]:
        """Importações por Agrupamento, desagregadas por país e NCM (`/importacao_agrupamentos_pais_ncm`). Ver `get_exportacao_agrupamentos_pais_ncm`."""
        return self._get_movimentacoes_agrupamentos_pais_ncm(
            '/importacao_agrupamentos_pais_ncm', agrupamento, ano_minimo, mes_maximo,
            nivel_agregacao, agregado_ano, posicao, departamento, cg)

    def _get_movimentacoes_agrupamentos_pais_ncm(self, endpoint: str, agrupamento: str, ano_minimo: int,
                                                  mes_maximo: int, nivel_agregacao: str, agregado_ano: bool,
                                                  posicao: int, departamento: str, cg: str) -> List[Dict[str, Any]]:
        params: Dict[str, Any] = {'agrupamento': agrupamento, 'agregado_ano': agregado_ano}
        if ano_minimo is not None:
            params['ano_minimo'] = ano_minimo
        if mes_maximo is not None:
            params['mes_maximo'] = mes_maximo
        if nivel_agregacao:
            params['nivel_agregacao'] = nivel_agregacao
        if posicao is not None:
            params['posicao'] = posicao
        if departamento:
            params['departamento'] = departamento
        if cg:
            params['cg'] = cg
        return self._fetch_all_paginated_get(endpoint, params)

    def get_agrupamentos_disponiveis(self, departamento: str = None, cg: str = None) -> List[Dict[str, Any]]:
        """Catálogo de agrupamentos de comex (`/agrupamentos_disponiveis`), 1 registro por
        (Agrupamento, Departamento, CG) — use para descobrir o nome a passar em `agrupamento=`
        nos outros métodos de agrupamentos, opcionalmente já filtrado."""
        params: Dict[str, Any] = {}
        if departamento:
            params['departamento'] = departamento
        if cg:
            params['cg'] = cg
        response = self._make_request('/agrupamentos_disponiveis', params)
        return self._extract_items(response)

    def close(self):
        """Fechar a sessão HTTP"""
        if hasattr(self, 'session'):
            self.session.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


# ========== FUNÇÕES DE CONVENIÊNCIA (DataFrame) ==========
#
# A classe `Comex` devolve os registros crus da sdic_api (List[Dict], colunas em
# PascalCase). As funções abaixo — mesmos nomes e parâmetros dos métodos — devolvem
# um DataFrame com o esquema padrão da biblioteca (snake_case, tipos fixos), o mesmo
# do R. Contrato: `contrato/comex_amostras.json`.

_COLUNAS = {
    'Ano': 'ano', 'Mes': 'mes',
    'NCM': 'ncm', 'DescricaoNCM': 'ncm_desc',
    'DivisaoISIC': 'divisao_isic_cod', 'NomeDivisaoISIC': 'divisao_isic_desc',
    'SecaoISIC': 'secao_isic_desc',  # nos fluxos vem o NOME da seção; no mapa, a letra
    'NomeSecaoISIC': 'secao_isic_desc',
    'QTEstat': 'quantidade_estatistica', 'QuantidadeEstatistica': 'quantidade_estatistica',
    'KgLiquido': 'kg_liquido', 'KGLiquido': 'kg_liquido', 'VLFob': 'vl_fob',
    'UF': 'uf', 'Pais': 'pais', 'Regiao': 'regiao',
    'Agrupamento': 'agrupamento', 'Setor': 'setor', 'Subsetor': 'subsetor', 'Produto': 'produto',
    'Departamento': 'departamento', 'CoordenacaoGeral': 'coordenacao_geral',
}


def _para_df(itens: List[Dict[str, Any]], mapa: bool = False) -> pd.DataFrame:
    """Registros da sdic_api -> DataFrame com colunas snake_case e tipos fixos.

    `ncm` (8 dígitos) e `divisao_isic_cod` (2 dígitos) viram texto com zeros à
    esquerda; `ano`/`mes` são Int64 (`mes` é nulo quando `agregado_ano=True`).
    """
    df = pd.DataFrame(itens)
    if df.empty:
        return df
    renomear = dict(_COLUNAS)
    if 'QTEstat' in df and 'QuantidadeEstatistica' in df:  # API nova traz os dois (QTEstat é obsoleto)
        df = df.drop(columns='QTEstat')
    if mapa:
        if 'CodigoSecaoISIC' in df:  # API nova: `SecaoISIC` já é o nome; a letra vem em `CodigoSecaoISIC`
            df = df.drop(columns='NomeSecaoISIC', errors='ignore')
            renomear['CodigoSecaoISIC'] = 'secao_isic_cod'
        else:  # API antiga: `SecaoISIC` é a letra
            renomear['SecaoISIC'] = 'secao_isic_cod'
    df = df.rename(columns=renomear)
    for col, largura in (('ncm', 8), ('divisao_isic_cod', 2)):
        if col in df:  # nulo (ex.: `nivel_agregacao` sem NCM) continua nulo, não vira "0000None"
            df[col] = df[col].where(df[col].isna(), df[col].astype(str).str.zfill(largura))
    if 'ano' in df:  # o mapa NCM x ISIC é um catálogo, sem período
        if 'mes' not in df:
            df['mes'] = None
        for col in ('ano', 'mes'):
            df[col] = pd.to_numeric(df[col]).astype('Int64')
    for col in ('vl_fob', 'kg_liquido', 'quantidade_estatistica'):
        if col in df:
            df[col] = pd.to_numeric(df[col])
    return df


def _funcao_df(nome: str, mapa: bool = False):
    metodo = getattr(Comex, nome)

    def funcao(**kwargs) -> pd.DataFrame:
        with Comex() as api:
            return _para_df(getattr(api, nome)(**kwargs), mapa=mapa)

    # Mantém a assinatura do método (sem `self`) para o autocompletar do usuário.
    parametros = list(inspect.signature(metodo).parameters.values())[1:]
    funcao.__signature__ = inspect.Signature(
        [p.replace(kind=inspect.Parameter.KEYWORD_ONLY) for p in parametros],
        return_annotation=pd.DataFrame,
    )
    funcao.__name__ = nome
    funcao.__doc__ = (metodo.__doc__ or '') + '\n\nRetorna um pandas.DataFrame com o esquema padrão (ver `_para_df`).'
    return funcao


get_exportacao_ncm_nacional_mensal = _funcao_df('get_exportacao_ncm_nacional_mensal')
get_importacao_ncm_nacional_mensal = _funcao_df('get_importacao_ncm_nacional_mensal')
get_exportacao_isic_divisao_nacional_mensal = _funcao_df('get_exportacao_isic_divisao_nacional_mensal')
get_importacao_isic_divisao_nacional_mensal = _funcao_df('get_importacao_isic_divisao_nacional_mensal')
get_exportacao_isic_divisao_estadual_mensal = _funcao_df('get_exportacao_isic_divisao_estadual_mensal')
get_importacao_isic_divisao_estadual_mensal = _funcao_df('get_importacao_isic_divisao_estadual_mensal')
get_exportacao_pais_nacional_mensal = _funcao_df('get_exportacao_pais_nacional_mensal')
get_importacao_pais_nacional_mensal = _funcao_df('get_importacao_pais_nacional_mensal')
get_ncm_isic_mapa = _funcao_df('get_ncm_isic_mapa', mapa=True)
get_exportacao_agrupamentos = _funcao_df('get_exportacao_agrupamentos')
get_importacao_agrupamentos = _funcao_df('get_importacao_agrupamentos')
get_exportacao_agrupamentos_pais_ncm = _funcao_df('get_exportacao_agrupamentos_pais_ncm')
get_importacao_agrupamentos_pais_ncm = _funcao_df('get_importacao_agrupamentos_pais_ncm')
get_agrupamentos_disponiveis = _funcao_df('get_agrupamentos_disponiveis')
