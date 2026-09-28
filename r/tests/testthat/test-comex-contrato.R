# Contrato do esquema Comex (R): `contrato/comex_amostras.json`, o mesmo lido pelo Python.

contrato <- testthat::test_path("..", "..", "..", "contrato", "comex_amostras.json")
casos <- if (file.exists(contrato)) jsonlite::fromJSON(contrato, simplifyVector = FALSE)$casos else list()

verifica_tipo <- list(int = is.integer, num = is.numeric, str = is.character)

test_that("contrato compartilhado está disponível", {
  skip_if_not(file.exists(contrato), "contrato/ fora do pacote instalado")
  expect_gt(length(casos), 0)
})

for (caso in casos) {
  local({
    caso <- caso
    test_that(paste("esquema padronizado:", caso$metodo, if (isTRUE(caso$api_nova)) "(api nova)" else ""), {
      df <- .comex_para_tibble(list(caso$linha), mapa = caso$mapa)
      esperado <- caso$colunas
      expect_setequal(names(df), names(esperado))
      for (col in names(esperado)) {
        if (!all(is.na(df[[col]]))) {
          expect_true(verifica_tipo[[esperado[[col]]]](df[[col]]),
                      info = paste(col, "esperado", esperado[[col]]))
        }
      }
      for (col in names(caso$valores)) expect_equal(df[[col]][1], caso$valores[[col]])
    })

    test_that(paste("função solta existe e é exportada:", caso$metodo), {
      expect_true(is.function(get(caso$metodo, envir = asNamespace("sdic.libraries"))))
      expect_true(caso$metodo %in% getNamespaceExports("sdic.libraries"))
    })
  })
}

test_that("resposta vazia devolve tibble vazio", {
  expect_equal(nrow(.comex_para_tibble(list())), 0)
})

test_that("filtro por seção aceita nome, letra e API nova ou antiga", {
  ncms <- function(mapa, secao) {
    api <- Comex$new()
    api$.__enclos_env__$private$.ncm_isic_mapa_cache <- mapa  # o mapa fica em cache na instância
    api$.ncms_da_secao(secao)
  }
  nova <- list(list(NCM = "01011010", SecaoISIC = "Agropecuária", CodigoSecaoISIC = "A", NomeSecaoISIC = "Agropecuária"))
  antiga <- list(list(NCM = 1011010L, SecaoISIC = "A", NomeSecaoISIC = "Agropecuária"))
  for (caso in list(list(nova, "01011010"), list(antiga, 1011010L))) {
    expect_equal(ncms(caso[[1]], "A"), caso[[2]])
    expect_equal(ncms(caso[[1]], "Agropecuária"), caso[[2]])
  }
})
