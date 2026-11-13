# Séries da sdic_api (`/series`): uma função para todas as bases publicadas lá.
#
# `listar_series()` diz o que existe; `get_serie(nome, ...)` devolve os valores;
# `get_dimensao_serie(nome, dimensao)` devolve os nomes dos códigos. As tabelas de de-para
# (`/referencias`) seguem o mesmo desenho. Espelho de `python/sdic_libraries/series.py`.

.series_texto <- function(v) {
  if (is.null(v) || length(v) == 0) return("")
  if (is.list(v) && !is.null(names(v))) return(paste(names(v), collapse = ", "))
  paste(as.character(unlist(v)), collapse = ", ")
}

# Um valor ou vários viram o texto do filtro: `c("SP", "RJ")` -> "SP,RJ"; TRUE -> "true".
.series_como_lista <- function(v) {
  v <- unlist(v)
  if (is.logical(v)) return(paste(ifelse(v, "true", "false"), collapse = ","))
  if (is.numeric(v)) return(paste(format(v, scientific = FALSE, trim = TRUE, digits = 15), collapse = ","))
  paste(as.character(v), collapse = ",")
}

.series_tipar <- function(x, tipo) {
  switch(tipo,
    STRING = as.character(x),
    INT64 = {
      n <- .sdic_numerico(x)
      if (all(is.na(n) | abs(n) <= .Machine$integer.max)) as.integer(n) else n
    },
    BOOL = as.logical(x),
    x
  )
}

# Acrescenta `<dimensao>_nome` (e `unidade`, na dimensão de variáveis) pelas colunas em comum.
.series_juntar_nomes <- function(df, dimensao, linhas) {
  dim <- .sdic_tabela(linhas)
  chaves <- intersect(names(dim), names(df))
  nome <- if ("nome" %in% names(dim)) "nome" else dimensao
  if (dimensao == "metadados" || length(chaves) == 0 || !nome %in% names(dim) || nome %in% chaves) return(df)
  extras <- setdiff(intersect("unidade", names(dim)), names(df))
  dim <- dim[!duplicated(dim[chaves]), c(chaves, nome, extras)]
  names(dim)[names(dim) == nome] <- paste0(dimensao, "_nome")
  for (chave in chaves) dim[[chave]] <- as.vector(dim[[chave]], mode = typeof(df[[chave]]))
  dplyr::left_join(df, dim, by = chaves)
}

#' Séries que a sdic_api publica em `/series`
#'
#' @return tibble com uma linha por série e as colunas `nome`, `descricao`, `fonte`,
#'   `colunas`, `filtros`, `obrigatorios`, `periodo`, `dimensoes` (listas como texto separado
#'   por vírgula).
#' @examples
#' \dontrun{
#' listar_series()[, c("nome", "descricao", "filtros")]
#' }
#' @export
listar_series <- function() {
  colunas <- .sdic_colunas_de("listar_series")
  linhas <- ClienteAPI$new()$.make_request("/series")
  .sdic_tabela(lapply(linhas, function(l) {
    textos <- lapply(colunas, function(coluna) .series_texto(l[[coluna]]))
    names(textos) <- colunas
    textos
  }), colunas)
}

