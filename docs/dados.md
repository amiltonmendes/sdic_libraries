# Dados consultados

<!-- Gerado por scripts/documentar.py a partir de contrato/catalogo.json. Não edite à mão. -->

De onde vem cada número que a biblioteca devolve. As bases pelo lado da carga (tabelas do BigQuery, janelas de atualização, estado de cada carga) estão em [Bases](/docs/bases) e no painel de cargas; aqui fica o lado da leitura.

## Origens

Três endereços, cada um com uma variável de ambiente para trocá-lo. `sdic_config()` mostra o que está em uso.

| Origem | O que é | Endereço padrão | Variável |
|---|---|---|---|
| `api` | sdic_api (BigQuery), com chave individual | https://sdicapi.dados.ninja | `SDIC_API_URL` |
| `dados` | JSON publicados pelo job publicar-dados (carga_base/publicacao) | https://storage.googleapis.com/fast-sdic-dados | `SDIC_DADOS_URL` |
| `politicas` | JSON das políticas publicados pelo gaia_nib | https://amiltonmendes.github.io/sdic_libraries | `SDIC_PAGES_URL` |

## Bases

<a id="rais"></a>

### Estoque de emprego formal (RAIS) (`rais`)

|  |  |
|---|---|
| Origem | `api` |
| Fonte | MTE, RAIS |
| Atualização | anual (carga manual) |
| No BigQuery | `mte_rais` |
| Documentação da base | `carga_base/docs/BASES.md` |
| Funções que leem | `get_estoque_emprego_nacional`, `get_estoque_emprego_estadual`, `get_estoque_emprego_nacional_agrupado`, `get_estoque_emprego_estadual_agrupado`, `get_estoque_emprego_porte_nacional`, `get_estoque_emprego_porte_estadual`, `get_estoque_emprego_classe_cnae_nacional`, `get_estoque_emprego_classe_cnae_estadual`, `get_estoque_emprego_uf_cbo`, `get_renda_media_emprego`, `get_potec_emprego` |

<a id="caged"></a>

### Saldo de emprego formal (Novo CAGED) (`caged`)

|  |  |
|---|---|
| Origem | `api` |
| Fonte | MTE, Novo CAGED |
| Atualização | mensal |
| No BigQuery | `mte_caged` |
| Carga (painel de cargas) | `caged` |
| Documentação da base | `carga_base/caged/DOCUMENTACAO.md` |
| Funções que leem | `get_saldo_emprego_nacional_mensal`, `get_saldo_emprego_nacional_anual`, `get_saldo_emprego_nacional_mensal_agrupado`, `get_saldo_emprego_estadual_mensal`, `get_saldo_emprego_estadual_anual`, `get_saldo_emprego_estadual_mensal_agrupado`, `get_saldo_emprego_municipal_mensal`, `get_saldo_emprego_municipal_anual`, `get_saldo_emprego_municipal_mensal_agrupado` |

<a id="rais_caged"></a>

### Estoque estimado (RAIS + saldo do CAGED) (`rais_caged`)

|  |  |
|---|---|
| Origem | `api` |
| Fonte | MTE, RAIS e Novo CAGED; estimativa da biblioteca |
| Atualização | mensal |
| No BigQuery | `mte_rais, mte_caged` |
| Carga (painel de cargas) | `caged` |
| Documentação da base | `METODOLOGIA.md` |
| Funções que leem | `get_estoque_emprego_estimado_nacional_anual`, `get_estoque_emprego_estimado_estadual_anual`, `get_estoque_emprego_estimado_municipal_anual` |

<a id="comexstat"></a>

### Comércio exterior (ComexStat) (`comexstat`)

|  |  |
|---|---|
| Origem | `api` |
| Fonte | MDIC/Secex, ComexStat |
| Atualização | mensal |
| No BigQuery | `secex_comexstat` |
| Carga (painel de cargas) | `comex` |
| Documentação da base | `carga_base/comex/DOCUMENTACAO.md` |
| Funções que leem | `get_exportacao_ncm_nacional_mensal`, `get_importacao_ncm_nacional_mensal`, `get_exportacao_isic_divisao_nacional_mensal`, `get_importacao_isic_divisao_nacional_mensal`, `get_exportacao_isic_divisao_estadual_mensal`, `get_importacao_isic_divisao_estadual_mensal`, `get_exportacao_pais_nacional_mensal`, `get_importacao_pais_nacional_mensal`, `get_ncm_isic_mapa`, `get_agrupamentos_disponiveis`, `get_exportacao_agrupamentos`, `get_importacao_agrupamentos`, `get_exportacao_agrupamentos_pais_ncm`, `get_importacao_agrupamentos_pais_ncm` |

<a id="atualizacao"></a>

### Período mais recente de cada base (`atualizacao`)

|  |  |
|---|---|
| Origem | `api` |
| Fonte | sdic_api |
| Atualização | a cada carga |
| Documentação da base | `METODOLOGIA.md` |
| Funções que leem | `get_date_bases` |

