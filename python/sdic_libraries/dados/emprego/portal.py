"""portal.py — DEPRECIADO: leitura do cache de emprego no layout antigo do GitHub Pages.

Estes arquivos eram publicados pelo `cgid_cargas`, que foi desligado; o pipeline novo
(`carga_base/publicacao`) não produz `cache/{UF}/emprego_cache.json`. As funções continuam
funcionando enquanto os arquivos antigos existirem, com aviso de depreciação.

Use no lugar (em `sdic_libraries`): `get_kpis_publicados(uf, "emprego")`,
`get_series_publicadas`, `get_ranking_publicado`, `get_detalhamento_publicado` e
`get_secao_publicada`. Para saldo e estoque por divisão CNAE, use as funções da API
(`get_saldo_emprego_estadual_mensal`, `get_estoque_emprego_estadual`). O arquivo
`{UF}/emprego_relatorio.json` do bucket de dados não tem função: leia com
`ler_json_publicado("dados", "<ambiente>/<UF>/emprego_relatorio.json")`.
"""
from __future__ import annotations

import functools
import warnings
from typing import Any, Dict, List, Optional

import pandas as pd

from ... import config
from ...transporte import NaoPublicado, SdicErro, ler_json_publicado
from .api import EmpregoAPIError

AMBIENTES = config.AMBIENTES

UFS_27 = [
    "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS",
    "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC",
    "SP", "SE", "TO",
]


def _depreciada(substituta: str):
    def decorar(funcao):
        @functools.wraps(funcao)
        def envolta(*args, **kwargs):
            warnings.warn(f"{funcao.__name__} lê o layout antigo do Pages e será removida. Use {substituta}.",
                          DeprecationWarning, stacklevel=2)
            return funcao(*args, **kwargs)
        return envolta
    return decorar


class PortalEmprego:
    """Leitor dos artefatos antigos de emprego (origem `politicas` do catálogo, sem chave)."""

    def __init__(self, base_url: Optional[str] = None, ambiente: Optional[str] = None, timeout: Optional[int] = None):
        self.base_url = config.url("politicas", base_url)
        self.ambiente = config.ambiente(ambiente)
        self.timeout = config.timeout(timeout)

    def __enter__(self) -> "PortalEmprego":
        return self

    def __exit__(self, *exc) -> None:
        pass

    def _fetch_json(self, path: str, *, opcional: bool = False) -> Optional[dict]:
        """GET de um JSON publicado. Arquivo inexistente → None se `opcional`; outra falha é sempre erro."""
        try:
            return ler_json_publicado("politicas", path, base_url=self.base_url, timeout=self.timeout)
        except NaoPublicado as e:
            if opcional:
                return None
            raise EmpregoAPIError(str(e), status_code=e.status_code, endpoint=e.endpoint) from e
        except SdicErro as e:
            raise EmpregoAPIError(str(e), status_code=e.status_code, endpoint=e.endpoint) from e

    def _ambiente(self, ambiente: Optional[str]) -> str:
        return config.ambiente(ambiente) if ambiente else self.ambiente

    # ── Caminhos ──────────────────────────────────────────────────────────────

    def _path_portal(self, uf: str, ambiente: str) -> str:
        return f"{ambiente}/{uf.upper()}/emprego.json"

    def _path_relatorio(self, uf: str, ambiente: str) -> str:
        return f"{ambiente}/cache/{uf.upper()}/emprego_cache.json"

    # ── Relatório (cache 1.0 — dados brutos) ──────────────────────────────────

    def relatorio(
        self, uf: str, ambiente: Optional[str] = None, *, opcional: bool = False
    ) -> Optional[dict]:
        """Payload bruto do cache (`emprego_cache.json`) da UF. None se ausente e opcional."""
        amb = self._ambiente(ambiente)
        return self._fetch_json(self._path_relatorio(uf, amb), opcional=opcional)

    # ── Portal (v1.1 — apresentação) ──────────────────────────────────────────

    def portal(
        self, uf: str, ambiente: Optional[str] = None, *, opcional: bool = False
    ) -> Optional[dict]:
        """Payload do portal (`emprego.json`, v1.1) da UF. None se ausente e opcional."""
        amb = self._ambiente(ambiente)
        return self._fetch_json(self._path_portal(uf, amb), opcional=opcional)


# ── Reconstrução de DataFrames a partir do cache (schema 1.0) ──────────────────

def _df_saldo(payload: Optional[dict]) -> pd.DataFrame:
    """`saldo` → DataFrame, com dtypes reforçados (competencia/cnae_divisao string)."""
    df = pd.DataFrame((payload or {}).get("saldo") or [])
    if not df.empty:
        if "competencia" in df.columns:
            df["competencia"] = df["competencia"].astype(str).str.zfill(6)
        if "cnae_divisao" in df.columns:
            df["cnae_divisao"] = df["cnae_divisao"].astype(str).str.zfill(2)
    return df


def _df_estoque(payload: Optional[dict]) -> pd.DataFrame:
    """`estoque` → DataFrame, com `cnae_divisao` como string (zero à esquerda)."""
    df = pd.DataFrame((payload or {}).get("estoque") or [])
    if not df.empty and "cnae_divisao" in df.columns:
        df["cnae_divisao"] = df["cnae_divisao"].astype(str).str.zfill(2)
    return df


