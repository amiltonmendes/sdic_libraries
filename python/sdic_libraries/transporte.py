"""Transporte: o único lugar da biblioteca que faz HTTP.

Dois tipos de origem (ver `catalogo.json`):

- **api**: a sdic_api, com chave individual (`Authorization: Bearer`), repetição em falha
  transitória (429, 502, 503, 504), paginação e cache opcional;
- **arquivo**: JSON públicos (bucket de dados, Pages das políticas), sem chave.

Os clientes (`Emprego`, `Comex`) e as funções de séries, seções publicadas e políticas usam só
o que está aqui. Trocar endereço, autenticação ou política de repetição é mexer neste arquivo
e em `config.py`.
"""
from __future__ import annotations

import hashlib
import logging
import warnings
from typing import Any, Callable, Dict, List, Optional

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from . import config
from .utils.cache import com_cache
from .utils.erros import detalhe_api

logger = logging.getLogger("sdic_libraries")
TAMANHO_PAGINA = 5000  # máximo aceito pela sdic_api


class SdicErro(Exception):
    """Erro de leitura. `status_code` e `endpoint` dizem o que falhou (None em falha de rede)."""

    def __init__(self, mensagem: str, status_code: Optional[int] = None, endpoint: Optional[str] = None):
        super().__init__(mensagem)
        self.status_code = status_code
        self.endpoint = endpoint


class NaoPublicado(SdicErro):
    """O arquivo pedido não existe na origem (404): ainda não foi publicado nesse ambiente."""


def _versao() -> str:
    from . import __version__
    return __version__


def nova_sessao(chave: Optional[str] = None) -> requests.Session:
    sessao = requests.Session()
    repeticao = Retry(total=3, connect=1, backoff_factor=1, status_forcelist=(429, 502, 503, 504),
                      allowed_methods=("GET", "POST"), respect_retry_after_header=True, raise_on_status=False)
    for prefixo in ("https://", "http://"):
        sessao.mount(prefixo, HTTPAdapter(max_retries=repeticao))
    sessao.headers.update({"User-Agent": f"sdic-libraries/{_versao()}", "Accept": "application/json"})
    if chave:
        # Só Authorization: o requests o retira num redirecionamento para outro host; um
        # cabeçalho próprio (x-api-key) seguiria junto.
        sessao.headers["Authorization"] = f"Bearer {chave}"
    return sessao


def mensagem_de_erro(erro: Exception, endpoint: str, variavel_chave: str = "SDIC_API_KEY") -> str:
    """Mensagem para quem usa: o que houve, em qual rota e o que fazer. Decide só pelo código HTTP."""
    resposta = getattr(erro, "response", None)
    status = getattr(resposta, "status_code", None)
    detalhe = detalhe_api(resposta) if resposta is not None else None
    sufixo = f" [{endpoint}" + (f", HTTP {status}]" if status else "]")
    if status in (400, 422):
        return f"Parâmetros inválidos: {detalhe or 'confira códigos e datas informados'}.{sufixo}"
    if status in (401, 403):
        return (f"Chave da API ausente, inválida ou sem acesso ({detalhe or 'sem detalhe'}). "
                f"Defina {variavel_chave} (sdic_config() mostra o que está valendo).{sufixo}")
    if status == 404:
        return (f"Rota ou recurso não encontrado{': ' + detalhe if detalhe else ''}. "
                f"Confira o nome e se a biblioteca está atualizada.{sufixo}")
    if status == 429:
        return f"Muitas requisições em pouco tempo; a biblioteca já tentou de novo. Aguarde e repita.{sufixo}"
    if status and status >= 500:
        return f"A API respondeu com erro interno depois das novas tentativas. Tente mais tarde.{sufixo}"
    if isinstance(erro, (requests.exceptions.ConnectionError, requests.exceptions.Timeout)):
        return f"Sem resposta da origem (rede ou tempo esgotado): {type(erro).__name__}.{sufixo}"
    if isinstance(erro, ValueError):
        return f"A resposta não é um JSON válido.{sufixo}"
    return f"Falha na requisição: {type(erro).__name__}.{sufixo}"


