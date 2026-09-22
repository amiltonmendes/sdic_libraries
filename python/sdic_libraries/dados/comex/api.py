"""
Comex API client para acessar dados de comércio exterior brasileiro

Cliente Python para os endpoints de comércio exterior (comex) da sdic_api,
centralizando o acesso que hoje está espalhado em chamadas diretas à API
pública do MDIC (ComexStat) em múltiplos consumidores da unidade.

Mesma estrutura de `dados.emprego.api` (mesmo padrão de configuração via
`.env`, tratamento de erro e paginação automática) — ver aquele módulo para
o desenho original.
"""

from __future__ import annotations

import logging
import os
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests


class ComexAPIError(Exception):
    """Exceção personalizada para erros da API de Comex"""
    pass


def _get_user_friendly_error_message(error: Exception, status_code: int = None) -> str:
    """Converte erros técnicos em mensagens amigáveis, sem expor URLs/detalhes internos."""
    error_str = str(error).lower()

    if any(x in error_str for x in ['connection', 'conexão', 'timeout', 'timed out']):
        return ("Problema de conectividade detectado. "
                "Verifique sua conexão com a internet e tente novamente em alguns minutos.")

    if status_code == 404 or '404' in error_str:
        return ("Serviço temporariamente indisponível. "
                "Aguarde alguns minutos e tente novamente.")

    if status_code and 500 <= status_code < 600:
        return ("O serviço está temporariamente em manutenção. "
                "Tente novamente em alguns minutos.")

    if status_code == 400 or '400' in error_str:
        return ("Parâmetros inválidos fornecidos. "
                "Verifique os códigos e datas informados.")

    if status_code in [401, 403] or any(x in error_str for x in ['401', '403', 'unauthorized', 'forbidden']):
        return ("Problema de autenticação. "
                "Verifique a chave de API configurada (COMEX_API_KEY).")

    if 'json' in error_str:
        return ("Resposta inválida recebida do serviço. "
                "Tente novamente em alguns minutos.")

    return ("Erro temporário no serviço. "
            "Verifique os parâmetros e tente novamente em alguns minutos.")


