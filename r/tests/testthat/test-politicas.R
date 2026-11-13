# Políticas do gaia_nib. Arquivos reais (recortados) em contrato/politicas_amostras.json, o
# mesmo dos testes em Python.

C <- amostras("politicas")
E <- C$esperado

preparar <- function(env = parent.frame()) {
  ambiente_limpo(env)
  origem_falsa(C$arquivos, env)
}

test_that("contrato compartilhado está disponível", {
  skip_if(is.null(C), "contrato/ fora do pacote instalado")
  expect_gt(length(C$arquivos), 0)
})

test_that("listar_politicas na ordem publicada, com permitida", {
  skip_if(is.null(C)); preparar()
  e <- E$listar_politicas
  df <- do.call(listar_politicas, e$args)
  iniciais <- unlist(e$colunas_iniciais)
  expect_equal(names(df)[seq_along(iniciais)], iniciais)
  expect_equal(names(df)[ncol(df)], "permitida")
  expect_equal(df$id, unlist(e$ids))  # ordem do catálogo, nunca reordenada
  expect_equal(df$id[df$permitida], unlist(e$permitidas))
  expect_type(df$regionalizavel, "logical")
})

test_that("get_politica: uma linha por indicador", {
  skip_if(is.null(C)); preparar()
  e <- E$get_politica
  df <- do.call(get_politica, e$args)
  expect_s3_class(df, "tbl_df")
  expect_equal(names(df), unlist(e$colunas))
  expect_equal(nrow(df), e$linhas)
  expect_equal(df$papel[1], "capa")
  expect_equal(df$valor_exibido[1], e$capa_valor_exibido)
  expect_true(all(df$uf == "SP"))
  expect_type(df$valor, "double")
})

test_that("get_politica nacional", {
  skip_if(is.null(C)); preparar()
  e <- E$get_politica_nacional
  df <- get_politica(e$args$id, uf = e$args$uf, ambiente = e$args$ambiente)
  expect_equal(df$papel, unlist(e$papeis))
  expect_true(all(df$uf == "BRASIL"))
})

test_that("política sem dado para a unidade devolve vazio com as colunas", {
  skip_if(is.null(C)); preparar()
  df <- do.call(get_politica, E$get_politica_ausente$args)
  expect_equal(nrow(df), 0)
  expect_equal(names(df), unlist(E$get_politica$colunas))
  expect_null(do.call(get_politica_publicada, E$get_politica_ausente$args))
  expect_type(do.call(get_politica_publicada, E$get_politica$args), "list")
})

test_that("get_politicas_estado", {
  skip_if(is.null(C)); preparar()
  e <- E$get_politicas_estado
  df <- do.call(get_politicas_estado, e$args)
  expect_equal(nrow(df), e$linhas)
  expect_equal(unique(df$policy_id), unlist(e$policy_ids))
  expect_equal(nrow(do.call(get_politicas_estado, c(e$args, so_permitidas = TRUE))), e$linhas)
})

test_that("get_resumo_politicas", {
  skip_if(is.null(C)); preparar()
  e <- E$get_resumo_politicas
  df <- do.call(get_resumo_politicas, e$args)
  expect_equal(names(df), unlist(e$colunas))
  expect_equal(nrow(df), 1)
  expect_equal(df$n_politicas, e$n_politicas)
  expect_equal(df$recursos_exibido, e$recursos_exibido)
  vazio <- get_resumo_politicas("AC", ambiente = "homologacao")
  expect_equal(nrow(vazio), 0)
  expect_equal(names(vazio), unlist(e$colunas))
})

test_that("municípios e manifesto", {
  skip_if(is.null(C)); preparar()
  m <- do.call(get_municipios_elegiveis, E$get_municipios_elegiveis$args)
  expect_equal(names(m), unlist(E$get_municipios_elegiveis$colunas))
  expect_equal(nrow(m), E$get_municipios_elegiveis$linhas)
  expect_type(m$ibge, "character")
  expect_true(all(nchar(m$ibge) == 7))
  e <- E$get_manifesto_politicas
  man <- do.call(get_manifesto_politicas, e$args)
  expect_equal(names(man), unlist(e$colunas))
  expect_equal(nrow(man), e$linhas)
  expect_equal(man$valor[man$campo == "rotulo_fonte"], e$rotulo_fonte)
})

test_that("produção sem políticas dá erro que diz o que fazer", {
  skip_if(is.null(C)); preparar()
  expect_error(listar_politicas(), "não estão publicadas em 'producao'", class = "sdic_nao_publicado")
})
