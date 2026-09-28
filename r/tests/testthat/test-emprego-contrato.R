# Contrato do esquema de emprego (R): `contrato/emprego_amostras.json`, o mesmo lido pelo Python.
# Passa a linha da API pelo caminho real (req_perform mockado -> cliente -> função exportada).

contrato_emprego <- testthat::test_path("..", "..", "..", "contrato", "emprego_amostras.json")
casos_emprego <- if (file.exists(contrato_emprego)) jsonlite::fromJSON(contrato_emprego, simplifyVector = FALSE)$casos else list()

verifica_tipo_emprego <- list(int = is.integer, num = is.numeric, str = is.character)

for (caso in casos_emprego) {
  local({
    caso <- caso
    test_that(paste("esquema padronizado:", caso$funcao), {
      corpo <- jsonlite::toJSON(list(count = 1, items = list(caso$linha)), auto_unbox = TRUE, null = "null")
      testthat::local_mocked_bindings(
        req_perform = function(req, ...) {
          httr2::response(status_code = 200, headers = list("Content-Type" = "application/json"),
                          body = charToRaw(as.character(corpo)))
        },
        .package = "httr2"
      )
      df <- do.call(get(caso$funcao, envir = asNamespace("sdic.libraries")), caso$kwargs)

      esperado <- caso$colunas
      expect_setequal(names(df), names(esperado))
      for (col in names(esperado)) {
        if (!all(is.na(df[[col]]))) {
          expect_true(verifica_tipo_emprego[[esperado[[col]]]](df[[col]]),
                      info = paste(col, "esperado", esperado[[col]]))
        }
      }
    })
  })
}

test_that("faixa de anos vale mesmo se a API implantada ignorar o filtro", {
  linhas <- lapply(2023:2025, function(a) list(ano = a, divisao_cnae_cod = "10", estoque_trabalhadores = 1))
  corpo <- jsonlite::toJSON(list(count = 3, items = linhas), auto_unbox = TRUE)  # API antiga: devolve tudo
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) httr2::response(status_code = 200, headers = list("Content-Type" = "application/json"),
                                                     body = charToRaw(as.character(corpo))),
    .package = "httr2"
  )
  expect_equal(get_estoque_emprego_nacional(nivel_cnae = 2, agregado = TRUE, ano_minimo = 2024, ano_maximo = 2024)$ano, 2024L)
  expect_equal(get_estoque_emprego_nacional(nivel_cnae = 2, agregado = TRUE, ano_minimo = 2024)$ano, c(2024L, 2025L))
  expect_equal(nrow(get_estoque_emprego_nacional(nivel_cnae = 2, agregado = TRUE)), 3)
})
