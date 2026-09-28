# Cache local das respostas da sdic_api (R/cache.R) — req_perform mockado, sem rede.

mock_perform_contando <- function(contador, corpo = list(count = 0, items = list())) {
  function(req, ...) {
    contador$n <- contador$n + 1
    httr2::response(status_code = 200, headers = list("Content-Type" = "application/json"),
                    body = charToRaw(as.character(jsonlite::toJSON(corpo, auto_unbox = TRUE))))
  }
}

novo_cliente <- function() suppressMessages(Comex$new(base_url = "https://sdicapi.teste", api_key = "k"))

test_that("desligado por padrão: sempre busca e não grava nada", {
  pasta <- withr::local_tempdir()
  withr::local_envvar(SDIC_CACHE_DIR = pasta, SDIC_CACHE_TTL = NA)
  contador <- new.env(); contador$n <- 0
  testthat::local_mocked_bindings(req_perform = mock_perform_contando(contador), .package = "httr2")
  api <- novo_cliente()
  api$.make_request("/x", list(a = 1)); api$.make_request("/x", list(a = 1))
  expect_equal(contador$n, 2)
  expect_length(list.files(pasta), 0)
})

test_that("com TTL, repetição vem do cache; params, corpo e host diferentes não", {
  withr::local_envvar(SDIC_CACHE_DIR = withr::local_tempdir(), SDIC_CACHE_TTL = "60")
  contador <- new.env(); contador$n <- 0
  testthat::local_mocked_bindings(req_perform = mock_perform_contando(contador), .package = "httr2")
  api <- novo_cliente()
  api$.make_request("/x", list(a = 1)); api$.make_request("/x", list(a = 1))
  expect_equal(contador$n, 1)
  api$.make_request("/x", list(a = 2)); expect_equal(contador$n, 2)
  api$.make_post_request("/y", list(anos = list(2025))); api$.make_post_request("/y", list(anos = list(2025)))
  expect_equal(contador$n, 3)
  api$.make_post_request("/y", list(anos = list(2026))); expect_equal(contador$n, 4)
  outro <- suppressMessages(Comex$new(base_url = "https://outro.teste", api_key = "k"))
  outro$.make_request("/x", list(a = 1)); expect_equal(contador$n, 5)
})

test_that("expirado ou corrompido busca de novo; erro não é gravado", {
  pasta <- withr::local_tempdir()
  withr::local_envvar(SDIC_CACHE_DIR = pasta, SDIC_CACHE_TTL = "60")
  contador <- new.env(); contador$n <- 0
  testthat::local_mocked_bindings(req_perform = mock_perform_contando(contador), .package = "httr2")
  api <- novo_cliente()
  api$.make_request("/x")
  arquivo <- list.files(pasta, full.names = TRUE)
  Sys.setFileTime(arquivo, Sys.time() - 3600)
  api$.make_request("/x"); expect_equal(contador$n, 2)
  writeLines("quebrado", arquivo)
  api$.make_request("/x"); expect_equal(contador$n, 3)

  pasta_erro <- withr::local_tempdir()
  withr::local_envvar(SDIC_CACHE_DIR = pasta_erro)
  testthat::local_mocked_bindings(req_perform = function(req, ...) stop("boom"), .package = "httr2")
  expect_error(novo_cliente()$.make_request("/z"))
  expect_length(list.files(pasta_erro), 0)
})