def _acum12m(payload: Optional[dict]) -> Optional[int]:
    """`acum12m_total` — None quando ausente (NUNCA 0)."""
    acum = (payload or {}).get("acum12m_total", None)
    return int(acum) if acum is not None else None


# ── Funções de módulo: RELATÓRIO (dados brutos do cache) ───────────────────────

@_depreciada('get_saldo_emprego_estadual_mensal/get_estoque_emprego_estadual (API) ou ler_json_publicado("dados", ".../emprego_relatorio.json")')
def get_relatorio_emprego_estadual(uf: str, ambiente: Optional[str] = None) -> dict:
    """Relatório completo (cache 1.0) de uma UF.

    Args:
        uf (str): sigla da UF (ex.: 'SP').
        ambiente (str): 'producao' (default) ou 'homologacao'.

    Returns:
        dict: {'saldo': DataFrame, 'estoque': DataFrame,
               'acum12m_total': int | None, 'metadata': dict}
    """
    with PortalEmprego(ambiente=ambiente) as p:
        payload = p.relatorio(uf) or {}
    return {
        "saldo": _df_saldo(payload),
        "estoque": _df_estoque(payload),
        "acum12m_total": _acum12m(payload),
        "metadata": payload.get("metadata", {}),
    }


@_depreciada('get_saldo_emprego_estadual_mensal/get_estoque_emprego_estadual (API) ou ler_json_publicado("dados", ".../emprego_relatorio.json")')
def get_relatorio_emprego_saldo_estadual(uf: str, ambiente: Optional[str] = None) -> pd.DataFrame:
    """Saldo CAGED mensal por divisão CNAE (cache) de uma UF, como DataFrame."""
    with PortalEmprego(ambiente=ambiente) as p:
        return _df_saldo(p.relatorio(uf))


@_depreciada('get_saldo_emprego_estadual_mensal/get_estoque_emprego_estadual (API) ou ler_json_publicado("dados", ".../emprego_relatorio.json")')
def get_relatorio_emprego_estoque_estadual(uf: str, ambiente: Optional[str] = None) -> pd.DataFrame:
    """Estoque RAIS por divisão CNAE (cache) de uma UF, como DataFrame."""
    with PortalEmprego(ambiente=ambiente) as p:
        return _df_estoque(p.relatorio(uf))


@_depreciada('get_saldo_emprego_estadual_mensal/get_estoque_emprego_estadual (API) ou ler_json_publicado("dados", ".../emprego_relatorio.json")')
def get_relatorio_emprego_metadata_estadual(uf: str, ambiente: Optional[str] = None) -> dict:
    """Metadados do relatório (reference, fonte, gerado_em, ...) de uma UF."""
    with PortalEmprego(ambiente=ambiente) as p:
        return (p.relatorio(uf) or {}).get("metadata", {})


@_depreciada('get_saldo_emprego_estadual_mensal/get_estoque_emprego_estadual (API) ou ler_json_publicado("dados", ".../emprego_relatorio.json")')
def get_relatorio_emprego_saldo_todos_estados(ambiente: Optional[str] = None) -> pd.DataFrame:
    """Saldo de todas as UFs disponíveis, empilhado, com coluna `uf`."""
    frames = []
    with PortalEmprego(ambiente=ambiente) as p:
        for uf in UFS_27:
            df = _df_saldo(p.relatorio(uf, opcional=True))
            if not df.empty:
                df.insert(0, "uf", uf)
                frames.append(df)
    faltam = sorted(set(UFS_27) - {f["uf"].iloc[0] for f in frames})
    if faltam and frames:
        warnings.warn(f"Sem arquivo publicado para {len(faltam)} UF(s): {', '.join(faltam)}. "
                      "O resultado não cobre o país inteiro.", RuntimeWarning, stacklevel=3)
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


@_depreciada('get_saldo_emprego_estadual_mensal/get_estoque_emprego_estadual (API) ou ler_json_publicado("dados", ".../emprego_relatorio.json")')
def get_relatorio_emprego_estoque_todos_estados(ambiente: Optional[str] = None) -> pd.DataFrame:
    """Estoque de todas as UFs disponíveis, empilhado, com coluna `uf`."""
    frames = []
    with PortalEmprego(ambiente=ambiente) as p:
        for uf in UFS_27:
            df = _df_estoque(p.relatorio(uf, opcional=True))
            if not df.empty:
                df.insert(0, "uf", uf)
                frames.append(df)
    faltam = sorted(set(UFS_27) - {f["uf"].iloc[0] for f in frames})
    if faltam and frames:
        warnings.warn(f"Sem arquivo publicado para {len(faltam)} UF(s): {', '.join(faltam)}. "
                      "O resultado não cobre o país inteiro.", RuntimeWarning, stacklevel=3)
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


# ── Funções de módulo: PORTAL (payload v1.1) ───────────────────────────────────

