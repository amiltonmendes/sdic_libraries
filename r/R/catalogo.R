# Catálogo das funções e das bases da biblioteca.
#
# Tudo vem de `inst/catalogo.json` (cópia de `contrato/catalogo.json`, a fonte única lida
# também pelo pacote Python). Não sabe qual função usar? `listar_bases()`. Quer saber de onde
# vem um dado e que colunas ele tem? `descrever(nome)`.

.sdic_colunas_de <- function(funcao) {
  vapply(.sdic_catalogo()$colunas[[funcao]], function(c) c[[1]], character(1))
}

#' Catálogo das funções públicas da biblioteca
#'
#' Não sabe qual função usar? `listar_bases()` devolve uma linha por função: tema, o que ela
#' traz, nível de agregação e um exemplo mínimo de chamada. O conteúdo é o mesmo do pacote
#' Python (`contrato/catalogo.json`).
#'
#' @param tema Filtro por tema: `"emprego"`, `"comex"`, `"series"`, `"publicados"`,
#'   `"politicas"` ou `"utilitarios"` (opcional).
#' @param subtema Filtro por subtema, ex.: `"estoque"`, `"saldo_caged"`, `"comercio_ncm"`;
#'   veja `unique(listar_bases()$subtema)` (opcional).
#' @return tibble com as colunas `tema`, `subtema`, `nivel`, `funcao`, `descricao`, `exemplo`,
#'   uma linha por função. Tema ou subtema inexistente gera erro que lista os valores válidos.
#' @export
#' @examples
#' \dontrun{
#' listar_bases()
#' listar_bases(tema = "publicados")
#' listar_bases(subtema = "saldo_caged")
#' }
listar_bases <- function(tema = NULL, subtema = NULL) {
  funcoes <- .sdic_catalogo()$funcoes
  campo <- function(nome) vapply(funcoes, function(f) f[[nome]] %||% NA_character_, character(1))
  df <- tibble::tibble(tema = campo("tema"), subtema = campo("subtema"), nivel = campo("nivel"),
                       funcao = campo("funcao"), descricao = campo("descricao"), exemplo = campo("exemplo_r"))
  filtros <- list(tema = tema, subtema = subtema)
  for (coluna in names(filtros)) {
    valor <- filtros[[coluna]]
    if (is.null(valor) || !nzchar(valor)) next
    if (!valor %in% df[[coluna]]) {
      .sdic_invalido(sprintf("%s desconhecido: '%s'. Valores: %s.", coluna, valor,
                             paste(sort(unique(df[[coluna]]), method = "radix"), collapse = ", ")))
    }
    df <- df[df[[coluna]] == valor, ]
  }
  df
}

#' Ficha de uma base ou de uma função do catálogo
#'
#' Diz de onde vem um dado (origem, endereço em uso, fonte, periodicidade, carga) e, para uma
#' função, que colunas ela devolve.
#'
#' @param nome Nome de uma base (ex.: `"secoes_publicadas"`, `"comexstat"`, `"politicas"`) ou
#'   de uma função (ex.: `"get_kpis_publicados"`). Para uma série da API, use
#'   [listar_series()].
#' @return tibble com as colunas `campo`, `valor`. Para uma função: descrição, exemplo, base
#'   que lê, origem e uma linha `coluna: <nome>` por coluna devolvida (tipo e significado).
#'   Para uma base: título, origem e endereço em uso, fonte, periodicidade, carga e funções.
#'   Nome fora do catálogo gera erro que lista as bases.
#' @export
#' @examples
#' \dontrun{
#' descrever("get_kpis_publicados")
#' descrever("secoes_publicadas")
#' }
descrever <- function(nome) {
  catalogo <- .sdic_catalogo()
  funcoes <- catalogo$funcoes
  nomes_funcoes <- vapply(funcoes, function(f) f$funcao, character(1))
  bases <- catalogo$bases
  campos <- character()
  valores <- character()
  linha <- function(campo, valor) {
    campos <<- c(campos, campo)
    valores <<- c(valores, as.character(valor))
  }
  ficha_base <- function(nome_base) {
    b <- bases[[nome_base]]
    caminho <- b$caminho %||% ""
    linha("base", paste0(nome_base, ": ", b$titulo))
    linha("origem", sprintf("%s (%s)", b$origem, catalogo$origens[[b$origem]]$descricao))
    linha("endereço em uso", paste0(.sdic_url(b$origem), if (startsWith(caminho, "{")) "/", caminho))
    rotulos <- c(fonte = "fonte", periodicidade = "periodicidade", `dataset no BigQuery` = "dataset",
                 `carga (painel de cargas)` = "carga", `documentação` = "documentacao", esquema = "esquema",
                 depreciada = "depreciada")
    for (campo in names(rotulos)) {
      valor <- b[[rotulos[[campo]]]]
      if (!is.null(valor) && !isFALSE(valor) && nzchar(as.character(valor))) linha(campo, valor)
    }
  }
  if (is.character(nome) && length(nome) == 1 && nome %in% nomes_funcoes) {
    f <- funcoes[[match(nome, nomes_funcoes)]]
    linha("função", nome)
    linha("descrição", f$descricao)
    linha("exemplo", f$exemplo_r)
    if (!is.null(f$base)) ficha_base(f$base)
    for (coluna in catalogo$colunas[[nome]]) {
      partes <- Filter(nzchar, c(coluna[[2]], coluna[[3]]))
      linha(paste0("coluna: ", coluna[[1]]), paste(partes, collapse = " — "))
    }
  } else if (is.character(nome) && length(nome) == 1 && nome %in% names(bases)) {
    ficha_base(nome)
    for (f in funcoes) if (identical(f$base, nome)) linha("função", f$funcao)
  } else {
    .sdic_invalido(sprintf("'%s' não está no catálogo. Bases: %s. Funções: listar_bases(). Séries da API: listar_series().",
                           paste(nome, collapse = ", "), paste(sort(names(bases), method = "radix"), collapse = ", ")))
  }
  tibble::tibble(campo = campos, valor = valores)
}
