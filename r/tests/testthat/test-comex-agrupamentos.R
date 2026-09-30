# Comex "agrupamentos" (R) — monta a URL/params certos; sem rede real.
#
# Pendente de deploy na sdic_api (2026-09-29, ver TODO.md) — estes testes fixam o
# contrato que o cliente já implementa, para não regredir enquanto a API não sobe.
# Usa os helpers `mock_response`/`mock_req_perform` de test-comex.R.

test_that("get_exportacao_agrupamentos monta url e params", {
  registro <- new.env()
  registro$chamadas <- list()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(mock_response(list(count = 0, items = list()))), registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste")
  api$get_exportacao_agrupamentos("Moda", ano_minimo = 2024, anos = c(2024, 2025), departamento = "Dep. X", cg = "CG Y")

  url <- registro$chamadas[[1]]$url
  expect_true(grepl("^https://sdicapi\\.teste/exportacao_agrupamentos", url))
  expect_true(grepl("agrupamento=Moda", url))
  expect_true(grepl("ano_minimo=2024", url))
  expect_true(grepl("anos=2024%2C2025|anos=2024,2025", url))
  expect_true(grepl("departamento=Dep", url))
  expect_true(grepl("cg=CG", url))
})

test_that("get_importacao_agrupamentos sem filtros opcionais so manda agrupamento", {
  registro <- new.env()
  registro$chamadas <- list()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(mock_response(list(count = 0, items = list()))), registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste")
  api$get_importacao_agrupamentos("Moda")

  url <- registro$chamadas[[1]]$url
  expect_true(grepl("agrupamento=Moda", url))
  expect_false(grepl("departamento=", url))
  expect_false(grepl("cg=", url))
})

test_that("get_exportacao_agrupamentos_pais_ncm repassa nivel_agregacao e posicao", {
  registro <- new.env()
  registro$chamadas <- list()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(mock_response(list(count = 0, items = list()))), registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste")
  api$get_exportacao_agrupamentos_pais_ncm("Moda", nivel_agregacao = "setor", posicao = 5, agregado_ano = TRUE)

  url <- registro$chamadas[[1]]$url
  expect_true(grepl("nivel_agregacao=setor", url))
  expect_true(grepl("posicao=5", url))
  expect_true(grepl("agregado_ano=TRUE|agregado_ano=true", url))
})

test_that("get_agrupamentos_disponiveis e uma chamada so, com filtro opcional", {
  registro <- new.env()
  registro$chamadas <- list()
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(mock_response(list(
      list(Agrupamento = "Moda", Departamento = "Dep. X", CoordenacaoGeral = "CG Y")
    ))), registro),
    .package = "httr2"
  )

  api <- Comex$new(base_url = "https://sdicapi.teste")
  resultado <- api$get_agrupamentos_disponiveis(departamento = "Dep. X")

  expect_equal(length(registro$chamadas), 1)  # não pagina - é um catálogo pequeno
  url <- registro$chamadas[[1]]$url
  expect_true(grepl("^https://sdicapi\\.teste/agrupamentos_disponiveis", url))
  expect_true(grepl("departamento=Dep", url))
  expect_equal(resultado[[1]]$Agrupamento, "Moda")
})

test_that("funcoes de modulo devolvem tibble com departamento e coordenacao_geral", {
  registro <- new.env()
  registro$chamadas <- list()
  linha <- list(Ano = 2026, Agrupamento = "Moda", Setor = "Têxtil", Subsetor = "Fios", Produto = "Algodão",
                Departamento = "Dep. X", CoordenacaoGeral = "CG Y", VLFob = 1, QTEstat = 1, KGLiquido = 1)
  testthat::local_mocked_bindings(
    req_perform = mock_req_perform(list(mock_response(list(count = 1, items = list(linha)))), registro),
    .package = "httr2"
  )

  df <- get_exportacao_agrupamentos(agrupamento = "Moda")
  expect_setequal(names(df), c("ano", "mes", "agrupamento", "setor", "subsetor", "produto",
                               "departamento", "coordenacao_geral", "vl_fob",
                               "quantidade_estatistica", "kg_liquido"))
})
