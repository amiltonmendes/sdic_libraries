# Transporte: erro com código e rota, paginação nos três formatos, cache por chave, repetição
# configurada. Espelho de python/tests/test_transporte.py.

test_that("erro decidido pelo código HTTP, com rota e status", {
  ambiente_limpo()
  casos <- list(list(401L, "SDIC_API_KEY"), list(403L, "SDIC_API_KEY"), list(404L, "não encontrado"),
                list(429L, "Muitas requisições"), list(503L, "erro interno"), list(422L, "Parâmetros inválidos"))
  for (caso in casos) {
    # a URL contém "400" (código de município): não pode virar "parâmetros inválidos"
    responde(list(resposta_json(list(detail = "motivo da API"), caso[[1]])))
    e <- tryCatch(Emprego$new(base_url = "https://x")$.make_request("/rota", list(codigos_municipio = 1400100)),
                  error = function(e) e)
    expect_s3_class(e, "sdic_erro")
    expect_match(conditionMessage(e), caso[[2]], fixed = TRUE)
    expect_match(conditionMessage(e), paste0("HTTP ", caso[[1]]), fixed = TRUE)
    expect_equal(e$status_code, caso[[1]])
    expect_equal(e$endpoint, "/rota")
  }
})

test_that("401 repassa o detalhe da API", {
  ambiente_limpo()
  responde(list(resposta_json(list(detail = "Chave de API inválida ou ausente"), 401L)))
  expect_error(Comex$new(base_url = "https://x")$.make_request("/r"), "Chave de API inválida ou ausente",
               class = "sdic_erro")
})

test_that("falha de rede não expõe URL nem chave", {
  ambiente_limpo()
  falha <- structure(class = c("httr2_failure", "httr2_error", "rlang_error", "error", "condition"),
                     list(message = "https://x/r?token=segredo falhou", call = NULL))
  responde(list(falha))
  e <- tryCatch(Emprego$new(base_url = "https://x", api_key = "segredo")$.make_request("/r"), error = function(e) e)
  expect_s3_class(e, "sdic_erro")
  expect_match(conditionMessage(e), "Sem resposta")
  expect_false(grepl("segredo", conditionMessage(e)))
  expect_null(e$status_code)
})

test_that("resposta que não é JSON vira erro claro", {
  ambiente_limpo()
  responde(list(httr2::response(status_code = 200L, body = charToRaw("<html>manutenção</html>"))))
  expect_error(ClienteAPI$new(base_url = "https://x")$.make_request("/r"), "não é um JSON válido", class = "sdic_erro")
})

test_that("paginação por proxima_pagina", {
  ambiente_limpo()
  registro <- responde(list(resposta_json(list(items = list(list(a = 1)), proxima_pagina = 2)),
                            resposta_json(list(items = list(list(a = 2)), proxima_pagina = NULL))))
  itens <- ClienteAPI$new(base_url = "https://x")$.fetch_all_paginated_get("/series/s", list())
  expect_equal(itens, list(list(a = 1L), list(a = 2L)))
  paginas <- vapply(registro$chamadas, function(r) httr2::url_parse(r$url)$query$pagina, character(1))
  expect_equal(paginas, c("1", "2"))
})

test_that("paginação por count", {
  ambiente_limpo()
  responde(list(resposta_json(list(count = 3, items = list(list(a = 1), list(a = 2)))),
                resposta_json(list(count = 3, items = list(list(a = 3))))))
  expect_length(ClienteAPI$new(base_url = "https://x")$.fetch_all_paginated_get("/r", list(tamanho_pagina = 2)), 3)
})

test_that("paginação por total de páginas e por página curta", {
  ambiente_limpo()
  registro <- responde(list(resposta_json(list(pages = 2, items = list(list(a = 1), list(a = 2)))),
                            resposta_json(list(pages = 2, items = list(list(a = 3), list(a = 4))))))
  expect_length(ClienteAPI$new(base_url = "https://x")$.fetch_all_paginated_get("/r", list(tamanho_pagina = 2)), 4)
  expect_length(registro$chamadas, 2)
  registro <- responde(list(resposta_json(list(list(a = 1)))))  # lista pura, menor que a página
  expect_length(ClienteAPI$new(base_url = "https://x")$.fetch_all_paginated_get("/r", list(tamanho_pagina = 2)), 1)
  expect_length(registro$chamadas, 1)
})

