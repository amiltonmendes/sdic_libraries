"""
Módulos de Utilidades para transformações e manipulação de dados

Este pacote fornece funções auxiliares para transformações de dados,
cálculos de índices, e outras operações estatísticas úteis.
"""

from __future__ import annotations

from . import transformacoes
from .transformacoes import (
    criar_indice
)

__all__ = ["transformacoes", "criar_indice"]