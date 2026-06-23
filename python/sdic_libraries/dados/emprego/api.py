"""
Emprego API client para acessar dados de saldo de emprego brasileiro

Este módulo fornece um cliente Python moderno para acessar dados detalhados de 
saldo de emprego de fontes estatísticas governamentais brasileiras com 
tratamento abrangente de erros e segurança de tipos.
"""

from __future__ import annotations

import logging
import os
import re
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Union

import pandas as pd
import requests


class EmpregoAPIError(Exception):
    """Exceção personalizada para erros da API de Emprego"""
    pass


def _get_user_friendly_error_message(error: Exception, status_code: int = None) -> str:
    """
    Converte erros técnicos em mensagens amigáveis para o usuário.
    Remove informações técnicas da API e URLs que não devem ser expostas.
    
    Args:
        error: A exceção original
        status_code: Código de status HTTP, se disponível
        
    Returns:
        str: Mensagem de erro amigável para o usuário
    """
    error_str = str(error).lower()
    
    # Erros de conexão/rede
    if any(x in error_str for x in ['connection', 'conexão', 'timeout', 'timed out']):
        return ("Problema de conectividade detectado. "
                "Verifique sua conexão com a internet e tente novamente em alguns minutos.")
    
    # Erros 404 - Not Found
    if status_code == 404 or '404' in error_str:
        return ("Serviço temporariamente indisponível. "
                "Aguarde alguns minutos e tente novamente.")
    
    # Erros 500 - Server Error
    if status_code and 500 <= status_code < 600:
        return ("O serviço está temporariamente em manutenção. "
                "Tente novamente em alguns minutos.")
    
    # Erros 400 - Bad Request
    if status_code == 400 or '400' in error_str:
        return ("Parâmetros inválidos fornecidos. "
                "Verifique os códigos e datas informados.")
    
    # Erros 401/403 - Authentication/Authorization
    if status_code in [401, 403] or any(x in error_str for x in ['401', '403', 'unauthorized', 'forbidden']):
        return ("Problema de autenticação. "
                "Verifique suas credenciais de acesso.")
    
    # Erro JSON inválido
    if 'json' in error_str:
        return ("Resposta inválida recebida do serviço. "
                "Tente novamente em alguns minutos.")
    
    # Erro genérico sem expor detalhes técnicos
    return ("Erro temporário no serviço. "
            "Verifique os parâmetros e tente novamente em alguns minutos.")


