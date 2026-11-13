#!/usr/bin/env python3
"""Gera tudo o que deriva de `contrato/catalogo.json`, a fonte única do catálogo.

    python scripts/documentar.py             # copia o catálogo para os dois pacotes e regenera CATALOGO.md e docs/
    python scripts/documentar.py --conferir  # não escreve; falha se algo gerado estiver desatualizado (CI e pytest)

Gerados (não edite à mão): `python/sdic_libraries/catalogo.json`, `r/inst/catalogo.json`, `CATALOGO.md` e
`docs/*.md`. As páginas de `docs/` são publicadas no painel de cargas em `/docs/biblioteca`
(`painel_cargas/deploy.sh docs`). O modo de usar de cada função fica no comentário dela (docstring e
roxygen); aqui entram o que ela devolve e de onde o dado vem.
"""
from __future__ import annotations

import inspect
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]
FONTE = RAIZ / "contrato" / "catalogo.json"
sys.path.insert(0, str(RAIZ / "python"))

TEMAS = {"emprego": "Emprego (RAIS e Novo CAGED)", "comex": "Comércio exterior (ComexStat)",
         "series": "Séries da API (bases do carga_base e indicadores)", "publicados": "Seções publicadas (JSON do portal)",
         "politicas": "Políticas da SDIC (gaia_nib)", "utilitarios": "Utilitários e configuração"}
AVISO = "<!-- Gerado por scripts/documentar.py a partir de contrato/catalogo.json. Não edite à mão. -->\n\n"


def _tabela(cabecalho: list[str], linhas: list[list[str]]) -> str:
    limpa = lambda c: str(c if c is not None else "").replace("|", "\\|").replace("\n", " ")  # noqa: E731
    return "\n".join(["| " + " | ".join(cabecalho) + " |", "|" + "---|" * len(cabecalho)]
                     + ["| " + " | ".join(limpa(c) for c in l) + " |" for l in linhas]) + "\n"


def _assinatura(nome: str) -> str:
    import sdic_libraries
    try:
        return f"{nome}{inspect.signature(getattr(sdic_libraries, nome))}"
    except (TypeError, ValueError, AttributeError):
        return f"{nome}(...)"


def catalogo_md(cat: dict) -> str:
    partes = ["# Catálogo de funções\n", AVISO.strip(), "",
              "Mesmo conteúdo de `listar_bases()` (Python e R). Detalhe de cada função: [docs/referencia.md](docs/referencia.md); "
              "de onde vem cada dado: [docs/dados.md](docs/dados.md). Nível `-` = não se aplica.\n"]
    for tema, titulo in TEMAS.items():
        funcoes = [f for f in cat["funcoes"] if f["tema"] == tema]
        if not funcoes:
            continue
        partes.append(f"## {titulo}\n")
        partes.append(_tabela(["Função", "Subtema", "Nível", "Descrição", "Exemplo"],
                              [[f"`{f['funcao']}`", f["subtema"], f["nivel"], f["descricao"],
                                f"Python: `{f['exemplo_py']}`<br>R: `{f['exemplo_r']}`"] for f in funcoes]))
    return "\n".join(partes)