test_that("resultado menor que o count avisa", {
  ambiente_limpo()
  responde(list(resposta_json(list(count = 10, items = list(list(a = 1))))))
  expect_warning(ClienteAPI$new(base_url = "https://x")$.fetch_all_paginated_get("/r", list(tamanho_pagina = 5)),
                 "informou 10 registros e vieram 1")
})

test_that("página sem lista de itens é erro, e não fim", {
  ambiente_limpo()
  responde(list(resposta_json(list(count = 5000, items = list(list(a = 1), list(a = 1)))),
                resposta_json(list(mensagem = "algo deu errado"))))
  expect_error(ClienteAPI$new(base_url = "https://x")$.fetch_all_paginated_get("/r", list(tamanho_pagina = 2)),
               "sem a lista de itens", class = "sdic_erro")
})

test_that("falha no meio da paginação propaga", {
  ambiente_limpo()
  responde(list(resposta_json(list(count = 4, items = list(list(a = 1), list(a = 2)))),
                resposta_json(list(), 503L)))
  e <- tryCatch(ClienteAPI$new(base_url = "https://x")$.fetch_all_paginated_get("/r", list(tamanho_pagina = 2)),
                error = function(e) e)
  expect_s3_class(e, "sdic_erro")
  expect_equal(e$status_code, 503L)
})

test_that("cache não serve resposta de uma chave a outra", {
  ambiente_limpo()
  withr::local_envvar(SDIC_CACHE_TTL = "60")
  registro <- responde(list(resposta_json(list(v = 1)), resposta_json(list(v = 2))))
  expect_equal(ClienteAPI$new(base_url = "https://x", api_key = "chave-a")$.make_request("/r"), list(v = 1L))
  expect_equal(ClienteAPI$new(base_url = "https://x", api_key = "chave-a")$.make_request("/r"), list(v = 1L))  # do cache
  expect_equal(ClienteAPI$new(base_url = "https://x")$.make_request("/r"), list(v = 2L))  # sem chave: vai à API
  expect_length(registro$chamadas, 2)
})

test_that("cache em disco não contém a chave: só o corpo JSON, em pasta 0700", {
  pasta <- ambiente_limpo()
  withr::local_envvar(SDIC_CACHE_TTL = "60")
  responde(list(resposta_json(list(v = 1))))
  ClienteAPI$new(base_url = "https://x", api_key = "segredo-no-cache")$.make_request("/r")
  arquivos <- list.files(file.path(pasta, "cache"), full.names = TRUE)
  expect_length(arquivos, 1)
  expect_match(arquivos, "\\.json$")
  bruto <- readBin(arquivos, "raw", file.size(arquivos))
  # nem em texto nem dentro de um objeto R serializado (o cache antigo gravava a requisição em .rds)
  expect_false(grepl("segredo-no-cache", paste(c(rawToChar(bruto[bruto != as.raw(0)]), basename(arquivos)), collapse = ""),
                     fixed = TRUE, useBytes = TRUE))
  expect_equal(jsonlite::fromJSON(arquivos), list(v = 1L))
  skip_on_os("windows")
  expect_equal(as.character(file.mode(file.path(pasta, "cache"))), "700")
})

test_that("requisição repete em falha transitória e só envia Bearer", {
  ambiente_limpo()
  req <- .sdic_requisicao("https://x/r", 30, "k")
  expect_equal(req$policies$retry_max_tries, 4)
  for (status in c(429L, 502L, 503L, 504L)) {
    expect_true(req$policies$retry_is_transient(httr2::response(status_code = status)))
  }
  expect_false(req$policies$retry_is_transient(httr2::response(status_code = 500L)))
  cabecalhos <- cabecalhos_da_requisicao(req)
  expect_equal(cabecalhos$Authorization, "Bearer k")
  expect_false("x-api-key" %in% tolower(names(cabecalhos)))
  expect_match(cabecalhos$`User-Agent`, as.character(utils::packageVersion("sdic.libraries")), fixed = TRUE)
  expect_false("Authorization" %in% names(cabecalhos_da_requisicao(.sdic_requisicao("https://x/r", 30))))
  expect_false(grepl("Bearer k", paste(capture.output(print(req)), collapse = "\n"), fixed = TRUE))
})

test_that("sem chave, nenhum Authorization é enviado (nem 'Bearer ' vazio)", {
  ambiente_limpo()
  registro <- responde(list(resposta_json(list()), resposta_json(list())))
  Emprego$new(base_url = "https://x")$.make_request("/r")
  Comex$new(base_url = "https://x", api_key = "")$.make_post_request("/r", list(a = 1))
  for (req in registro$chamadas) expect_false("Authorization" %in% names(cabecalhos_da_requisicao(req)))
  expect_equal(registro$chamadas[[2]]$method, "POST")
})

