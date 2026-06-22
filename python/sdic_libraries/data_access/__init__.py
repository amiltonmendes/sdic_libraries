"""
Módulos de Acesso a Dados para várias fontes de dados do governo brasileiro

Este pacote fornece acesso padronizado a dados de emprego e outros
dados estatísticos de APIs do governo brasileiro.
"""

from __future__ import annotations

from . import emprego
from .emprego import (
    Emprego, 
    EmpregoAPIError,
    # Funções nacionais
    get_saldo_emprego_nacional_mensal,
    get_saldo_emprego_nacional_anual, 
    get_saldo_emprego_nacional_mensal_agrupado,
    # Funções estaduais
    get_saldo_emprego_estadual_mensal,
    get_saldo_emprego_estadual_anual,
    get_saldo_emprego_estadual_mensal_agrupado,
    # Funções municipais
    get_saldo_emprego_municipal_mensal,
    get_saldo_emprego_municipal_anual,
    get_saldo_emprego_municipal_mensal_agrupado,
    # Funções de estoque
    get_estoque_emprego_nacional,
    get_estoque_emprego_estadual,
    # Funções de estoque estimado
    get_estoque_emprego_estimado_nacional_anual,
    get_estoque_emprego_estimado_estadual_anual,
    get_estoque_emprego_estimado_municipal_anual,
    get_estoque_emprego_estimado_nacional_anual_agrupado,
    get_estoque_emprego_estimado_estadual_anual_agrupado,
    get_estoque_emprego_estimado_municipal_anual_agrupado,
    # Funções de CAGED
    get_saldo_caged_nacional,
    get_saldo_caged_estadual,
    get_saldo_caged_municipal,
    # Funções auxiliares
    _validate_cnae_codes,
    _filter_columns_by_aggregation,
    _filter_cnae_columns_for_grouped_methods,
    _filter_cnae_columns_by_level,
)

__all__ = [
    "emprego",
    "Emprego",
    "EmpregoAPIError",
    # Funções nacionais
    "get_saldo_emprego_nacional_mensal",
    "get_saldo_emprego_nacional_anual", 
    "get_saldo_emprego_nacional_mensal_agrupado",
    # Funções estaduais
    "get_saldo_emprego_estadual_mensal",
    "get_saldo_emprego_estadual_anual",
    "get_saldo_emprego_estadual_mensal_agrupado",
    # Funções municipais
    "get_saldo_emprego_municipal_mensal",
    "get_saldo_emprego_municipal_anual",
    "get_saldo_emprego_municipal_mensal_agrupado",
    # Funções de estoque
    "get_estoque_emprego_nacional",
    "get_estoque_emprego_estadual",
    # Funções de estoque estimado
    "get_estoque_emprego_estimado_nacional_anual",
    "get_estoque_emprego_estimado_estadual_anual",
    "get_estoque_emprego_estimado_municipal_anual",
    "get_estoque_emprego_estimado_nacional_anual_agrupado",
    "get_estoque_emprego_estimado_estadual_anual_agrupado",
    "get_estoque_emprego_estimado_municipal_anual_agrupado",
    # Funções de CAGED
    "get_saldo_caged_nacional",
    "get_saldo_caged_estadual",
    "get_saldo_caged_municipal",
    # Funções auxiliares
    "_validate_cnae_codes",
    "_filter_columns_by_aggregation",
    "_filter_cnae_columns_for_grouped_methods",
    "_filter_cnae_columns_by_level",
]