def referencia_md(cat: dict) -> str:
    partes = ["# Referência das funções\n", AVISO.strip(), "",
              "Uma entrada por função pública, igual em Python (`sdic_libraries`) e em R (`sdic.libraries`). "
              "A ajuda completa de cada uma, com todos os parâmetros, está no próprio ambiente: "
              "`help(funcao)` ou `funcao?` em Python, `?funcao` em R.\n"]
    for tema, titulo in TEMAS.items():
        funcoes = [f for f in cat["funcoes"] if f["tema"] == tema]
        if not funcoes:
            continue
        partes.append(f"## {titulo}\n")
        for f in funcoes:
            partes.append(f"### `{f['funcao']}`\n")
            partes.append(f["descricao"] + "\n")
            base = cat["bases"].get(f.get("base") or "")
            if base and base.get("depreciada"):
                partes.append(f"**Depreciada.** {base['depreciada']}\n")
            partes.append("```python\n# Python\nfrom sdic_libraries import " + f["funcao"] + "\n" + f["exemplo_py"] + "\n```\n")
            partes.append("```r\n# R\nlibrary(sdic.libraries)\n" + f["exemplo_r"] + "\n```\n")
            partes.append(f"Assinatura (Python): `{_assinatura(f['funcao'])}`\n")
            if f.get("base"):
                partes.append(f"Dados consultados: [{base['titulo']}](dados.md#{f['base']}).\n")
            colunas = cat["colunas"].get(f["funcao"])
            if colunas:
                partes.append("Colunas devolvidas:\n")
                partes.append(_tabela(["Coluna", "Tipo", "Significado"], [[f"`{c}`", t, s] for c, t, s in colunas]))
    return "\n".join(partes)


def dados_md(cat: dict) -> str:
    partes = ["# Dados consultados\n", AVISO.strip(), "",
              "De onde vem cada número que a biblioteca devolve. As bases pelo lado da carga (tabelas do BigQuery, "
              "janelas de atualização, estado de cada carga) estão em [Bases](/docs/bases) e no painel de cargas; "
              "aqui fica o lado da leitura.\n",
              "## Origens\n",
              "Três endereços, cada um com uma variável de ambiente para trocá-lo. `sdic_config()` mostra o que está em uso.\n",
              _tabela(["Origem", "O que é", "Endereço padrão", "Variável"],
                      [[f"`{n}`", o["descricao"], o["url"], f"`{o['variavel']}`"] for n, o in cat["origens"].items()]),
              "## Bases\n"]
    for nome, b in cat["bases"].items():
        partes.append(f'<a id="{nome}"></a>\n\n### {b["titulo"]} (`{nome}`)\n')
        if b.get("depreciada"):
            partes.append(f"**Depreciada.** {b['depreciada']}\n")
        linhas = [["Origem", f"`{b['origem']}`" + (f", caminho `{b['caminho']}`" if b.get("caminho") else "")],
                  ["Fonte", b.get("fonte")], ["Atualização", b.get("periodicidade")]]
        if b.get("dataset"):
            linhas.append(["No BigQuery", f"`{b['dataset']}`"])
        if b.get("carga"):
            linhas.append(["Carga (painel de cargas)", f"`{b['carga']}`"])
        if b.get("esquema"):
            linhas.append(["Esquema", b["esquema"]])
        if b.get("documentacao"):
            linhas.append(["Documentação da base", f"`{b['documentacao']}`"])
        funcoes = [f"`{f['funcao']}`" for f in cat["funcoes"] if f.get("base") == nome]
        linhas.append(["Funções que leem", ", ".join(funcoes)])
        partes.append(_tabela(["", ""], linhas))
    partes += ["## Seções publicadas\n",
               "Arquivos `{ambiente}/{UF ou BRASIL}/{seção}.json`, no contrato v1.1, os mesmos que o portal e os subsídios leem.\n",
               _tabela(["Seção", "Título", "Existe para", "Fonte"],
                       [[f"`{n}`", s["titulo"], s["unidades"], s["fonte"]] for n, s in cat["secoes"].items()]),
               "Cada arquivo também tem a variante `{seção}_relatorio.json`, com os dados detalhados dos relatórios. "
               "Ela não tem função própria: leia com `ler_json_publicado(\"dados\", \"<ambiente>/<UF>/<seção>_relatorio.json\")`.\n",
               "## Ambientes\n",
               "`producao` (padrão) e `homologacao`, por `SDIC_AMBIENTE` ou pelo argumento `ambiente`. O ambiente vale para "
               "as seções publicadas e para as políticas; a API tem um ambiente só. Um arquivo que não existe no ambiente "
               "pedido gera erro `NaoPublicado` com a URL: a função nunca cai em outro ambiente por conta própria.\n"]
    return "\n".join(partes)


