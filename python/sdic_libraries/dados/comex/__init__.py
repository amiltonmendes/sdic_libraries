"""Subpacote de comex (comércio exterior).

- ``api`` — cliente da sdic_api (``Comex`` e ``ComexAPIError``).

Centraliza o acesso a dado de comércio exterior da unidade, substituindo
chamadas diretas de consumidores individuais à API pública do MDIC.
"""
from __future__ import annotations

from . import api
from .api import Comex, ComexAPIError

__all__ = [
    "api",
    "Comex",
    "ComexAPIError",
]
