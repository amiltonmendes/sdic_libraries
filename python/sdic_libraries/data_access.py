"""Alias de compatibilidade — `data_access` foi renomeado para `dados` (0.4.0).

Mantido temporariamente para não quebrar imports legados como
``from sdic_libraries.data_access.emprego import Emprego``. Prefira
``from sdic_libraries.dados.emprego import Emprego``. Será removido numa versão futura.
"""
from __future__ import annotations

import sys
import warnings

from . import dados as _dados
from .dados import *  # noqa: F401,F403 — reexporta a superfície pública de `dados`
from .dados import emprego  # noqa: F401

warnings.warn(
    "`sdic_libraries.data_access` foi renomeado para `sdic_libraries.dados`. "
    "Atualize seus imports; o alias será removido numa versão futura.",
    DeprecationWarning,
    stacklevel=2,
)

# Permite `import sdic_libraries.data_access.emprego` (e seus submódulos).
sys.modules[__name__ + ".emprego"] = emprego
sys.modules[__name__ + ".emprego.api"] = emprego.api
sys.modules[__name__ + ".emprego.portal"] = emprego.portal

__all__ = list(getattr(_dados, "__all__", []))
