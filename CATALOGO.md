# Catálogo de funções

Gerado de `python/sdic_libraries/catalogo.py` + `r/R/catalogo.R` — não edite à mão,
rode `python scripts/gerar_catalogo_md.py`. Mesmo conteúdo de `listar_bases()`
(Python e R), em formato de página. Nível `-` = não se aplica (catálogos estáticos,
utilitários).

## Emprego (RAIS/CAGED)

### estoque

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_estoque_emprego_estadual` | estadual | Igual ao nacional, por UF. | Python: `get_estoque_emprego_estadual(uf='SP', codigos_cnae=['10'])`<br>R: `get_estoque_emprego_estadual(sigla_uf = 'SP', codigos_cnae = '10')` |
| `get_estoque_emprego_estadual_agrupado` | estadual | Igual ao agrupado nacional, por UF. | Python: `get_estoque_emprego_estadual_agrupado(sigla_uf='SP', nome_grupo='TI', lista_cnae=['620'])`<br>R: `get_estoque_emprego_estadual_agrupado(sigla_uf = 'SP', nome_grupo = 'TI', lista_cnae = '620')` |
| `get_estoque_emprego_nacional` | nacional | Estoque de vínculos ativos (31/12) por divisão ou grupo CNAE. | Python: `get_estoque_emprego_nacional(codigos_cnae=['10'], nivel_cnae=2)`<br>R: `get_estoque_emprego_nacional(codigos_cnae = '10', nivel_cnae = 2)` |
| `get_estoque_emprego_nacional_agrupado` | nacional | Estoque somado para uma lista de CNAEs sob um nome de grupo (ex.: 'TI'). | Python: `get_estoque_emprego_nacional_agrupado('TI', ['620', '631'])`<br>R: `get_estoque_emprego_nacional_agrupado('TI', c('620', '631'))` |

### estoque_classe

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_estoque_emprego_classe_cnae_estadual` | estadual | Igual ao classe nacional, por UF. | Python: `get_estoque_emprego_classe_cnae_estadual(uf='SP', codigos_classe=['1011'])`<br>R: `get_estoque_emprego_classe_cnae_estadual(uf = 'SP', codigos_classe = '1011')` |
| `get_estoque_emprego_classe_cnae_nacional` | nacional | Estoque por classe CNAE (4 dígitos, mais fino que divisão/grupo). | Python: `get_estoque_emprego_classe_cnae_nacional(codigos_classe=['1011'])`<br>R: `get_estoque_emprego_classe_cnae_nacional(codigos_classe = '1011')` |

### estoque_estimado

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_estoque_emprego_estimado_estadual_anual` | estadual | Igual ao estimado nacional, por UF. | Python: `get_estoque_emprego_estimado_estadual_anual(sigla_uf='SP', codigo_cnae='10')`<br>R: `get_estoque_emprego_estimado_estadual_anual(sigla_uf = 'SP', codigo_cnae = '10')` |
| `get_estoque_emprego_estimado_municipal_anual` | municipal | Igual ao estimado nacional, por município. | Python: `get_estoque_emprego_estimado_municipal_anual(sigla_uf='SP', codigo_municipio=3550308, codigo_cnae='10')`<br>R: `get_estoque_emprego_estimado_municipal_anual(sigla_uf = 'SP', codigo_municipio = 3550308, codigo_cnae = '10')` |
| `get_estoque_emprego_estimado_nacional_anual` | nacional | Estoque real (RAIS) + projeção com o saldo CAGED acumulado até o ano corrente (coluna 'origem': Real/Estimação). | Python: `get_estoque_emprego_estimado_nacional_anual(codigo_cnae='10')`<br>R: `get_estoque_emprego_estimado_nacional_anual(codigo_cnae = '10')` |

### estoque_ocupacao

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_estoque_emprego_uf_cbo` | estadual | Estoque por UF, classe CNAE e ocupação (CBO). Endpoint pesado: sempre filtre siglas_uf e codigos_classe. | Python: `get_estoque_emprego_uf_cbo(siglas_uf=['SP'], codigos_classe=['4711'])`<br>R: `get_estoque_emprego_uf_cbo(siglas_uf = 'SP', codigos_classe = '4711')` |

