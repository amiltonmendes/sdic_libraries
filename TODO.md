# TODO

Backlog de tarefas deixadas para o futuro — leitura obrigatória para agentes (Codex, Claude,
outros) antes de começar uma tarefa nova neste repositório, para não redescobrir o que já foi
investigado. Ver [AGENTS.md](AGENTS.md) para as regras gerais; aqui é só a fila de trabalho.

Cada item tem: o que falta, o que já foi verificado (pra não repetir a investigação) e o que
"pronto" significa. Ao concluir um item, mova pra baixo do `---` final com a data, ou apague se
não valer a pena manter o histórico.

## Comex: endpoints de "agrupamentos" — SQL executado, falta o deploy da sdic_api

**Estado: script SQL executado com sucesso contra `fast-sdic` em 2026-09-30 (ver item 1). Código
de sdic_api e sdic_libraries pronto e testado, nada commitado ainda. Falta o deploy da sdic_api
(item 2) e, junto com ele, decidir o que fazer com a lacuna de dados residual descoberta na
verificação pós-execução (ver "Achado novo" abaixo do item 1) — não é bloqueante para o deploy,
mas afeta a cobertura de produtos de alguns agrupamentos.**

### O que já foi feito

1. **Script SQL — EXECUTADO em 2026-09-30** contra `fast-sdic`
   ([`sdic_api/scripts/sql/reconstruir_views_agrupamentos_comex.sql`](../sdic_api/scripts/sql/reconstruir_views_agrupamentos_comex.sql),
   histórico completo da investigação no cabeçalho do próprio script). As 4 views (`exportacao_agrupamentos`,
   `importacao_agrupamentos`, `exportacao_agrupamentos_pais_ncm`, `importacao_agrupamentos_pais_ncm`)
   foram recriadas com `DEP_RESP`/`CG_RESP` e a normalização de `SHNCM` (remove pontos, `LPAD` a 8
   dígitos quando sobram 7 puros, e herda o `LPAD(CAST(ncm.CO_NCM AS STRING), 8, '0')` que já estava
   na view ao vivo desde 2026-09-29 — ver nota de revisão no cabeçalho do script). Antes de rodar,
   conferi que nenhuma das 4 views tinha mudado desde a última checagem (comparação de
   `lastModifiedTime`) e salvei as definições anteriores em `/tmp/.../scratchpad/rollback_views/`
   (fora do repo, válido só nesta sessão) para rollback manual se precisar.

   **Verificação pós-execução (2026-09-30):**
   - `DEP_RESP IS NULL`: 0 em todas as 4 views — ok.
   - Todo `AGRUPAMENTO` não nulo de `parametros_unidade` aparece em pelo menos uma das 2
     materialized views — ok (a lista de 6 agrupamentos "ausentes" documentada antes de rodar —
     "Café", "Pescados" etc. — usava nomes/capitalização que não existem na tabela; o texto real é
     `"CAFÉ"`, `"ANIMAIS VIVOS (EXCETO PESCADOS)"`, `"PESCADOS"` etc. Provavelmente um erro de
     transcrição anterior à compactação desta conversa — corrigido aqui).
   - **Achado (número real, maior que o documentado antes de rodar):** logo após a execução,
     16.390 de 16.425 linhas resolviam (99,8%) — **35 sem match**, não as "4" documentadas antes.

   **Ajuste manual no banco feito por você em seguida (confirmado 2026-09-30, mesmo dia):**
   `parametros_unidade` foi editada fora deste fluxo (16.425 → 16.364 linhas, -61) — refresh
   automático das materialized views já picked up a mudança (refresh watermark poucos minutos
   depois). Reconferido após o ajuste:
   - As 2 linhas com `AGRUPAMENTO IS NULL` foram removidas.
   - Os 3 casos de "Moda" (`"5602.2"`, `"5603.9"`, `"5603.1"`) foram **apagados**, não substituídos
     por códigos válidos — não sobrou nenhum SHNCM começando em `5602`/`5603` pra esse agrupamento;
     se isso tirou produtos que deveriam existir em "Moda", só quem mexeu no banco sabe dizer.
   - As outras ~58 linhas removidas não tinham relação com a lista de 35 residuais — eram linhas
     que já casavam certo antes (`resolvidas` caiu de 16.390 para 16.332 também). Não sei o motivo
     dessa limpeza; não é algo que dá pra inferir só olhando o resultado.
   - **Residual atual: 32 linhas sem match** (era 35): Saúde (11), Automotivo (8), Liprode (7, a
     maioria com o valor sentinela `"99999999"`), Linha Amarela (2), "8549 - Desperdícios..." (1),
     PESCADOS (1: `"0307490"` — o código real é `"03074900"`, zero **depois**, não antes; a
     heurística de `LPAD` à esquerda não cobre esse caso), Produtos de Higiene Pessoal e Cosméticos
     (1: `"42021"`), "Regra de Tributação do Mercosul" (1: `"440714"`, SH6 que não existe em
     `ncm-sh`). Continuam sendo, na maioria, códigos que não existem em `ncm`/`ncm-sh` sob nenhuma
     leitura plausível — defeito de cadastro, não corrigível por normalização de string. Nenhuma
     alteração adicional foi feita nas views ou na produção além do que já estava documentado.
