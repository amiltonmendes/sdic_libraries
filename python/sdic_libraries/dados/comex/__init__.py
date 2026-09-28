"""Subpacote de comex (comércio exterior).

- ``api`` — cliente da sdic_api (``Comex`` e ``ComexAPIError``) e funções soltas
  que devolvem ``DataFrame`` com o esquema padrão (snake_case, tipos fixos).

Centraliza o acesso a dado de comércio exterior da unidade, substituindo
chamadas diretas de consumidores individuais à API pública do MDIC.
"""
from __future__ import annotations

from . import api
from .api import (
    Comex,
    ComexAPIError,
    get_exportacao_ncm_nacional_mensal,
    get_importacao_ncm_nacional_mensal,
    get_exportacao_isic_divisao_nacional_mensal,
    get_importacao_isic_divisao_nacional_mensal,
    get_exportacao_isic_divisao_estadual_mensal,
    get_importacao_isic_divisao_estadual_mensal,
    get_exportacao_pais_nacional_mensal,
    get_importacao_pais_nacional_mensal,
    get_ncm_isic_mapa,
)

__all__ = [
    "api",
    "Comex",
    "ComexAPIError",
    "get_exportacao_ncm_nacional_mensal",
    "get_importacao_ncm_nacional_mensal",
    "get_exportacao_isic_divisao_nacional_mensal",
    "get_importacao_isic_divisao_nacional_mensal",
    "get_exportacao_isic_divisao_estadual_mensal",
    "get_importacao_isic_divisao_estadual_mensal",
    "get_exportacao_pais_nacional_mensal",
    "get_importacao_pais_nacional_mensal",
    "get_ncm_isic_mapa",
]
