#!/usr/bin/env python3
"""Gera CATALOGO.md a partir de python/sdic_libraries/catalogo.py e r/R/catalogo.R.

Lê os dois catálogos (cada um com seu próprio interpretador — nada de parsear R com
regex) e falha se um tema/subtema/nível/função/descrição divergir entre eles: as duas
linguagens têm que descrever a mesma função da mesma forma. Roda pelo Makefile
(`make catalogo`) ou direto: `python scripts/gerar_catalogo_md.py`.
"""
from __future__ import annotations

import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
CHAVES = ("tema", "subtema", "nivel", "funcao", "descricao")


def catalogo_python() -> list[dict]:
    sys.path.insert(0, str(RAIZ / "python"))
    from sdic_libraries.catalogo import _CATALOGO, COLUNAS
    return [dict(zip(COLUNAS, linha)) for linha in _CATALOGO]


def catalogo_r() -> list[dict]:
    script = (
        'source("R/catalogo.R"); '
        'cat(jsonlite::toJSON(dplyr::bind_rows(.catalogo_linhas), auto_unbox = TRUE))'
    )
    saida = subprocess.run(
        ["Rscript", "-e", script], cwd=RAIZ / "r", capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(saida)


def conferir_paridade(py: list[dict], r: list[dict]) -> None:
    chave = lambda linha: tuple(linha[c] for c in CHAVES)  # noqa: E731
    py_set, r_set = {chave(l) for l in py}, {chave(l) for l in r}
    if py_set != r_set:
        so_py = py_set - r_set
        so_r = r_set - py_set
        raise SystemExit(
            "catalogo.py e catalogo.R divergem (tema/subtema/nivel/funcao/descricao):\n"
            f"  só em catalogo.py: {sorted(so_py)}\n  só em catalogo.R: {sorted(so_r)}"
        )


def gerar_markdown(py: list[dict], r: list[dict]) -> str:
    exemplo_r = {l["funcao"]: l["exemplo"] for l in r}
    por_tema: dict[str, dict[str, list[dict]]] = defaultdict(lambda: defaultdict(list))
    for linha in py:
        por_tema[linha["tema"]][linha["subtema"]].append(linha)

    nomes_tema = {"emprego": "Emprego (RAIS/CAGED)", "comex": "Comércio exterior",
                  "utilitarios": "Utilitários"}
    partes = [
        "# Catálogo de funções\n",
        "Gerado de `python/sdic_libraries/catalogo.py` + `r/R/catalogo.R` — não edite à mão,",
        "rode `python scripts/gerar_catalogo_md.py`. Mesmo conteúdo de `listar_bases()`",
        "(Python e R), em formato de página. Nível `-` = não se aplica (catálogos estáticos,",
        "utilitários).\n",
    ]
    for tema in ("emprego", "comex", "utilitarios"):
        if tema not in por_tema:
            continue
        partes.append(f"## {nomes_tema[tema]}\n")
        for subtema, linhas in sorted(por_tema[tema].items()):
            partes.append(f"### {subtema}\n")
            partes.append("| Função | Nível | Descrição | Exemplo |")
            partes.append("|---|---|---|---|")
            for linha in sorted(linhas, key=lambda l: l["funcao"]):
                exemplo = f"Python: `{linha['exemplo']}`<br>R: `{exemplo_r.get(linha['funcao'], linha['exemplo'])}`"
                partes.append(
                    f"| `{linha['funcao']}` | {linha['nivel']} | {linha['descricao']} | {exemplo} |"
                )
            partes.append("")
    return "\n".join(partes) + "\n"


if __name__ == "__main__":
    py, r = catalogo_python(), catalogo_r()
    conferir_paridade(py, r)
    (RAIZ / "CATALOGO.md").write_text(gerar_markdown(py, r), encoding="utf-8")
    print(f"CATALOGO.md gerado: {len(py)} funções, {len(set(l['tema'] for l in py))} temas.")
