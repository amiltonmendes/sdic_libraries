# Catálogo de funções

<!-- Gerado por scripts/documentar.py a partir de contrato/catalogo.json. Não edite à mão. -->

Mesmo conteúdo de `listar_bases()` (Python e R). Detalhe de cada função: [docs/referencia.md](docs/referencia.md); de onde vem cada dado: [docs/dados.md](docs/dados.md). Nível `-` = não se aplica.

## Emprego (RAIS e Novo CAGED)

| Função | Subtema | Nível | Descrição | Exemplo |
|---|---|---|---|---|
| `get_estoque_emprego_nacional` | estoque | nacional | Estoque de vínculos ativos (31/12) por divisão ou grupo CNAE. | Python: `get_estoque_emprego_nacional(codigos_cnae=['10'], nivel_cnae=2)`<br>R: `get_estoque_emprego_nacional(codigos_cnae = '10', nivel_cnae = 2)` |
| `get_estoque_emprego_estadual` | estoque | estadual | Igual ao nacional, por UF. | Python: `get_estoque_emprego_estadual(uf='SP', codigos_cnae=['10'])`<br>R: `get_estoque_emprego_estadual(sigla_uf = 'SP', codigos_cnae = '10')` |
| `get_estoque_emprego_nacional_agrupado` | estoque | nacional | Estoque somado para uma lista de CNAEs sob um nome de grupo (ex.: 'TI'). | Python: `get_estoque_emprego_nacional_agrupado('TI', ['620', '631'])`<br>R: `get_estoque_emprego_nacional_agrupado('TI', c('620', '631'))` |
| `get_estoque_emprego_estadual_agrupado` | estoque | estadual | Igual ao agrupado nacional, por UF. | Python: `get_estoque_emprego_estadual_agrupado(sigla_uf='SP', nome_grupo='TI', lista_cnae=['620'])`<br>R: `get_estoque_emprego_estadual_agrupado(sigla_uf = 'SP', nome_grupo = 'TI', lista_cnae = '620')` |
| `get_estoque_emprego_estimado_nacional_anual` | estoque_estimado | nacional | Estoque real (RAIS) + projeção com o saldo CAGED acumulado até o ano corrente (coluna 'origem': Real/Estimação). | Python: `get_estoque_emprego_estimado_nacional_anual(codigo_cnae='10')`<br>R: `get_estoque_emprego_estimado_nacional_anual(codigo_cnae = '10')` |
| `get_estoque_emprego_estimado_estadual_anual` | estoque_estimado | estadual | Igual ao estimado nacional, por UF. | Python: `get_estoque_emprego_estimado_estadual_anual(sigla_uf='SP', codigo_cnae='10')`<br>R: `get_estoque_emprego_estimado_estadual_anual(sigla_uf = 'SP', codigo_cnae = '10')` |
| `get_estoque_emprego_estimado_municipal_anual` | estoque_estimado | municipal | Igual ao estimado nacional, por município. | Python: `get_estoque_emprego_estimado_municipal_anual(sigla_uf='SP', codigo_municipio=3550308, codigo_cnae='10')`<br>R: `get_estoque_emprego_estimado_municipal_anual(sigla_uf = 'SP', codigo_municipio = 3550308, codigo_cnae = '10')` |
| `get_estoque_emprego_porte_nacional` | estoque_porte | nacional | Estoque por porte do estabelecimento (Sebrae/DIEESE) e setor (Indústria x Comércio/Serviços). | Python: `get_estoque_emprego_porte_nacional('divisao', codigos_cnae=['10'], setor='Indústria')`<br>R: `get_estoque_emprego_porte_nacional('divisao', codigos_cnae = '10', setor = 'Indústria')` |
| `get_estoque_emprego_porte_estadual` | estoque_porte | estadual | Igual ao porte nacional, por UF. | Python: `get_estoque_emprego_porte_estadual(uf='SP', nivel_cnae='divisao', porte=['Microempresa'])`<br>R: `get_estoque_emprego_porte_estadual(uf = 'SP', nivel_cnae = 'divisao', porte = 'Microempresa')` |
| `get_estoque_emprego_classe_cnae_nacional` | estoque_classe | nacional | Estoque por classe CNAE (4 dígitos, mais fino que divisão/grupo). | Python: `get_estoque_emprego_classe_cnae_nacional(codigos_classe=['1011'])`<br>R: `get_estoque_emprego_classe_cnae_nacional(codigos_classe = '1011')` |
| `get_estoque_emprego_classe_cnae_estadual` | estoque_classe | estadual | Igual ao classe nacional, por UF. | Python: `get_estoque_emprego_classe_cnae_estadual(uf='SP', codigos_classe=['1011'])`<br>R: `get_estoque_emprego_classe_cnae_estadual(uf = 'SP', codigos_classe = '1011')` |
| `get_estoque_emprego_uf_cbo` | estoque_ocupacao | estadual | Estoque por UF, classe CNAE e ocupação (CBO). Endpoint pesado: sempre filtre siglas_uf e codigos_classe. | Python: `get_estoque_emprego_uf_cbo(siglas_uf=['SP'], codigos_classe=['4711'])`<br>R: `get_estoque_emprego_uf_cbo(siglas_uf = 'SP', codigos_classe = '4711')` |
| `get_renda_media_emprego` | renda | nacional | Remuneração média (RAIS) por divisão/grupo CNAE ou geral. | Python: `get_renda_media_emprego(tipos=['Divisao'], codigos=['10'])`<br>R: `get_renda_media_emprego(tipos = 'Divisao', codigos = '10')` |
| `get_potec_emprego` | potec | nacional | Índice Potec: fração de pessoal ocupado técnico-científico por classe CNAE (proxy de P&D da PINTEC). | Python: `get_potec_emprego(codigos_classe=['7210'])`<br>R: `get_potec_emprego(codigos_classe = '7210')` |
| `get_date_bases` | metadados | - | Data da última atualização de cada base (CAGED, RAIS, ComexStat). | Python: `get_date_bases()`<br>R: `get_date_bases()` |
| `get_saldo_emprego_nacional_mensal` | saldo_caged | nacional | Saldo mensal (admissões − desligamentos) por divisão/grupo/subclasse CNAE. | Python: `get_saldo_emprego_nacional_mensal(nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_nacional_mensal(nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_nacional_anual` | saldo_caged | nacional | Saldo somado por ano, mesmo recorte do mensal. | Python: `get_saldo_emprego_nacional_anual(nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_nacional_anual(nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_nacional_mensal_agrupado` | saldo_caged | nacional | Saldo mensal somado para uma lista de CNAEs sob um nome de grupo. | Python: `get_saldo_emprego_nacional_mensal_agrupado('TI', ['620', '631'])`<br>R: `get_saldo_emprego_nacional_mensal_agrupado('TI', c('620', '631'))` |
| `get_saldo_emprego_estadual_mensal` | saldo_caged | estadual | Igual ao saldo mensal nacional, por UF. | Python: `get_saldo_emprego_estadual_mensal(sigla_uf='SP', nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_estadual_mensal(sigla_uf = 'SP', nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_estadual_anual` | saldo_caged | estadual | Igual ao saldo anual nacional, por UF. | Python: `get_saldo_emprego_estadual_anual(sigla_uf='SP', nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_estadual_anual(sigla_uf = 'SP', nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_estadual_mensal_agrupado` | saldo_caged | estadual | Igual ao saldo agrupado nacional, por UF. | Python: `get_saldo_emprego_estadual_mensal_agrupado(sigla_uf='SP', nome_grupo='TI', lista_cnae=['620'])`<br>R: `get_saldo_emprego_estadual_mensal_agrupado(sigla_uf = 'SP', nome_grupo = 'TI', lista_cnae = '620')` |
| `get_saldo_emprego_municipal_mensal` | saldo_caged | municipal | Igual ao saldo mensal nacional, por município. | Python: `get_saldo_emprego_municipal_mensal(sigla_uf='SP', codigo_municipio=3550308, nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_municipal_mensal(sigla_uf = 'SP', codigo_municipio = 3550308, nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_municipal_anual` | saldo_caged | municipal | Igual ao saldo anual nacional, por município. | Python: `get_saldo_emprego_municipal_anual(sigla_uf='SP', codigo_municipio=3550308, nivel_cnae='divisao', codigo_cnae='10')`<br>R: `get_saldo_emprego_municipal_anual(sigla_uf = 'SP', codigo_municipio = 3550308, nivel_cnae = 'divisao', codigo_cnae = '10')` |
| `get_saldo_emprego_municipal_mensal_agrupado` | saldo_caged | municipal | Igual ao saldo agrupado nacional, por município. | Python: `get_saldo_emprego_municipal_mensal_agrupado(sigla_uf='SP', codigo_municipio=3550308, nome_grupo='TI', lista_cnae=['620'])`<br>R: `get_saldo_emprego_municipal_mensal_agrupado(sigla_uf = 'SP', codigo_municipio = 3550308, nome_grupo = 'TI', lista_cnae = '620')` |
| `get_relatorio_emprego_saldo_estadual` | portal_cache | estadual | Saldo CAGED mensal por UF, lido do cache já publicado (GitHub Pages) — não chama a API ao vivo. | Python: `get_relatorio_emprego_saldo_estadual(uf='SP')`<br>R: `get_relatorio_emprego_saldo_estadual(uf = 'SP')` |
| `get_relatorio_emprego_estoque_estadual` | portal_cache | estadual | Estoque RAIS por UF, lido do cache já publicado — não chama a API ao vivo. | Python: `get_relatorio_emprego_estoque_estadual(uf='SP')`<br>R: `get_relatorio_emprego_estoque_estadual(uf = 'SP')` |