2. **sdic_api** (`api/models/comex.py`, `api/schemas/comex_gcloud.py`, `api/cruds/comex_gcloud.py`,
   `api/routers/comex_gcloud.py`): `Departamento`/`CoordenacaoGeral` nos 4 endpoints de
   agrupamentos (sempre no retorno); parâmetros `departamento=`/`cg=` opcionais nos 4; endpoint
   novo `GET /agrupamentos_disponiveis` (lista `parametros_unidade` por Agrupamento/Departamento/CG,
   com os mesmos filtros) — resolve a descoberta de nomes válidos que bloqueava este item antes.
   De brinde: a query crua de `/exportacao_agrupamentos`/`/importacao_agrupamentos` usava
   `markupsafe.escape` (HTML, não SQL) como proteção contra injeção — trocado por parâmetro
   nomeado do BigQuery (`bigquery.ScalarQueryParameter`) já que a função estava sendo mexida.
   74/74 testes passando (`tests/test_comex_gcloud_schemas.py`, `tests/test_main.py`,
   `tests/test_comex_gcloud_agrupamentos.py` — mock de `bigquery.Client`, confirma que o valor de
   `agrupamento` nunca é concatenado na string da query).
3. **sdic_libraries**: 5 funções novas (Python: `python/sdic_libraries/dados/comex/api.py`; R:
   `r/R/comex.R`) — `get_exportacao_agrupamentos`, `get_importacao_agrupamentos`,
   `get_exportacao_agrupamentos_pais_ncm`, `get_importacao_agrupamentos_pais_ncm`,
   `get_agrupamentos_disponiveis` — mesmo padrão dos outros 9 endpoints de comex (`_para_df`/
   `.comex_para_tibble`, `departamento`/`coordenacao_geral` sempre nas colunas de saída). Testadas
   com HTTP mockado (`test_comex_agrupamentos.py`, `test-comex-agrupamentos.R`) e contrato
   (`contrato/comex_amostras.json`, casos marcados `"pendente_deploy": true` — amostra escrita à
   mão, não capturada, porque a API ainda não existe em produção). Suítes completas: Python
   81/81 (21 pulados, API local), R 326/326 (20 pulados).

### Falta fazer (ação humana, fora do que um agente deve decidir sozinho)

1. **Deploy da sdic_api** (Cloud Run) com o código deste item — deploy é de quem opera a nuvem,
   não algo que um agente faz sozinho (ver AGENTS.md, seção Deploy).
2. **Decidir o que fazer com os 32 casos residuais de `parametros_unidade`** sem `CO_NCM`/`CO_SH`
   correspondente (ver item 1 de "O que já foi feito" acima para a lista atualizada por
   agrupamento — Saúde, Automotivo, Liprode, Linha Amarela, PESCADOS, Produtos de Higiene, Regra de
   Tributação). Não bloqueia o deploy — as views já estão no ar e cobrem 99,8% dos casos — mas
   alguém que conheça a fonte de `parametros_unidade` precisa decidir: os 8 códigos de "Automotivo"
   e 11 de "Saúde" são NCM obsoletos/errados (corrigir na fonte)? O `"99999999"` de "Liprode" é
   proposital (significa "todos os produtos"; nesse caso a view precisaria tratar esse valor à
   parte, não como um NCM) ou erro de digitação? Isso é decisão de dono de dado, não de query.
3. **Depois de 1 no ar:**
   - Trocar as amostras `"pendente_deploy": true` de `contrato/comex_amostras.json` por uma
     captura real (mesmo processo já usado pros outros 9 endpoints — GET direto, conferir tipos).
   - Só então adicionar as 5 funções a `python/sdic_libraries/catalogo.py`/`r/R/catalogo.R`
     (`tema="comex"`, `subtema="comercio_agrupamentos"`) e rodar
     `python scripts/gerar_catalogo_md.py` — de propósito deixado de fora até aqui: o catálogo
     existe pra listar o que **funciona hoje**, e antes do deploy essas funções dão erro contra a
     sdic_api de produção.
   - Exemplo no README usando `get_agrupamentos_disponiveis()` pra descobrir o nome antes de
     chamar as outras 4 — nunca um nome mágico sem explicar de onde veio.

---

*(itens concluídos vão aqui, com a data)*