test_that("arquivo publicado ausente vira sdic_nao_publicado", {
  ambiente_limpo()
  origem_falsa(list("homologacao/SP/emprego.json" = list(ok = TRUE)))
  expect_equal(ler_json_publicado("dados", "homologacao/SP/emprego.json"), list(ok = TRUE))
  e <- tryCatch(ler_json_publicado("dados", "producao/SP/emprego.json"), error = function(e) e)
  expect_s3_class(e, c("sdic_nao_publicado", "sdic_erro"), exact = FALSE)
  expect_match(conditionMessage(e), "https://storage.googleapis.com/fast-sdic-dados/producao/SP/emprego.json", fixed = TRUE)
  expect_equal(e$status_code, 404L)
  expect_error(ler_json_publicado("outra", "a.json"), "Origem desconhecida", class = "sdic_valor_invalido")
})

test_that("arquivo publicado nunca leva a chave; base_url explícita vale", {
  ambiente_limpo()
  withr::local_envvar(SDIC_API_KEY = "k")
  registro <- responde(list(resposta_json(list()), resposta_json(list())))
  ler_json_publicado("dados", "a.json")
  ler_json_publicado("politicas", "/b.json", base_url = "https://outro.exemplo/pasta/")
  expect_false("Authorization" %in% names(cabecalhos_da_requisicao(registro$chamadas[[1]])))
  expect_equal(registro$chamadas[[2]]$url, "https://outro.exemplo/pasta/b.json")
})

test_that("estoque estimado não engole falha do saldo de um ano", {
  ambiente_limpo()
  falha <- function(...) rlang::abort("503", class = "sdic_erro", status_code = 503L)
  testthat::local_mocked_bindings(get_saldo_emprego_nacional_mensal_agrupado = falha,
                                  get_saldo_emprego_nacional_anual = falha)
  expect_error(.get_grouped_annual_saldo_data("nacional", "g", "10", 2024, 2024), "saldo de 2024", class = "sdic_erro")
  e <- tryCatch(.get_annual_saldo_data("nacional", "divisao", "10", 2024, 2025), error = function(e) e)
  expect_match(conditionMessage(e), "saldo de 2024")
  expect_equal(e$status_code, 503L)
})

test_that("saldo anual agrupado soma os meses do ano", {
  ambiente_limpo()
  mensal <- function(nome_grupo, lista_cnae, data_minima) {
    tibble::tibble(competencia = c("2024-01-01", "2024-02-01", "2025-01-01"), nome_grupo = nome_grupo,
                   saldo_reajustado = c(10, 5, 100))
  }
  testthat::local_mocked_bindings(get_saldo_emprego_nacional_mensal_agrupado = mensal)
  df <- .get_grouped_annual_saldo_data("nacional", "g", "10", 2024, 2025)
  expect_equal(df$ano, c(2024, 2025))
  expect_equal(df$saldo_reajustado, c(15, 100))
})

test_that("portal antigo: avisa a depreciação, só arquivo ausente é opcional e faltas são avisadas", {
  ambiente_limpo()
  kpis <- list(kpis = list(list(id = "a", value = 1)))
  origem_falsa(list("producao/SP/emprego.json" = kpis, "producao/RJ/emprego.json" = kpis))
  expect_warning(get_portal_emprego_kpis_estadual("SP"), "get_kpis_publicados", class = "deprecatedWarning")
  avisos <- character()
  df <- withCallingHandlers(get_portal_emprego_kpis_todos_estados(),
                            warning = function(w) { avisos <<- c(avisos, conditionMessage(w)); invokeRestart("muffleWarning") })
  expect_equal(sort(unique(df$uf)), c("RJ", "SP"))
  expect_true(any(grepl("Sem arquivo publicado para 25 UF", avisos)))
  expect_equal(suppressWarnings(listar_estados_disponiveis()), c("RJ", "SP"))
  expect_error(suppressWarnings(get_portal_emprego_estadual("AC")), class = "sdic_nao_publicado")
  withr::local_envvar(SDIC_AMBIENTE = "homologacao")
  expect_error(suppressWarnings(get_portal_emprego_estadual("SP")), "homologacao/SP/emprego.json")
  # falha de rede não é "UF sem arquivo": vira erro
  httr2::local_mocked_responses(function(req) resposta_json(list(), 500L))
  expect_error(suppressWarnings(get_relatorio_emprego_saldo_todos_estados()), class = "sdic_erro")
})
