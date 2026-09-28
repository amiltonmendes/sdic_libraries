# juntar_emprego_comex: chave (ano, divisão), soma do comex antes da união, validação de colunas.

emprego_j <- tibble::tibble(ano = 2025L, divisao_cnae_cod = c("10", "47", "24"), estoque_trabalhadores = c(100L, 500L, 40L))
# comex com várias linhas por (ano, divisão): meses/UFs — não pode multiplicar o emprego
comex_j <- tibble::tibble(ano = 2025L, divisao_isic_cod = c("10", "10", "24", "89"),
                          vl_fob = c(1, 2, 5, 9), kg_liquido = c(10, 20, 50, 90))

test_that("soma o comex e não multiplica linhas do emprego", {
  r <- juntar_emprego_comex(emprego_j, comex_j)
  expect_equal(nrow(r), 3)
  dez <- r[r$divisao_cnae_cod == "10", ]
  expect_equal(c(dez$vl_fob, dez$kg_liquido, dez$estoque_trabalhadores), c(3, 30, 100))
})

test_that("left mantém serviços com comex NA; inner descarta; full traz a 89", {
  expect_true(is.na(juntar_emprego_comex(emprego_j, comex_j)$vl_fob[2]))
  expect_setequal(juntar_emprego_comex(emprego_j, comex_j, "inner")$divisao_cnae_cod, c("10", "24"))
  expect_true("89" %in% juntar_emprego_comex(emprego_j, comex_j, "full")$divisao_cnae_cod)
})

test_that("coluna faltando dá erro claro", {
  expect_error(juntar_emprego_comex(emprego_j, comex_j[, c("ano", "vl_fob")]), "comex sem a\\(s\\) coluna\\(s\\) divisao_isic_cod")
  expect_error(juntar_emprego_comex(emprego_j[, "divisao_cnae_cod"], comex_j), "emprego sem a\\(s\\) coluna\\(s\\) ano")
})