### estoque_porte

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_estoque_emprego_porte_estadual` | estadual | Igual ao porte nacional, por UF. | Python: `get_estoque_emprego_porte_estadual(uf='SP', nivel_cnae='divisao', porte=['Microempresa'])`<br>R: `get_estoque_emprego_porte_estadual(uf = 'SP', nivel_cnae = 'divisao', porte = 'Microempresa')` |
| `get_estoque_emprego_porte_nacional` | nacional | Estoque por porte do estabelecimento (Sebrae/DIEESE) e setor (Indústria x Comércio/Serviços). | Python: `get_estoque_emprego_porte_nacional('divisao', codigos_cnae=['10'], setor='Indústria')`<br>R: `get_estoque_emprego_porte_nacional('divisao', codigos_cnae = '10', setor = 'Indústria')` |

### metadados

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_date_bases` | - | Data da última atualização de cada base (CAGED, RAIS, ComexStat). | Python: `get_date_bases()`<br>R: `get_date_bases()` |

### portal_cache

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_relatorio_emprego_estoque_estadual` | estadual | Estoque RAIS por UF, lido do cache já publicado — não chama a API ao vivo. | Python: `get_relatorio_emprego_estoque_estadual(uf='SP')`<br>R: `get_relatorio_emprego_estoque_estadual(uf = 'SP')` |
| `get_relatorio_emprego_saldo_estadual` | estadual | Saldo CAGED mensal por UF, lido do cache já publicado (GitHub Pages) — não chama a API ao vivo. | Python: `get_relatorio_emprego_saldo_estadual(uf='SP')`<br>R: `get_relatorio_emprego_saldo_estadual(uf = 'SP')` |

### potec

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_potec_emprego` | nacional | Índice Potec: fração de pessoal ocupado técnico-científico por classe CNAE (proxy de P&D da PINTEC). | Python: `get_potec_emprego(codigos_classe=['7210'])`<br>R: `get_potec_emprego(codigos_classe = '7210')` |

### renda

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_renda_media_emprego` | nacional | Remuneração média (RAIS) por divisão/grupo CNAE ou geral. | Python: `get_renda_media_emprego(tipos=['Divisao'], codigos=['10'])`<br>R: `get_renda_media_emprego(tipos = 'Divisao', codigos = '10')` |

### saldo_caged

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_saldo_emprego_estadual_anual` | estadual | Igual ao saldo anual nacional, por UF. | Python: `get_saldo_emprego_estadual_anual(sigla_uf='SP', nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_estadual_anual(sigla_uf = 'SP', nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_estadual_mensal` | estadual | Igual ao saldo mensal nacional, por UF. | Python: `get_saldo_emprego_estadual_mensal(sigla_uf='SP', nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_estadual_mensal(sigla_uf = 'SP', nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_estadual_mensal_agrupado` | estadual | Igual ao saldo agrupado nacional, por UF. | Python: `get_saldo_emprego_estadual_mensal_agrupado(sigla_uf='SP', nome_grupo='TI', lista_cnae=['620'])`<br>R: `get_saldo_emprego_estadual_mensal_agrupado(sigla_uf = 'SP', nome_grupo = 'TI', lista_cnae = '620')` |
| `get_saldo_emprego_municipal_anual` | municipal | Igual ao saldo anual nacional, por município. | Python: `get_saldo_emprego_municipal_anual(sigla_uf='SP', codigo_municipio=3550308, nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_municipal_anual(sigla_uf = 'SP', codigo_municipio = 3550308, nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_municipal_mensal` | municipal | Igual ao saldo mensal nacional, por município. | Python: `get_saldo_emprego_municipal_mensal(sigla_uf='SP', codigo_municipio=3550308, nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_municipal_mensal(sigla_uf = 'SP', codigo_municipio = 3550308, nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_municipal_mensal_agrupado` | municipal | Igual ao saldo agrupado nacional, por município. | Python: `get_saldo_emprego_municipal_mensal_agrupado(sigla_uf='SP', codigo_municipio=3550308, nome_grupo='TI', lista_cnae=['620'])`<br>R: `get_saldo_emprego_municipal_mensal_agrupado(sigla_uf = 'SP', codigo_municipio = 3550308, nome_grupo = 'TI', lista_cnae = '620')` |
| `get_saldo_emprego_nacional_anual` | nacional | Saldo somado por ano, mesmo recorte do mensal. | Python: `get_saldo_emprego_nacional_anual(nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_nacional_anual(nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_nacional_mensal` | nacional | Saldo mensal (admissões − desligamentos) por divisão/grupo/subclasse CNAE. | Python: `get_saldo_emprego_nacional_mensal(nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_nacional_mensal(nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_nacional_mensal_agrupado` | nacional | Saldo mensal somado para uma lista de CNAEs sob um nome de grupo. | Python: `get_saldo_emprego_nacional_mensal_agrupado('TI', ['620', '631'])`<br>R: `get_saldo_emprego_nacional_mensal_agrupado('TI', c('620', '631'))` |

