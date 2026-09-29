# Catálogo das funções públicas da biblioteca, por tema.
#
# Não sabe qual função usar? listar_bases() devolve um tibble com uma linha por
# função: tema, o que ela traz, nível de agregação e um exemplo mínimo de chamada.
# Todas as funções listadas são as já exportadas pelo pacote (emprego.R/comex.R) —
# o catálogo só aponta para elas, não reimplementa nada.

# tema, subtema, nivel, funcao, descricao, exemplo
.catalogo_linhas <- list(
  # ---- emprego / estoque (RAIS) ----
  list(tema = "emprego", subtema = "estoque", nivel = "nacional", funcao = "get_estoque_emprego_nacional",
       descricao = "Estoque de vínculos ativos (31/12) por divisão ou grupo CNAE.",
       exemplo = "get_estoque_emprego_nacional(codigos_cnae = '10', nivel_cnae = 2)"),
  list(tema = "emprego", subtema = "estoque", nivel = "estadual", funcao = "get_estoque_emprego_estadual",
       descricao = "Igual ao nacional, por UF.",
       exemplo = "get_estoque_emprego_estadual(sigla_uf = 'SP', codigos_cnae = '10')"),
  list(tema = "emprego", subtema = "estoque", nivel = "nacional", funcao = "get_estoque_emprego_nacional_agrupado",
       descricao = "Estoque somado para uma lista de CNAEs sob um nome de grupo (ex.: 'TI').",
       exemplo = "get_estoque_emprego_nacional_agrupado('TI', c('620', '631'))"),
  list(tema = "emprego", subtema = "estoque", nivel = "estadual", funcao = "get_estoque_emprego_estadual_agrupado",
       descricao = "Igual ao agrupado nacional, por UF.",
       exemplo = "get_estoque_emprego_estadual_agrupado(sigla_uf = 'SP', nome_grupo = 'TI', lista_cnae = '620')"),
  list(tema = "emprego", subtema = "estoque_estimado", nivel = "nacional", funcao = "get_estoque_emprego_estimado_nacional_anual",
       descricao = "Estoque real (RAIS) + projeção com o saldo CAGED acumulado até o ano corrente (coluna 'origem': Real/Estimação).",
       exemplo = "get_estoque_emprego_estimado_nacional_anual(codigo_cnae = '10')"),
  list(tema = "emprego", subtema = "estoque_estimado", nivel = "estadual", funcao = "get_estoque_emprego_estimado_estadual_anual",
       descricao = "Igual ao estimado nacional, por UF.",
       exemplo = "get_estoque_emprego_estimado_estadual_anual(sigla_uf = 'SP', codigo_cnae = '10')"),
  list(tema = "emprego", subtema = "estoque_estimado", nivel = "municipal", funcao = "get_estoque_emprego_estimado_municipal_anual",
       descricao = "Igual ao estimado nacional, por município.",
       exemplo = "get_estoque_emprego_estimado_municipal_anual(sigla_uf = 'SP', codigo_municipio = 3550308, codigo_cnae = '10')"),
  list(tema = "emprego", subtema = "estoque_porte", nivel = "nacional", funcao = "get_estoque_emprego_porte_nacional",
       descricao = "Estoque por porte do estabelecimento (Sebrae/DIEESE) e setor (Indústria x Comércio/Serviços).",
       exemplo = "get_estoque_emprego_porte_nacional('divisao', codigos_cnae = '10', setor = 'Indústria')"),
  list(tema = "emprego", subtema = "estoque_porte", nivel = "estadual", funcao = "get_estoque_emprego_porte_estadual",
       descricao = "Igual ao porte nacional, por UF.",
       exemplo = "get_estoque_emprego_porte_estadual(uf = 'SP', nivel_cnae = 'divisao', porte = 'Microempresa')"),
  list(tema = "emprego", subtema = "estoque_classe", nivel = "nacional", funcao = "get_estoque_emprego_classe_cnae_nacional",
       descricao = "Estoque por classe CNAE (4 dígitos, mais fino que divisão/grupo).",
       exemplo = "get_estoque_emprego_classe_cnae_nacional(codigos_classe = '1011')"),
  list(tema = "emprego", subtema = "estoque_classe", nivel = "estadual", funcao = "get_estoque_emprego_classe_cnae_estadual",
       descricao = "Igual ao classe nacional, por UF.",
       exemplo = "get_estoque_emprego_classe_cnae_estadual(uf = 'SP', codigos_classe = '1011')"),
  list(tema = "emprego", subtema = "estoque_ocupacao", nivel = "estadual", funcao = "get_estoque_emprego_uf_cbo",
       descricao = "Estoque por UF, classe CNAE e ocupação (CBO). Endpoint pesado: sempre filtre siglas_uf e codigos_classe.",
       exemplo = "get_estoque_emprego_uf_cbo(siglas_uf = 'SP', codigos_classe = '4711')"),
  list(tema = "emprego", subtema = "renda", nivel = "nacional", funcao = "get_renda_media_emprego",
       descricao = "Remuneração média (RAIS) por divisão/grupo CNAE ou geral.",
       exemplo = "get_renda_media_emprego(tipos = 'Divisao', codigos = '10')"),
  list(tema = "emprego", subtema = "potec", nivel = "nacional", funcao = "get_potec_emprego",
       descricao = "Índice Potec: fração de pessoal ocupado técnico-científico por classe CNAE (proxy de P&D da PINTEC).",
       exemplo = "get_potec_emprego(codigos_classe = '7210')"),
  list(tema = "emprego", subtema = "metadados", nivel = "-", funcao = "get_date_bases",
       descricao = "Data da última atualização de cada base (CAGED, RAIS, ComexStat).",
       exemplo = "get_date_bases()"),
  # ---- emprego / saldo (Novo CAGED) ----
  list(tema = "emprego", subtema = "saldo_caged", nivel = "nacional", funcao = "get_saldo_emprego_nacional_mensal",
       descricao = "Saldo mensal (admissões − desligamentos) por divisão/grupo/subclasse CNAE.",
       exemplo = "get_saldo_emprego_nacional_mensal(nivel_cnae = 'divisao', codigo_cnae = '10')"),
  list(tema = "emprego", subtema = "saldo_caged", nivel = "nacional", funcao = "get_saldo_emprego_nacional_anual",
       descricao = "Saldo somado por ano, mesmo recorte do mensal.",
       exemplo = "get_saldo_emprego_nacional_anual(nivel_cnae = 'divisao', codigo_cnae = '10')"),
  list(tema = "emprego", subtema = "saldo_caged", nivel = "nacional", funcao = "get_saldo_emprego_nacional_mensal_agrupado",
       descricao = "Saldo mensal somado para uma lista de CNAEs sob um nome de grupo.",
       exemplo = "get_saldo_emprego_nacional_mensal_agrupado('TI', c('620', '631'))"),
  list(tema = "emprego", subtema = "saldo_caged", nivel = "estadual", funcao = "get_saldo_emprego_estadual_mensal",
       descricao = "Igual ao saldo mensal nacional, por UF.",
       exemplo = "get_saldo_emprego_estadual_mensal(sigla_uf = 'SP', nivel_cnae = 'divisao', codigo_cnae = '10')"),
  list(tema = "emprego", subtema = "saldo_caged", nivel = "estadual", funcao = "get_saldo_emprego_estadual_anual",
       descricao = "Igual ao saldo anual nacional, por UF.",
       exemplo = "get_saldo_emprego_estadual_anual(sigla_uf = 'SP', nivel_cnae = 'divisao', codigo_cnae = '10')"),
  list(tema = "emprego", subtema = "saldo_caged", nivel = "estadual", funcao = "get_saldo_emprego_estadual_mensal_agrupado",
       descricao = "Igual ao saldo agrupado nacional, por UF.",
       exemplo = "get_saldo_emprego_estadual_mensal_agrupado(sigla_uf = 'SP', nome_grupo = 'TI', lista_cnae = '620')"),
  list(tema = "emprego", subtema = "saldo_caged", nivel = "municipal", funcao = "get_saldo_emprego_municipal_mensal",
       descricao = "Igual ao saldo mensal nacional, por município.",
       exemplo = "get_saldo_emprego_municipal_mensal(sigla_uf = 'SP', codigo_municipio = 3550308, nivel_cnae = 'divisao', codigo_cnae = '10')"),
  list(tema = "emprego", subtema = "saldo_caged", nivel = "municipal", funcao = "get_saldo_emprego_municipal_anual",
       descricao = "Igual ao saldo anual nacional, por município.",
       exemplo = "get_saldo_emprego_municipal_anual(sigla_uf = 'SP', codigo_municipio = 3550308, nivel_cnae = 'divisao', codigo_cnae = '10')"),
  list(tema = "emprego", subtema = "saldo_caged", nivel = "municipal", funcao = "get_saldo_emprego_municipal_mensal_agrupado",
       descricao = "Igual ao saldo agrupado nacional, por município.",
       exemplo = "get_saldo_emprego_municipal_mensal_agrupado(sigla_uf = 'SP', codigo_municipio = 3550308, nome_grupo = 'TI', lista_cnae = '620')"),
  # ---- emprego / portal (cache já publicado, sem chamar a API) ----
  list(tema = "emprego", subtema = "portal_cache", nivel = "estadual", funcao = "get_relatorio_emprego_saldo_estadual",
       descricao = "Saldo CAGED mensal por UF, lido do cache já publicado (GitHub Pages) — não chama a API ao vivo.",
       exemplo = "get_relatorio_emprego_saldo_estadual(uf = 'SP')"),
  list(tema = "emprego", subtema = "portal_cache", nivel = "estadual", funcao = "get_relatorio_emprego_estoque_estadual",
       descricao = "Estoque RAIS por UF, lido do cache já publicado — não chama a API ao vivo.",
       exemplo = "get_relatorio_emprego_estoque_estadual(uf = 'SP')"),
  # ---- comex ----
  list(tema = "comex", subtema = "comercio_ncm", nivel = "nacional", funcao = "get_exportacao_ncm_nacional_mensal",
       descricao = "Exportações mensais por NCM (produto), com filtro opcional por seção ISIC.",
       exemplo = "get_exportacao_ncm_nacional_mensal(ano_minimo = 2024, secao = 'Indústria de Transformação')"),
  list(tema = "comex", subtema = "comercio_ncm", nivel = "nacional", funcao = "get_importacao_ncm_nacional_mensal",
       descricao = "Igual ao NCM de exportação, para importações.",
       exemplo = "get_importacao_ncm_nacional_mensal(ano_minimo = 2024)"),
  list(tema = "comex", subtema = "comercio_isic", nivel = "nacional", funcao = "get_exportacao_isic_divisao_nacional_mensal",
       descricao = "Exportações mensais por divisão ISIC (setor) — a chave para juntar com emprego (juntar_emprego_comex).",
       exemplo = "get_exportacao_isic_divisao_nacional_mensal(ano_minimo = 2024, agregado_ano = TRUE)"),
  list(tema = "comex", subtema = "comercio_isic", nivel = "nacional", funcao = "get_importacao_isic_divisao_nacional_mensal",
       descricao = "Igual ao ISIC de exportação, para importações.",
       exemplo = "get_importacao_isic_divisao_nacional_mensal(ano_minimo = 2024, agregado_ano = TRUE)"),
  list(tema = "comex", subtema = "comercio_isic", nivel = "estadual", funcao = "get_exportacao_isic_divisao_estadual_mensal",
       descricao = "Igual ao ISIC nacional, por UF (e opcionalmente por país/bloco).",
       exemplo = "get_exportacao_isic_divisao_estadual_mensal(estado = 'São Paulo', ano_minimo = 2024)"),
  list(tema = "comex", subtema = "comercio_isic", nivel = "estadual", funcao = "get_importacao_isic_divisao_estadual_mensal",
       descricao = "Igual ao ISIC estadual de exportação, para importações.",
       exemplo = "get_importacao_isic_divisao_estadual_mensal(estado = 'São Paulo', ano_minimo = 2024)"),
  list(tema = "comex", subtema = "comercio_pais", nivel = "nacional", funcao = "get_exportacao_pais_nacional_mensal",
       descricao = "Exportações mensais por país de destino.",
       exemplo = "get_exportacao_pais_nacional_mensal(pais = 'Argentina', ano_minimo = 2024)"),
  list(tema = "comex", subtema = "comercio_pais", nivel = "nacional", funcao = "get_importacao_pais_nacional_mensal",
       descricao = "Igual ao país de exportação, para importações (país de origem).",
       exemplo = "get_importacao_pais_nacional_mensal(pais = 'Argentina', ano_minimo = 2024)"),
  list(tema = "comex", subtema = "comercio_mapa", nivel = "-", funcao = "get_ncm_isic_mapa",
       descricao = "De-para NCM → divisão/seção ISIC (catálogo estático, ~13 mil códigos).",
       exemplo = "get_ncm_isic_mapa()"),
  # ---- utilitários (transformam o que as funções acima devolvem) ----
  list(tema = "utilitarios", subtema = "transformacao", nivel = "-", funcao = "criar_indice",
       descricao = "Índice-base (ano_base = 100) para colunas numéricas de uma série temporal.",
       exemplo = "criar_indice(df, ano_base = 2020, coluna_data = 'ano', colunas_valores = 'estoque_trabalhadores')"),
  list(tema = "utilitarios", subtema = "transformacao", nivel = "-", funcao = "juntar_emprego_comex",
       descricao = "Une emprego e comércio exterior por divisão CNAE/ISIC e ano.",
       exemplo = "juntar_emprego_comex(df_emprego, df_comex)")
)

#' Catálogo das funções públicas da biblioteca
#'
#' Não sabe qual função usar? `listar_bases()` devolve um tibble com uma linha por
#' função: tema, o que ela traz, nível de agregação e um exemplo mínimo de chamada.
#'
#' @param tema Filtro por tema: "emprego", "comex" ou "utilitarios" (opcional)
#' @param subtema Filtro adicional, ex. "estoque", "saldo_caged", "comercio_ncm" -
#'   veja `unique(listar_bases()$subtema)` para todos os valores (opcional)
#' @return tibble com colunas tema, subtema, nivel, funcao, descricao, exemplo
#' @export
#' @examples
#' \dontrun{
#' listar_bases()
#' listar_bases(tema = "comex")
#' listar_bases(subtema = "saldo_caged")
#' }
listar_bases <- function(tema = NULL, subtema = NULL) {
  df <- tibble::as_tibble(dplyr::bind_rows(.catalogo_linhas))
  if (!is.null(tema)) df <- df[df$tema == tema, ]
  if (!is.null(subtema)) df <- df[df$subtema == subtema, ]
  df
}