## Comércio exterior (ComexStat)

| Função | Subtema | Nível | Descrição | Exemplo |
|---|---|---|---|---|
| `get_exportacao_ncm_nacional_mensal` | comercio_ncm | nacional | Exportações mensais por NCM (produto), com filtro opcional por seção ISIC. | Python: `get_exportacao_ncm_nacional_mensal(ano_minimo=2024, secao='Indústria de Transformação')`<br>R: `get_exportacao_ncm_nacional_mensal(ano_minimo = 2024, secao = 'Indústria de Transformação')` |
| `get_importacao_ncm_nacional_mensal` | comercio_ncm | nacional | Igual ao NCM de exportação, para importações. | Python: `get_importacao_ncm_nacional_mensal(ano_minimo=2024)`<br>R: `get_importacao_ncm_nacional_mensal(ano_minimo = 2024)` |
| `get_exportacao_isic_divisao_nacional_mensal` | comercio_isic | nacional | Exportações mensais por divisão ISIC (setor) — a chave para juntar com emprego (juntar_emprego_comex). | Python: `get_exportacao_isic_divisao_nacional_mensal(ano_minimo=2024, agregado_ano=True)`<br>R: `get_exportacao_isic_divisao_nacional_mensal(ano_minimo = 2024, agregado_ano = TRUE)` |
| `get_importacao_isic_divisao_nacional_mensal` | comercio_isic | nacional | Igual ao ISIC de exportação, para importações. | Python: `get_importacao_isic_divisao_nacional_mensal(ano_minimo=2024, agregado_ano=True)`<br>R: `get_importacao_isic_divisao_nacional_mensal(ano_minimo = 2024, agregado_ano = TRUE)` |
| `get_exportacao_isic_divisao_estadual_mensal` | comercio_isic | estadual | Igual ao ISIC nacional, por UF (e opcionalmente por país/bloco). | Python: `get_exportacao_isic_divisao_estadual_mensal(estado='São Paulo', ano_minimo=2024)`<br>R: `get_exportacao_isic_divisao_estadual_mensal(estado = 'São Paulo', ano_minimo = 2024)` |
| `get_importacao_isic_divisao_estadual_mensal` | comercio_isic | estadual | Igual ao ISIC estadual de exportação, para importações. | Python: `get_importacao_isic_divisao_estadual_mensal(estado='São Paulo', ano_minimo=2024)`<br>R: `get_importacao_isic_divisao_estadual_mensal(estado = 'São Paulo', ano_minimo = 2024)` |
| `get_exportacao_pais_nacional_mensal` | comercio_pais | nacional | Exportações mensais por país de destino. | Python: `get_exportacao_pais_nacional_mensal(pais='Argentina', ano_minimo=2024)`<br>R: `get_exportacao_pais_nacional_mensal(pais = 'Argentina', ano_minimo = 2024)` |
| `get_importacao_pais_nacional_mensal` | comercio_pais | nacional | Igual ao país de exportação, para importações (país de origem). | Python: `get_importacao_pais_nacional_mensal(pais='Argentina', ano_minimo=2024)`<br>R: `get_importacao_pais_nacional_mensal(pais = 'Argentina', ano_minimo = 2024)` |
| `get_ncm_isic_mapa` | comercio_mapa | - | De-para NCM → divisão/seção ISIC (catálogo estático, ~13 mil códigos). | Python: `get_ncm_isic_mapa()`<br>R: `get_ncm_isic_mapa()` |
| `get_agrupamentos_disponiveis` | comercio_agrupamentos | nacional | Agrupamentos de NCM da SDIC (nome, departamento e coordenação): use para descobrir o nome a passar em `agrupamento`. | Python: `get_agrupamentos_disponiveis()`<br>R: `get_agrupamentos_disponiveis()` |
| `get_exportacao_agrupamentos` | comercio_agrupamentos | nacional | Exportação mensal de um agrupamento de NCM da SDIC. | Python: `get_exportacao_agrupamentos(agrupamento='Complexo da Saúde', ano_minimo=2024)`<br>R: `get_exportacao_agrupamentos(agrupamento = 'Complexo da Saúde', ano_minimo = 2024)` |
| `get_importacao_agrupamentos` | comercio_agrupamentos | nacional | Importação mensal de um agrupamento de NCM da SDIC. | Python: `get_importacao_agrupamentos(agrupamento='Complexo da Saúde', ano_minimo=2024)`<br>R: `get_importacao_agrupamentos(agrupamento = 'Complexo da Saúde', ano_minimo = 2024)` |
| `get_exportacao_agrupamentos_pais_ncm` | comercio_agrupamentos | nacional | Exportação de um agrupamento por país e NCM, ou somada por setor, subsetor ou produto (`nivel_agregacao`). | Python: `get_exportacao_agrupamentos_pais_ncm(agrupamento='Complexo da Saúde', ano_minimo=2024, nivel_agregacao='setor')`<br>R: `get_exportacao_agrupamentos_pais_ncm(agrupamento = 'Complexo da Saúde', ano_minimo = 2024, nivel_agregacao = 'setor')` |
| `get_importacao_agrupamentos_pais_ncm` | comercio_agrupamentos | nacional | Importação de um agrupamento por país e NCM, ou somada por setor, subsetor ou produto (`nivel_agregacao`). | Python: `get_importacao_agrupamentos_pais_ncm(agrupamento='Complexo da Saúde', ano_minimo=2024, nivel_agregacao='setor')`<br>R: `get_importacao_agrupamentos_pais_ncm(agrupamento = 'Complexo da Saúde', ano_minimo = 2024, nivel_agregacao = 'setor')` |