## Comércio exterior

### comercio_isic

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_exportacao_isic_divisao_estadual_mensal` | estadual | Igual ao ISIC nacional, por UF (e opcionalmente por país/bloco). | Python: `get_exportacao_isic_divisao_estadual_mensal(estado='São Paulo', ano_minimo=2024)`<br>R: `get_exportacao_isic_divisao_estadual_mensal(estado = 'São Paulo', ano_minimo = 2024)` |
| `get_exportacao_isic_divisao_nacional_mensal` | nacional | Exportações mensais por divisão ISIC (setor) — a chave para juntar com emprego (juntar_emprego_comex). | Python: `get_exportacao_isic_divisao_nacional_mensal(ano_minimo=2024, agregado_ano=True)`<br>R: `get_exportacao_isic_divisao_nacional_mensal(ano_minimo = 2024, agregado_ano = TRUE)` |
| `get_importacao_isic_divisao_estadual_mensal` | estadual | Igual ao ISIC estadual de exportação, para importações. | Python: `get_importacao_isic_divisao_estadual_mensal(estado='São Paulo', ano_minimo=2024)`<br>R: `get_importacao_isic_divisao_estadual_mensal(estado = 'São Paulo', ano_minimo = 2024)` |
| `get_importacao_isic_divisao_nacional_mensal` | nacional | Igual ao ISIC de exportação, para importações. | Python: `get_importacao_isic_divisao_nacional_mensal(ano_minimo=2024, agregado_ano=True)`<br>R: `get_importacao_isic_divisao_nacional_mensal(ano_minimo = 2024, agregado_ano = TRUE)` |

### comercio_mapa

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_ncm_isic_mapa` | - | De-para NCM → divisão/seção ISIC (catálogo estático, ~13 mil códigos). | Python: `get_ncm_isic_mapa()`<br>R: `get_ncm_isic_mapa()` |

### comercio_ncm

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_exportacao_ncm_nacional_mensal` | nacional | Exportações mensais por NCM (produto), com filtro opcional por seção ISIC. | Python: `get_exportacao_ncm_nacional_mensal(ano_minimo=2024, secao='Indústria de Transformação')`<br>R: `get_exportacao_ncm_nacional_mensal(ano_minimo = 2024, secao = 'Indústria de Transformação')` |
| `get_importacao_ncm_nacional_mensal` | nacional | Igual ao NCM de exportação, para importações. | Python: `get_importacao_ncm_nacional_mensal(ano_minimo=2024)`<br>R: `get_importacao_ncm_nacional_mensal(ano_minimo = 2024)` |

### comercio_pais

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `get_exportacao_pais_nacional_mensal` | nacional | Exportações mensais por país de destino. | Python: `get_exportacao_pais_nacional_mensal(pais='Argentina', ano_minimo=2024)`<br>R: `get_exportacao_pais_nacional_mensal(pais = 'Argentina', ano_minimo = 2024)` |
| `get_importacao_pais_nacional_mensal` | nacional | Igual ao país de exportação, para importações (país de origem). | Python: `get_importacao_pais_nacional_mensal(pais='Argentina', ano_minimo=2024)`<br>R: `get_importacao_pais_nacional_mensal(pais = 'Argentina', ano_minimo = 2024)` |

## Utilitários

### transformacao

| Função | Nível | Descrição | Exemplo |
|---|---|---|---|
| `criar_indice` | - | Índice-base (ano_base = 100) para colunas numéricas de uma série temporal. | Python: `criar_indice(df, ano_base=2020, coluna_data='ano', colunas_valores=['estoque_trabalhadores'])`<br>R: `criar_indice(df, ano_base = 2020, coluna_data = 'ano', colunas_valores = 'estoque_trabalhadores')` |
| `juntar_emprego_comex` | - | Une emprego e comércio exterior por divisão CNAE/ISIC e ano. | Python: `juntar_emprego_comex(df_emprego, df_comex)`<br>R: `juntar_emprego_comex(df_emprego, df_comex)` |

