# Changelog

Formato livre (sem [Keep a Changelog](https://keepachangelog.com) ainda) — o essencial é: o que
muda pro usuário ao atualizar. Versionamento nas duas linguagens juntas; ver [AGENTS.md](AGENTS.md#versionamento).

## [0.5.1] — 2026-10-08

### Corrigido
- Comex: `get_exportacao_ncm_nacional_mensal`/`get_importacao_ncm_nacional_mensal` com `lista_ncms`
  voltaram a funcionar. A carga do ComexStat de 08/10/2026 passou os códigos para texto no BigQuery,
  e a lista com números dava erro 500 na sdic_api 2.0. Os NCMs agora vão como texto de 8 dígitos
  (`4032000` → `"04032000"`); continue passando número ou texto, como preferir (Python e R).

### Compatibilidade
- Funciona com a sdic_api 2.x e 3.x. Os filtros `divisao=` e `bloco=` dependem da **sdic_api 3.0.0**
  (já em produção), que aceita o código como número ou texto.
- Nenhuma mudança no esquema dos `DataFrame`/`tibble` devolvidos. A sdic_api 3.0.0 passou a
  devolver `CodigoNCM` como texto em `/ncms`, mas a biblioteca não usa esse endpoint.

## [0.5.0] — 2026-09-29

### Adicionado
- `listar_bases()` (Python e R): catálogo das funções públicas, filtrável por `tema`/`subtema`.
  [CATALOGO.md](CATALOGO.md) tem o mesmo conteúdo em página, gerado de `catalogo.py`/`catalogo.R`.
- Comex: funções de módulo (`get_exportacao_*`, `get_importacao_*`, `get_ncm_isic_mapa`) devolvendo
  `DataFrame`/`tibble` já padronizado — antes só a classe `Comex` (registros crus) existia.
- `juntar_emprego_comex()`: une emprego e comércio exterior por divisão CNAE/ISIC e ano.
- Cache local em disco, opt-in (`SDIC_CACHE_TTL`), só sobre a sdic_api.
- Contrato de esquema testado entre Python e R para emprego e comex (`contrato/*_amostras.json`).
- `AGENTS.md`/`CLAUDE.md`: guia obrigatório de arquitetura e decisões de design para agentes.

### Corrigido
- `ano_minimo`/`ano_maximo` (funções de emprego) agora também são filtrados no cliente — protege
  contra uma sdic_api implantada anterior a esses parâmetros, que os ignorava silenciosamente.
- R: colunas 100% nulas não eram mais descartadas ao converter resposta da API em tibble.
- Correções de esquema na sdic_api (tipos, texto): NCM/divisão ISIC como texto com zeros à
  esquerda, nome canônico `quantidade_estatistica`, acentuação de `DescricaoNCM` corrigida.

### Descontinuado (aviso, sem quebra)
- Python: `Emprego.get_saldo_emprego_as_dataframe` — use `get_saldo_emprego_<nivel>_mensal`/`_anual`.
- R: `get_all_pages`, `get_saldo_emprego_as_tibble`, `get_saldo_emprego_lista_cnae_as_tibble`,
  `get_saldo_emprego_grupos_cnae_as_tibble` — use `get_saldo_emprego_<nivel>_mensal`/`_anual`/`_mensal_agrupado`.

## Antes de 0.5.0

Não documentado retroativamente. `0.4.0` renomeou `sdic_libraries.data_access` para
`sdic_libraries.dados` (alias mantido, com aviso de depreciação).