## Séries da API (bases do carga_base e indicadores)

| Função | Subtema | Nível | Descrição | Exemplo |
|---|---|---|---|---|
| `listar_series` | catalogo | - | Séries que a sdic_api publica em `/series` (bases do carga_base e indicadores oficiais): nome, descrição, fonte, filtros e dimensões. | Python: `listar_series()`<br>R: `listar_series()` |
| `get_serie` | valores | - | Valores de uma série, com filtros pelos nomes das colunas e período (`desde`, `ate`). `com_nomes` junta os nomes das dimensões. | Python: `get_serie('sidra_producao', cod_tabela=8888, cod_localidade='35', desde='2025-01-01')`<br>R: `get_serie('sidra_producao', cod_tabela = 8888, cod_localidade = '35', desde = '2025-01-01')` |
| `get_dimensao_serie` | dimensoes | - | Códigos e nomes de uma dimensão de uma série (variáveis, categorias, localidades, atividades). | Python: `get_dimensao_serie('sidra_producao', 'variavel')`<br>R: `get_dimensao_serie('sidra_producao', 'variavel')` |

## Seções publicadas (JSON do portal)

| Função | Subtema | Nível | Descrição | Exemplo |
|---|---|---|---|---|
| `listar_secoes_publicadas` | catalogo | - | Seções publicadas em JSON (as mesmas do portal) e para quais unidades existem. | Python: `listar_secoes_publicadas()`<br>R: `listar_secoes_publicadas()` |
| `get_kpis_publicados` | secao | estadual | Indicadores de uma seção publicada, um por linha (inclui o indicador de capa), com fonte, referência e data. | Python: `get_kpis_publicados('SP', 'emprego')`<br>R: `get_kpis_publicados('SP', 'emprego')` |
| `get_series_publicadas` | secao | estadual | Séries dos gráficos de uma seção publicada, em formato longo (gráfico, série, período, valor). | Python: `get_series_publicadas('SP', 'emprego')`<br>R: `get_series_publicadas('SP', 'emprego')` |
| `get_ranking_publicado` | secao | estadual | Listas ordenadas de uma seção publicada (ex.: maiores saldos), um item por linha. | Python: `get_ranking_publicado('SP', 'emprego')`<br>R: `get_ranking_publicado('SP', 'emprego')` |
| `get_detalhamento_publicado` | secao | estadual | Composições de uma seção publicada (ex.: por intensidade tecnológica), com valor e participação. | Python: `get_detalhamento_publicado('SP', 'emprego')`<br>R: `get_detalhamento_publicado('SP', 'emprego')` |
| `get_destaques_publicados` | secao | estadual | Título, linha de apoio e destaques do texto de uma seção publicada, com os valores já preenchidos. | Python: `get_destaques_publicados('SP', 'emprego')`<br>R: `get_destaques_publicados('SP', 'emprego')` |
| `get_secao_publicada` | secao | estadual | JSON completo de uma seção publicada (contrato v1.1), como dicionário/lista. Baixo nível: prefira as funções que devolvem tabela. | Python: `get_secao_publicada('SP', 'emprego')`<br>R: `get_secao_publicada('SP', 'emprego')` |
| `get_atualizacao_publicada` | metadados | - | Quando cada carga foi publicada pela última vez nos JSON do ambiente. | Python: `get_atualizacao_publicada()`<br>R: `get_atualizacao_publicada()` |