<a id="series"></a>

### Séries da sdic_api (/series) (`series`)

|  |  |
|---|---|
| Origem | `api`, caminho `/series/{nome}` |
| Fonte | IBGE (SIDRA, Contas Regionais), MDIC (ComexStat) e indicadores oficiais; a lista atual vem de listar_series() |
| Atualização | conforme a série |
| No BigQuery | `ibge_sidra_producao, ibge_sidra_pib, ibge_contas_regionais, secex_comexstat` |
| Carga (painel de cargas) | `sidra_producao, sidra_pib, contas_regionais, comex` |
| Documentação da base | `carga_base/docs/BASES.md` |
| Funções que leem | `listar_series`, `get_serie`, `get_dimensao_serie` |

<a id="secoes_publicadas"></a>

### Seções publicadas (JSON do portal e dos subsídios) (`secoes_publicadas`)

|  |  |
|---|---|
| Origem | `dados`, caminho `{ambiente}/{uf}/{arquivo}.json` |
| Fonte | carga_base/publicacao (job publicar-dados), a partir do BigQuery |
| Atualização | a cada carga publicada |
| No BigQuery | `visões portal_* e cache_*` |
| Carga (painel de cargas) | `comex, caged, sidra_producao, sidra_pib, contas_regionais` |
| Esquema | contrato v1.1 (schema_version) |
| Documentação da base | `carga_base/publicacao/publicar/README.md` |
| Funções que leem | `listar_secoes_publicadas`, `get_kpis_publicados`, `get_series_publicadas`, `get_ranking_publicado`, `get_detalhamento_publicado`, `get_destaques_publicados`, `get_secao_publicada`, `get_atualizacao_publicada` |

<a id="politicas"></a>

### Políticas da SDIC (`politicas`)

|  |  |
|---|---|
| Origem | `politicas`, caminho `{ambiente}/{uf\|nacional}/politicas/{id}.json` |
| Fonte | gaia_nib/politicas_sdic |
| Atualização | a cada publicação do gaia_nib |
| Documentação da base | `gaia_nib/politicas_sdic/PUBLICACAO.md` |
| Funções que leem | `listar_politicas`, `get_politica`, `get_politicas_estado`, `get_resumo_politicas`, `get_municipios_elegiveis`, `get_manifesto_politicas`, `get_politica_publicada` |

<a id="emprego_portal_antigo"></a>

### Cache de emprego no layout antigo do Pages (`emprego_portal_antigo`)

**Depreciada.** Use get_kpis_publicados(uf, 'emprego') e as demais funções de seções publicadas.

|  |  |
|---|---|
| Origem | `politicas`, caminho `{ambiente}/cache/{uf}/emprego_cache.json` |
| Fonte | cgid_cargas (desligado) |
| Atualização | não atualiza mais |
| Funções que leem | `get_relatorio_emprego_saldo_estadual`, `get_relatorio_emprego_estoque_estadual` |

<a id="referencias"></a>

### Tabelas de de-para (CNAE, ISIC, municípios, intensidade tecnológica, agrupamentos NCM) (`referencias`)

|  |  |
|---|---|
| Origem | `api`, caminho `/referencias/{nome}` |
| Fonte | carga_base/referencias (CSVs versionados) |
| Atualização | quando um mapeamento muda |
| No BigQuery | `referencias` |
| Documentação da base | `carga_base/docs/MAPEAMENTOS.md` |
| Funções que leem | `listar_referencias`, `get_referencia` |

## Seções publicadas

Arquivos `{ambiente}/{UF ou BRASIL}/{seção}.json`, no contrato v1.1, os mesmos que o portal e os subsídios leem.

| Seção | Título | Existe para | Fonte |
|---|---|---|---|
| `emprego` | Emprego | UF e BRASIL | Novo CAGED e RAIS (MTE) |
| `pib_estadual` | PIB estadual | UF e BRASIL | IBGE, Contas Regionais e SIDRA |
| `comercio` | Comércio exterior | UF e BRASIL | MDIC, ComexStat |
| `comercio_ue` | Comércio exterior com a União Europeia | UF e BRASIL | MDIC, ComexStat |
| `producao_industrial` | Produção industrial | UF e BRASIL | IBGE, PIM-PF e PIA |
| `pib_nacional` | PIB nacional | BRASIL | IBGE, Contas Nacionais |

Cada arquivo também tem a variante `{seção}_relatorio.json`, com os dados detalhados dos relatórios. Ela não tem função própria: leia com `ler_json_publicado("dados", "<ambiente>/<UF>/<seção>_relatorio.json")`.

## Ambientes

`producao` (padrão) e `homologacao`, por `SDIC_AMBIENTE` ou pelo argumento `ambiente`. O ambiente vale para as seções publicadas e para as políticas; a API tem um ambiente só. Um arquivo que não existe no ambiente pedido gera erro `NaoPublicado` com a URL: a função nunca cai em outro ambiente por conta própria.