class Comex:
    """
    Cliente para acessar dados de comércio exterior (comex) via sdic_api.

    Attributes:
        base_url (str): URL base da sdic_api
        timeout (int): Timeout das requisições em segundos
        session (requests.Session): Sessão HTTP para pool de conexões
    """

    def __init__(self, base_url: str = None, timeout: int = 30, api_key: str = None):
        """
        Inicializar cliente da API de Comex.

        Variáveis de ambiente são carregadas automaticamente de:
        1. Variáveis de ambiente do sistema
        2. Arquivo .env no diretório atual (se existir)
        3. Arquivo .env no diretório home do usuário (se existir)
        4. /etc/sdic/.env (configuração do sistema)

        Args:
            base_url (str, optional): Sobrescrever URL base da API auto-detectada
            timeout (int): Timeout das requisições em segundos. Padrão 30.
            api_key (str, optional): Sobrescrever chave da API auto-detectada
        """
        self._load_env_files()

        self.base_url = (
            base_url or
            os.getenv('COMEX_API_BASE_URL') or
            "https://sdicapi.dados.ninja"
        )

        self.timeout = int(os.getenv('API_TIMEOUT', str(timeout)))
        self.api_key = api_key or os.getenv('COMEX_API_KEY')

        log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
        if hasattr(logging, log_level):
            logging.getLogger().setLevel(getattr(logging, log_level))

        self.session = requests.Session()
        self.logger = logging.getLogger(__name__)

        version = os.getenv('SDIC_VERSION', '0.4.0')
        self.session.headers.update({
            'User-Agent': f'sdic-libraries/{version}',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
        })

        if self.api_key:
            # A sdic_api valida hoje via header `x-api-key` (ver
            # api/security/api_key.py); `Authorization: Bearer` é enviado
            # também para não quebrar caso o mecanismo evolua para checá-lo.
            self.session.headers.update({
                'Authorization': f'Bearer {self.api_key}',
                'x-api-key': self.api_key,
            })

        self._ncm_isic_mapa_cache: Optional[List[Dict[str, Any]]] = None

    def _make_request(self, endpoint: str, params: Dict[str, Any] = None) -> Dict[str, Any]:
        url = f"{self.base_url.rstrip('/')}/{endpoint.lstrip('/')}"
        try:
            response = self.session.get(url, params=params, timeout=self.timeout)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Falha na requisição da API: {e}")
            status_code = getattr(e.response, 'status_code', None) if hasattr(e, 'response') and e.response else None
            raise ComexAPIError(_get_user_friendly_error_message(e, status_code))
        except ValueError as e:
            self.logger.error(f"Resposta JSON inválida: {e}")
            raise ComexAPIError(_get_user_friendly_error_message(e))

    def _make_post_request(self, endpoint: str, body: Any, params: Dict[str, Any] = None) -> Dict[str, Any]:
        url = f"{self.base_url.rstrip('/')}/{endpoint.lstrip('/')}"
        try:
            response = self.session.post(url, json=body, params=params, timeout=self.timeout)
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Falha na requisição da API: {e}")
            status_code = getattr(e.response, 'status_code', None) if hasattr(e, 'response') and e.response else None
            raise ComexAPIError(_get_user_friendly_error_message(e, status_code))
        except ValueError as e:
            self.logger.error(f"Resposta JSON inválida: {e}")
            raise ComexAPIError(_get_user_friendly_error_message(e))

    def _extract_items(self, response: Any) -> List[Dict[str, Any]]:
        if isinstance(response, list):
            return [item for item in response if isinstance(item, dict)]
        if not isinstance(response, dict):
            raise ComexAPIError("Formato de resposta inesperado da API")
        items = response.get('items')
        if isinstance(items, list):
            return [item for item in items if isinstance(item, dict)]
        return []

    def _get_total_count(self, response: Any) -> Optional[int]:
        if not isinstance(response, dict):
            return None
        value = response.get('count')
        return value if isinstance(value, int) and value >= 0 else None

    def _fetch_all_paginated_get(self, endpoint: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Consolida automaticamente todas as páginas de um endpoint GET."""
        all_items: List[Dict[str, Any]] = []
        pagina = 1
        total_count: Optional[int] = None

        while True:
            request_params = dict(params)
            request_params['pagina'] = pagina
            request_params.setdefault('tamanho_pagina', 1000)
            page_size = int(request_params.get('tamanho_pagina', 1000) or 1000)

            response = self._make_request(endpoint, request_params)
            items = self._extract_items(response)
            if not items:
                break

            all_items.extend(items)

            if total_count is None:
                total_count = self._get_total_count(response)

            if total_count is not None and len(all_items) >= total_count:
                break
            if len(items) < page_size:
                break

            pagina += 1

        return all_items

    def _fetch_all_paginated_post(self, endpoint: str, body: Dict[str, Any], params: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Consolida automaticamente todas as páginas de um endpoint POST.

        A paginação é embutida tanto no corpo quanto nos parâmetros de query:
        o endpoint de NCM (`/exportacao_agregada_ncm`) espera `pagina`/
        `tamanho_pagina` dentro do corpo JSON, diferente do padrão GET.
        """
        all_items: List[Dict[str, Any]] = []
        pagina = 1
        total_count: Optional[int] = None

        while True:
            request_params = dict(params)
            request_params['pagina'] = pagina
            request_params.setdefault('tamanho_pagina', 1000)
            page_size = int(request_params.get('tamanho_pagina', 1000) or 1000)

            request_body = dict(body)
            request_body['pagina'] = pagina
            request_body.setdefault('tamanho_pagina', page_size)

            response = self._make_post_request(endpoint, request_body, params=request_params)
            items = self._extract_items(response)
            if not items:
                break

            all_items.extend(items)

            if total_count is None:
                total_count = self._get_total_count(response)

            if total_count is not None and len(all_items) >= total_count:
                break
            if len(items) < page_size:
                break

            pagina += 1

        return all_items

    def _load_env_files(self):
        try:
            from dotenv import load_dotenv
            env_locations = [Path.cwd() / '.env', Path.home() / '.env', Path('/etc/sdic/.env')]
            for env_file in env_locations:
                if env_file.exists():
                    load_dotenv(env_file, override=False)
                    break
        except ImportError:
            env_locations = [Path.cwd() / '.env', Path.home() / '.env', Path('/etc/sdic/.env')]
            for env_file in env_locations:
                if env_file.exists():
                    self._load_env_file(env_file)
                    break

    def _load_env_file(self, env_file_path: Path):
        try:
            with open(env_file_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        key, value = key.strip(), value.strip()
                        if value.startswith('"') and value.endswith('"'):
                            value = value[1:-1]
                        elif value.startswith("'") and value.endswith("'"):
                            value = value[1:-1]
                        if key not in os.environ:
                            os.environ[key] = value
        except Exception:
            pass

    # ========== NCM (nacional) ==========

    def _ncms_da_secao(self, secao: str) -> set:
        """Códigos NCM pertencentes a uma seção ISIC (aceita a letra, ex. `C`,
        ou o nome por extenso, ex. `Indústria de Transformação`)."""
        mapa = self.get_ncm_isic_mapa()
        return {
            linha['NCM'] for linha in mapa
            if linha.get('SecaoISIC') == secao or linha.get('NomeSecaoISIC') == secao
        }

    def _get_ncm_nacional_mensal(self, endpoint: str, ano_minimo: int = None, mes_maximo: int = None,
                                  anos: List[int] = None, lista_ncms: List[int] = None,
                                  secao: str = None) -> List[Dict[str, Any]]:
        body: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'anos': anos or [],
            'lista_ncms': lista_ncms or [],
        }
        items = self._fetch_all_paginated_post(endpoint, body, {})
        if secao:
            ncms_da_secao = self._ncms_da_secao(secao)
            items = [item for item in items if item.get('NCM') in ncms_da_secao]
        return items

    def get_exportacao_ncm_nacional_mensal(self, ano_minimo: int = None, mes_maximo: int = None,
                                            anos: List[int] = None, lista_ncms: List[int] = None,
                                            secao: str = None) -> List[Dict[str, Any]]:
        """Exportações nacionais agregadas por NCM (`/exportacao_agregada_ncm`).

        `secao`, quando informada, filtra os NCMs pela seção ISIC correspondente
        (usando `get_ncm_isic_mapa`, cacheado em memória na instância) — o
        endpoint de origem não carrega essa informação.
        """
        return self._get_ncm_nacional_mensal('/exportacao_agregada_ncm', ano_minimo, mes_maximo, anos, lista_ncms, secao)

    def get_importacao_ncm_nacional_mensal(self, ano_minimo: int = None, mes_maximo: int = None,
                                            anos: List[int] = None, lista_ncms: List[int] = None,
                                            secao: str = None) -> List[Dict[str, Any]]:
        """Importações nacionais agregadas por NCM (`/importacao_agregada_ncm`). Ver `get_exportacao_ncm_nacional_mensal`."""
        return self._get_ncm_nacional_mensal('/importacao_agregada_ncm', ano_minimo, mes_maximo, anos, lista_ncms, secao)

    # ========== ISIC DIVISÃO (nacional) ==========

    def get_exportacao_isic_divisao_nacional_mensal(self, ano_minimo: int = None, mes_maximo: int = None,
                                                      secao: str = None, divisao: int = None,
                                                      agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Exportações nacionais por divisão ISIC (`/exportacao_isic_divisao_gcloud`)."""
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'secao': secao or '',
            'agregado_ano': agregado_ano,
        }
        if divisao is not None:
            params['divisao'] = divisao
        return self._fetch_all_paginated_get('/exportacao_isic_divisao_gcloud', params)

    def get_importacao_isic_divisao_nacional_mensal(self, ano_minimo: int = None, mes_maximo: int = None,
                                                      secao: str = None, divisao: int = None,
                                                      agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Importações nacionais por divisão ISIC (`/importacao_isic_divisao_gcloud`)."""
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'secao': secao or '',
            'agregado_ano': agregado_ano,
        }
        if divisao is not None:
            params['divisao'] = divisao
        return self._fetch_all_paginated_get('/importacao_isic_divisao_gcloud', params)

    # ========== ISIC DIVISÃO (estadual, por país) ==========

    def get_exportacao_isic_divisao_estadual_mensal(self, estado: str = None, pais: str = None,
                                                       ano_minimo: int = None, mes_maximo: int = None,
                                                       secao: str = None, divisao: int = None,
                                                       bloco: int = None, agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Exportações por UF, país e divisão ISIC (`/exportacao_uf_isic_divisao_gcloud`).

        `bloco`: código de bloco econômico (`pais_bloco.CO_BLOCO`, ex. `22`
        para União Europeia) para filtrar por um recorte de países sem listar
        cada um manualmente.
        """
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'estado': estado or '',
            'pais': pais or '',
            'secao': secao or '',
            'agregado_ano': agregado_ano,
        }
        if divisao is not None:
            params['divisao'] = divisao
        if bloco is not None:
            params['bloco'] = bloco
        return self._fetch_all_paginated_get('/exportacao_uf_isic_divisao_gcloud', params)

    def get_importacao_isic_divisao_estadual_mensal(self, estado: str = None, pais: str = None,
                                                       ano_minimo: int = None, mes_maximo: int = None,
                                                       secao: str = None, divisao: int = None,
                                                       bloco: int = None, agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Importações por UF, país e divisão ISIC (`/importacao_uf_isic_divisao_gcloud`). Ver `get_exportacao_isic_divisao_estadual_mensal`."""
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'estado': estado or '',
            'pais': pais or '',
            'secao': secao or '',
            'agregado_ano': agregado_ano,
        }
        if divisao is not None:
            params['divisao'] = divisao
        if bloco is not None:
            params['bloco'] = bloco
        return self._fetch_all_paginated_get('/importacao_uf_isic_divisao_gcloud', params)

    # ========== PAÍS (nacional) ==========

    def get_exportacao_pais_nacional_mensal(self, pais: str = None, secao: str = None,
                                             ano_minimo: int = None, mes_maximo: int = None,
                                             agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Exportações nacionais por país (`/exportacao_pais_gcloud`)."""
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'pais': pais or '',
            'secao': secao or '',
            'agregado_ano': agregado_ano,
        }
        return self._fetch_all_paginated_get('/exportacao_pais_gcloud', params)

    def get_importacao_pais_nacional_mensal(self, pais: str = None, secao: str = None,
                                             ano_minimo: int = None, mes_maximo: int = None,
                                             agregado_ano: bool = False) -> List[Dict[str, Any]]:
        """Importações nacionais por país (`/importacao_pais_gcloud`)."""
        params: Dict[str, Any] = {
            'ano_minimo': ano_minimo or 0,
            'mes_maximo': mes_maximo or 0,
            'pais': pais or '',
            'secao': secao or '',
            'agregado_ano': agregado_ano,
        }
        return self._fetch_all_paginated_get('/importacao_pais_gcloud', params)

    # ========== CATÁLOGO NCM -> ISIC ==========

    def get_ncm_isic_mapa(self) -> List[Dict[str, Any]]:
        """Catálogo NCM -> ISIC (divisão e seção), `/ncm_isic_mapa_gcloud`.

        Catálogo estático (~13 mil códigos) — buscado uma vez e cacheado em
        memória na instância; chamadas seguintes não fazem nova requisição.
        """
        if self._ncm_isic_mapa_cache is None:
            self._ncm_isic_mapa_cache = self._fetch_all_paginated_get('/ncm_isic_mapa_gcloud', {})
        return self._ncm_isic_mapa_cache

    def close(self):
        """Fechar a sessão HTTP"""
        if hasattr(self, 'session'):
            self.session.close()

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()
