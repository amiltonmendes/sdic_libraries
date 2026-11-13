# Mudanças

<!-- Gerado por scripts/documentar.py a partir de contrato/catalogo.json. Não edite à mão. -->


Formato livre (sem [Keep a Changelog](https://keepachangelog.com) ainda) — o essencial é: o que
muda pro usuário ao atualizar. Versionamento nas duas linguagens juntas; ver [AGENTS.md](../AGENTS.md#versionamento).

## [0.6.0] — 2026-11-13

A biblioteca passa a ser a porta única de leitura da plataforma: além de emprego e comex, lê as séries da
API, as seções publicadas em JSON e as políticas. Configuração e HTTP ficam num lugar só por linguagem.

### Adicionado
- **Séries da API:** `listar_series()`, `get_serie(nome, desde, ate, com_nomes, **filtros)`, `get_dimensao_serie()`.
- **Seções publicadas** (os JSON do portal e dos subsídios): `listar_secoes_publicadas()`, `get_kpis_publicados()`,
  `get_series_publicadas()`, `get_ranking_publicado()`, `get_detalhamento_publicado()`, `get_destaques_publicados()`,
  `get_atualizacao_publicada()`, `get_secao_publicada()`.
- **Políticas** (gaia_nib): `listar_politicas()`, `get_politica()`, `get_politicas_estado()`, `get_resumo_politicas()`,
  `get_municipios_elegiveis()`, `get_manifesto_politicas()`, `get_politica_publicada()`.
- `sdic_config()` (o que está configurado e de onde veio), `descrever(nome)` (ficha de base ou função, com colunas),
  `ler_json_publicado(origem, caminho)`.
- Uma variável por coisa: `SDIC_API_KEY`, `SDIC_API_URL`, `SDIC_DADOS_URL`, `SDIC_PAGES_URL`, `SDIC_AMBIENTE`, `SDIC_TIMEOUT`.
- `.env.local` passa a ser lido (era documentado e ignorado). Em R, o `.env` passa a funcionar (a leitura falhava em silêncio).
- Repetição automática em falha transitória (HTTP 429, 502, 503, 504).
- Erros com `status_code` e `endpoint` (`SdicErro`; `EmpregoAPIError` e `ComexAPIError` derivam dela).
- Python: todas as funções também se importam da raiz (`from sdic_libraries import get_serie`).
- Documentação em `docs/`, gerada do catálogo; `listar_bases()` cobre também os agrupamentos do comex.

### Corrigido
- **Segurança da chave:** só `Authorization: Bearer` (o `x-api-key` seguia redirecionamento para outro host); a chave
  só é enviada para `https://`; não aparece no `print()` dos clientes R nem no cache em disco do R; o cache separa as
  respostas por chave.
- **Dado errado sem aviso:** o estoque estimado agrupado engolia a falha de um ano e devolvia os anos seguintes com o
  acumulado faltando; agora falha. As funções `*_todos_estados` avisam quais UFs faltaram.
- O argumento `timeout` vence a variável de ambiente (era o contrário).
- Criar um cliente não altera mais o logger raiz do processo nem grava o `.env` inteiro no ambiente.
- Mensagens de erro decididas pelo código HTTP: um 401 com `1400100` na URL virava "parâmetros inválidos"; 404 e 429
  viravam "aguarde". O detalhe devolvido pela API é repassado.
- Python: `codigos_cnae='10'` consultava os códigos `1` e `0`; texto, número ou lista são aceitos.
- `PORTAL_EMPREGO_AMBIENTE` era ignorada pelas funções; o ambiente agora vem de `SDIC_AMBIENTE` quando não é informado.
- Página sem lista de itens no meio da paginação é erro (era tratada como fim); resultado menor que o `count` gera aviso.

### Mudou (pode exigir ajuste)
- `listar_bases(tema="inexistente")` gera erro listando os temas (devolvia tabela vazia).
- Cabeçalho `x-api-key` deixou de ser enviado. A sdic_api 4.0.0 aceita `Authorization: Bearer`.
- R: `Emprego$new()$api_key` e `Comex$new()$api_key` não existem mais (campo privado); a mensagem "API inicializada"
  deixou de ser impressa.
- Textos das mensagens de erro mudaram; trate erros por `status_code`, não pelo texto.

### Descontinuado (continua funcionando, com aviso)
- `get_portal_emprego_*`, `get_relatorio_emprego_*` e `listar_estados_disponiveis` (layout antigo do Pages, que o
  pipeline novo não produz): use as funções de seções publicadas.
- Variáveis `EMPLOYMENT_API_KEY`, `COMEX_API_KEY`, `EMPLOYMENT_API_BASE_URL`, `COMEX_API_BASE_URL`,
  `PORTAL_EMPREGO_BASE_URL`, `PORTAL_EMPREGO_AMBIENTE`, `API_TIMEOUT`: use as `SDIC_*`.

### Removido
- `SDIC_VERSION` e `LOG_LEVEL` (não são mais lidas). Instaladores `setup.py` (raiz), `python/setup.py`,
  `python/install.py`, `python/install_github.py`: instale com `pip` e `remotes` (ver INSTALL.md).

## [0.5.4] — 2026-11-10

Necessária para a sdic_api 4.0.0. As versões anteriores param de funcionar quando a 4.0.0 entrar no ar.

### Corrigido
- Comex: os métodos usam os nomes de rota da sdic_api 4.0.0, que tirou o sufixo `_gcloud`
  (`/exportacao_isic_divisao`, `/importacao_isic_divisao`, `/exportacao_uf_isic_divisao`,
  `/importacao_uf_isic_divisao`, `/exportacao_pais`, `/importacao_pais`, `/ncm_isic_mapa`).
- `get_date_bases`: a sdic_api 4.0.0 não tem mais `/data_bases`. A função continua com o mesmo retorno
  (`Base`, `DataUltimaAtualizacao`) e agora lê o período mais recente da 1ª linha de uma rota de cada
  base (3 chamadas pequenas). ComexStat e CAGED: 1º dia do último mês; RAIS: 31/12 do último ano.
  Uma base que falhar fica de fora, com aviso.

### Compatibilidade
- Nenhuma mudança de função, parâmetro ou coluna. A sdic_api 4.0.0 também passa a exigir chave
  individual: grave-a em `COMEX_API_KEY` e `EMPLOYMENT_API_KEY`.

## [0.5.3] — 2026-10-15

### Corrigido
- Comex: `ncm` (e `divisao_isic_cod`) nulo continua nulo no DataFrame/tibble. Em
  `get_exportacao_agrupamentos_pais_ncm`/`get_importacao_agrupamentos_pais_ncm` com
  `nivel_agregacao='setor'|'subsetor'|'produto'`, a sdic_api não devolve NCM, e a coluna vinha com
  lixo: `"0000None"` em Python e `"      NA"` em R. Agora vem `None`/`NA`.

### Compatibilidade
- Nenhuma mudança de função, parâmetro ou coluna nas funções que devolvem DataFrame/tibble.
- A partir da próxima versão da sdic_api, `NCM` passa a vir como **texto de 8 dígitos** (`"02011000"`) também
  em `/exportacao_agrupamentos_pais_ncm`, `/importacao_agrupamentos_pais_ncm` e
  `/importacoes_detalhadas_pais_ncm`. Antes vinha como número, e os capítulos 01 a 09 perdiam o zero à esquerda. As funções
  que devolvem DataFrame/tibble já entregavam `ncm` como texto e não mudam. Quem usa os métodos crus da classe
  `Comex` (Python, `List[Dict]`) passa a receber `item['NCM']` como `str`, não `int`.

## [0.5.2] — 2026-10-09

### Corrigido
- Mensagens de erro: quando a sdic_api recusa um parâmetro (HTTP 400/422), a biblioteca agora mostra
  a explicação da API em vez de "Erro temporário no serviço". Ex.: `data_minima='2025-01'` →
  `Parâmetros inválidos: data_minima: '2025-01' inválida; use o formato AAAA-MM-DD (ex.: 2026-08-01 …)`.
  Em R, a mensagem passa a ser `HTTP 422: <explicação da API>`.
- Python: o código HTTP do erro se perdia (um `requests.Response` de erro é falso em `if`), e toda
  falha virava a mensagem genérica. Agora 500 → "em manutenção", 401/403 → autenticação, como
  pretendido. Erros 5xx continuam sem expor detalhes internos.

### Compatibilidade
- Nenhuma mudança de função, parâmetro ou coluna. Só o texto das exceções (`EmpregoAPIError`/`ComexAPIError`
  em Python; o erro de `stop()` em R) muda — código que compara a mensagem exata precisa ser revisto.
- A sdic_api 3.1.0 (em produção desde 09/10/2026) aceita UF por sigla, nome ou código IBGE em todos os
  parâmetros de estado (`estado=`, `uf=`, `siglas_uf=`) e responde 422 a datas do CAGED fora do formato
  `AAAA-MM-DD`; as funções da biblioteca já repassam esses valores sem alteração.

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
