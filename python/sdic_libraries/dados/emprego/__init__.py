"""Subpacote de emprego (CAGED/RAIS).

Reúne duas faces:

- ``api``    — cliente da API ao vivo (``Emprego`` e funções ``get_*``).
- ``portal`` — leitura dos artefatos publicados no GitHub Pages
               (relatórios/cache e payloads do portal), por estado.

Os símbolos públicos de ambos são reexportados aqui, de modo que
``sdic_libraries.dados.emprego.<func>`` continue funcionando como antes,
e ``sdic_libraries.dados.emprego.portal.<func>`` exponha as novas funções.
"""
from __future__ import annotations

from . import api
from . import portal
from .api import (
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
from .portal import (
    PortalEmprego,
    # Relatório (cache — dados brutos)
    get_relatorio_emprego_estadual,
    get_relatorio_emprego_saldo_estadual,
    get_relatorio_emprego_estoque_estadual,
    get_relatorio_emprego_metadata_estadual,
    get_relatorio_emprego_saldo_todos_estados,
    get_relatorio_emprego_estoque_todos_estados,
    # Portal (payload v1.1)
    get_portal_emprego_estadual,
    get_portal_emprego_capa_estadual,
    get_portal_emprego_kpis_estadual,
    get_portal_emprego_charts_estadual,
    get_portal_emprego_ranked_lists_estadual,
    get_portal_emprego_breakdowns_estadual,
    get_portal_emprego_kpis_todos_estados,
    # Descoberta
    listar_estados_disponiveis,
)

__all__ = [
    "api",
    "portal",
    "Emprego",
    "EmpregoAPIError",
    "PortalEmprego",
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
    # Relatório (portal — dados brutos)
    "get_relatorio_emprego_estadual",
    "get_relatorio_emprego_saldo_estadual",
    "get_relatorio_emprego_estoque_estadual",
    "get_relatorio_emprego_metadata_estadual",
    "get_relatorio_emprego_saldo_todos_estados",
    "get_relatorio_emprego_estoque_todos_estados",
    # Portal (payload v1.1)
    "get_portal_emprego_estadual",
    "get_portal_emprego_capa_estadual",
    "get_portal_emprego_kpis_estadual",
    "get_portal_emprego_charts_estadual",
    "get_portal_emprego_ranked_lists_estadual",
    "get_portal_emprego_breakdowns_estadual",
    "get_portal_emprego_kpis_todos_estados",
    # Descoberta
    "listar_estados_disponiveis",
    # Funções auxiliares
    "_validate_cnae_codes",
    "_filter_columns_by_aggregation",
    "_filter_cnae_columns_for_grouped_methods",
    "_filter_cnae_columns_by_level",
]