QUAL = """# Qual função usar

{aviso}

| Preciso de | Use | Exemplo |
|---|---|---|
| Um número que o portal também mostra (indicadores, séries dos gráficos, rankings das seções) | Seções publicadas | `get_kpis_publicados("SP", "emprego")` |
| Uma política da SDIC | Políticas | `get_politicas_estado("SP")` |
| Uma série de uma base (SIDRA, Contas Regionais, comex por UF e ISIC) ou um indicador oficial | Séries da API | `get_serie("sidra_producao", cod_tabela=8888, cod_localidade="35")` |
| Emprego formal com recorte próprio (CNAE, município, porte, ocupação) | Emprego | `get_saldo_emprego_estadual_mensal(sigla_uf="SP", codigo_cnae="10")` |
| Comércio exterior com recorte próprio (NCM, país, ISIC, agrupamentos) | Comex | `get_exportacao_isic_divisao_estadual_mensal(estado="São Paulo")` |
| Saber o que existe | `listar_bases()`, `listar_series()`, `listar_secoes_publicadas()`, `listar_politicas()` | |
| Saber de onde vem um dado e que colunas ele tem | `descrever(nome)` | `descrever("get_kpis_publicados")` |
| Saber de onde a biblioteca está lendo | `sdic_config()` | |
| Um arquivo publicado que não tem função (último recurso) | `ler_json_publicado(origem, caminho)` | `ler_json_publicado("dados", "homologacao/SP/emprego_relatorio.json")` |

Regras que valem para qualquer relatório ou análise:

- **Leia só pela biblioteca.** Nada de HTTP próprio, planilha local ou cópia de arquivo: é isso que permite
  trocar o endereço da API ou o local dos arquivos sem mexer no seu código.
- **Não some nem compare políticas ou indicadores de unidades diferentes** (R$ com atendimentos, por exemplo).
  A ordem das políticas é a publicada; não reordene.
- **Diga o ambiente quando não for produção**: `ambiente="homologacao"` ou `SDIC_AMBIENTE=homologacao`.
- **Número que não existe em lugar nenhum** vira um indicador (`cgid_reports/indicadores`), não uma conta dentro
  do relatório. Depois de oficial e publicado na API, ele é lido com `get_serie(id)`.
"""

INDEX = """# Biblioteca de dados da SDIC

{aviso}

Uma porta única para ler os dados da plataforma, com as mesmas funções em **Python** (`sdic_libraries`) e em
**R** (`sdic.libraries`). Toda função devolve uma tabela (`DataFrame` ou `tibble`). Versão {versao}.

- [Qual função usar](qual_funcao_usar.md)
- [Referência das funções](referencia.md)
- [Dados consultados](dados.md): de onde vem cada número
- [Configuração](configuracao.md): chave, endereços, ambientes e erros comuns
- [Mudanças](mudancas.md)

## Instalar

```bash
# Python
pip install "git+https://github.com/amiltonmendes/sdic_libraries.git#subdirectory=python"
```

```r
# R
remotes::install_github("amiltonmendes/sdic_libraries", subdir = "r")
```

## Chave da API

A API exige uma chave individual (peça ao dono do projeto). Grave-a em um arquivo `.env.local` na pasta do seu
projeto (o `.gitignore` deve ignorá-lo) ou em uma variável de ambiente:

```
SDIC_API_KEY=sua-chave
```

As seções publicadas e as políticas são arquivos públicos e não precisam de chave.

## Primeiro uso

```python
from sdic_libraries import listar_bases, descrever, get_kpis_publicados, get_serie

listar_bases()                                   # o que existe
descrever("get_kpis_publicados")                 # de onde vem e que colunas tem
get_kpis_publicados("SP", "emprego", ambiente="homologacao")
get_serie("contas_regionais_vab", sg_uf="SP", com_nomes=True)
```

```r
library(sdic.libraries)

listar_bases()
descrever("get_kpis_publicados")
get_kpis_publicados("SP", "emprego", ambiente = "homologacao")
get_serie("contas_regionais_vab", sg_uf = "SP", com_nomes = TRUE)
```

## Ajuda dentro do ambiente

| | Python | R |
|---|---|---|
| Ajuda de uma função | `help(get_serie)` ou `get_serie?` (Jupyter) | `?get_serie` |
| Visão geral do pacote | `help(sdic_libraries)` | `?sdic.libraries`, `help(package = "sdic.libraries")` |
| O que existe | `listar_bases()` | `listar_bases()` |
| Ficha de uma base ou função | `descrever("politicas")` | `descrever("politicas")` |
| O que está configurado | `sdic_config()` | `sdic_config()` |
"""

