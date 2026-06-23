"""portal.py — leitura dos artefatos de emprego publicados no GitHub Pages.

Lado **leitor** do pipeline de emprego. O projeto `cgid_cargas` busca CAGED/RAIS
(via a API desta biblioteca), gera dois artefatos por estado e os publica no
GitHub Pages, em dois ambientes (`producao` e `homologacao`):

    Portal    : <BASE>/{ambiente}/{UF}/emprego.json            (schema v1.1)
    Relatório : <BASE>/{ambiente}/cache/{UF}/emprego_cache.json (schema 1.0)

Este módulo lê esses JSONs de volta e os entrega como `dict`/`pandas.DataFrame`:

  - **Relatório** (cache 1.0): dados brutos — `saldo` (CAGED mensal por divisão
    CNAE), `estoque` (RAIS por divisão) e `acum12m_total`. Para análise.
  - **Portal** (v1.1): payload pronto para apresentação — `capa_kpi`, `story`,
    `kpis`, `charts`, `ranked_lists`, `breakdowns`, já em pt-BR.

Configuração:
    PORTAL_EMPREGO_BASE_URL   URL pública base (default abaixo).
    PORTAL_EMPREGO_AMBIENTE   ambiente default ('producao' | 'homologacao').

Uso:
    from sdic_libraries.dados.emprego.portal import (
        get_relatorio_emprego_saldo_estadual,
        get_portal_emprego_estadual,
    )
    df = get_relatorio_emprego_saldo_estadual("SP")
    payload = get_portal_emprego_estadual("SP", ambiente="homologacao")
"""
from __future__ import annotations

import logging
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

import pandas as pd
import requests

# Reaproveita a exceção e a tradução amigável de erros do cliente da API.
from .api import EmpregoAPIError, _get_user_friendly_error_message

# URL pública base onde o `cgid_cargas` publica os artefatos de emprego.
DEFAULT_PORTAL_BASE_URL = "https://amiltonmendes.github.io/sdic_libraries"
AMBIENTES = ("producao", "homologacao")

UFS_27 = [
    "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS",
    "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC",
    "SP", "SE", "TO",
]


