"""Cache local (em disco) das respostas da sdic_api.

Fica desligado por padrão. Ligue com `SDIC_CACHE_TTL=<segundos>` (ex.: 3600) ou
`api.cache_ttl = 3600`. A chave inclui método, URL completa (host da sdic_api),
parâmetros e corpo da requisição; só respostas bem-sucedidas são gravadas. Os
clientes só chamam a sdic_api, então o cache nunca guarda dado de outra fonte.
Pasta: `SDIC_CACHE_DIR` ou `~/.cache/sdic_libraries` (apague-a para limpar).
"""
from __future__ import annotations

import hashlib
import json
import os
import time
from pathlib import Path
from typing import Any, Callable


def _pasta() -> Path:
    return Path(os.getenv('SDIC_CACHE_DIR') or Path.home() / '.cache' / 'sdic_libraries')


def com_cache(ttl: int, requisicao: tuple, buscar: Callable[[], Any]) -> Any:
    """Devolve a resposta em cache (se tiver menos de `ttl` segundos) ou chama `buscar()`.

    `requisicao` = (método, url, params, corpo) — identifica a resposta.
    """
    if not ttl or ttl <= 0:
        return buscar()
    chave = hashlib.sha256(json.dumps(requisicao, sort_keys=True, default=str).encode()).hexdigest()
    arquivo = _pasta() / f'{chave}.json'
    try:
        if time.time() - arquivo.stat().st_mtime < ttl:
            return json.loads(arquivo.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        pass  # sem cache, expirado ou corrompido: busca de novo
    resposta = buscar()
    try:
        arquivo.parent.mkdir(parents=True, exist_ok=True)
        temporario = arquivo.with_suffix('.tmp')
        temporario.write_text(json.dumps(resposta), encoding='utf-8')
        temporario.replace(arquivo)  # gravação atômica
    except OSError:
        pass  # cache é otimização: falha de disco nunca derruba a consulta
    return resposta