## Políticas da SDIC (gaia_nib)

| Função | Subtema | Nível | Descrição | Exemplo |
|---|---|---|---|---|
| `listar_politicas` | catalogo | - | Políticas publicadas pelo gaia_nib, na ordem do catálogo publicado, com a marca `permitida`. | Python: `listar_politicas()`<br>R: `listar_politicas()` |
| `get_politica` | politica | estadual | Indicadores de uma política (capa, secundário e modalidades), um por linha, para uma UF ou para o Brasil (`uf=None`). | Python: `get_politica('b_mais_p', uf='SP')`<br>R: `get_politica('b_mais_p', uf = 'SP')` |
| `get_politicas_estado` | politica | estadual | Indicadores de todas as políticas publicadas para uma UF, na ordem do catálogo. Não soma nem ordena políticas entre si. | Python: `get_politicas_estado('SP')`<br>R: `get_politicas_estado('SP')` |
| `get_resumo_politicas` | politica | estadual | Resumo publicado das políticas de uma UF ou do Brasil (`uf=None`): quantidade, recursos, atendimentos e posição. | Python: `get_resumo_politicas('SP')`<br>R: `get_resumo_politicas('SP')` |
| `get_municipios_elegiveis` | catalogo | municipal | Municípios com políticas publicadas (código IBGE, nome, UF). | Python: `get_municipios_elegiveis()`<br>R: `get_municipios_elegiveis()` |
| `get_manifesto_politicas` | catalogo | - | Rótulo da fonte, diretorias exibidas e notas publicadas junto com as políticas. | Python: `get_manifesto_politicas()`<br>R: `get_manifesto_politicas()` |
| `get_politica_publicada` | politica | estadual | JSON completo de uma política, como dicionário/lista. Baixo nível: prefira `get_politica`. | Python: `get_politica_publicada('b_mais_p', uf='SP')`<br>R: `get_politica_publicada('b_mais_p', uf = 'SP')` |

