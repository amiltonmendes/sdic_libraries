#!/usr/bin/env python3
"""Recaptura `contrato/series_amostras.json` com respostas REAIS da sdic_api (precisa de SDIC_API_KEY).

O arquivo versionado foi montado a partir do código da API (campo `a_recapturar: true`). Este script troca
as respostas pelas reais, mantendo o formato que os testes das duas linguagens leem, e recalcula `esperado`.

    SDIC_API_KEY=... python scripts/capturar_series.py
    cd python && python -m pytest -q tests/test_series.py     # e os testes de R
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(RAIZ / "python"))
ARQUIVO = RAIZ / "contrato" / "series_amostras.json"
FILTROS = {"cod_tabela": 8888, "cod_localidade": "35", "cod_variavel": 12606, "desde": "2025-01-01", "ate": "2025-03-31"}


def main() -> int:
    from sdic_libraries.transporte import ClienteAPI

    with ClienteAPI() as api:
        if not api.api_key:
            print("Defina SDIC_API_KEY (a API responde 401 sem chave).", file=sys.stderr)
            return 1
        catalogo = api._make_request("/series")
        params = {k: str(v) for k, v in FILTROS.items()}
        p1 = api._make_request("/series/sidra_producao", {**params, "pagina": 1, "tamanho_pagina": 2})
        p2 = api._make_request("/series/sidra_producao", {**params, "pagina": 2, "tamanho_pagina": 2})
        p2["proxima_pagina"] = None  # o teste lê duas páginas
        respostas = {"/series": catalogo, "/series/sidra_producao?pagina=1": p1, "/series/sidra_producao?pagina=2": p2}
        codigos = {(i["cod_tabela"], i["cod_variavel"], i["cod_categoria"], i["cod_localidade"]) for i in p1["items"] + p2["items"]}
        for dimensao in ("variavel", "categoria", "localidade", "metadados"):
            linhas = api._make_request(f"/series/sidra_producao/dimensoes/{dimensao}")
            respostas[f"/series/sidra_producao/dimensoes/{dimensao}"] = [
                l for l in linhas
                if l.get("cod_tabela", 8888) == 8888
                and (dimensao != "variavel" or any(l["cod_variavel"] == c[1] for c in codigos))
                and (dimensao != "categoria" or any(l["cod_categoria"] == c[2] for c in codigos))
                and (dimensao != "localidade" or any(l["cod_localidade"] == c[3] for c in codigos))]
    itens = p1["items"] + p2["items"]
    dim = lambda d: respostas[f"/series/sidra_producao/dimensoes/{d}"]  # noqa: E731
    sidra = next(s for s in catalogo if s["nome"] == "sidra_producao")
    amostra = {
        "_origem": "Respostas reais da sdic_api capturadas por scripts/capturar_series.py (filtros: %s)." % FILTROS,
        "a_recapturar": False,
        "respostas": respostas,
        "esperado": {
            "listar_series": {"colunas": ["nome", "descricao", "fonte", "colunas", "filtros", "obrigatorios", "periodo", "dimensoes"],
                              "nomes": [s["nome"] for s in catalogo]},
            "get_serie": {"args": {"nome": "sidra_producao", **{k: v for k, v in FILTROS.items()}},
                          "colunas": sidra["colunas"], "linhas": len(itens), "paginas": 2,
                          "valores": [None if i["valor"] is None else float(i["valor"]) for i in itens],
                          "cod_localidade": "35", "query_esperada": params},
            "get_serie_com_nomes": {"colunas_extras": ["categoria_nome", "localidade_nome", "variavel_nome", "unidade"],
                                    "variavel_nome": dim("variavel")[0]["nome"], "localidade_nome": dim("localidade")[0]["nome"]},
            "get_dimensao_serie": {"args": {"nome": "sidra_producao", "dimensao": "variavel"},
                                   "colunas": list(dim("variavel")[0]), "linhas": len(dim("variavel"))}}}
    ARQUIVO.write_text(json.dumps(amostra, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{ARQUIVO.relative_to(RAIZ)} recapturado: {len(itens)} linhas. Rode os testes das duas linguagens.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
