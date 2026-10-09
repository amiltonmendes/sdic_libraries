"""Mensagem de validação devolvida pela sdic_api (campo `detail` do FastAPI)."""
from __future__ import annotations

from typing import Any, Optional


def detalhe_api(resposta: Any) -> Optional[str]:
    """`detail` de uma resposta de erro, como texto; None se não houver.

    O FastAPI devolve `detail` como texto (erros da própria API, ex.: data em formato
    inválido) ou como lista de `{loc, msg}` (validação de parâmetros)."""
    try:
        detalhe = resposta.json().get('detail')
    except Exception:
        return None
    if isinstance(detalhe, list):
        detalhe = '; '.join(
            f"{'.'.join(str(p) for p in d.get('loc', [])[1:]) or 'parâmetro'}: {d.get('msg', '')}"
            if isinstance(d, dict) else str(d)
            for d in detalhe
        )
    return detalhe if isinstance(detalhe, str) and detalhe.strip() else None
