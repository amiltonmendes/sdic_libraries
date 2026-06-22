"""
SDIC Libraries - Utility libraries for employment and statistical data access

A comprehensive library for accessing Brazilian employment balance data 
(saldo de emprego detalhado) and other statistical information from 
government sources.
"""

from __future__ import annotations

from . import data_access
from . import utils

__version__ = "0.3.2"
__author__ = "SDIC Team"
__email__ = "sdic.dados@mdic.gov.br"
__license__ = "MIT"
__copyright__ = "Copyright 2026, SDIC Team"

__all__ = ["data_access", "utils", "__version__"]