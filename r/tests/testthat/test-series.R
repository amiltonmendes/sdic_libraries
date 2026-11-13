# Séries (/series) e tabelas de de-para (/referencias). As respostas vêm de
# contrato/series_amostras.json, o mesmo arquivo dos testes em Python.

C <- amostras("series")

# Serve `C$respostas` (ou `respostas`) e registra caminho e query de cada requisição.
api_falsa <- function(respostas = C$respostas, env = parent.frame()) {
  registro <- new.env()
  registro$chamadas <- list()
  httr2::local_mocked_responses(function(req) {
    partes <- httr2::url_parse(req$url)
    registro$chamadas[[length(registro$chamadas) + 1]] <- list(caminho = partes$path, query = partes$query)
    chave <- if (!is.null(partes$query$pagina)) paste0(partes$path, "?pagina=", partes$query$pagina) else partes$path
    if (chave %in% names(respostas)) return(resposta_json(respostas[[chave]], url = req$url))
    resposta_json(list(detail = paste("Série desconhecida:", partes$path)), 404L, req$url)
  }, env = env)
  registro
}

paginas_de <- function(registro, caminho) Filter(function(c) c$caminho == caminho, registro$chamadas)

test_that("contrato compartilhado está disponível", {
  skip_if(is.null(C), "contrato/ fora do pacote instalado")
  expect_gt(length(C$respostas), 0)
})

test_that("listar_series", {
  skip_if(is.null(C)); ambiente_limpo(); api_falsa()
  df <- listar_series()
  expect_equal(names(df), unlist(C$esperado$listar_series$colunas))
  expect_equal(df$nome, unlist(C$esperado$listar_series$nomes))
  expect_equal(df$filtros[1], "cod_tabela, cod_variavel, nivel, cod_localidade, cod_categoria")
})

test_that("get_serie junta páginas, tipa e envia filtros", {
  skip_if(is.null(C)); ambiente_limpo(); registro <- api_falsa()
  e <- C$esperado$get_serie
  df <- do.call(get_serie, e$args)
  expect_s3_class(df, "tbl_df")
  expect_equal(names(df), unlist(e$colunas))
  expect_equal(nrow(df), e$linhas)
  expect_equal(df$valor[1:2], unlist(e$valores[1:2]))
  expect_equal(is.na(df$valor), c(FALSE, FALSE, TRUE))
  expect_identical(df$cod_localidade, rep(e$cod_localidade, 3))  # texto, não número
  expect_type(df$cod_tabela, "integer")
  paginas <- paginas_de(registro, "/series/sidra_producao")
  expect_length(paginas, e$paginas)
  expect_equal(paginas[[1]]$query[names(e$query_esperada)], e$query_esperada)
})

test_that("get_serie: um valor ou vários (texto, número ou vetor) viram filtro separado por vírgula", {
  skip_if(is.null(C)); ambiente_limpo(); registro <- api_falsa()
  get_serie("sidra_producao", cod_tabela = 8888, cod_localidade = c("35", "33"), cod_variavel = c(12606, 1e5),
            nivel = NULL, ate = 2025)
  query <- paginas_de(registro, "/series/sidra_producao")[[1]]$query
  expect_equal(query$cod_localidade, "35,33")
  expect_equal(query$cod_variavel, "12606,100000")
  expect_equal(query$ate, "2025")
  expect_false("nivel" %in% names(query))
})

test_that("get_serie com_nomes", {
  skip_if(is.null(C)); ambiente_limpo(); api_falsa()
  e <- C$esperado$get_serie_com_nomes
  df <- get_serie("sidra_producao", cod_tabela = 8888, com_nomes = TRUE)
  expect_true(all(unlist(e$colunas_extras) %in% names(df)))
  expect_equal(nrow(df), 3)
  expect_equal(df$variavel_nome[1], e$variavel_nome)
  expect_equal(df$localidade_nome[1], e$localidade_nome)
})

test_that("get_serie vazia mantém as colunas", {
  skip_if(is.null(C)); ambiente_limpo()
  respostas <- C$respostas
  respostas[["/series/sidra_producao?pagina=1"]] <- list(items = list(), proxima_pagina = NULL)
  api_falsa(respostas)
  df <- get_serie("sidra_producao", cod_tabela = 1)
  expect_equal(nrow(df), 0)
  expect_equal(names(df), unlist(C$esperado$get_serie$colunas))
})

test_that("get_serie desconhecida", {
  skip_if(is.null(C)); ambiente_limpo(); api_falsa()
  e <- tryCatch(get_serie("nao_existe"), error = function(e) e)
  expect_s3_class(e, "sdic_erro")
  expect_match(conditionMessage(e), "listar_series")
  expect_equal(e$status_code, 404L)
})

test_that("get_dimensao_serie", {
  skip_if(is.null(C)); ambiente_limpo(); api_falsa()
  e <- C$esperado$get_dimensao_serie
  df <- do.call(get_dimensao_serie, e$args)
  expect_equal(names(df), unlist(e$colunas))
  expect_equal(nrow(df), e$linhas)
})

test_that("referências", {
  skip_if(is.null(C)); ambiente_limpo(); api_falsa()
  lista <- listar_referencias()
  expect_equal(names(lista), unlist(C$esperado$listar_referencias$colunas))
  expect_equal(nrow(lista), C$esperado$listar_referencias$linhas)
  e <- C$esperado$get_referencia
  df <- do.call(get_referencia, e$args)
  expect_equal(nrow(df), e$linhas)
  expect_identical(df[[1]][1], e$primeiro_codigo)  # texto: zero à esquerda preservado
  expect_true(all(vapply(df, is.character, logical(1))))
})
