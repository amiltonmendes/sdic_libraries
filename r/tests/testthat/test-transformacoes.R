# Regressão: com tibble, df[mask, coluna] devolvia um tibble 1x1 e o índice saía
# como coluna aninhada com valor errado (~120 em todos os anos).
test_that("criar_indice calcula base 100 corretamente em tibble e data.frame", {
  dados <- tibble::tibble(ano = 2019:2021, estoque = c(90, 100, 120))

  for (df in list(dados, as.data.frame(dados))) {
    r <- criar_indice(df, ano_base = 2020, coluna_data = "ano", colunas_valores = "estoque")
    expect_true(is.numeric(r$estoque_indice))
    expect_equal(r$estoque_indice, c(90, 100, 120))
  }
})

test_that("criar_indice usa a média quando o ano base tem várias linhas", {
  dados <- tibble::tibble(ano = c(2020, 2020, 2021), v = c(10, 30, 40))
  r <- criar_indice(dados, 2020, "ano", "v")
  expect_equal(r$v_indice, c(50, 150, 200))
})