def em_lista(valor: Any) -> List[str]:
    """Um código ou vários, como texto: `'10'`, `10` e `['10', 11]` viram `['10']`, `['10']` e `['10', '11']`.
    (Sem isto, `','.join('10')` consultava os códigos `1` e `0`.)"""
    if valor is None:
        return []
    if isinstance(valor, (str, int, float)):
        return [str(valor)]
    return [str(v) for v in valor]


class ClienteAPI:
    """Base dos clientes da sdic_api: configuração, sessão, requisição, paginação e cache."""

    erro = SdicErro

    def __init__(self, base_url: Optional[str] = None, timeout: Optional[int] = None, api_key: Optional[str] = None):
        self.base_url = config.url("api", base_url)
        self.timeout = config.timeout(timeout)
        self.cache_ttl = config.cache_ttl()  # segundos; 0 = sem cache (ver utils/cache.py)
        self.api_key = config.chave(api_key)
        if self.api_key:
            config.conferir_destino_da_chave(self.base_url)
        self.session = nova_sessao(self.api_key)
        self.logger = logger

    def __repr__(self) -> str:  # a chave nunca aparece
        return f"{type(self).__name__}(base_url={self.base_url!r}, chave={'definida' if self.api_key else 'não definida'})"

    def close(self) -> None:
        self.session.close()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()

    def _url(self, endpoint: str) -> str:
        return f"{self.base_url.rstrip('/')}/{endpoint.lstrip('/')}"

    def _identidade(self) -> Optional[str]:
        """Entra na chave do cache: resposta de uma chave não serve a outra (nem a quem não tem)."""
        return hashlib.sha256(self.api_key.encode()).hexdigest()[:12] if self.api_key else None

    def _requisitar(self, metodo: str, endpoint: str, params: Optional[Dict[str, Any]], corpo: Any = None) -> Any:
        url = self._url(endpoint)

        def buscar():
            if metodo == "GET":
                resposta = self.session.get(url, params=params, timeout=self.timeout)
            else:
                resposta = self.session.post(url, json=corpo, params=params, timeout=self.timeout)
            resposta.raise_for_status()
            return resposta.json()

        try:
            return com_cache(self.cache_ttl, (metodo, url, params, corpo, self._identidade()), buscar)
        except (requests.exceptions.RequestException, ValueError) as e:
            status = getattr(getattr(e, "response", None), "status_code", None)
            self.logger.debug("Falha em %s %s: %s", metodo, endpoint, type(e).__name__)
            raise self.erro(mensagem_de_erro(e, endpoint), status_code=status, endpoint=endpoint) from e

    def _make_request(self, endpoint: str, params: Optional[Dict[str, Any]] = None) -> Any:
        return self._requisitar("GET", endpoint, params)

    def _make_post_request(self, endpoint: str, body: Any, params: Optional[Dict[str, Any]] = None) -> Any:
        return self._requisitar("POST", endpoint, params, body)

    # ---- paginação -----------------------------------------------------------------------
    def _normalize_response_item(self, item: Dict[str, Any]) -> Dict[str, Any]:
        return item

    def _extract_items(self, response: Any) -> List[Dict[str, Any]]:
        if isinstance(response, list):
            itens = response
        elif isinstance(response, dict):
            itens = next((response[k] for k in ("items", "data", "results", "records")
                          if isinstance(response.get(k), list)), None)
            if itens is None:
                raise self.erro("Formato de resposta inesperado da API: página sem a lista de itens.")
        else:
            raise self.erro("Formato de resposta inesperado da API")
        return [self._normalize_response_item(i) for i in itens if isinstance(i, dict)]

    @staticmethod
    def _inteiro(resposta: Any, *chaves: str) -> Optional[int]:
        if isinstance(resposta, dict):
            for chave in chaves:
                v = resposta.get(chave)
                if isinstance(v, int) and not isinstance(v, bool) and v >= 0:
                    return v
        return None

    def _get_total_count(self, response: Any) -> Optional[int]:
        return self._inteiro(response, "count")

    def _get_total_pages(self, response: Any) -> Optional[int]:
        return self._inteiro(response, "pages", "total_pages", "paginas", "totalPaginas") or None

    def _paginar(self, pedir: Callable[[Dict[str, Any]], Any], params: Optional[Dict[str, Any]],
                 endpoint: str = "") -> List[Dict[str, Any]]:
        """Junta todas as páginas. Para, nesta ordem, por: `proxima_pagina` nulo (rotas `/series`),
        total de páginas, total de registros (`count`), página menor que a pedida."""
        todos: List[Dict[str, Any]] = []
        pagina, total = 1, None
        while True:
            p = dict(params or {})
            p["pagina"] = pagina
            p.setdefault("tamanho_pagina", TAMANHO_PAGINA)
            tamanho = int(p["tamanho_pagina"] or TAMANHO_PAGINA)
            resposta = pedir(p)
            itens = self._extract_items(resposta)
            todos.extend(itens)
            if total is None:
                total = self._get_total_count(resposta)
            if isinstance(resposta, dict) and "proxima_pagina" in resposta:
                if resposta["proxima_pagina"] is None:
                    break
            elif not itens:
                break
            else:
                paginas = self._get_total_pages(resposta)
                if paginas is not None and pagina >= paginas:
                    break
                if total is not None and len(todos) >= total:
                    break
                if len(itens) < tamanho:
                    break
            if pagina % 20 == 0:
                self.logger.info("%s: %d páginas lidas (%d linhas)", endpoint, pagina, len(todos))
            pagina += 1
        if total is not None and len(todos) != total:
            warnings.warn(f"{endpoint}: a API informou {total} registros e vieram {len(todos)}. "
                          "O resultado pode estar incompleto; repita a consulta.", RuntimeWarning, stacklevel=3)
        return todos

    def _fetch_all_paginated_get(self, endpoint: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        return self._paginar(lambda p: self._make_request(endpoint, p), params, endpoint)

    def _fetch_all_paginated_post(self, endpoint: str, body: Any, params: Dict[str, Any]) -> List[Dict[str, Any]]:
        def pedir(p):
            corpo = body
            if isinstance(body, dict) and self._paginacao_no_corpo:
                corpo = dict(body, pagina=p["pagina"])
                corpo.setdefault("tamanho_pagina", p["tamanho_pagina"])
            return self._make_post_request(endpoint, corpo, params=p)
        return self._paginar(pedir, params, endpoint)

    _paginacao_no_corpo = False  # Comex: `/exportacao_agregada_ncm` espera a página também no corpo


# ---- arquivos publicados (sem chave) ------------------------------------------------------
_sessao_arquivos: Optional[requests.Session] = None


def ler_json_publicado(origem: str, caminho: str, base_url: Optional[str] = None,
                       timeout: Optional[int] = None) -> Any:
    """Lê um JSON público de uma origem do catálogo (`dados` ou `politicas`).

    É o nível mais baixo de leitura de arquivos: prefira `get_secao_publicada`, `get_politica` etc.
    Nenhuma chave é enviada. Um 404 vira `NaoPublicado`, com a URL pedida na mensagem.

    Example:
        >>> ler_json_publicado("dados", "homologacao/SP/emprego.json")
    """
    global _sessao_arquivos
    if _sessao_arquivos is None:
        _sessao_arquivos = nova_sessao()
    url = f"{config.url(origem, base_url)}/{caminho.lstrip('/')}"

    def buscar():
        resposta = _sessao_arquivos.get(url, timeout=config.timeout(timeout))
        resposta.raise_for_status()
        return resposta.json()

    try:
        return com_cache(config.cache_ttl(), ("GET", url, None, None, None), buscar)
    except requests.exceptions.HTTPError as e:
        status = getattr(e.response, "status_code", None)
        if status in (403, 404):  # o bucket responde 403 ou 404 para objeto inexistente
            raise NaoPublicado(f"Arquivo não publicado: {url}. Confira o ambiente (SDIC_AMBIENTE) e a unidade.",
                               status_code=status, endpoint=url) from e
        raise SdicErro(mensagem_de_erro(e, url), status_code=status, endpoint=url) from e
    except (requests.exceptions.RequestException, ValueError) as e:
        raise SdicErro(mensagem_de_erro(e, url), endpoint=url) from e
