# listar_bases(): toda função catalogada precisa existir de verdade (senão o catálogo mente).

test_that("não vazio e colunas esperadas", {
  df <- listar_bases()
  expect_gt(nrow(df), 0)
  expect_equal(names(df), c("tema", "subtema", "nivel", "funcao", "descricao", "exemplo"))
})

test_that("toda função catalogada existe e é exportada", {
  df <- listar_bases()
  for (i in seq_len(nrow(df))) {
    funcao <- df$funcao[i]
    expect_true(exists(funcao, envir = asNamespace("sdic.libraries"), mode = "function"),
                info = paste(funcao, "catalogada mas não existe"))
    expect_true(funcao %in% getNamespaceExports("sdic.libraries"), info = paste(funcao, "não exportada"))
  }
})

test_that("filtro por tema e subtema", {
  expect_equal(unique(listar_bases(tema = "comex")$tema), "comex")
  expect_lt(nrow(listar_bases(tema = "comex")), nrow(listar_bases()))
  expect_equal(unique(listar_bases(subtema = "saldo_caged")$subtema), "saldo_caged")
  expect_error(listar_bases(tema = "inexistente"), "tema desconhecido.*comex.*emprego")
})

test_that("descrever: função, base e nome desconhecido", {
  ficha <- descrever("get_kpis_publicados")
  expect_equal(names(ficha), c("campo", "valor"))
  expect_true("coluna: valor_exibido" %in% ficha$campo)
  expect_equal(ficha$valor[ficha$campo == "exemplo"], listar_bases()$exemplo[listar_bases()$funcao == "get_kpis_publicados"])
  expect_true("get_kpis_publicados" %in% descrever("secoes_publicadas")$valor)
  expect_error(descrever("nao_existe"), "não está no catálogo")
})

test_that("o catálogo do pacote é o mesmo arquivo de contrato/", {
  fonte <- testthat::test_path("..", "..", "..", "contrato", "catalogo.json")
  skip_if_not(file.exists(fonte), "contrato/ fora do pacote instalado")
  expect_equal(unname(tools::md5sum(system.file("catalogo.json", package = "sdic.libraries"))), unname(tools::md5sum(fonte)))
})

test_that("sem linha duplicada", {
  df <- listar_bases()
  expect_false(any(duplicated(df[, c("tema", "funcao")])))
})
