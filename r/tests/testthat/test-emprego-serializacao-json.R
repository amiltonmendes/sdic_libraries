# Regressão: um único código CNAE/UF/município num corpo POST não pode virar
# escalar no JSON. httr2/jsonlite fazem auto_unbox de vetores atômicos de
# tamanho 1 por padrão — sem I(), c("47") e "47" produzem o mesmo JSON
# ("47" em vez de ["47"]), e a API rejeita com 422 porque espera list[str].
#
# Mock de httr2::req_perform (mesmo padrão de test-comex.R) — sem rede real.
# Em vez de inspecionar a URL da chamada, serializa req$body$data com os
# mesmos parâmetros que httr2 usaria (req$body$params) e confere o JSON.

mock_req_perform_captura_body <- function(registro) {
  function(req, ...) {
    registro$body <- req$body
    httr2::response(
      status_code = 200,
      headers = list("Content-Type" = "application/json"),
      body = charToRaw(jsonlite::toJSON(list(count = 0, items = list()), auto_unbox = TRUE))
    )
  }
}

.json_do_body <- function(body) {
  do.call(jsonlite::toJSON, c(list(body$data), body$params))
}

test_that("get_saldo_emprego_detalhado_lista_cnae serializa 1 codigo como array", {
  registro <- new.env()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform_captura_body(registro),
    .package = "httr2"
  )

  api <- Emprego$new(base_url = "https://sdicapi.teste", api_key = "chave-teste")
  api$get_saldo_emprego_detalhado_lista_cnae(
    lista_cnae = "47", nome_grupo = "Comercio", nivel_agregacao = "nacional", nivel_cnae = 2
  )

  json <- .json_do_body(registro$body)
  expect_true(grepl('"codigos":\\["47"\\]', json))
  expect_false(grepl('"codigos":"47"', json))
})

test_that("get_saldo_emprego_detalhado_lista_cnae serializa 1 UF e 1 municipio como array", {
  registro <- new.env()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform_captura_body(registro),
    .package = "httr2"
  )

  api <- Emprego$new(base_url = "https://sdicapi.teste", api_key = "chave-teste")
  api$get_saldo_emprego_detalhado_lista_cnae(
    lista_cnae = "47", nome_grupo = "Comercio", nivel_agregacao = "municipal",
    municipio = 3550308, nivel_cnae = 2
  )

  json <- .json_do_body(registro$body)
  expect_true(grepl('"codigos_municipio":\\[3550308\\]', json))
  expect_false(grepl('"codigos_municipio":3550308[^]]', json))
})

test_that("get_saldo_emprego_detalhado_grupos_cnae serializa 1 codigo por grupo como array", {
  registro <- new.env()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform_captura_body(registro),
    .package = "httr2"
  )

  api <- Emprego$new(base_url = "https://sdicapi.teste", api_key = "chave-teste")
  grupos <- list(list(nome_grupo = "Comercio", codigos_cnae = "47"))
  api$get_saldo_emprego_detalhado_grupos_cnae(
    grupos_cnae = grupos, nivel_agregacao = "nacional", nivel_cnae = 2
  )

  json <- .json_do_body(registro$body)
  expect_true(grepl('"codigos":\\["47"\\]', json))
})

test_that("get_estoque_emprego_grupos_cnae serializa 1 codigo por grupo como array", {
  registro <- new.env()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform_captura_body(registro),
    .package = "httr2"
  )

  api <- Emprego$new(base_url = "https://sdicapi.teste", api_key = "chave-teste")
  grupos <- list(list(nome_grupo = "Comercio", codigos_cnae = "47"))
  api$get_estoque_emprego_grupos_cnae(grupos_cnae = grupos, ufs = "SP")

  json <- .json_do_body(registro$body)
  expect_true(grepl('"codigos_cnae":\\["47"\\]', json))
})
