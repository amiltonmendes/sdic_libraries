"""
Funções de transformação e manipulação de dados

Este módulo contém funções para transformar dados, calcular índices,
e realizar outras operações estatísticas.
"""

from __future__ import annotations
from typing import Union, List
import pandas as pd
import numpy as np


def criar_indice(
    df: pd.DataFrame,
    ano_base: int, 
    coluna_data: str,
    colunas_valores: Union[str, List[str]]
) -> pd.DataFrame:
    """
    Cria índices para colunas de valores baseado em um ano de referência.
    
    Esta função calcula índices relativos ao ano base para as colunas especificadas,
    adicionando novas colunas com sufixo '_indice' ao dataframe original.
    
    Args:
        df: DataFrame com os dados a serem transformados
        ano_base: Ano de referência para o cálculo do índice (base = 100)
        coluna_data: Nome da coluna que contém as datas/anos
        colunas_valores: Nome da coluna ou lista de colunas para calcular índice
        
    Returns:
        DataFrame com as colunas originais mais as novas colunas de índice
        
    Raises:
        ValueError: Se o ano_base não existir na coluna de data
        ValueError: Se alguma das colunas especificadas não existir no DataFrame
        ValueError: Se a coluna de data não puder ser convertida para ano
        
    Examples:
        >>> df = pd.DataFrame({
        ...     'ano': [2020, 2021, 2022],
        ...     'vendas': [100, 120, 110],
        ...     'lucro': [50, 60, 55]
        ... })
        >>> df_com_indice = criar_indice(df, 2020, 'ano', ['vendas', 'lucro'])
        >>> print(df_com_indice)
           ano  vendas  lucro  vendas_indice  lucro_indice
        0  2020     100     50          100.0         100.0
        1  2021     120     60          120.0         120.0
        2  2022     110     55          110.0         110.0
    """
    # Validações de entrada
    if df.empty:
        raise ValueError("DataFrame não pode estar vazio")
        
    if coluna_data not in df.columns:
        raise ValueError(f"Coluna de data '{coluna_data}' não encontrada no DataFrame")
        
    # Converte colunas_valores para lista se for string
    if isinstance(colunas_valores, str):
        colunas_valores = [colunas_valores]
        
    # Verifica se todas as colunas de valores existem
    colunas_inexistentes = [col for col in colunas_valores if col not in df.columns]
    if colunas_inexistentes:
        raise ValueError(f"Colunas não encontradas no DataFrame: {colunas_inexistentes}")
        
    # Cria uma cópia do dataframe para não modificar o original
    df_resultado = df.copy()
    
    # Tenta extrair o ano da coluna de data
    try:
        if df_resultado[coluna_data].dtype == 'object':
            # Se for string, tenta converter para datetime primeiro
            df_resultado['_ano_temp'] = pd.to_datetime(df_resultado[coluna_data]).dt.year
        elif pd.api.types.is_datetime64_any_dtype(df_resultado[coluna_data]):
            # Se já for datetime, extrai o ano
            df_resultado['_ano_temp'] = df_resultado[coluna_data].dt.year
        elif pd.api.types.is_numeric_dtype(df_resultado[coluna_data]):
            # Se for numérico, assume que já são anos
            df_resultado['_ano_temp'] = df_resultado[coluna_data].astype(int)
        else:
            raise ValueError(f"Tipo de dados da coluna '{coluna_data}' não suportado para extração do ano")
    except Exception as e:
        raise ValueError(f"Erro ao extrair ano da coluna '{coluna_data}': {str(e)}")
        
    # Verifica se o ano base existe nos dados
    anos_disponiveis = df_resultado['_ano_temp'].unique()
    if ano_base not in anos_disponiveis:
        raise ValueError(
            f"Ano base {ano_base} não encontrado nos dados. "
            f"Anos disponíveis: {sorted(anos_disponiveis)}"
        )
        
    # Calcula os índices para cada coluna especificada
    for coluna in colunas_valores:
        # Encontra os valores do ano base
        mask_ano_base = df_resultado['_ano_temp'] == ano_base
        
        # Se existem múltiplas linhas para o ano base, calcula a média
        if mask_ano_base.sum() == 0:
            raise ValueError(f"Nenhum dado encontrado para o ano base {ano_base}")
        elif mask_ano_base.sum() == 1:
            valor_base = df_resultado.loc[mask_ano_base, coluna].iloc[0]
        else:
            # Múltiplas entradas para o ano base - usa média
            valor_base = df_resultado.loc[mask_ano_base, coluna].mean()
            
        # Evita divisão por zero
        if valor_base == 0 or pd.isna(valor_base):
            # Se valor base é zero ou NaN, índice será NaN para todos os anos
            df_resultado[f"{coluna}_indice"] = np.nan
        else:
            # Calcula o índice: (valor_atual / valor_base) * 100
            df_resultado[f"{coluna}_indice"] = (df_resultado[coluna] / valor_base) * 100
            
    # Remove coluna temporária
    df_resultado = df_resultado.drop('_ano_temp', axis=1)
    
    return df_resultado


def juntar_emprego_comex(emprego: pd.DataFrame, comex: pd.DataFrame, how: str = 'left') -> pd.DataFrame:
    """Une emprego (RAIS/CAGED) e comércio exterior por **divisão e ano**.

    A chave é a divisão de 2 dígitos: `divisao_cnae_cod` (emprego) = `divisao_isic_cod`
    (comex). Coincidem 38 divisões; as de serviços só existem no emprego e a `89` só no
    comex. O comex é somado por (ano, divisão) antes da união, para que meses, países ou
    UFs não multipliquem as linhas do emprego. Feche o ano no comex (`ano_minimo`,
    `agregado_ano=True`) — o ano corrente é parcial.

    Args:
        emprego: precisa de `ano` e `divisao_cnae_cod` (ex.: `get_estoque_emprego_nacional`,
            com `nivel_cnae=2`).
        comex: precisa de `ano` e `divisao_isic_cod` (ex.:
            `get_exportacao_isic_divisao_nacional_mensal`); soma `vl_fob`, `kg_liquido` e
            `quantidade_estatistica`.
        how: 'left' (padrão: mantém toda divisão do emprego, comex nulo onde não há),
            'inner', 'outer'.
    """
    for nome, df, colunas in (('emprego', emprego, ('ano', 'divisao_cnae_cod')),
                              ('comex', comex, ('ano', 'divisao_isic_cod'))):
        faltam = [c for c in colunas if c not in df.columns]
        if faltam:
            raise ValueError(f"{nome} sem a(s) coluna(s) {faltam}; colunas disponíveis: {list(df.columns)}")
    valores = [c for c in ('vl_fob', 'kg_liquido', 'quantidade_estatistica') if c in comex.columns]
    somado = (comex.groupby(['ano', 'divisao_isic_cod'], as_index=False)[valores].sum()
              .rename(columns={'divisao_isic_cod': 'divisao_cnae_cod'}))
    return emprego.merge(somado, on=['ano', 'divisao_cnae_cod'], how=how)