CONFIG = """# Configuração

{aviso}

## Variáveis

{variaveis}

Cada valor é procurado nesta ordem, e o primeiro encontrado vale: argumento da função, variável de ambiente,
`.env.local` e `.env` da pasta atual, `~/.env`, `/etc/sdic/.env`, padrão. Os arquivos são apenas lidos: a
biblioteca não altera o ambiente do processo nem a configuração de log de quem a usa. `sdic_config()` mostra
o que está valendo e de onde veio (a chave nunca é exibida).

Nomes antigos ainda aceitos, com aviso de depreciação: `EMPLOYMENT_API_KEY` e `COMEX_API_KEY` (use
`SDIC_API_KEY`), `EMPLOYMENT_API_BASE_URL` e `COMEX_API_BASE_URL` (`SDIC_API_URL`), `PORTAL_EMPREGO_BASE_URL`
(`SDIC_PAGES_URL`), `PORTAL_EMPREGO_AMBIENTE` (`SDIC_AMBIENTE`), `API_TIMEOUT` (`SDIC_TIMEOUT`).

## Se o endereço mudar

Quem usa a biblioteca não muda nada no código: as funções recebem nomes (`"sidra_producao"`, `"SP"`,
`"emprego"`), nunca endereços.

| Mudança | O que fazer |
|---|---|
| A API, o bucket ou o Pages mudam de endereço | Atualizar a biblioteca (o endereço padrão está em `contrato/catalogo.json`). Até atualizar, definir a variável da origem (`SDIC_API_URL`, `SDIC_DADOS_URL`, `SDIC_PAGES_URL`) |
| Conferir dados antes da promoção | `SDIC_AMBIENTE=homologacao` ou `ambiente="homologacao"` |
| Uma base muda de origem (arquivo para API, por exemplo) | Nada: a função e as colunas continuam as mesmas |

## Segurança da chave

- A chave vai só no cabeçalho `Authorization`, e só para endereços `https://` (ou para a própria máquina, em teste).
- Não aparece em mensagens de erro, em `print()` dos clientes, em `sdic_config()` nem nos arquivos de cache.
- Guarde-a em `.env.local` (fora do git) ou em variável de ambiente; nunca em `.env` versionado.

## Cache

Desligado por padrão. `SDIC_CACHE_TTL=3600` guarda as respostas por uma hora em `SDIC_CACHE_DIR`
(padrão `~/.cache/sdic_libraries`). Use valores curtos: depois de uma carga, o cache serve o dado antigo até
expirar. Para limpar, apague a pasta.

## Erros comuns

| Mensagem | Causa | O que fazer |
|---|---|---|
| `Chave da API ausente, inválida ou sem acesso` (HTTP 401 ou 403) | Sem `SDIC_API_KEY`, ou chave revogada | Definir a chave; `sdic_config()` diz se ela está sendo encontrada |
| `não está publicada em 'producao'` | A seção ou as políticas ainda não foram promovidas | Usar `ambiente="homologacao"`, ou aguardar a promoção |
| `Parâmetros inválidos: ...` (HTTP 422) | Filtro desconhecido, obrigatório ausente ou valor em formato errado | A mensagem repete o que a API explicou; em séries, ver `listar_series()` |
| `Rota ou recurso não encontrado` (HTTP 404) | Série inexistente ou biblioteca desatualizada em relação à API | `listar_series()`; atualizar a biblioteca |
| `Muitas requisições` (HTTP 429), `erro interno` (HTTP 5xx) | Falha transitória; a biblioteca já repetiu 3 vezes | Tentar mais tarde |
| `Sem resposta da origem` | Rede ou tempo esgotado | Conferir a conexão; aumentar `SDIC_TIMEOUT` em consultas grandes |
| `A chave da API não é enviada para ...` | `SDIC_API_URL` não é `https://` | Corrigir a URL (`sdic_config()` mostra de onde ela veio) |
| Aviso `a API informou N registros e vieram M` | Paginação incompleta | Repetir a consulta |

Os erros têm `status_code` e `endpoint` (Python: exceção `SdicErro`; R: condição de classe `sdic_erro`), para
quem precisa tratá-los em código.
"""