## Utilitários e configuração

| Função | Subtema | Nível | Descrição | Exemplo |
|---|---|---|---|---|
| `criar_indice` | transformacao | - | Índice-base (ano_base = 100) para colunas numéricas de uma série temporal. | Python: `criar_indice(df, ano_base=2020, coluna_data='ano', colunas_valores=['estoque_trabalhadores'])`<br>R: `criar_indice(df, ano_base = 2020, coluna_data = 'ano', colunas_valores = 'estoque_trabalhadores')` |
| `juntar_emprego_comex` | transformacao | - | Une emprego e comércio exterior por divisão CNAE/ISIC e ano. | Python: `juntar_emprego_comex(df_emprego, df_comex)`<br>R: `juntar_emprego_comex(df_emprego, df_comex)` |
| `sdic_config` | configuracao | - | De onde a biblioteca está lendo (API, dados, políticas), ambiente, se há chave e de onde veio cada valor. | Python: `sdic_config()`<br>R: `sdic_config()` |
| `descrever` | configuracao | - | Ficha de uma base ou função do catálogo: origem, fonte, periodicidade, colunas e funções que a leem. | Python: `descrever('secoes_publicadas')`<br>R: `descrever('secoes_publicadas')` |
| `ler_json_publicado` | configuracao | - | Lê um JSON público de uma origem do catálogo. Último recurso: use quando não houver função pronta. | Python: `ler_json_publicado('dados', 'homologacao/SP/emprego.json')`<br>R: `ler_json_publicado('dados', 'homologacao/SP/emprego.json')` |
