# Testes unitários do cliente Comex (R6) — mock de `httr2::req_perform` via
# `testthat::local_mocked_bindings` (sem rede real, sem tocar bindings
# travados de métodos R6 de um pacote instalado).

mock_response <- function(json_data, status_code = 200) {
  httr2::response(
    status_code = status_code,
    headers = list("Content-Type" = "application/json"),
    body = charToRaw(jsonlite::toJSON(json_data, auto_unbox = TRUE, null = "null"))
  )
}

# Cria uma função substituta para `httr2::req_perform` que devolve as
# respostas em `respostas`, em sequência, e registra os requests recebidos
# em `registro$chamadas`.
mock_req_perform <- function(respostas, registro) {
  idx <- 0
  function(req, ...) {
    idx <<- idx + 1
    registro$chamadas[[idx]] <- req
    respostas[[idx]]
  }
}

test_that("api_key fica disponivel no objeto", {
  api <- Comex$new(base_url = "https://sdicapi.teste", api_key = "chave-teste")
  expect_equal(api$api_key, "chave-teste")
})

test_that("base_url default e o host publico", {
  withr::local_envvar(c(COMEX_API_BASE_URL = NA))
  api <- Comex$new(api_key = NULL)
  expect_equal(api$base_url, "https://sdicapi.dados.ninja")
})

test_that("get_exportacao_isic_divisao_nacional_mensal monta url e params", {
  registro <- new.env()
  registro$chamadas <- list()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(mock_response(list(count = 0, items = list()))), registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste", api_key = "chave-teste")
  api$get_exportacao_isic_divisao_nacional_mensal(ano_minimo = 2023, secao = "C")

  expect_equal(length(registro$chamadas), 1)
  url <- registro$chamadas[[1]]$url
  expect_true(grepl("^https://sdicapi\\.teste/exportacao_isic_divisao_gcloud", url))
  expect_true(grepl("ano_minimo=2023", url))
  expect_true(grepl("secao=C", url))
})

test_that("get_exportacao_isic_divisao_estadual_mensal repassa bloco", {
  registro <- new.env()
  registro$chamadas <- list()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(mock_response(list(count = 0, items = list()))), registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste")
  api$get_exportacao_isic_divisao_estadual_mensal(estado = "São Paulo", bloco = 22)

  url <- registro$chamadas[[1]]$url
  expect_true(grepl("bloco=22", url))
})

test_that(".fetch_all_paginated_get consolida paginas", {
  registro <- new.env()
  registro$chamadas <- list()
  respostas <- list(
    mock_response(list(count = 3, items = list(list(a = 1), list(a = 2)))),
    mock_response(list(count = 3, items = list(list(a = 3))))
  )
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(respostas, registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste")
  itens <- api$.fetch_all_paginated_get("/exportacao_pais_gcloud", list(ano_minimo = 2023, tamanho_pagina = 2))

  expect_equal(length(itens), 3)
  expect_equal(length(registro$chamadas), 2)
})

test_that(".fetch_all_paginated_post embute pagina no corpo", {
  registro <- new.env()
  registro$chamadas <- list()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(mock_response(list(count = 1, items = list(list(NCM = 123))))), registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste")
  api$.fetch_all_paginated_post("/exportacao_agregada_ncm", list(ano_minimo = 2023), list())

  corpo <- registro$chamadas[[1]]$body$data
  expect_equal(corpo$pagina, 1)
  expect_equal(corpo$ano_minimo, 2023)
})

test_that("secao filtra NCM via mapa NCM->ISIC", {
  registro <- new.env()
  registro$chamadas <- list()
  mapa <- mock_response(list(count = 2, items = list(
    list(NCM = 111, DescricaoNCM = "x", DivisaoISIC = 10, NomeDivisaoISIC = "y", SecaoISIC = "C", NomeSecaoISIC = "Indústria de Transformação"),
    list(NCM = 222, DescricaoNCM = "z", DivisaoISIC = 1, NomeDivisaoISIC = "w", SecaoISIC = "A", NomeSecaoISIC = "Agropecuária")
  )))
  ncm <- mock_response(list(count = 2, items = list(
    list(Ano = 2023, Mes = 1, NCM = 111, DescricaoNCM = "x", VLFob = 100, QTEstat = 1, KgLiquido = 1),
    list(Ano = 2023, Mes = 1, NCM = 222, DescricaoNCM = "z", VLFob = 200, QTEstat = 1, KgLiquido = 1)
  )))
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(ncm, mapa), registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste")
  itens <- api$get_exportacao_ncm_nacional_mensal(ano_minimo = 2023, secao = "C")

  expect_equal(length(itens), 1)
  expect_equal(itens[[1]]$NCM, 111)
})

test_that("get_ncm_isic_mapa e cacheado em memoria", {
  registro <- new.env()
  registro$chamadas <- list()
  mapa <- mock_response(list(count = 1, items = list(
    list(NCM = 1, DescricaoNCM = "x", DivisaoISIC = 1, NomeDivisaoISIC = "y", SecaoISIC = "A", NomeSecaoISIC = "z")
  )))
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(mapa), registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste")
  api$get_ncm_isic_mapa()
  api$get_ncm_isic_mapa()

  expect_equal(length(registro$chamadas), 1)
})

test_that("erro HTTP vira cli_abort (falha de requisicao tratada)", {
  registro <- new.env()
  registro$chamadas <- list()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(mock_response(list(detail = "erro"), status_code = 500)), registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste")
  expect_error(api$get_exportacao_pais_nacional_mensal())
})
