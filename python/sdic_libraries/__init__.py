"""sdic_libraries: leitura dos dados da plataforma da SDIC, em tabelas.

Uma porta única, com o mesmo nome de função em Python e em R (`sdic.libraries`):

- emprego (RAIS, Novo CAGED) e comércio exterior (ComexStat), pela sdic_api;
- séries das bases do `carga_base` e indicadores oficiais (`listar_series`, `get_serie`);
- seções publicadas em JSON, as mesmas do portal (`get_kpis_publicados` e afins);
- políticas da SDIC publicadas pelo `gaia_nib` (`listar_politicas`, `get_politica`).

Por onde começar: `listar_bases()` (o que existe), `descrever(nome)` (de onde vem e que
colunas tem), `sdic_config()` (de onde a biblioteca está lendo). A chave individual da API
vai em `SDIC_API_KEY` (variável de ambiente ou `.env.local`).
"""

from __future__ import annotations

__version__ = "0.6.0"
__author__ = "SDIC Team"
__email__ = "sdic.dados@mdic.gov.br"
__license__ = "MIT"
__copyright__ = "Copyright 2026, SDIC Team"

from . import dados, utils
from .catalogo import descrever, listar_bases
from .config import sdic_config
from .politicas import (get_manifesto_politicas, get_municipios_elegiveis, get_politica, get_politica_publicada,
                        get_politicas_estado, get_resumo_politicas, listar_politicas)
from .publicados import (get_atualizacao_publicada, get_destaques_publicados, get_detalhamento_publicado,
                         get_kpis_publicados, get_ranking_publicado, get_secao_publicada, get_series_publicadas,
                         listar_secoes_publicadas)
from .series import get_dimensao_serie, get_referencia, get_serie, listar_referencias, listar_series
from .transporte import NaoPublicado, SdicErro, ler_json_publicado

# `data_access` foi renomeado para `dados` (0.4.0). O módulo de compatibilidade só é carregado
# (e só avisa) quando importado explicitamente.

_NOVAS = [
    "listar_bases", "descrever", "sdic_config", "ler_json_publicado",
    "listar_series", "get_serie", "get_dimensao_serie", "listar_referencias", "get_referencia",
    "listar_secoes_publicadas", "get_secao_publicada", "get_kpis_publicados", "get_series_publicadas",
    "get_ranking_publicado", "get_detalhamento_publicado", "get_destaques_publicados", "get_atualizacao_publicada",
    "listar_politicas", "get_politica", "get_politicas_estado", "get_politica_publicada", "get_resumo_politicas",
    "get_municipios_elegiveis", "get_manifesto_politicas",
]
__all__ = ["dados", "utils", "SdicErro", "NaoPublicado", "__version__"] + _NOVAS


def _anexar_exemplos() -> None:
    """`help(funcao)` mostra o exemplo do catálogo quando o docstring não tem um."""
    from .config import CATALOGO
    from .dados import comex, emprego
    for f in CATALOGO["funcoes"]:
        for modulo in (emprego, comex, utils):
            objeto = getattr(modulo, f["funcao"], None)
            doc = getattr(objeto, "__doc__", None)
            if callable(objeto) and doc and "Example" not in doc and ">>>" not in doc:
                try:
                    objeto.__doc__ = f"{doc.rstrip()}\n\n    Example:\n        >>> {f['exemplo_py']}\n"
                except (AttributeError, TypeError):
                    pass
                break


_anexar_exemplos()


def __getattr__(nome: str):
    """`from sdic_libraries import get_saldo_emprego_nacional_mensal` também funciona: as funções
    de emprego e comex ficam acessíveis pela raiz, sem precisar saber o submódulo."""
    from .dados import comex, emprego
    for modulo in (emprego, comex, utils):
        if nome in getattr(modulo, "__all__", ()) and not nome.startswith("_"):
            return getattr(modulo, nome)
    raise AttributeError(f"sdic_libraries não tem {nome!r}. Veja listar_bases().")