@_depreciada('get_kpis_publicados(uf, "emprego") e as demais funções de seções publicadas')
def get_portal_emprego_estadual(uf: str, ambiente: Optional[str] = None) -> dict:
    """Payload completo do portal (v1.1) de uma UF — como publicado."""
    with PortalEmprego(ambiente=ambiente) as p:
        return p.portal(uf) or {}


@_depreciada('get_kpis_publicados(uf, "emprego") e as demais funções de seções publicadas')
def get_portal_emprego_capa_estadual(uf: str, ambiente: Optional[str] = None) -> dict:
    """KPI de capa (`capa_kpi`) — destaque do saldo 12m — de uma UF."""
    with PortalEmprego(ambiente=ambiente) as p:
        return (p.portal(uf) or {}).get("capa_kpi", {})


@_depreciada('get_kpis_publicados(uf, "emprego") e as demais funções de seções publicadas')
def get_portal_emprego_kpis_estadual(uf: str, ambiente: Optional[str] = None) -> pd.DataFrame:
    """KPIs do portal de uma UF como DataFrame (id, label, value, display_value, ...)."""
    with PortalEmprego(ambiente=ambiente) as p:
        payload = p.portal(uf) or {}
    return pd.DataFrame(payload.get("kpis") or [])


@_depreciada('get_kpis_publicados(uf, "emprego") e as demais funções de seções publicadas')
def get_portal_emprego_charts_estadual(uf: str, ambiente: Optional[str] = None) -> Dict[str, pd.DataFrame]:
    """Séries dos gráficos do portal. dict {chart_id: DataFrame[competencia, valor]}."""
    with PortalEmprego(ambiente=ambiente) as p:
        payload = p.portal(uf) or {}
    out: Dict[str, pd.DataFrame] = {}
    for chart in payload.get("charts") or []:
        series = (chart.get("series") or [{}])[0]
        pts = series.get("points") or []
        out[chart.get("id", f"chart_{len(out)}")] = pd.DataFrame(
            [{"competencia": pt.get("t"), "valor": pt.get("v")} for pt in pts]
        )
    return out


@_depreciada('get_kpis_publicados(uf, "emprego") e as demais funções de seções publicadas')
def get_portal_emprego_ranked_lists_estadual(uf: str, ambiente: Optional[str] = None) -> Dict[str, pd.DataFrame]:
    """Rankings do portal (maiores saldos/estoques). dict {list_id: DataFrame[items]}."""
    with PortalEmprego(ambiente=ambiente) as p:
        payload = p.portal(uf) or {}
    return {
        rl.get("id", f"rank_{i}"): pd.DataFrame(rl.get("items") or [])
        for i, rl in enumerate(payload.get("ranked_lists") or [])
    }


@_depreciada('get_kpis_publicados(uf, "emprego") e as demais funções de seções publicadas')
def get_portal_emprego_breakdowns_estadual(uf: str, ambiente: Optional[str] = None) -> Dict[str, pd.DataFrame]:
    """Composições do portal (ex.: intensidade tecnológica). dict {id: DataFrame[items]}."""
    with PortalEmprego(ambiente=ambiente) as p:
        payload = p.portal(uf) or {}
    return {
        bd.get("id", f"breakdown_{i}"): pd.DataFrame(bd.get("items") or [])
        for i, bd in enumerate(payload.get("breakdowns") or [])
    }


@_depreciada('get_kpis_publicados(uf, "emprego") e as demais funções de seções publicadas')
def get_portal_emprego_kpis_todos_estados(ambiente: Optional[str] = None) -> pd.DataFrame:
    """KPIs de todas as UFs disponíveis, empilhados, com coluna `uf` — comparação entre estados."""
    frames = []
    with PortalEmprego(ambiente=ambiente) as p:
        for uf in UFS_27:
            payload = p.portal(uf, opcional=True)
            if payload and payload.get("kpis"):
                df = pd.DataFrame(payload["kpis"])
                df.insert(0, "uf", uf)
                frames.append(df)
    faltam = sorted(set(UFS_27) - {f["uf"].iloc[0] for f in frames})
    if faltam and frames:
        warnings.warn(f"Sem arquivo publicado para {len(faltam)} UF(s): {', '.join(faltam)}. "
                      "O resultado não cobre o país inteiro.", RuntimeWarning, stacklevel=3)
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


# ── Descoberta ─────────────────────────────────────────────────────────────────

@_depreciada('listar_secoes_publicadas()')
def listar_estados_disponiveis(ambiente: Optional[str] = None, tipo: str = "portal") -> List[str]:
    """Lista as UFs com artefato publicado.

    Args:
        ambiente (str): 'producao' (default) ou 'homologacao'.
        tipo (str): 'portal' (emprego.json) ou 'relatorio' (cache).

    Returns:
        List[str]: siglas das UFs disponíveis.
    """
    disponiveis = []
    with PortalEmprego(ambiente=ambiente) as p:
        for uf in UFS_27:
            payload = (
                p.relatorio(uf, opcional=True)
                if tipo == "relatorio"
                else p.portal(uf, opcional=True)
            )
            if payload is not None:
                disponiveis.append(uf)
    return disponiveis