#' Valores de uma série de `/series`, com todas as páginas
#'
#' @param nome Nome da série (veja [listar_series()]), ex.: `"sidra_producao"`.
#' @param desde,ate Início e fim do período, inclusive. Data `"AAAA-MM-DD"` ou ano, conforme
#'   a coluna `periodo` da série.
#' @param com_nomes Se `TRUE`, junta, para cada código que tenha dimensão (`cod_variavel`,
#'   `cod_categoria`, `cod_localidade`, `cod_atividade`), a coluna `<dimensão>_nome`.
#' @param ... Filtros pelos nomes das colunas (os de `listar_series()$filtros`), com um valor
#'   ou vários (texto, número ou vetor): `sg_uf = c("SP", "RJ")`, `cod_tabela = 8888`.
#' @return tibble com as colunas da série, na ordem publicada (veja `listar_series()$colunas`).
#'   Códigos de filtro do tipo texto ficam como texto (zeros à esquerda preservados); `valor`,
#'   quando existe, vira número (o SIDRA publica texto; `-` e `...` viram `NA`, e o motivo
#'   fica em `simbolo`). Com `com_nomes`, também as colunas `<dimensão>_nome` e `unidade`.
#'   Sem linhas: tabela vazia com as mesmas colunas. Série desconhecida (404), filtro inválido
#'   ou obrigatório ausente (422) e falta de chave (401) geram erro da classe `sdic_erro`.
#' @examples
#' \dontrun{
#' get_serie("sidra_producao", cod_tabela = 8888, cod_localidade = "35", desde = "2025-01-01")
#' get_serie("contas_regionais_vab", sg_uf = "SP", com_nomes = TRUE)
#' }
#' @export
get_serie <- function(nome, desde = NULL, ate = NULL, com_nomes = FALSE, ...) {
  filtros <- Filter(Negate(is.null), list(...))
  params <- lapply(filtros, .series_como_lista)
  if (!is.null(desde)) params$desde <- as.character(desde)
  if (!is.null(ate)) params$ate <- as.character(ate)
  cliente <- ClienteAPI$new()
  definicao <- Filter(function(s) identical(s$nome, nome), cliente$.make_request("/series"))
  rota <- paste0("/series/", nome)
  if (length(definicao) == 0) {
    .sdic_abortar(sprintf("Série desconhecida: '%s'. Veja listar_series().", nome), status_code = 404L, endpoint = rota)
  }
  definicao <- definicao[[1]]
  df <- .sdic_tabela(cliente$.fetch_all_paginated_get(rota, params), unlist(definicao$colunas))
  for (coluna in intersect(names(definicao$filtros), names(df))) {
    df[[coluna]] <- .series_tipar(df[[coluna]], definicao$filtros[[coluna]])
  }
  if ("valor" %in% names(df)) df$valor <- .sdic_numerico(df$valor)
  if (isTRUE(com_nomes)) {
    for (dimensao in unlist(definicao$dimensoes)) {
      df <- .series_juntar_nomes(df, dimensao, cliente$.make_request(paste0(rota, "/dimensoes/", dimensao)))
    }
  }
  df
}

#' Códigos e nomes de uma dimensão de uma série
#'
#' @param nome Nome da série (veja [listar_series()]).
#' @param dimensao Uma das dimensões de `listar_series()$dimensoes` (ex.: `"variavel"`,
#'   `"categoria"`, `"localidade"`, `"metadados"`, `"atividade"`).
#' @return tibble com as colunas da tabela de dimensão (códigos e nomes), como publicadas.
#' @examples
#' \dontrun{
#' get_dimensao_serie("sidra_producao", "variavel")
#' }
#' @export
get_dimensao_serie <- function(nome, dimensao) {
  .sdic_tabela(ClienteAPI$new()$.make_request(paste0("/series/", nome, "/dimensoes/", dimensao)))
}

#' Tabelas de de-para disponíveis na API
#'
#' Tabelas do dataset `referencias` (mantido em `carga_base/referencias`), servidas pela
#' sdic_api em `/referencias`.
#'
#' @return tibble com as colunas `nome`, `descricao`.
#' @examples
#' \dontrun{
#' listar_referencias()
#' }
#' @export
listar_referencias <- function() {
  .sdic_tabela(ClienteAPI$new()$.make_request("/referencias"), c("nome", "descricao"))
}

#' Uma tabela de de-para inteira
#'
#' CNAE, ISIC, CNAE x ISIC, municípios, intensidade tecnológica, agrupamentos NCM.
#'
#' @param nome Um dos nomes de [listar_referencias()], ex.: `"cnae"`, `"isic_cnae"`,
#'   `"municipio"`.
#' @return tibble com as colunas da tabela, todas como texto (códigos com zeros à esquerda
#'   preservados).
#' @examples
#' \dontrun{
#' get_referencia("isic_cnae")
#' }
#' @export
get_referencia <- function(nome) {
  df <- .sdic_tabela(ClienteAPI$new()$.make_request(paste0("/referencias/", nome)))
  df[] <- lapply(df, as.character)
  df
}