class Emprego:
    """
    Cliente para acessar dados de saldo de emprego
    
    Attributes:
        base_url (str): A URL base para a API de emprego
        timeout (int): Timeout das requisições em segundos
        session (requests.Session): Sessão HTTP para pool de conexões
    """
    
    def __init__(self, base_url: str = None, timeout: int = 30, api_key: str = None):
        """
        Inicializar cliente da API de Emprego
        
        Variáveis de ambiente são carregadas automaticamente de:
        1. Variáveis de ambiente do sistema
        2. Arquivo .env no diretório atual (se existir)
        3. Arquivo .env no diretório home do usuário (se existir)
        
        Nenhuma ação do usuário necessária - funciona perfeitamente pronto para uso!
        
        Args:
            base_url (str, optional): Sobrescrever URL base da API auto-detectada
            timeout (int): Timeout das requisições em segundos. Padrão 30.
            api_key (str, optional): Sobrescrever chave da API auto-detectada
        """
        # Carregar automaticamente arquivos .env (usuário não precisa fazer nada)
        self._load_env_files()
        
        # Auto-carregar configuração com fallbacks inteligentes
        self.base_url = (
            base_url or                                      # 1. Parâmetro explícito
            os.getenv('EMPLOYMENT_API_BASE_URL') or         # 2. Variável de ambiente / .env
            "https://sdicapi.dados.ninja"               # 3. Endpoint público (DNS próprio)
        )
        
        self.timeout = int(os.getenv('API_TIMEOUT', str(timeout)))
        self.api_key = api_key or os.getenv('EMPLOYMENT_API_KEY')  # Opcional
        
        # Auto-configurar nível de logging
        log_level = os.getenv('LOG_LEVEL', 'INFO').upper()
        if hasattr(logging, log_level):
            logging.getLogger().setLevel(getattr(logging, log_level))
        
        self.session = requests.Session()
        self.logger = logging.getLogger(__name__)
        
        # Auto-detectar versão para User-Agent
        version = os.getenv('SDIC_VERSION', '0.4.0')
        self.session.headers.update({
            'User-Agent': f'sdic-libraries/{version}',
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        })
        
        # Opcional: Adicionar chave da API aos headers se disponível
        if self.api_key:
            self.session.headers.update({
                'Authorization': f'Bearer {self.api_key}'
            })
    
    def _make_request(self, endpoint: str, params: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Fazer uma requisição HTTP para a API
        
        Args:
            endpoint (str): Caminho do endpoint da API
            params (dict, optional): Parâmetros de query
            
        Returns:
            dict: Dados de resposta JSON
            
        Raises:
            EmpregoAPIError: Se a requisição falhar ou retornar erro
        """
        url = f"{self.base_url.rstrip('/')}/{endpoint.lstrip('/')}"
        
        try:
            response = self.session.get(url, params=params, timeout=self.timeout)
            response.raise_for_status()
            
            return response.json()
            
        except requests.exceptions.RequestException as e:
            # Log técnico apenas para desenvolvedores/administradores
            self.logger.error(f"Falha na requisição da API: {e}")
            
            # Obter status code se disponível
            status_code = getattr(e.response, 'status_code', None) if hasattr(e, 'response') and e.response else None
            
            # Retornar mensagem amigável para o usuário
            user_message = _get_user_friendly_error_message(e, status_code)
            raise EmpregoAPIError(user_message)
            
        except ValueError as e:
            self.logger.error(f"Resposta JSON inválida: {e}")
            user_message = _get_user_friendly_error_message(e)
            raise EmpregoAPIError(user_message)

    def _make_post_request(self, endpoint: str, body: Any, params: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Fazer uma requisição HTTP POST para a API

        Args:
            endpoint (str): Caminho do endpoint da API
            body: Corpo da requisição JSON
            params (dict, optional): Parâmetros de query

        Returns:
            dict: Dados de resposta JSON

        Raises:
            EmpregoAPIError: Se a requisição falhar ou retornar erro
        """
        url = f"{self.base_url.rstrip('/')}/{endpoint.lstrip('/')}"

        try:
            response = self.session.post(url, json=body, params=params, timeout=self.timeout)
            response.raise_for_status()

            return response.json()

        except requests.exceptions.RequestException as e:
            # Log técnico apenas para desenvolvedores/administradores
            self.logger.error(f"Falha na requisição da API: {e}")
            
            # Obter status code se disponível
            status_code = getattr(e.response, 'status_code', None) if hasattr(e, 'response') and e.response else None
            
            # Retornar mensagem amigável para o usuário
            user_message = _get_user_friendly_error_message(e, status_code)
            raise EmpregoAPIError(user_message)
            
        except ValueError as e:
            self.logger.error(f"Resposta JSON inválida: {e}")
            user_message = _get_user_friendly_error_message(e)
            raise EmpregoAPIError(user_message)

    def _extract_items(self, response: Any) -> List[Dict[str, Any]]:
        """Extrair itens de respostas paginadas e não paginadas sem expor metadados."""
        if isinstance(response, list):
            return [self._normalize_response_item(item) for item in response if isinstance(item, dict)]

        if not isinstance(response, dict):
            raise EmpregoAPIError("Formato de resposta inesperado da API")

        items = response.get('items')
        if isinstance(items, list):
            return [self._normalize_response_item(item) for item in items if isinstance(item, dict)]

        for alt_key in ('data', 'results', 'records'):
            alt_items = response.get(alt_key)
            if isinstance(alt_items, list):
                return [self._normalize_response_item(item) for item in alt_items if isinstance(item, dict)]

        return []

    def _normalize_response_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        """Normalizar aliases de campos para manter compatibilidade entre versões da API."""
        normalized = dict(item)

        if 'mes_referencia' in normalized and 'competencia' not in normalized:
            normalized['competencia'] = normalized['mes_referencia']
        if 'competencia' in normalized and 'mes_referencia' not in normalized:
            normalized['mes_referencia'] = normalized['competencia']

        if 'ano' in normalized and 'Ano' not in normalized:
            normalized['Ano'] = normalized['ano']
        if 'Ano' in normalized and 'ano' not in normalized:
            normalized['ano'] = normalized['Ano']

        if 'cod_municipio' in normalized and 'codigo_municipio' not in normalized:
            normalized['codigo_municipio'] = normalized['cod_municipio']
        if 'cod_uf' in normalized and 'codigo_uf' not in normalized:
            normalized['codigo_uf'] = normalized['cod_uf']

        return normalized

    def _get_total_pages(self, response: Any) -> Optional[int]:
        """Ler total de páginas quando disponível."""
        if not isinstance(response, dict):
            return None

        for key in ('pages', 'total_pages', 'paginas', 'totalPaginas'):
            value = response.get(key)
            if isinstance(value, int) and value > 0:
                return value

        return None

    def _get_total_count(self, response: Any) -> Optional[int]:
        """Ler total de registros quando disponível (API 2.0 usa count/items)."""
        if not isinstance(response, dict):
            return None

        value = response.get('count')
        if isinstance(value, int) and value >= 0:
            return value

        return None

    def _fetch_all_paginated_get(self, endpoint: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Consolidar automaticamente todas as páginas de endpoints GET."""
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

            total_pages = self._get_total_pages(response)
            if total_pages is not None and pagina >= total_pages:
                break

            if total_count is not None and len(all_items) >= total_count:
                break

            if len(items) < page_size:
                break

            pagina += 1

        return all_items

    def _fetch_all_paginated_post(self, endpoint: str, body: Any, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Consolidar automaticamente todas as páginas de endpoints POST."""
        all_items: List[Dict[str, Any]] = []
        pagina = 1
        total_count: Optional[int] = None

        while True:
            request_params = dict(params)
            request_params['pagina'] = pagina
            request_params.setdefault('tamanho_pagina', 1000)
            page_size = int(request_params.get('tamanho_pagina', 1000) or 1000)

            response = self._make_post_request(endpoint, body, params=request_params)
            items = self._extract_items(response)
            if not items:
                break

            all_items.extend(items)

            if total_count is None:
                total_count = self._get_total_count(response)

            total_pages = self._get_total_pages(response)
            if total_pages is not None and pagina >= total_pages:
                break

            if total_count is not None and len(all_items) >= total_count:
                break

            if len(items) < page_size:
                break

            pagina += 1

        return all_items

    def _normalize_key(self, key: str) -> str:
        """Normalizar nomes de colunas para comparação robusta."""
        return re.sub(r'[^a-z0-9]', '', key.lower())

    def _is_geo_key(self, normalized_key: str, level: str) -> bool:
        """Verificar se a chave representa um campo geográfico de um nível específico."""
        state_tokens = (
            'uf', 'siglauf', 'coduf', 'codigouf', 'nomeuf',
            'estado', 'nomeestado', 'codestado', 'codigoestado'
        )
        municipal_tokens = (
            'municipio', 'nomemunicipio', 'codmunicipio', 'codigomunicipio',
            'ibge', 'codigoibge', 'codibge', 'municipioibge', 'codigomunicipioibge'
        )

        if level == 'estadual':
            return any(token in normalized_key for token in state_tokens)

        if level == 'municipal':
            return any(token in normalized_key for token in municipal_tokens)

        return False

    def _is_cnae_key(self, normalized_key: str, level: str) -> bool:
        """Verificar se a chave representa campos de um nível CNAE específico."""
        if level == 'grupo':
            return 'grupocnae' in normalized_key

        if level == 'subclasse':
            return 'subclasse' in normalized_key

        return False

    def _filter_estoque_items(
        self,
        items: List[Dict[str, Any]],
        nivel_agregacao: str,
        nivel_cnae: int,
        has_grupos: bool = False,
    ) -> List[Dict[str, Any]]:
        """
        Remover colunas além do nível de desagregação solicitado para estoque.

        Regras:
        - Nacional: remove campos estaduais e municipais
        - Estadual: remove campos municipais
        - nivel_cnae=2 (divisão): remove campos de grupo e subclasse
        - nivel_cnae=3 (grupo): remove campos de subclasse
        """
        remove_geo_levels: List[str] = []
        if nivel_agregacao == 'nacional':
            remove_geo_levels = ['estadual', 'municipal']
        elif nivel_agregacao == 'estadual':
            remove_geo_levels = ['municipal']

        remove_cnae_levels: List[str] = []
        if nivel_cnae == 2:
            remove_cnae_levels = ['grupo', 'subclasse']
        elif nivel_cnae == 3:
            remove_cnae_levels = ['subclasse']

        filtered_items: List[Dict[str, Any]] = []
        for item in items:
            if not isinstance(item, dict):
                filtered_items.append(item)
                continue

            cleaned_item: Dict[str, Any] = {}
            for key, value in item.items():
                normalized_key = self._normalize_key(key)

                remove_geo = any(
                    self._is_geo_key(normalized_key, geo_level)
                    for geo_level in remove_geo_levels
                )
                if remove_geo:
                    continue

                remove_cnae = any(
                    self._is_cnae_key(normalized_key, cnae_level)
                    for cnae_level in remove_cnae_levels
                )
                if remove_cnae:
                    continue

                if not has_grupos and normalized_key == 'nomegrupo':
                    continue

                if has_grupos and value is None:
                    continue

                cleaned_item[key] = value

            filtered_items.append(cleaned_item)

        return filtered_items

    def _load_env_files(self):
        """
        Carregar automaticamente arquivos .env com fallback para parsing manual
        Prioridade: diretório atual > home do usuário > ambiente do sistema
        """
        # Tentar python-dotenv primeiro (mais robusto)
        try:
            from dotenv import load_dotenv
            
            env_locations = [
                Path.cwd() / '.env',           # Diretório atual
                Path.home() / '.env',          # Diretório home do usuário  
                Path('/etc/sdic/.env'),        # Configuração do sistema
            ]
            
            for env_file in env_locations:
                if env_file.exists():
                    load_dotenv(env_file, override=False)  # Não sobrescrever vars existentes
                    break  # Usar o primeiro encontrado
                    
        except ImportError:
            # Fallback para parsing manual se python-dotenv não estiver disponível
            env_locations = [
                Path.cwd() / '.env',           # Diretório atual
                Path.home() / '.env',          # Diretório home do usuário  
                Path('/etc/sdic/.env'),        # Configuração do sistema
            ]
            
            for env_file in env_locations:
                if env_file.exists():
                    self._load_env_file(env_file)
                    break  # Usar o primeiro encontrado

    def _load_env_file(self, env_file_path: Path):
        """Carregar variáveis de ambiente do arquivo"""
        try:
            with open(env_file_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        key, value = key.strip(), value.strip()
                        # Remover aspas se presentes
                        if value.startswith('"') and value.endswith('"'):
                            value = value[1:-1]
                        elif value.startswith("'") and value.endswith("'"):
                            value = value[1:-1]
                        # Definir apenas se não já estiver no ambiente
                        if key not in os.environ:
                            os.environ[key] = value
        except Exception:
            pass  # Ignorar erros silenciosamente - experiência fluida

    # ========== ESTOQUE DE EMPREGO ==========

    def get_estoque_emprego_nacional(self,
                                    codigos_cnae: List[str] = None,
                                    nivel_cnae: int = 2,
                                    agregado: bool = False) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de estoque de emprego nacional,
        fazendo loop automático por todas as páginas de resultado.
        
        Args:
            codigos_cnae (List[str], optional): Lista de códigos CNAE
            nivel_cnae (int): Nível CNAE (2=divisão, 3=grupo)
            agregado (bool): Se True, agrega todos os estados
            
        Returns:
            List[Dict[str, Any]]: Todos os registros de estoque de emprego
            
        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        if nivel_cnae not in [2, 3]:
            raise ValueError("nivel_cnae deve ser 2 (divisão) ou 3 (grupo)")

        # Construir parâmetros base
        params: Dict[str, Any] = {
            'nivel_cnae': nivel_cnae,
            'agregado': agregado,
            'tamanho_pagina': 1000,
        }
        
        if codigos_cnae:
            params['codigos_cnae'] = ','.join(codigos_cnae)
        
        items = self._fetch_all_paginated_get('/get_estoque_emprego_nacional/', params)
        nivel_agregacao = 'nacional' if agregado else 'estadual'
        return self._filter_estoque_items(items, nivel_agregacao=nivel_agregacao, nivel_cnae=nivel_cnae, has_grupos=False)

    def get_estoque_emprego_estadual(self,
                                    ufs: Union[str, List[str]],
                                    codigos_cnae: List[str] = None,
                                    nivel_cnae: int = 2) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de estoque de emprego estadual,
        fazendo loop automático por todas as páginas de resultado.
        
        Args:
            ufs (str | List[str]): Sigla(s) de UF (ex: 'SP' ou ['SP', 'RJ'])
            codigos_cnae (List[str], optional): Lista de códigos CNAE
            nivel_cnae (int): Nível CNAE (2=divisão, 3=grupo)
            
        Returns:
            List[Dict[str, Any]]: Todos os registros de estoque de emprego
            
        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        if nivel_cnae not in [2, 3]:
            raise ValueError("nivel_cnae deve ser 2 (divisão) ou 3 (grupo)")

        ufs_str = ','.join(ufs) if isinstance(ufs, list) else ufs

        # Construir parâmetros base
        params: Dict[str, Any] = {
            'ufs': ufs_str,
            'nivel_cnae': nivel_cnae,
            'tamanho_pagina': 1000,
        }
        
        if codigos_cnae:
            params['codigos_cnae'] = ','.join(codigos_cnae)
        
        items = self._fetch_all_paginated_get('/get_estoque_emprego_estadual/', params)
        return self._filter_estoque_items(items, nivel_agregacao='estadual', nivel_cnae=nivel_cnae, has_grupos=False)

    def get_estoque_emprego_nacional_lista_cnae(self,
                                               codigos_cnae: List[str],
                                               nivel_cnae: int = 2,
                                               agregado: bool = False) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de estoque de emprego nacional para lista de códigos CNAE,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            codigos_cnae (List[str]): Lista de códigos CNAE
            nivel_cnae (int): Nível CNAE (2=divisão, 3=grupo)
            agregado (bool): Se True, agrega todos os estados

        Returns:
            List[Dict[str, Any]]: Todos os registros de estoque de emprego

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        if not codigos_cnae:
            raise ValueError("codigos_cnae deve conter pelo menos um código CNAE")

        if nivel_cnae not in [2, 3]:
            raise ValueError("nivel_cnae deve ser 2 (divisão) ou 3 (grupo)")

        query_params: Dict[str, Any] = {
            'nivel_cnae': nivel_cnae,
            'agregado': agregado,
            'tamanho_pagina': 1000
        }

        body = {'codigos_cnae': codigos_cnae}
        items = self._fetch_all_paginated_post('/get_estoque_emprego_nacional_lista_cnae', body, query_params)
        nivel_agregacao = 'nacional' if agregado else 'estadual'
        return self._filter_estoque_items(items, nivel_agregacao=nivel_agregacao, nivel_cnae=nivel_cnae, has_grupos=False)

    def get_estoque_emprego_nacional_grupos_cnae(self,
                                                grupos_cnae: List[Dict[str, Any]],
                                                nivel_cnae: int = 2,
                                                agregado: bool = False) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de estoque de emprego nacional para grupos de códigos CNAE,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            grupos_cnae (List[Dict]): Lista de grupos com nome_grupo e codigos_cnae
            nivel_cnae (int): Nível CNAE (2=divisão, 3=grupo)
            agregado (bool): Se True, agrega todos os estados

        Returns:
            List[Dict[str, Any]]: Todos os registros de estoque de emprego

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        if not grupos_cnae:
            raise ValueError("grupos_cnae deve conter pelo menos um grupo")

        if nivel_cnae not in [2, 3]:
            raise ValueError("nivel_cnae deve ser 2 (divisão) ou 3 (grupo)")

        query_params: Dict[str, Any] = {
            'nivel_cnae': nivel_cnae,
            'agregado': agregado,
            'tamanho_pagina': 1000
        }

        items = self._fetch_all_paginated_post('/get_estoque_emprego_nacional_grupos_cnae', grupos_cnae, query_params)
        nivel_agregacao = 'nacional' if agregado else 'estadual'
        return self._filter_estoque_items(items, nivel_agregacao=nivel_agregacao, nivel_cnae=nivel_cnae, has_grupos=True)

    def get_estoque_emprego_estadual_lista_cnae(self,
                                               ufs: Union[str, List[str]],
                                               codigos_cnae: List[str],
                                               nivel_cnae: int = 2,
                                               agregado: bool = False) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de estoque de emprego estadual para lista de códigos CNAE,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            ufs (str | List[str]): Sigla(s) de UF (ex: 'SP' ou ['SP', 'RJ'])
            codigos_cnae (List[str]): Lista de códigos CNAE
            nivel_cnae (int): Nível CNAE (2=divisão, 3=grupo)
            agregado (bool): Se True, agrega as UFs informadas

        Returns:
            List[Dict[str, Any]]: Todos os registros de estoque de emprego

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        if not codigos_cnae:
            raise ValueError("codigos_cnae deve conter pelo menos um código CNAE")

        if nivel_cnae not in [2, 3]:
            raise ValueError("nivel_cnae deve ser 2 (divisão) ou 3 (grupo)")

        ufs_str = ','.join(ufs) if isinstance(ufs, list) else ufs

        query_params: Dict[str, Any] = {
            'ufs': ufs_str,
            'nivel_cnae': nivel_cnae,
            'agregado': agregado,
            'tamanho_pagina': 1000
        }

        body = {'codigos_cnae': codigos_cnae}
        items = self._fetch_all_paginated_post('/get_estoque_emprego_estadual_lista_cnae/', body, query_params)
        return self._filter_estoque_items(items, nivel_agregacao='estadual', nivel_cnae=nivel_cnae, has_grupos=False)

    def get_estoque_emprego_estadual_grupos_cnae(self,
                                                ufs: Union[str, List[str]],
                                                grupos_cnae: List[Dict[str, Any]],
                                                nivel_cnae: int = 2,
                                                agregado: bool = False) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de estoque de emprego estadual para grupos de códigos CNAE,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            ufs (str | List[str]): Sigla(s) de UF (ex: 'SP' ou ['SP', 'RJ'])
            grupos_cnae (List[Dict]): Lista de grupos com nome_grupo e codigos_cnae
            nivel_cnae (int): Nível CNAE (2=divisão, 3=grupo)
            agregado (bool): Se True, agrega as UFs informadas

        Returns:
            List[Dict[str, Any]]: Todos os registros de estoque de emprego

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        if not grupos_cnae:
            raise ValueError("grupos_cnae deve conter pelo menos um grupo")

        if nivel_cnae not in [2, 3]:
            raise ValueError("nivel_cnae deve ser 2 (divisão) ou 3 (grupo)")

        ufs_str = ','.join(ufs) if isinstance(ufs, list) else ufs

        query_params: Dict[str, Any] = {
            'ufs': ufs_str,
            'nivel_cnae': nivel_cnae,
            'agregado': agregado,
            'tamanho_pagina': 1000
        }

        items = self._fetch_all_paginated_post('/get_estoque_emprego_estadual_grupos_cnae/', grupos_cnae, query_params)
        return self._filter_estoque_items(items, nivel_agregacao='estadual', nivel_cnae=nivel_cnae, has_grupos=True)

    # ========== SALDO CAGED ==========

    def get_saldo_caged_nacional_divisao(self,
                                        codigos_divisao: List[str] = None,
                                        data_minima: str = None,
                                        data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED nacional por divisão,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            codigos_divisao (List[str], optional): Lista de códigos de divisão
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        params: Dict[str, Any] = {'tamanho_pagina': 1000}

        if codigos_divisao:
            params['codigos_divisao'] = codigos_divisao
        if data_minima:
            params['data_minima'] = data_minima
        if data_maxima:
            params['data_maxima'] = data_maxima

        return self._fetch_all_paginated_get('/saldo_caged/nacional/divisao', params)

    def get_saldo_caged_nacional_grupo(self,
                                      codigos_grupo: List[str] = None,
                                      data_minima: str = None,
                                      data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED nacional por grupo,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            codigos_grupo (List[str], optional): Lista de códigos de grupo
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        params: Dict[str, Any] = {'tamanho_pagina': 1000}

        if codigos_grupo:
            params['codigos_grupo'] = codigos_grupo
        if data_minima:
            params['data_minima'] = data_minima
        if data_maxima:
            params['data_maxima'] = data_maxima

        return self._fetch_all_paginated_get('/saldo_caged/nacional/grupo', params)

    def get_saldo_caged_nacional_subclasse(self,
                                          codigos_subclasse: List[str] = None,
                                          data_minima: str = None,
                                          data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED nacional por subclasse,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            codigos_subclasse (List[str], optional): Lista de códigos de subclasse
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        params: Dict[str, Any] = {'tamanho_pagina': 1000}

        if codigos_subclasse:
            params['codigos_subclasse'] = codigos_subclasse
        if data_minima:
            params['data_minima'] = data_minima
        if data_maxima:
            params['data_maxima'] = data_maxima

        return self._fetch_all_paginated_get('/saldo_caged/nacional/subclasse', params)

    def get_saldo_caged_estadual_divisao(self,
                                        siglas_uf: List[str] = None,
                                        codigos_uf: List[int] = None,
                                        codigos_divisao: List[str] = None,
                                        data_minima: str = None,
                                        data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED estadual por divisão,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            siglas_uf (List[str], optional): Lista de siglas de UF
            codigos_uf (List[int], optional): Lista de códigos de UF
            codigos_divisao (List[str], optional): Lista de códigos de divisão
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        params: Dict[str, Any] = {'tamanho_pagina': 1000}

        if siglas_uf:
            params['siglas_uf'] = siglas_uf
        if codigos_uf:
            params['codigos_uf'] = codigos_uf
        if codigos_divisao:
            params['codigos_divisao'] = codigos_divisao
        if data_minima:
            params['data_minima'] = data_minima
        if data_maxima:
            params['data_maxima'] = data_maxima

        return self._fetch_all_paginated_get('/saldo_caged/estadual/divisao', params)

    def get_saldo_caged_estadual_grupo(self,
                                      siglas_uf: List[str] = None,
                                      codigos_uf: List[int] = None,
                                      codigos_grupo: List[str] = None,
                                      data_minima: str = None,
                                      data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED estadual por grupo,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            siglas_uf (List[str], optional): Lista de siglas de UF
            codigos_uf (List[int], optional): Lista de códigos de UF
            codigos_grupo (List[str], optional): Lista de códigos de grupo
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        params: Dict[str, Any] = {'tamanho_pagina': 1000}

        if siglas_uf:
            params['siglas_uf'] = siglas_uf
        if codigos_uf:
            params['codigos_uf'] = codigos_uf
        if codigos_grupo:
            params['codigos_grupo'] = codigos_grupo
        if data_minima:
            params['data_minima'] = data_minima
        if data_maxima:
            params['data_maxima'] = data_maxima

        return self._fetch_all_paginated_get('/saldo_caged/estadual/grupo', params)

    def get_saldo_caged_estadual_subclasse(self,
                                          siglas_uf: List[str] = None,
                                          codigos_uf: List[int] = None,
                                          codigos_subclasse: List[str] = None,
                                          data_minima: str = None,
                                          data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED estadual por subclasse,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            siglas_uf (List[str], optional): Lista de siglas de UF
            codigos_uf (List[int], optional): Lista de códigos de UF
            codigos_subclasse (List[str], optional): Lista de códigos de subclasse
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        params: Dict[str, Any] = {'tamanho_pagina': 1000}

        if siglas_uf:
            params['siglas_uf'] = siglas_uf
        if codigos_uf:
            params['codigos_uf'] = codigos_uf
        if codigos_subclasse:
            params['codigos_subclasse'] = codigos_subclasse
        if data_minima:
            params['data_minima'] = data_minima
        if data_maxima:
            params['data_maxima'] = data_maxima

        return self._fetch_all_paginated_get('/saldo_caged/estadual/subclasse', params)

    def get_saldo_caged_municipal_divisao(self,
                                         siglas_uf: List[str] = None,
                                         codigos_uf: List[int] = None,
                                         codigos_municipio: List[int] = None,
                                         codigos_divisao: List[str] = None,
                                         data_minima: str = None,
                                         data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED municipal por divisão,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            siglas_uf (List[str], optional): Lista de siglas de UF
            codigos_uf (List[int], optional): Lista de códigos de UF
            codigos_municipio (List[int], optional): Lista de códigos de município
            codigos_divisao (List[str], optional): Lista de códigos de divisão
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        params: Dict[str, Any] = {'tamanho_pagina': 1000}

        if siglas_uf:
            params['siglas_uf'] = siglas_uf
        if codigos_uf:
            params['codigos_uf'] = codigos_uf
        if codigos_municipio:
            params['codigos_municipio'] = codigos_municipio
        if codigos_divisao:
            params['codigos_divisao'] = codigos_divisao
        if data_minima:
            params['data_minima'] = data_minima
        if data_maxima:
            params['data_maxima'] = data_maxima

        return self._fetch_all_paginated_get('/saldo_caged/municipal/divisao', params)

    def get_saldo_caged_municipal_grupo(self,
                                       siglas_uf: List[str] = None,
                                       codigos_uf: List[int] = None,
                                       codigos_municipio: List[int] = None,
                                       codigos_grupo: List[str] = None,
                                       data_minima: str = None,
                                       data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED municipal por grupo,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            siglas_uf (List[str], optional): Lista de siglas de UF
            codigos_uf (List[int], optional): Lista de códigos de UF
            codigos_municipio (List[int], optional): Lista de códigos de município
            codigos_grupo (List[str], optional): Lista de códigos de grupo
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        params: Dict[str, Any] = {'tamanho_pagina': 1000}

        if siglas_uf:
            params['siglas_uf'] = siglas_uf
        if codigos_uf:
            params['codigos_uf'] = codigos_uf
        if codigos_municipio:
            params['codigos_municipio'] = codigos_municipio
        if codigos_grupo:
            params['codigos_grupo'] = codigos_grupo
        if data_minima:
            params['data_minima'] = data_minima
        if data_maxima:
            params['data_maxima'] = data_maxima

        return self._fetch_all_paginated_get('/saldo_caged/municipal/grupo', params)

    def get_saldo_caged_municipal_subclasse(self,
                                           siglas_uf: List[str] = None,
                                           codigos_uf: List[int] = None,
                                           codigos_municipio: List[int] = None,
                                           codigos_subclasse: List[str] = None,
                                           data_minima: str = None,
                                           data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED municipal por subclasse,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            siglas_uf (List[str], optional): Lista de siglas de UF
            codigos_uf (List[int], optional): Lista de códigos de UF
            codigos_municipio (List[int], optional): Lista de códigos de município
            codigos_subclasse (List[str], optional): Lista de códigos de subclasse
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        params: Dict[str, Any] = {'tamanho_pagina': 1000}

        if siglas_uf:
            params['siglas_uf'] = siglas_uf
        if codigos_uf:
            params['codigos_uf'] = codigos_uf
        if codigos_municipio:
            params['codigos_municipio'] = codigos_municipio
        if codigos_subclasse:
            params['codigos_subclasse'] = codigos_subclasse
        if data_minima:
            params['data_minima'] = data_minima
        if data_maxima:
            params['data_maxima'] = data_maxima

        return self._fetch_all_paginated_get('/saldo_caged/municipal/subclasse', params)

    # ========== SALDO CAGED POR LISTA DE CÓDIGOS ==========

    def get_saldo_caged_lista_codigos(self,
                                     nivel_agregacao: str,
                                     nivel_cnae: str,
                                     codigos: List[str],
                                     siglas_uf: List[str] = None,
                                     codigos_uf: List[int] = None,
                                     codigos_municipio: List[int] = None,
                                     data_minima: str = None,
                                     data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED por lista de códigos,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            nivel_agregacao (str): 'nacional', 'estadual', ou 'municipal'
            nivel_cnae (str): 'divisao', 'grupo', ou 'subclasse'
            codigos (List[str]): Lista de códigos CNAE
            siglas_uf (List[str], optional): Lista de siglas de UF
            codigos_uf (List[int], optional): Lista de códigos de UF
            codigos_municipio (List[int], optional): Lista de códigos de município
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        if nivel_agregacao not in ('nacional', 'estadual', 'municipal'):
            raise ValueError("nivel_agregacao deve ser 'nacional', 'estadual' ou 'municipal'")
        
        if nivel_cnae not in ('divisao', 'grupo', 'subclasse'):
            raise ValueError("nivel_cnae deve ser 'divisao', 'grupo' ou 'subclasse'")

        if not codigos:
            raise ValueError("codigos deve conter pelo menos um código CNAE")

        body = {
            'codigos': codigos,
            'siglas_uf': siglas_uf,
            'codigos_uf': codigos_uf,
            'codigos_municipio': codigos_municipio,
            'data_minima': data_minima,
            'data_maxima': data_maxima
        }

        # Remove valores None
        body = {k: v for k, v in body.items() if v is not None}

        query_params: Dict[str, Any] = {
            'tamanho_pagina': 1000
        }

        endpoint = f'/saldo_caged/{nivel_agregacao}/{nivel_cnae}/lista_codigos'
        return self._fetch_all_paginated_post(endpoint, body, query_params)

    def get_saldo_caged_grupos_codigos(self,
                                      nivel_agregacao: str,
                                      nivel_cnae: str,
                                      grupos: List[Dict[str, Any]],
                                      siglas_uf: List[str] = None,
                                      codigos_uf: List[int] = None,
                                      codigos_municipio: List[int] = None,
                                      data_minima: str = None,
                                      data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter TODOS os dados de saldo CAGED por grupos de códigos,
        fazendo loop automático por todas as páginas de resultado.

        Args:
            nivel_agregacao (str): 'nacional', 'estadual', ou 'municipal'
            nivel_cnae (str): 'divisao', 'grupo', ou 'subclasse'
            grupos (List[Dict]): Lista de grupos com nome_grupo e codigos
            siglas_uf (List[str], optional): Lista de siglas de UF
            codigos_uf (List[int], optional): Lista de códigos de UF
            codigos_municipio (List[int], optional): Lista de códigos de município
            data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
            data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo CAGED

        Raises:
            EmpregoAPIError: Se a requisição da API falhar
        """
        if nivel_agregacao not in ('nacional', 'estadual', 'municipal'):
            raise ValueError("nivel_agregacao deve ser 'nacional', 'estadual' ou 'municipal'")
        
        if nivel_cnae not in ('divisao', 'grupo', 'subclasse'):
            raise ValueError("nivel_cnae deve ser 'divisao', 'grupo' ou 'subclasse'")

        if not grupos:
            raise ValueError("grupos deve conter pelo menos um grupo")

        body = {
            'grupos': grupos,
            'siglas_uf': siglas_uf,
            'codigos_uf': codigos_uf,
            'codigos_municipio': codigos_municipio,
            'data_minima': data_minima,
            'data_maxima': data_maxima
        }

        # Remove valores None
        body = {k: v for k, v in body.items() if v is not None}

        query_params: Dict[str, Any] = {
            'tamanho_pagina': 1000
        }

        endpoint = f'/saldo_caged/{nivel_agregacao}/{nivel_cnae}/grupos_codigos'
        return self._fetch_all_paginated_post(endpoint, body, query_params)

    # ========== SALDO EMPREGO DETALHADO (API UNIFICADA) ==========

    def get_saldo_emprego_detalhado(
            self,
            nivel_agregacao: str = 'nacional',
            nivel_cnae: int = None,
            sigla_uf: str = None,
            uf: str = None,
            codigo_cnae: str = None,
            codigo_municipio: int = None,
            data_minima: str = None,
            data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter dados de saldo de emprego detalhado usando endpoints CAGED corretos.

        Args:
            nivel_agregacao (str): 'nacional', 'estadual' ou 'municipal'
            nivel_cnae (int, optional): Nível CNAE (2=divisão, 3=grupo, None=subclasse)
            sigla_uf (str, optional): Sigla do estado (ex: 'SP')
            uf (str, optional): Alias legado para sigla_uf
            codigo_cnae (str, optional): Filtro por código CNAE específico
            codigo_municipio (int, optional): Código IBGE do município
            data_minima (str, optional): Data mínima em formato YYYY-MM-DD
            data_maxima (str, optional): Data máxima em formato YYYY-MM-DD

        Returns:
            List[Dict[str, Any]]: Todos os registros de saldo de emprego
        """
        # Mapear nível CNAE para endpoints corretos
        if nivel_cnae is None or nivel_cnae == 4:
            nivel_endpoint = 'subclasse'
        elif nivel_cnae == 3:
            nivel_endpoint = 'grupo'
        elif nivel_cnae == 2:
            nivel_endpoint = 'divisao'
        else:
            raise ValueError("nivel_cnae deve ser None (subclasse), 2 (divisão) ou 3 (grupo)")
        
        # Construir parâmetros
        params: Dict[str, Any] = {}
        if data_minima:
            params['data_minima'] = data_minima
        if data_maxima:
            params['data_maxima'] = data_maxima
        if codigo_cnae:
            if nivel_endpoint == 'divisao':
                params['codigos_divisao'] = [codigo_cnae]
            elif nivel_endpoint == 'grupo':
                params['codigos_grupo'] = [codigo_cnae]
            else:  # subclasse
                params['codigos_subclasse'] = [codigo_cnae]
        
        # Usar endpoints CAGED corretos baseados na documentação
        if nivel_agregacao == 'nacional':
            if nivel_endpoint == 'divisao':
                return self.get_saldo_caged_nacional_divisao(**params)
            elif nivel_endpoint == 'grupo':
                return self.get_saldo_caged_nacional_grupo(**params)
            else:  # subclasse
                return self.get_saldo_caged_nacional_subclasse(**params)
        elif nivel_agregacao == 'estadual':
            resolved_uf = sigla_uf or uf
            if not resolved_uf:
                raise ValueError("sigla_uf é obrigatória para nível estadual")
            params['siglas_uf'] = [resolved_uf]
            
            if nivel_endpoint == 'divisao':
                return self.get_saldo_caged_estadual_divisao(**params)
            elif nivel_endpoint == 'grupo':
                return self.get_saldo_caged_estadual_grupo(**params)
            else:  # subclasse
                return self.get_saldo_caged_estadual_subclasse(**params)
        elif nivel_agregacao == 'municipal':
            if not codigo_municipio:
                raise ValueError("codigo_municipio é obrigatório para nível municipal")
            params['codigos_municipio'] = [int(codigo_municipio)]
            
            if nivel_endpoint == 'divisao':
                return self.get_saldo_caged_municipal_divisao(**params)
            elif nivel_endpoint == 'grupo':
                return self.get_saldo_caged_municipal_grupo(**params)
            else:  # subclasse
                return self.get_saldo_caged_municipal_subclasse(**params)
        else:
            raise ValueError("nivel_agregacao deve ser 'nacional', 'estadual' ou 'municipal'")

    def get_saldo_emprego_detalhado_lista_cnae(
            self,
            lista_cnae: List[str],
            nome_grupo: str,
            nivel_agregacao: str = 'nacional',
            nivel_cnae: int = None,
            sigla_uf: str = None,
            uf: str = None,
            codigo_municipio: int = None,
            data_minima: str = None,
            data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter dados de saldo de emprego para uma lista de códigos CNAE agrupados.

        Args:
            lista_cnae (List[str]): Códigos CNAE do grupo
            nome_grupo (str): Nome descritivo do grupo
            nivel_agregacao (str): 'nacional', 'estadual' ou 'municipal'
            nivel_cnae (int, optional): Nível CNAE (2=divisão, 3=grupo)
            sigla_uf (str, optional): Sigla do estado
            uf (str, optional): Alias legado para sigla_uf
            codigo_municipio (int, optional): Código IBGE do município
            data_minima (str, optional): Data mínima em formato YYYY-MM-DD
            data_maxima (str, optional): Data máxima em formato YYYY-MM-DD

        Returns:
            List[Dict[str, Any]]: Todos os registros agrupados
        """
        # Mapear nível CNAE para string
        if nivel_cnae is None or nivel_cnae == 4:
            nivel_str = 'subclasse'
        elif nivel_cnae == 3:
            nivel_str = 'grupo'
        elif nivel_cnae == 2:
            nivel_str = 'divisao'
        else:
            raise ValueError("nivel_cnae deve ser None (subclasse), 2 (divisão) ou 3 (grupo)")
        
        # Usar endpoint CAGED correto baseado na documentação da API
        return self.get_saldo_caged_lista_codigos(
            nivel_agregacao=nivel_agregacao,
            nivel_cnae=nivel_str,
            codigos=lista_cnae,  # Parâmetro correto é 'codigos'
            siglas_uf=[sigla_uf or uf] if sigla_uf or uf else None,
            codigos_municipio=[int(codigo_municipio)] if codigo_municipio else None,
            data_minima=data_minima,
            data_maxima=data_maxima
        )

    def get_saldo_emprego_detalhado_grupos_cnae(
            self,
            grupos_cnae: List[Dict[str, Any]],
            nivel_agregacao: str = 'nacional',
            nivel_cnae: int = None,
            sigla_uf: str = None,
            data_minima: str = None,
            data_maxima: str = None) -> List[Dict[str, Any]]:
        """
        Obter dados de saldo de emprego para múltiplos grupos de códigos CNAE.

        Args:
            grupos_cnae (List[Dict]): Lista de grupos com nome_grupo e codigos_cnae
            nivel_agregacao (str): 'nacional', 'estadual' ou 'municipal'
            nivel_cnae (int, optional): Nível CNAE (2=divisão, 3=grupo)
            sigla_uf (str, optional): Sigla do estado
            data_minima (str, optional): Data mínima em formato YYYY-MM-DD
            data_maxima (str, optional): Data máxima em formato YYYY-MM-DD

        Returns:
            List[Dict[str, Any]]: Todos os registros agrupados
        """
        # Mapear nível CNAE para string
        if nivel_cnae is None or nivel_cnae == 4:
            nivel_str = 'subclasse'
        elif nivel_cnae == 3:
            nivel_str = 'grupo'
        elif nivel_cnae == 2:
            nivel_str = 'divisao'
        else:
            raise ValueError("nivel_cnae deve ser None (subclasse), 2 (divisão) ou 3 (grupo)")
        
        # Transformar formato dos grupos para API CAGED (codigos_cnae -> codigos)
        grupos_formatados = []
        for grupo in grupos_cnae:
            grupo_corrigido = {
                'nome_grupo': grupo.get('nome_grupo', 'Grupo'),
                'codigos': grupo.get('codigos_cnae', grupo.get('codigos', []))
            }
            grupos_formatados.append(grupo_corrigido)
        
        # Usar endpoint CAGED correto baseado na documentação da API
        return self.get_saldo_caged_grupos_codigos(
            nivel_agregacao=nivel_agregacao,
            nivel_cnae=nivel_str,
            grupos=grupos_formatados,  # Grupos com formato correto
            siglas_uf=[sigla_uf] if sigla_uf else None,
            data_minima=data_minima,
            data_maxima=data_maxima
        )

    def get_estoque_emprego_lista_cnae_agregado(
            self,
            codigos_cnae: List[str],
            nivel_cnae: int,
            agregado: bool = False,
            sigla_uf: str = None) -> List[Dict[str, Any]]:
        """
        Obter dados de estoque de emprego para lista de códigos CNAE, roteando para
        endpoint nacional ou estadual conforme os parâmetros.

        Args:
            codigos_cnae (List[str]): Lista de códigos CNAE
            nivel_cnae (int): Nível CNAE (2=divisão, 3=grupo)
            agregado (bool): Se True, usa endpoint nacional
            sigla_uf (str, optional): Sigla do estado; define endpoint estadual

        Returns:
            List[Dict[str, Any]]: Todos os registros de estoque
        """
        if sigla_uf:
            return self.get_estoque_emprego_estadual_lista_cnae(sigla_uf, codigos_cnae, nivel_cnae)
        return self.get_estoque_emprego_nacional_lista_cnae(codigos_cnae, nivel_cnae, agregado)

    def get_saldo_emprego_as_dataframe(self, nivel_agregacao: str = 'nacional', **kwargs) -> 'pd.DataFrame':
        """
        Obter dados de saldo de emprego como DataFrame.

        Args:
            nivel_agregacao (str): 'nacional', 'estadual' ou 'municipal'
            **kwargs: Parâmetros adicionais passados para get_saldo_emprego_detalhado

        Returns:
            pd.DataFrame: Dados de saldo de emprego
        """
        dados = self.get_saldo_emprego_detalhado(nivel_agregacao=nivel_agregacao, **kwargs)
        return pd.DataFrame(dados)

    def close(self):
        """Fechar a sessão HTTP"""
        if hasattr(self, 'session'):
            self.session.close()

    def __enter__(self):
        """Entrada do context manager"""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Saída do context manager"""
        self.close()


# ========== CAMADA DE ABSTRAÇÃO - Funções públicas simplificadas ==========

def get_estoque_emprego_nacional(codigos_cnae: List[str] = None,
                                nivel_cnae: int = 2,
                                agregado: bool = False) -> pd.DataFrame:
    """
    Obter dados de estoque de emprego nacional como DataFrame

    Args:
        codigos_cnae (List[str], optional): Lista de códigos CNAE
        nivel_cnae (int): Nível CNAE (2=divisão, 3=grupo)
        agregado (bool): Se True, agrega todos os estados

    Returns:
        pd.DataFrame: Dados de estoque de emprego nacional
    """
    with Emprego() as api:
        dados = api.get_estoque_emprego_nacional(
            codigos_cnae=codigos_cnae,
            nivel_cnae=nivel_cnae,
            agregado=agregado
        )
    return pd.DataFrame(dados)

def get_estoque_emprego_estadual(uf: str,
                                codigos_cnae: List[str] = None,
                                nivel_cnae: int = 2) -> pd.DataFrame:
    """
    Obter dados de estoque de emprego estadual como DataFrame

    Args:
        uf (str): Sigla da UF (ex: 'SP', 'RJ')
        codigos_cnae (List[str], optional): Lista de códigos CNAE
        nivel_cnae (int): Nível CNAE (2=divisão, 3=grupo)

    Returns:
        pd.DataFrame: Dados de estoque de emprego estadual
    """
    with Emprego() as api:
        dados = api.get_estoque_emprego_estadual(
            ufs=uf,
            codigos_cnae=codigos_cnae,
            nivel_cnae=nivel_cnae
        )
    return pd.DataFrame(dados)



def get_saldo_caged_nacional(nivel_cnae: str,
                            codigos: List[str] = None,
                            data_minima: str = None,
                            data_maxima: str = None) -> pd.DataFrame:
    """
    Obter dados de saldo CAGED nacional como DataFrame

    Args:
        nivel_cnae (str): 'divisao', 'grupo' ou 'subclasse'
        codigos (List[str], optional): Lista de códigos CNAE
        data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
        data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

    Returns:
        pd.DataFrame: Dados de saldo CAGED nacional
    """
    with Emprego() as api:
        if nivel_cnae == 'divisao':
            dados = api.get_saldo_caged_nacional_divisao(
                codigos_divisao=codigos,
                data_minima=data_minima,
                data_maxima=data_maxima
            )
        elif nivel_cnae == 'grupo':
            dados = api.get_saldo_caged_nacional_grupo(
                codigos_grupo=codigos,
                data_minima=data_minima,
                data_maxima=data_maxima
            )
        elif nivel_cnae == 'subclasse':
            dados = api.get_saldo_caged_nacional_subclasse(
                codigos_subclasse=codigos,
                data_minima=data_minima,
                data_maxima=data_maxima
            )
        else:
            raise ValueError("nivel_cnae deve ser 'divisao', 'grupo' ou 'subclasse'")
            
    return pd.DataFrame(dados)

def get_saldo_caged_estadual(nivel_cnae: str,
                            siglas_uf: List[str] = None,
                            codigos_uf: List[int] = None,
                            codigos: List[str] = None,
                            data_minima: str = None,
                            data_maxima: str = None) -> pd.DataFrame:
    """
    Obter dados de saldo CAGED estadual como DataFrame

    Args:
        nivel_cnae (str): 'divisao', 'grupo' ou 'subclasse'
        siglas_uf (List[str], optional): Lista de siglas de UF
        codigos_uf (List[int], optional): Lista de códigos de UF
        codigos (List[str], optional): Lista de códigos CNAE
        data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
        data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

    Returns:
        pd.DataFrame: Dados de saldo CAGED estadual
    """
    with Emprego() as api:
        if nivel_cnae == 'divisao':
            dados = api.get_saldo_caged_estadual_divisao(
                siglas_uf=siglas_uf,
                codigos_uf=codigos_uf,
                codigos_divisao=codigos,
                data_minima=data_minima,
                data_maxima=data_maxima
            )
        elif nivel_cnae == 'grupo':
            dados = api.get_saldo_caged_estadual_grupo(
                siglas_uf=siglas_uf,
                codigos_uf=codigos_uf,
                codigos_grupo=codigos,
                data_minima=data_minima,
                data_maxima=data_maxima
            )
        elif nivel_cnae == 'subclasse':
            dados = api.get_saldo_caged_estadual_subclasse(
                siglas_uf=siglas_uf,
                codigos_uf=codigos_uf,
                codigos_subclasse=codigos,
                data_minima=data_minima,
                data_maxima=data_maxima
            )
        else:
            raise ValueError("nivel_cnae deve ser 'divisao', 'grupo' ou 'subclasse'")
            
    return pd.DataFrame(dados)

def get_saldo_caged_municipal(nivel_cnae: str,
                             siglas_uf: List[str] = None,
                             codigos_uf: List[int] = None,
                             codigos_municipio: List[int] = None,
                             codigos: List[str] = None,
                             data_minima: str = None,
                             data_maxima: str = None) -> pd.DataFrame:
    """
    Obter dados de saldo CAGED municipal como DataFrame

    Args:
        nivel_cnae (str): 'divisao', 'grupo' ou 'subclasse'
        siglas_uf (List[str], optional): Lista de siglas de UF
        codigos_uf (List[int], optional): Lista de códigos de UF
        codigos_municipio (List[int], optional): Lista de códigos de município
        codigos (List[str], optional): Lista de códigos CNAE
        data_minima (str, optional): Data mínima (formato YYYY-MM-DD)
        data_maxima (str, optional): Data máxima (formato YYYY-MM-DD)

    Returns:
        pd.DataFrame: Dados de saldo CAGED municipal
    """
    with Emprego() as api:
        if nivel_cnae == 'divisao':
            dados = api.get_saldo_caged_municipal_divisao(
                siglas_uf=siglas_uf,
                codigos_uf=codigos_uf,
                codigos_municipio=codigos_municipio,
                codigos_divisao=codigos,
                data_minima=data_minima,
                data_maxima=data_maxima
            )
        elif nivel_cnae == 'grupo':
            dados = api.get_saldo_caged_municipal_grupo(
                siglas_uf=siglas_uf,
                codigos_uf=codigos_uf,
                codigos_municipio=codigos_municipio,
                codigos_grupo=codigos,
                data_minima=data_minima,
                data_maxima=data_maxima
            )
        elif nivel_cnae == 'subclasse':
            dados = api.get_saldo_caged_municipal_subclasse(
                siglas_uf=siglas_uf,
                codigos_uf=codigos_uf,
                codigos_municipio=codigos_municipio,
                codigos_subclasse=codigos,
                data_minima=data_minima,
                data_maxima=data_maxima
            )
        else:
            raise ValueError("nivel_cnae deve ser 'divisao', 'grupo' ou 'subclasse'")
            
    return pd.DataFrame(dados)


# ========== FUNÇÕES ADICIONAIS PARA PARIDADE COM R ==========

def _validate_cnae_level(nivel_cnae: str) -> Optional[int]:
    """Validar e converter nível CNAE string para int da API"""
    nivel_map = {
        'subclasse': None,
        'divisao': 2,
        'divisão': 2,
        'grupo': 3
    }
    
    if nivel_cnae not in nivel_map:
        raise ValueError("nivel_cnae deve ser: 'subclasse', 'divisao' ou 'grupo'")
    
    return nivel_map[nivel_cnae]


def _validate_cnae_codes(codigos_cnae: List[str]) -> str:
    """Validar códigos CNAE e determinar nível automaticamente"""
    if not codigos_cnae or len(codigos_cnae) == 0:
        raise ValueError("Lista de códigos CNAE não pode estar vazia")
    
    # Verificar se todos os códigos têm o mesmo número de dígitos
    lengths = [len(str(codigo).strip()) for codigo in codigos_cnae]
    if len(set(lengths)) > 1:
        raise ValueError("Todos os códigos CNAE devem ter o mesmo número de dígitos")
    
    length_val = lengths[0]
    
    # Mapear número de dígitos para nível CNAE
    if length_val == 2:
        return 'divisao'
    elif length_val == 3:
        return 'grupo'
    elif length_val == 7:
        return 'subclasse'
    else:
        raise ValueError("Códigos CNAE devem ter 2 dígitos (divisão), 3 dígitos (grupo) ou 7 dígitos (subclasse)")


def _filter_columns_by_aggregation(df: pd.DataFrame, nivel_agregacao: str) -> pd.DataFrame:
    """Filtrar colunas baseado no nível de agregação geográfica"""
    if df.empty:
        return df
    
    # Colunas a serem removidas por nível (nomes reais da API)
    columns_to_remove = {
        'nacional': [
            # Colunas de UF
            'uf', 'sigla_uf', 'codigo_uf', 'nome_uf', 'cod_uf',
            # Colunas de município
            'municipio', 'codigo_municipio', 'nome_municipio', 'cod_municipio'
        ],
        'estadual': [
            # Apenas colunas de município
            'municipio', 'codigo_municipio', 'nome_municipio', 'cod_municipio'
        ],
        'municipal': []  # Manter todas as colunas para municipal
    }
    
    remove_cols = columns_to_remove.get(nivel_agregacao, [])
    
    # Filtrar apenas colunas que existem no DataFrame
    existing_cols_to_remove = [col for col in remove_cols if col in df.columns]
    
    if existing_cols_to_remove:
        df = df.drop(columns=existing_cols_to_remove)
    
    return df


def _filter_cnae_columns_for_grouped_methods(df: pd.DataFrame, nivel_agregacao: str) -> pd.DataFrame:
    """Filtrar colunas CNAE específicas dos métodos agrupados"""
    if df.empty:
        return df
    
    # Para métodos agrupados, remover códigos CNAE específicos (mantém apenas nome_grupo)
    # Nomes reais das colunas retornadas pela API
    cnae_columns_to_remove = [
        # Códigos e descrições de divisão
        'divisao_cnae_cod', 'divisao_cnae_desc', 'codigo_divisao', 'descricao_divisao',
        # Códigos e descrições de grupo  
        'grupo_cnae_cod', 'grupo_cnae_desc', 'codigo_grupo', 'descricao_grupo',
        # Códigos e descrições de subclasse
        'subclasse_cnae_cod', 'subclasse_cnae_desc', 'subclasse', 'descricao_subclasse',
        # Outras colunas CNAE possíveis
        'secao', 'descricao_secao', 'descricao_classe', 'GrupoAtividadeEconomica',
        'DescricaoCnae', 'cnae_2_0_codigo', 'cnae_2_0_descricao'
    ]
    
    # Filtrar apenas colunas que existem no DataFrame
    existing_cnae_cols_to_remove = [col for col in cnae_columns_to_remove if col in df.columns]
    
    if existing_cnae_cols_to_remove:
        df = df.drop(columns=existing_cnae_cols_to_remove)
    
    # Aplicar também filtros geográficos
    df = _filter_columns_by_aggregation(df, nivel_agregacao)
    
    return df


def _filter_cnae_columns_by_level(df: pd.DataFrame, nivel_cnae: str) -> pd.DataFrame:
    """Filtrar colunas CNAE específicas baseado no nível CNAE selecionado"""
    if df.empty:
        return df
    
    # Colunas que sempre devem ser removidas
    always_remove = ['nome_grupo', 'descricao_classe']
    
    # Colunas a remover baseado no nível CNAE
    level_specific_remove = {
        'divisao': [
            'codigo_grupo', 'descricao_grupo',  # Remover dados de grupo
            'subclasse', 'descricao_subclasse'  # Remover dados de subclasse
        ],
        'grupo': [
            'subclasse', 'descricao_subclasse'  # Remover apenas dados de subclasse
        ],
        'subclasse': []  # Não remover nada específico (mantém tudo exceto always_remove)
    }
    
    # Combinar colunas a remover
    cols_to_remove = always_remove + level_specific_remove.get(nivel_cnae, [])
    
    # Filtrar apenas colunas que existem no DataFrame
    existing_cols_to_remove = [col for col in cols_to_remove if col in df.columns]
    
    if existing_cols_to_remove:
        df = df.drop(columns=existing_cols_to_remove)
    
    return df


# ========== FUNÇÕES NACIONAIS ==========

def get_saldo_emprego_nacional_mensal(nivel_cnae: str = 'subclasse', 
                                     codigo_cnae: str = None, 
                                     data_minima: str = None) -> pd.DataFrame:
    """
    Obter dados mensais de saldo de emprego em nível nacional

    Args:
        nivel_cnae (str): Nível CNAE ('subclasse', 'divisao', 'grupo')
        codigo_cnae (str, optional): Filtro por código CNAE específico
        data_minima (str, optional): Data mínima em formato YYYY-MM-DD

    Returns:
        pd.DataFrame: Dados mensais com informações CNAE filtradas
    """
    nivel_api = _validate_cnae_level(nivel_cnae)
    
    with Emprego() as api:
        dados = api.get_saldo_emprego_detalhado(
            nivel_agregacao='nacional',
            nivel_cnae=nivel_api,
            codigo_cnae=codigo_cnae,
            data_minima=data_minima
        )
    
    if dados:
        df = pd.DataFrame(dados)
        df = _filter_columns_by_aggregation(df, 'nacional')
        df = _filter_cnae_columns_by_level(df, nivel_cnae)
        return df
    else:
        return pd.DataFrame()


def get_saldo_emprego_nacional_anual(nivel_cnae: str = 'subclasse', 
                                    codigo_cnae: str = None, 
                                    ano_minimo: int = None) -> pd.DataFrame:
    """
    Obter dados anuais de saldo de emprego em nível nacional

    Args:
        nivel_cnae (str): Nível CNAE ('subclasse', 'divisao', 'grupo')
        codigo_cnae (str, optional): Filtro por código CNAE específico
        ano_minimo (int, optional): Ano mínimo para filtrar dados

    Returns:
        pd.DataFrame: Dados anuais agregados
    """
    data_minima = f"{ano_minimo}-01-01" if ano_minimo else None
    df = get_saldo_emprego_nacional_mensal(nivel_cnae, codigo_cnae, data_minima)
    
    if df.empty:
        return df

    df = _normalizar_colunas_temporais_saldo(df)
    
    # Colunas numéricas para agregação
    cols_numericas = [col for col in df.columns if any(term in col.lower() for term in ['saldo_reajustado'])]
    
    # Colunas CNAE para agrupamento
    cols_cnae = [col for col in df.columns if any(term in col.lower() for term in ['divisao_cnae_cod', 'divisao_cnae_desc', 'grupo_cnae_cod', 'grupo_cnae_desc', 'subclasse_cnae_cod', 'subclasse_cnae_desc'])]
    cols_agrupamento = ['ano'] + cols_cnae
    
    # Agrupar por ano
    df_anual = df.groupby(cols_agrupamento)[cols_numericas].sum().reset_index()
    
    return df_anual


def get_saldo_emprego_nacional_mensal_agrupado(nome_grupo: str, 
                                              lista_cnae: List[str],
                                              data_minima: str = None) -> pd.DataFrame:
    """
    Obter dados mensais agrupados para lista de códigos CNAE em nível nacional

    Args:
        nome_grupo (str): Nome para o grupo CNAE
        lista_cnae (List[str]): Lista de códigos CNAE (mesmo número de dígitos)
        data_minima (str, optional): Data mínima em formato YYYY-MM-DD

    Returns:
        pd.DataFrame: Dados mensais agrupados (sem colunas CNAE específicas)
    """
    nivel_cnae_str = _validate_cnae_codes(lista_cnae)
    nivel_api = _validate_cnae_level(nivel_cnae_str)

    # Usar método de grupos para agregação com nome
    grupos_cnae = [{
        'nome_grupo': nome_grupo,
        'codigos_cnae': lista_cnae
    }]

    with Emprego() as api:
        dados = api.get_saldo_emprego_detalhado_grupos_cnae(
            grupos_cnae=grupos_cnae,
            nivel_agregacao='nacional',
            nivel_cnae=nivel_api,
            data_minima=data_minima
        )
    
    if dados:
        df = pd.DataFrame(dados)
        df = _filter_cnae_columns_for_grouped_methods(df, 'nacional')
        return df
    else:
        return pd.DataFrame()


def get_saldo_emprego_nacional_mensal_lista(lista_cnae: List[str],
                                           data_minima: str = None) -> pd.DataFrame:
    """
    Obter dados mensais para lista de códigos CNAE em nível nacional (sem agrupamento)

    Args:
        lista_cnae (List[str]): Lista de códigos CNAE (mesmo número de dígitos)
        data_minima (str, optional): Data mínima em formato YYYY-MM-DD

    Returns:
        pd.DataFrame: Dados mensais individuais por código CNAE
    """
    nivel_cnae_str = _validate_cnae_codes(lista_cnae)
    nivel_api = _validate_cnae_level(nivel_cnae_str)

    with Emprego() as api:
        dados = api.get_saldo_emprego_detalhado_lista_cnae(
            lista_cnae=lista_cnae,
            nome_grupo="Lista CNAE",  # Nome dummy obrigatório
            nivel_agregacao='nacional',
            nivel_cnae=nivel_api,
            data_minima=data_minima
        )
    
    if dados:
        df = pd.DataFrame(dados)
        df = _filter_columns_by_aggregation(df, 'nacional')
        df = _filter_cnae_columns_by_level(df, nivel_cnae_str)
        return df
    else:
        return pd.DataFrame()


# ========== FUNÇÕES ESTADUAIS ==========

def get_saldo_emprego_estadual_mensal(sigla_uf: str,
                                     nivel_cnae: str = 'subclasse', 
                                     codigo_cnae: str = None, 
                                     data_minima: str = None) -> pd.DataFrame:
    """
    Obter dados mensais de saldo de emprego em nível estadual

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.)
        nivel_cnae (str): Nível CNAE ('subclasse', 'divisao', 'grupo')
        codigo_cnae (str, optional): Filtro por código CNAE específico
        data_minima (str, optional): Data mínima em formato YYYY-MM-DD

    Returns:
        pd.DataFrame: Dados mensais filtrados
    """
    nivel_api = _validate_cnae_level(nivel_cnae)
    
    with Emprego() as api:
        dados = api.get_saldo_emprego_detalhado(
            nivel_agregacao='estadual',
            sigla_uf=sigla_uf,
            nivel_cnae=nivel_api,
            codigo_cnae=codigo_cnae,
            data_minima=data_minima
        )
    
    if dados:
        df = pd.DataFrame(dados)
        df = _filter_columns_by_aggregation(df, 'estadual')
        df = _filter_cnae_columns_by_level(df, nivel_cnae)
        return df
    else:
        return pd.DataFrame()


def get_saldo_emprego_estadual_anual(sigla_uf: str,
                                    nivel_cnae: str = 'subclasse', 
                                    codigo_cnae: str = None, 
                                    ano_minimo: int = None) -> pd.DataFrame:
    """
    Obter dados anuais de saldo de emprego em nível estadual

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.)
        nivel_cnae (str): Nível CNAE ('subclasse', 'divisao', 'grupo')
        codigo_cnae (str, optional): Filtro por código CNAE específico
        ano_minimo (int, optional): Ano mínimo para filtrar dados

    Returns:
        pd.DataFrame: Dados anuais agregados
    """
    data_minima = f"{ano_minimo}-01-01" if ano_minimo else None
    df = get_saldo_emprego_estadual_mensal(sigla_uf, nivel_cnae, codigo_cnae, data_minima)
    
    if df.empty:
        return df

    df = _normalizar_colunas_temporais_saldo(df)
    
    # Colunas numéricas para agregação
    cols_numericas = [col for col in df.columns if any(term in col.lower() for term in ['saldo', 'admissoes', 'desligamentos'])]
    
    # Colunas CNAE e geográficas para agrupamento
    cols_cnae = [col for col in df.columns if any(term in col.lower() for term in ['cnae', 'nome', 'descricao', 'secao'])]
    cols_geo = [col for col in df.columns if any(term in col.lower() for term in ['uf', 'estado'])]
    cols_agrupamento = ['ano'] + cols_cnae + cols_geo
    
    # Agrupar por ano
    df_anual = df.groupby(cols_agrupamento)[cols_numericas].sum().reset_index()
    
    return df_anual


def get_saldo_emprego_estadual_mensal_lista(sigla_uf: str,
                                          lista_cnae: List[str],
                                          data_minima: str = None) -> pd.DataFrame:
    """
    Obter dados mensais para lista de códigos CNAE em nível estadual (sem agrupamento)

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.)
        lista_cnae (List[str]): Lista de códigos CNAE (mesmo número de dígitos)
        data_minima (str, optional): Data mínima em formato YYYY-MM-DD

    Returns:
        pd.DataFrame: Dados mensais individuais por código CNAE
    """
    nivel_cnae_str = _validate_cnae_codes(lista_cnae)
    nivel_api = _validate_cnae_level(nivel_cnae_str)

    with Emprego() as api:
        dados = api.get_saldo_emprego_detalhado_lista_cnae(
            lista_cnae=lista_cnae,
            nome_grupo="Lista CNAE",  # Nome dummy obrigatório
            nivel_agregacao='estadual',
            nivel_cnae=nivel_api,
            sigla_uf=sigla_uf,
            data_minima=data_minima
        )
    
    if dados:
        df = pd.DataFrame(dados)
        df = _filter_columns_by_aggregation(df, 'estadual')
        df = _filter_cnae_columns_by_level(df, nivel_cnae_str)
        return df
    else:
        return pd.DataFrame()


def get_saldo_emprego_estadual_mensal_agrupado(sigla_uf: str,
                                              nome_grupo: str, 
                                              lista_cnae: List[str],
                                              data_minima: str = None) -> pd.DataFrame:
    """
    Obter dados mensais agrupados para lista de códigos CNAE em nível estadual

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.)
        nome_grupo (str): Nome para o grupo CNAE
        lista_cnae (List[str]): Lista de códigos CNAE (mesmo número de dígitos)
        data_minima (str, optional): Data mínima em formato YYYY-MM-DD

    Returns:
        pd.DataFrame: Dados mensais agrupados (sem colunas CNAE específicas)
    """
    nivel_cnae_str = _validate_cnae_codes(lista_cnae)
    nivel_api = _validate_cnae_level(nivel_cnae_str)

    # Usar método de grupos para agregação com nome
    grupos_cnae = [{
        'nome_grupo': nome_grupo,
        'codigos_cnae': lista_cnae
    }]

    with Emprego() as api:
        dados = api.get_saldo_emprego_detalhado_grupos_cnae(
            grupos_cnae=grupos_cnae,
            nivel_agregacao='estadual',
            nivel_cnae=nivel_api,
            sigla_uf=sigla_uf,
            data_minima=data_minima
        )
    
    if dados:
        df = pd.DataFrame(dados)
        df = _filter_cnae_columns_for_grouped_methods(df, 'estadual')
        return df
    else:
        return pd.DataFrame()


# ========== FUNÇÕES MUNICIPAIS ==========

def get_saldo_emprego_municipal_mensal(codigo_municipio: int,
                                      nivel_cnae: str = 'subclasse', 
                                      sigla_uf: str = None,
                                      codigo_cnae: str = None, 
                                      data_minima: str = None) -> pd.DataFrame:
    """
    Obter dados mensais de saldo de emprego em nível municipal

    Args:
        sigla_uf (str, optional): Sigla do estado ('SP', 'RJ', etc.)
        codigo_municipio (int): Código IBGE do município
        nivel_cnae (str): Nível CNAE ('subclasse', 'divisao', 'grupo')
        codigo_cnae (str, optional): Filtro por código CNAE específico
        data_minima (str, optional): Data mínima em formato YYYY-MM-DD

    Returns:
        pd.DataFrame: Dados mensais filtrados
    """
    nivel_api = _validate_cnae_level(nivel_cnae)
    
    with Emprego() as api:
        dados = api.get_saldo_emprego_detalhado(
            nivel_agregacao='municipal',
            sigla_uf=sigla_uf,
            nivel_cnae=nivel_api,
            codigo_cnae=codigo_cnae,
            codigo_municipio=codigo_municipio,
            data_minima=data_minima
        )
    
    if dados:
        df = pd.DataFrame(dados)
        df = _filter_columns_by_aggregation(df, 'municipal')
        df = _filter_cnae_columns_by_level(df, nivel_cnae)
        return df
    else:
        return pd.DataFrame()


def get_saldo_emprego_municipal_anual(sigla_uf: str,
                                     codigo_municipio: int,
                                     nivel_cnae: str = 'subclasse', 
                                     codigo_cnae: str = None, 
                                     ano_minimo: int = None) -> pd.DataFrame:
    """
    Obter dados anuais de saldo de emprego em nível municipal

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.)
        codigo_municipio (int): Código IBGE do município
        nivel_cnae (str): Nível CNAE ('subclasse', 'divisao', 'grupo')
        codigo_cnae (str, optional): Filtro por código CNAE específico
        ano_minimo (int, optional): Ano mínimo para filtrar dados

    Returns:
        pd.DataFrame: Dados anuais agregados
    """
    data_minima = f"{ano_minimo}-01-01" if ano_minimo else None
    df = get_saldo_emprego_municipal_mensal(sigla_uf, codigo_municipio, nivel_cnae, codigo_cnae, data_minima)
    
    if df.empty:
        return df

    df = _normalizar_colunas_temporais_saldo(df)
    
    # Colunas numéricas para agregação
    cols_numericas = [col for col in df.columns if any(term in col.lower() for term in ['saldo', 'admissoes', 'desligamentos'])]
    
    # Colunas CNAE e geográficas para agrupamento
    cols_cnae = [col for col in df.columns if any(term in col.lower() for term in ['cnae', 'nome', 'descricao', 'secao'])]
    cols_geo = [col for col in df.columns if any(term in col.lower() for term in ['uf', 'estado', 'municipio', 'cidade'])]
    cols_agrupamento = ['ano'] + cols_cnae + cols_geo
    
    # Agrupar por ano
    df_anual = df.groupby(cols_agrupamento)[cols_numericas].sum().reset_index()
    
    return df_anual


def get_saldo_emprego_municipal_mensal_agrupado(sigla_uf: str,
                                               codigo_municipio: int,
                                               nome_grupo: str, 
                                               lista_cnae: List[str],
                                               data_minima: str = None) -> pd.DataFrame:
    """
    Obter dados mensais agrupados para lista de códigos CNAE em nível municipal

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.)
        codigo_municipio (int): Código IBGE do município
        nome_grupo (str): Nome para o grupo CNAE
        lista_cnae (List[str]): Lista de códigos CNAE (mesmo número de dígitos)
        data_minima (str, optional): Data mínima em formato YYYY-MM-DD

    Returns:
        pd.DataFrame: Dados mensais agrupados (sem colunas CNAE específicas)
    """
    nivel_cnae_str = _validate_cnae_codes(lista_cnae)
    nivel_api = _validate_cnae_level(nivel_cnae_str)

    # Usar método de grupos para agregação com nome
    grupos_cnae = [{
        'nome_grupo': nome_grupo,
        'codigos_cnae': lista_cnae
    }]

    with Emprego() as api:
        dados = api.get_saldo_emprego_detalhado_grupos_cnae(
            grupos_cnae=grupos_cnae,
            nivel_agregacao='municipal',
            nivel_cnae=nivel_api,
            sigla_uf=sigla_uf,
            data_minima=data_minima
        )
    
    if dados:
        df = pd.DataFrame(dados)
        df = _filter_cnae_columns_for_grouped_methods(df, 'municipal')
        return df
    else:
        return pd.DataFrame()


def get_saldo_emprego_municipal_mensal_lista(sigla_uf: str,
                                            codigo_municipio: int,
                                            lista_cnae: List[str],
                                            data_minima: str = None) -> pd.DataFrame:
    """
    Obter dados mensais para lista de códigos CNAE em nível municipal (sem agrupamento)

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.)
        codigo_municipio (int): Código IBGE do município  
        lista_cnae (List[str]): Lista de códigos CNAE (mesmo número de dígitos)
        data_minima (str, optional): Data mínima em formato YYYY-MM-DD

    Returns:
        pd.DataFrame: Dados mensais individuais por código CNAE
    """
    nivel_cnae_str = _validate_cnae_codes(lista_cnae)
    nivel_api = _validate_cnae_level(nivel_cnae_str)

    with Emprego() as api:
        dados = api.get_saldo_emprego_detalhado_lista_cnae(
            lista_cnae=lista_cnae,
            nome_grupo="Lista CNAE",  # Nome dummy obrigatório
            nivel_agregacao='municipal',
            nivel_cnae=nivel_api,
            sigla_uf=sigla_uf,
            codigo_municipio=codigo_municipio,
            data_minima=data_minima
        )
    
    if dados:
        df = pd.DataFrame(dados)
        df = _filter_columns_by_aggregation(df, 'municipal')
        df = _filter_cnae_columns_by_level(df, nivel_cnae_str)
        return df
    else:
        return pd.DataFrame()


def get_saldo_emprego_municipal_mensal_agrupado(codigo_municipio: int,
                                               nome_grupo: str, 
                                               lista_cnae: List[str],
                                               sigla_uf: str = None,
                                               data_minima: str = None) -> pd.DataFrame:
    """
    Obter dados mensais agrupados para lista de códigos CNAE em nível municipal

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.)
        codigo_municipio (int): Código IBGE do município
        nome_grupo (str): Nome para o grupo CNAE
        lista_cnae (List[str]): Lista de códigos CNAE (mesmo número de dígitos)
        data_minima (str, optional): Data mínima em formato YYYY-MM-DD

    Returns:
        pd.DataFrame: Dados mensais agrupados (sem colunas CNAE específicas)
    """
    nivel_cnae_str = _validate_cnae_codes(lista_cnae)
    nivel_api = _validate_cnae_level(nivel_cnae_str)

    # Para nível municipal, usar método de lista (grupos não suportam código de município)
    with Emprego() as api:
        dados = api.get_saldo_emprego_detalhado_lista_cnae(
            lista_cnae=lista_cnae,
            nome_grupo=nome_grupo,
            nivel_agregacao='municipal',
            nivel_cnae=nivel_api,
            sigla_uf=sigla_uf,
            codigo_municipio=codigo_municipio,
            data_minima=data_minima
        )
    
    if dados:
        df = pd.DataFrame(dados)
        
        # Para métodos agrupados municipais, agrupar por período e somar
        if not df.empty and len(lista_cnae) > 1:
            # Identificar colunas de período (prioridade: competencia > mes_referencia)
            period_cols = []
            if 'competencia' in df.columns:
                period_cols.append('competencia')
            elif 'mes_referencia' in df.columns:
                period_cols.append('mes_referencia')
            
            # Identificar colunas geográficas (manter identificadores)
            geo_cols = []
            for col in df.columns:
                if any(term in col.lower() for term in ['uf', 'municipio', 'codigo', 'sigla']):
                    geo_cols.append(col)
            
            # Colunas para agrupamento (período + geografia)
            group_cols = period_cols + geo_cols
            
            # Identificar colunas numéricas (valores de saldo) - estrutura real da API
            possible_numeric = [
                'saldo_emprego', 'saldo_reajustado', 'saldo_sem_reajuste',
                'admissoes', 'desligamentos', 'valor', 'quantidade'
            ]
            numeric_cols = [col for col in possible_numeric if col in df.columns]
            
            if group_cols and numeric_cols:
                # Agrupar e somar
                df = df.groupby(group_cols)[numeric_cols].sum().reset_index()
                
                # Adicionar nome do grupo se não estiver presente
                if 'nome_grupo' not in df.columns:
                    df['nome_grupo'] = nome_grupo
            else:
                # Se não há colunas para agrupar, manter dados originais
                if 'nome_grupo' not in df.columns:
                    df['nome_grupo'] = nome_grupo
        
        # Aplicar filtros para remover colunas CNAE específicas
        df = _filter_cnae_columns_for_grouped_methods(df, 'municipal')
        return df
    else:
        return pd.DataFrame()


# ========== FUNÇÕES DE ESTOQUE ESTIMADO ==========

def _normalizar_colunas_temporais_saldo(df: pd.DataFrame) -> pd.DataFrame:
    """Padronizar colunas temporais de saldo para evitar regressões entre aliases da API."""
    if df.empty:
        return df

    df = df.copy()

    if 'competencia' not in df.columns and 'mes_referencia' in df.columns:
        df['competencia'] = df['mes_referencia']
    if 'mes_referencia' not in df.columns and 'competencia' in df.columns:
        df['mes_referencia'] = df['competencia']

    candidatos_tempo = [col for col in ('competencia', 'mes_referencia') if col in df.columns]
    parsed = []
    for col in candidatos_tempo:
        serie = pd.to_datetime(df[col], errors='coerce')
        parsed.append((col, serie.notna().sum(), serie))

    if parsed:
        _, _, melhor_serie = max(parsed, key=lambda item: item[1])
        if melhor_serie.notna().any():
            df['ano'] = melhor_serie.dt.year.astype('Int64')
            df = df[df['ano'].notna()].copy()
            df['ano'] = df['ano'].astype(int)
            if 'Ano' not in df.columns:
                df['Ano'] = df['ano']
            return df

    if 'ano' in df.columns or 'Ano' in df.columns:
        df = _normalizar_coluna_ano(df)
        if 'Ano' not in df.columns:
            df['Ano'] = df['ano']
        return df

    raise ValueError("Coluna temporal não encontrada: esperado competencia/mes_referencia ou ano/Ano")

def _normalizar_coluna_ano(df: pd.DataFrame) -> pd.DataFrame:
    """Padronizar coluna de ano para inteiro em `ano`."""
    if df.empty:
        return df

    ano_col = next((c for c in ('ano', 'Ano') if c in df.columns), None)
    if not ano_col:
        raise ValueError("Coluna de ano não encontrada")

    df = df.copy()
    if pd.api.types.is_numeric_dtype(df[ano_col]):
        df['ano'] = df[ano_col].astype(int)
    else:
        convertido = pd.to_datetime(df[ano_col], errors='coerce')
        if convertido.notna().any():
            df['ano'] = convertido.dt.year.astype('Int64')
        else:
            df['ano'] = pd.to_numeric(df[ano_col], errors='coerce').astype('Int64')

    df = df[df['ano'].notna()].copy()
    df['ano'] = df['ano'].astype(int)
    return df


def _normalizar_coluna_estoque(df: pd.DataFrame) -> pd.DataFrame:
    """Padronizar coluna de estoque para `estoque_trabalhadores`."""
    if df.empty:
        return df

    col_estoque = next(
        (c for c in ('estoque_trabalhadores', 'EstoqueTrabalhadores') if c in df.columns),
        None,
    )
    if not col_estoque:
        raise ValueError("Coluna de estoque_trabalhadores não encontrada nos dados")

    df = df.copy()
    if col_estoque != 'estoque_trabalhadores':
        df = df.rename(columns={col_estoque: 'estoque_trabalhadores'})
    return df


def _obter_coluna_saldo(df_saldo: pd.DataFrame) -> str:
    candidatos = [
        col for col in df_saldo.columns
        if ('saldo_reajustado' in col.lower()) or ('saldoemprego' in col.lower())
    ]
    if not candidatos:
        raise ValueError("Coluna de saldo não encontrada nos dados")
    return candidatos[0]


def _remover_colunas_saldo(df: pd.DataFrame) -> pd.DataFrame:
    """Remover métricas de saldo do retorno final de estoque."""
    if df.empty:
        return df
    cols_drop = [c for c in df.columns if 'saldo_reajustado' in c.lower()]
    if cols_drop:
        return df.drop(columns=cols_drop)
    return df


def _projetar_estoque_anual(df_estoque: pd.DataFrame,
                            df_saldo: pd.DataFrame,
                            ano_maximo: int = None) -> pd.DataFrame:
    """Projetar estoque a partir do último ano real + saldo acumulado por grupo."""
    if df_estoque.empty:
        return df_estoque

    df_real = _normalizar_coluna_estoque(_normalizar_coluna_ano(df_estoque))
    df_real = df_real.copy()
    df_real['origem'] = 'Real'

    if df_saldo.empty:
        return _remover_colunas_saldo(df_real.sort_values('ano').reset_index(drop=True))

    df_saldo = _normalizar_coluna_ano(df_saldo)
    col_saldo = _obter_coluna_saldo(df_saldo)

    ultimo_ano_real = int(df_real['ano'].max())
    df_saldo = df_saldo[df_saldo['ano'] > ultimo_ano_real].copy()
    if ano_maximo is not None:
        df_saldo = df_saldo[df_saldo['ano'] <= int(ano_maximo)].copy()

    if df_saldo.empty:
        return _remover_colunas_saldo(df_real.sort_values('ano').reset_index(drop=True))

    cols_agrupamento = [
        col for col in df_real.columns
        if col not in {'ano', 'origem', 'estoque_trabalhadores'}
        and 'desc' not in col.lower()
        and 'descricao' not in col.lower()
        and col in df_saldo.columns
    ]

    df_base = df_real[df_real['ano'] == ultimo_ano_real].copy()
    if cols_agrupamento:
        df_base = (
            df_base[cols_agrupamento + ['estoque_trabalhadores']]
            .groupby(cols_agrupamento, dropna=False, as_index=False)
            .sum()
        )
        df_projecao = df_saldo.merge(df_base, on=cols_agrupamento, how='inner')
        if df_projecao.empty:
            return _remover_colunas_saldo(df_real.sort_values('ano').reset_index(drop=True))
        df_projecao = df_projecao.sort_values(cols_agrupamento + ['ano']).reset_index(drop=True)
        saldo_acumulado = df_projecao.groupby(cols_agrupamento, dropna=False)[col_saldo].cumsum()
    else:
        estoque_base = float(df_base['estoque_trabalhadores'].sum())
        df_projecao = df_saldo.sort_values('ano').reset_index(drop=True)
        saldo_acumulado = df_projecao[col_saldo].cumsum()
        df_projecao['estoque_trabalhadores'] = estoque_base

    df_projecao['estoque_trabalhadores'] = (
        df_projecao['estoque_trabalhadores'] + saldo_acumulado
    ).clip(lower=0)
    df_projecao['origem'] = 'Estimação'

    df_resultado = pd.concat([df_real, df_projecao], ignore_index=True, sort=False)

    sort_cols = ['ano'] + cols_agrupamento if cols_agrupamento else ['ano']
    df_resultado = df_resultado.sort_values(sort_cols).reset_index(drop=True)
    df_resultado = _remover_colunas_saldo(df_resultado)
    return df_resultado


def _obter_saldo_anual_agrupado(nome_grupo: str,
                                lista_cnae: List[str],
                                ano_inicio: int,
                                ano_limite: int,
                                sigla_uf: str = None) -> pd.DataFrame:
    """Consolidar saldo anual para métodos agrupados (nacional/estadual)."""
    dfs_saldo = []

    for ano in range(int(ano_inicio), int(ano_limite) + 1):
        try:
            if sigla_uf:
                df_mensal = get_saldo_emprego_estadual_mensal_agrupado(
                    sigla_uf=sigla_uf,
                    nome_grupo=nome_grupo,
                    lista_cnae=lista_cnae,
                    data_minima=f"{ano}-01-01"
                )
            else:
                df_mensal = get_saldo_emprego_nacional_mensal_agrupado(
                    nome_grupo=nome_grupo,
                    lista_cnae=lista_cnae,
                    data_minima=f"{ano}-01-01"
                )

            if df_mensal.empty or 'competencia' not in df_mensal.columns:
                continue

            df_mensal = df_mensal.copy()
            df_mensal['competencia'] = pd.to_datetime(df_mensal['competencia'], errors='coerce')
            df_mensal = df_mensal[df_mensal['competencia'].dt.year == ano]
            if df_mensal.empty:
                continue

            df_mensal['ano'] = ano
            col_saldo = next((c for c in df_mensal.columns if 'saldo_reajustado' in c.lower()), None)
            if not col_saldo:
                continue

            cols_grp = ['ano']
            for c in ('nome_grupo', 'sigla_uf'):
                if c in df_mensal.columns:
                    cols_grp.append(c)

            df_anual = df_mensal.groupby(cols_grp, dropna=False, as_index=False)[col_saldo].sum()
            dfs_saldo.append(df_anual)
        except Exception:
            continue

    if not dfs_saldo:
        return pd.DataFrame()
    return pd.concat(dfs_saldo, ignore_index=True)

def get_estoque_emprego_estimado_nacional_anual(nivel_cnae: str = 'divisao',
                                               codigo_cnae: str = None,
                                               ano_minimo: int = None,
                                               ano_maximo: int = None) -> pd.DataFrame:
    """
    Obter dados anuais de estoque de emprego estimado em nível nacional.
    
    O estoque estimado combina dados reais de estoque com projeções baseadas 
    no saldo de emprego acumulado a partir do último ano de dados reais.

    Args:
        nivel_cnae (str): Nível CNAE ('divisao' ou 'grupo')
        codigo_cnae (str, optional): Filtro por código CNAE específico
        ano_minimo (int, optional): Ano mínimo para filtrar dados
        ano_maximo (int, optional): Ano máximo para projeção (se não informado, usa dados disponíveis)

    Returns:
        pd.DataFrame: Dados de estoque com coluna 'origem' indicando 'Real' ou 'Estimação'
    """
    nivel_api = _validate_cnae_level(nivel_cnae)
    if nivel_api is None:
        raise ValueError("nivel_cnae deve ser 'divisao' ou 'grupo' para dados de estoque")

    df_estoque = get_estoque_emprego_nacional(
        codigos_cnae=[codigo_cnae] if codigo_cnae else None,
        nivel_cnae=nivel_api,
        agregado=True
    )
    if df_estoque.empty:
        return pd.DataFrame()

    df_estoque = _normalizar_coluna_ano(df_estoque)
    if ano_minimo is not None:
        df_estoque = df_estoque[df_estoque['ano'] >= int(ano_minimo)].copy()
    if df_estoque.empty:
        return pd.DataFrame()

    ultimo_ano_real = int(df_estoque['ano'].max())
    ano_inicio_saldo = ultimo_ano_real + 1
    if ano_maximo is not None and ano_inicio_saldo > int(ano_maximo):
        return _remover_colunas_saldo(_normalizar_coluna_estoque(df_estoque).assign(origem='Real'))

    df_saldo = get_saldo_emprego_nacional_anual(nivel_cnae, codigo_cnae, ano_inicio_saldo)
    return _projetar_estoque_anual(df_estoque, df_saldo, ano_maximo)


def get_estoque_emprego_estimado_estadual_anual(sigla_uf: str,
                                               nivel_cnae: str = 'divisao',
                                               codigo_cnae: str = None,
                                               ano_minimo: int = None,
                                               ano_maximo: int = None) -> pd.DataFrame:
    """
    Obter dados anuais de estoque de emprego estimado em nível estadual.
    
    O estoque estimado combina dados reais de estoque com projeções baseadas 
    no saldo de emprego acumulado a partir do último ano de dados reais.

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.)
        nivel_cnae (str): Nível CNAE ('divisao' ou 'grupo')
        codigo_cnae (str, optional): Filtro por código CNAE específico
        ano_minimo (int, optional): Ano mínimo para filtrar dados
        ano_maximo (int, optional): Ano máximo para projeção

    Returns:
        pd.DataFrame: Dados de estoque com coluna 'origem' indicando 'Real' ou 'Estimação'
    """
    nivel_api = _validate_cnae_level(nivel_cnae)
    if nivel_api is None:
        raise ValueError("nivel_cnae deve ser 'divisao' ou 'grupo' para dados de estoque")

    df_estoque = get_estoque_emprego_estadual(
        uf=sigla_uf,
        codigos_cnae=[codigo_cnae] if codigo_cnae else None,
        nivel_cnae=nivel_api
    )
    if df_estoque.empty:
        return pd.DataFrame()

    df_estoque = _normalizar_coluna_ano(df_estoque)
    if ano_minimo is not None:
        df_estoque = df_estoque[df_estoque['ano'] >= int(ano_minimo)].copy()
    if df_estoque.empty:
        return pd.DataFrame()

    ultimo_ano_real = int(df_estoque['ano'].max())
    ano_inicio_saldo = ultimo_ano_real + 1
    if ano_maximo is not None and ano_inicio_saldo > int(ano_maximo):
        return _remover_colunas_saldo(_normalizar_coluna_estoque(df_estoque).assign(origem='Real'))

    df_saldo = get_saldo_emprego_estadual_anual(sigla_uf, nivel_cnae, codigo_cnae, ano_inicio_saldo)
    return _projetar_estoque_anual(df_estoque, df_saldo, ano_maximo)


def get_estoque_emprego_estimado_municipal_anual(sigla_uf: str,
                                                codigo_municipio: int,
                                                nivel_cnae: str = 'divisao',
                                                codigo_cnae: str = None,
                                                ano_minimo: int = None,
                                                ano_maximo: int = None) -> pd.DataFrame:
    """
    Obter dados anuais de estoque de emprego estimado em nível municipal.
    
    NOTA: Dados de estoque em nível municipal não estão disponíveis na base atual.
    Esta função está disponível para compatibilidade futura.

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.')
        codigo_municipio (int): Código IBGE do município
        nivel_cnae (str): Nível CNAE ('divisao' ou 'grupo')
        codigo_cnae (str, optional): Filtro por código CNAE específico
        ano_minimo (int, optional): Ano mínimo para filtrar dados
        ano_maximo (int, optional): Ano máximo para projeção

    Returns:
        pd.DataFrame: DataFrame vazio com mensagem informativa

    Raises:
        NotImplementedError: Dados municipais de estoque não estão disponíveis
    """
    raise NotImplementedError(
        "Dados de estoque em nível municipal não estão disponíveis na base atual. "
        "A funcionalidade de estoque estimado municipal será implementada quando "
        "os dados municipais de estoque estiverem disponíveis."
    )


def get_estoque_emprego_estimado_nacional_anual_agrupado(nome_grupo: str,
                                                        lista_cnae: List[str],
                                                        ano_minimo: int = None,
                                                        ano_maximo: int = None) -> pd.DataFrame:
    """
    Obter dados anuais de estoque de emprego estimado agrupado por lista CNAE em nível nacional.
    
    O estoque estimado combina dados reais de estoque com projeções baseadas 
    no saldo de emprego acumulado a partir do último ano de dados reais.

    Args:
        nome_grupo (str): Nome para o grupo CNAE
        lista_cnae (List[str]): Lista de códigos CNAE (mesmo número de dígitos)
        ano_minimo (int, optional): Ano mínimo para filtrar dados
        ano_maximo (int, optional): Ano máximo para projeção

    Returns:
        pd.DataFrame: Dados de estoque agrupado com coluna 'origem' indicando 'Real' ou 'Estimação'
    """
    nivel_cnae_str = _validate_cnae_codes(lista_cnae)
    nivel_api = _validate_cnae_level(nivel_cnae_str)
    if nivel_api is None:
        raise ValueError("nivel_cnae deve ser 'divisao' ou 'grupo' para dados de estoque")

    # 1. Obter dados reais de estoque agrupado
    with Emprego() as api:
        dados = api.get_estoque_emprego_nacional_grupos_cnae(
            grupos_cnae=[{'nome_grupo': nome_grupo, 'codigos_cnae': lista_cnae}],
            nivel_cnae=nivel_api
        )
    df_estoque = pd.DataFrame(dados)
    df_estoque = _filter_cnae_columns_for_grouped_methods(df_estoque, 'nacional')
    if df_estoque.empty:
        return pd.DataFrame()

    df_estoque = _normalizar_coluna_ano(df_estoque)
    if ano_minimo is not None:
        df_estoque = df_estoque[df_estoque['ano'] >= int(ano_minimo)].copy()
    if df_estoque.empty:
        return pd.DataFrame()

    ultimo_ano_real = int(df_estoque['ano'].max())
    ano_inicio_saldo = ultimo_ano_real + 1
    if ano_maximo is not None and ano_inicio_saldo > int(ano_maximo):
        return _remover_colunas_saldo(_normalizar_coluna_estoque(df_estoque).assign(origem='Real'))

    ano_limite = int(ano_maximo) if ano_maximo is not None else ultimo_ano_real + 10
    df_saldo = _obter_saldo_anual_agrupado(
        nome_grupo=nome_grupo,
        lista_cnae=lista_cnae,
        ano_inicio=ano_inicio_saldo,
        ano_limite=ano_limite,
        sigla_uf=None
    )
    return _projetar_estoque_anual(df_estoque, df_saldo, ano_maximo)


def get_estoque_emprego_estimado_estadual_anual_agrupado(sigla_uf: str,
                                                        nome_grupo: str,
                                                        lista_cnae: List[str],
                                                        ano_minimo: int = None,
                                                        ano_maximo: int = None) -> pd.DataFrame:
    """
    Obter dados anuais de estoque de emprego estimado agrupado por lista CNAE em nível estadual.
    
    O estoque estimado combina dados reais de estoque com projeções baseadas 
    no saldo de emprego acumulado a partir do último ano de dados reais.

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.)
        nome_grupo (str): Nome para o grupo CNAE
        lista_cnae (List[str]): Lista de códigos CNAE (mesmo número de dígitos)
        ano_minimo (int, optional): Ano mínimo para filtrar dados
        ano_maximo (int, optional): Ano máximo para projeção

    Returns:
        pd.DataFrame: Dados de estoque agrupado com coluna 'origem' indicando 'Real' ou 'Estimação'
    """
    nivel_cnae_str = _validate_cnae_codes(lista_cnae)
    nivel_api = _validate_cnae_level(nivel_cnae_str)
    if nivel_api is None:
        raise ValueError("nivel_cnae deve ser 'divisao' ou 'grupo' para dados de estoque")

    # 1. Obter dados reais de estoque agrupado
    with Emprego() as api:
        dados = api.get_estoque_emprego_estadual_grupos_cnae(
            ufs=sigla_uf,
            grupos_cnae=[{'nome_grupo': nome_grupo, 'codigos_cnae': lista_cnae}],
            nivel_cnae=nivel_api
        )
    df_estoque = pd.DataFrame(dados)
    df_estoque = _filter_cnae_columns_for_grouped_methods(df_estoque, 'estadual')
    if df_estoque.empty:
        return pd.DataFrame()

    df_estoque = _normalizar_coluna_ano(df_estoque)
    if ano_minimo is not None:
        df_estoque = df_estoque[df_estoque['ano'] >= int(ano_minimo)].copy()
    if df_estoque.empty:
        return pd.DataFrame()

    ultimo_ano_real = int(df_estoque['ano'].max())
    ano_inicio_saldo = ultimo_ano_real + 1
    if ano_maximo is not None and ano_inicio_saldo > int(ano_maximo):
        return _remover_colunas_saldo(_normalizar_coluna_estoque(df_estoque).assign(origem='Real'))

    ano_limite = int(ano_maximo) if ano_maximo is not None else ultimo_ano_real + 10
    df_saldo = _obter_saldo_anual_agrupado(
        nome_grupo=nome_grupo,
        lista_cnae=lista_cnae,
        ano_inicio=ano_inicio_saldo,
        ano_limite=ano_limite,
        sigla_uf=sigla_uf
    )
    return _projetar_estoque_anual(df_estoque, df_saldo, ano_maximo)


def get_estoque_emprego_estimado_municipal_anual_agrupado(sigla_uf: str,
                                                         codigo_municipio: int,
                                                         nome_grupo: str,
                                                         lista_cnae: List[str],
                                                         ano_minimo: int = None,
                                                         ano_maximo: int = None) -> pd.DataFrame:
    """
    Obter dados anuais de estoque de emprego estimado agrupado em nível municipal.
    
    NOTA: Dados de estoque em nível municipal não estão disponíveis na base atual.
    Esta função está disponível para compatibilidade futura.

    Args:
        sigla_uf (str): Sigla do estado ('SP', 'RJ', etc.')
        codigo_municipio (int): Código IBGE do município
        nome_grupo (str): Nome para o grupo CNAE
        lista_cnae (List[str]): Lista de códigos CNAE
        ano_minimo (int, optional): Ano mínimo para filtrar dados
        ano_maximo (int, optional): Ano máximo para projeção

    Returns:
        pd.DataFrame: DataFrame vazio com mensagem informativa

    Raises:
        NotImplementedError: Dados municipais de estoque não estão disponíveis
    """
    raise NotImplementedError(
        "Dados de estoque em nível municipal não estão disponíveis na base atual. "
        "A funcionalidade de estoque estimado municipal será implementada quando "
        "os dados municipais de estoque estiverem disponíveis."
    )