class PortalEmprego:
    """Cliente de leitura dos artefatos de emprego publicados no GitHub Pages.

    Attributes:
        base_url (str): URL pública base (sem `/{ambiente}/...`).
        ambiente (str): 'producao' (default) ou 'homologacao'.
        timeout (int): timeout das requisições em segundos.
        session (requests.Session): sessão HTTP com pool de conexões.
    """

    def __init__(
        self,
        base_url: Optional[str] = None,
        ambiente: Optional[str] = None,
        timeout: int = 30,
    ):
        self._load_env_files()

        self.base_url = (
            base_url
            or os.getenv("PORTAL_EMPREGO_BASE_URL")
            or DEFAULT_PORTAL_BASE_URL
        ).rstrip("/")

        self.ambiente = self._validar_ambiente(
            ambiente or os.getenv("PORTAL_EMPREGO_AMBIENTE") or "producao"
        )
        self.timeout = int(os.getenv("API_TIMEOUT", str(timeout)))

        log_level = os.getenv("LOG_LEVEL", "INFO").upper()
        if hasattr(logging, log_level):
            logging.getLogger().setLevel(getattr(logging, log_level))

        self.session = requests.Session()
        self.logger = logging.getLogger(__name__)
        version = os.getenv("SDIC_VERSION", "0.4.0")
        self.session.headers.update({
            "User-Agent": f"sdic-libraries/{version}",
            "Accept": "application/json",
        })

    # ── Contexto / env ────────────────────────────────────────────────────────

    def __enter__(self) -> "PortalEmprego":
        return self

    def __exit__(self, *exc) -> None:
        self.session.close()

    @staticmethod
    def _validar_ambiente(ambiente: str) -> str:
        amb = (ambiente or "").strip().lower()
        if amb not in AMBIENTES:
            raise ValueError(
                f"ambiente inválido: {ambiente!r}. Use {' ou '.join(AMBIENTES)}."
            )
        return amb

    def _load_env_files(self) -> None:
        """Carrega `.env` automaticamente (mesma lógica do cliente da API)."""
        env_locations = [
            Path.cwd() / ".env",
            Path.home() / ".env",
            Path("/etc/sdic/.env"),
        ]
        try:
            from dotenv import load_dotenv

            for env_file in env_locations:
                if env_file.exists():
                    load_dotenv(env_file, override=False)
                    break
        except ImportError:
            for env_file in env_locations:
                if env_file.exists():
                    self._load_env_file(env_file)
                    break

    def _load_env_file(self, env_file_path: Path) -> None:
        try:
            with open(env_file_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, value = (p.strip() for p in line.split("=", 1))
                        if value[:1] in {'"', "'"} and value[-1:] == value[:1]:
                            value = value[1:-1]
                        os.environ.setdefault(key, value)
        except Exception:  # noqa: BLE001 — experiência fluida
            pass

    # ── HTTP ──────────────────────────────────────────────────────────────────

    def _fetch_json(self, path: str, *, opcional: bool = False) -> Optional[dict]:
        """GET de um JSON publicado. 404 → None se `opcional`, senão erro amigável."""
        url = f"{self.base_url}/{path.lstrip('/')}"
        try:
            response = self.session.get(url, timeout=self.timeout)
            if opcional and response.status_code == 404:
                return None
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            status_code = getattr(getattr(e, "response", None), "status_code", None)
            if opcional and status_code == 404:
                return None
            self.logger.error(f"Falha ao buscar {path}: {e}")
            raise EmpregoAPIError(_get_user_friendly_error_message(e, status_code))
        except ValueError as e:
            self.logger.error(f"JSON inválido em {path}: {e}")
            raise EmpregoAPIError(_get_user_friendly_error_message(e))

    def _ambiente(self, ambiente: Optional[str]) -> str:
        return self._validar_ambiente(ambiente) if ambiente else self.ambiente

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

def get_relatorio_emprego_estadual(uf: str, ambiente: str = "producao") -> dict:
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


def get_relatorio_emprego_saldo_estadual(uf: str, ambiente: str = "producao") -> pd.DataFrame:
    """Saldo CAGED mensal por divisão CNAE (cache) de uma UF, como DataFrame."""
    with PortalEmprego(ambiente=ambiente) as p:
        return _df_saldo(p.relatorio(uf))


def get_relatorio_emprego_estoque_estadual(uf: str, ambiente: str = "producao") -> pd.DataFrame:
    """Estoque RAIS por divisão CNAE (cache) de uma UF, como DataFrame."""
    with PortalEmprego(ambiente=ambiente) as p:
        return _df_estoque(p.relatorio(uf))


def get_relatorio_emprego_metadata_estadual(uf: str, ambiente: str = "producao") -> dict:
    """Metadados do relatório (reference, fonte, gerado_em, ...) de uma UF."""
    with PortalEmprego(ambiente=ambiente) as p:
        return (p.relatorio(uf) or {}).get("metadata", {})


def get_relatorio_emprego_saldo_todos_estados(ambiente: str = "producao") -> pd.DataFrame:
    """Saldo de todas as UFs disponíveis, empilhado, com coluna `uf`."""
    frames = []
    with PortalEmprego(ambiente=ambiente) as p:
        for uf in UFS_27:
            df = _df_saldo(p.relatorio(uf, opcional=True))
            if not df.empty:
                df.insert(0, "uf", uf)
                frames.append(df)
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


def get_relatorio_emprego_estoque_todos_estados(ambiente: str = "producao") -> pd.DataFrame:
    """Estoque de todas as UFs disponíveis, empilhado, com coluna `uf`."""
    frames = []
    with PortalEmprego(ambiente=ambiente) as p:
        for uf in UFS_27:
            df = _df_estoque(p.relatorio(uf, opcional=True))
            if not df.empty:
                df.insert(0, "uf", uf)
                frames.append(df)
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


# ── Funções de módulo: PORTAL (payload v1.1) ───────────────────────────────────

def get_portal_emprego_estadual(uf: str, ambiente: str = "producao") -> dict:
    """Payload completo do portal (v1.1) de uma UF — como publicado."""
    with PortalEmprego(ambiente=ambiente) as p:
        return p.portal(uf) or {}


def get_portal_emprego_capa_estadual(uf: str, ambiente: str = "producao") -> dict:
    """KPI de capa (`capa_kpi`) — destaque do saldo 12m — de uma UF."""
    with PortalEmprego(ambiente=ambiente) as p:
        return (p.portal(uf) or {}).get("capa_kpi", {})


def get_portal_emprego_kpis_estadual(uf: str, ambiente: str = "producao") -> pd.DataFrame:
    """KPIs do portal de uma UF como DataFrame (id, label, value, display_value, ...)."""
    with PortalEmprego(ambiente=ambiente) as p:
        payload = p.portal(uf) or {}
    return pd.DataFrame(payload.get("kpis") or [])


def get_portal_emprego_charts_estadual(uf: str, ambiente: str = "producao") -> Dict[str, pd.DataFrame]:
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


def get_portal_emprego_ranked_lists_estadual(uf: str, ambiente: str = "producao") -> Dict[str, pd.DataFrame]:
    """Rankings do portal (maiores saldos/estoques). dict {list_id: DataFrame[items]}."""
    with PortalEmprego(ambiente=ambiente) as p:
        payload = p.portal(uf) or {}
    return {
        rl.get("id", f"rank_{i}"): pd.DataFrame(rl.get("items") or [])
        for i, rl in enumerate(payload.get("ranked_lists") or [])
    }


def get_portal_emprego_breakdowns_estadual(uf: str, ambiente: str = "producao") -> Dict[str, pd.DataFrame]:
    """Composições do portal (ex.: intensidade tecnológica). dict {id: DataFrame[items]}."""
    with PortalEmprego(ambiente=ambiente) as p:
        payload = p.portal(uf) or {}
    return {
        bd.get("id", f"breakdown_{i}"): pd.DataFrame(bd.get("items") or [])
        for i, bd in enumerate(payload.get("breakdowns") or [])
    }


def get_portal_emprego_kpis_todos_estados(ambiente: str = "producao") -> pd.DataFrame:
    """KPIs de todas as UFs disponíveis, empilhados, com coluna `uf` — comparação entre estados."""
    frames = []
    with PortalEmprego(ambiente=ambiente) as p:
        for uf in UFS_27:
            payload = p.portal(uf, opcional=True)
            if payload and payload.get("kpis"):
                df = pd.DataFrame(payload["kpis"])
                df.insert(0, "uf", uf)
                frames.append(df)
    return pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()


# ── Descoberta ─────────────────────────────────────────────────────────────────

def listar_estados_disponiveis(ambiente: str = "producao", tipo: str = "portal") -> List[str]:
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
