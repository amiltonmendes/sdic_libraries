"""
SDIC Libraries - Utility libraries for employment and statistical data access

A comprehensive library for accessing Brazilian employment balance data 
(saldo de emprego detalhado) and other statistical information from 
government sources.
"""

from __future__ import annotations

from . import dados
from . import utils

# `data_access` foi renomeado para `dados` (0.4.0). O módulo de compatibilidade
# `data_access` ainda existe e reexporta `dados`, mas só é carregado (e só emite o
# DeprecationWarning) quando importado explicitamente — não no import do pacote.

__version__ = "0.4.0"
__author__ = "SDIC Team"
__email__ = "sdic.dados@mdic.gov.br"
__license__ = "MIT"
__copyright__ = "Copyright 2026, SDIC Team"

__all__ = ["dados", "utils", "__version__"]