VARIAVEIS = [
    ["`SDIC_API_KEY`", "Chave individual da API", "sem chave"],
    ["`SDIC_AMBIENTE`", "`producao` ou `homologacao` (seções publicadas e políticas)", "`producao`"],
    ["`SDIC_API_URL`", "Endereço da sdic_api", None],
    ["`SDIC_DADOS_URL`", "Endereço dos JSON publicados", None],
    ["`SDIC_PAGES_URL`", "Endereço dos JSON das políticas", None],
    ["`SDIC_TIMEOUT`", "Segundos por requisição", "30"],
    ["`SDIC_CACHE_TTL`", "Segundos de validade do cache em disco (0 desliga)", "0"],
    ["`SDIC_CACHE_DIR`", "Pasta do cache", "`~/.cache/sdic_libraries`"],
]


def gerar() -> dict[Path, str]:
    texto = FONTE.read_text(encoding="utf-8")
    cat = json.loads(texto)
    from sdic_libraries import __version__
    padrao = {o["variavel"]: o["url"] for o in cat["origens"].values()}
    variaveis = _tabela(["Variável", "Para quê", "Padrão"],
                        [[v, d, p or padrao.get(v.strip("`"))] for v, d, p in VARIAVEIS])
    docs = RAIZ / "docs"
    return {
        RAIZ / "python" / "sdic_libraries" / "catalogo.json": texto,
        RAIZ / "r" / "inst" / "catalogo.json": texto,
        RAIZ / "CATALOGO.md": catalogo_md(cat),
        docs / "index.md": INDEX.format(aviso=AVISO.strip(), versao=__version__),
        docs / "qual_funcao_usar.md": QUAL.format(aviso=AVISO.strip()),
        docs / "referencia.md": referencia_md(cat),
        docs / "dados.md": dados_md(cat),
        docs / "configuracao.md": CONFIG.format(aviso=AVISO.strip(), variaveis=variaveis),
        # links do CHANGELOG são relativos à raiz do repositório; docs/ fica um nível abaixo
        docs / "mudancas.md": "# Mudanças\n\n" + AVISO + (RAIZ / "CHANGELOG.md").read_text(encoding="utf-8").split("\n", 1)[1]
        .replace("](AGENTS.md", "](../AGENTS.md").replace("](INSTALL.md", "](../INSTALL.md"),
    }


def main() -> int:
    conferir = "--conferir" in sys.argv
    desatualizados = []
    for caminho, conteudo in gerar().items():
        atual = caminho.read_text(encoding="utf-8") if caminho.exists() else None
        if atual != conteudo:
            desatualizados.append(str(caminho.relative_to(RAIZ)))
            if not conferir:
                caminho.parent.mkdir(parents=True, exist_ok=True)
                caminho.write_text(conteudo, encoding="utf-8")
    if conferir and desatualizados:
        print("Desatualizados (rode `python scripts/documentar.py`):\n  " + "\n  ".join(desatualizados), file=sys.stderr)
        return 1
    print("Atualizados: " + (", ".join(desatualizados) or "nada a fazer"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
