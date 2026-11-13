# Seções publicadas. Arquivos reais em contrato/publicados_amostras.json, o mesmo dos testes
# em Python.

C <- amostras("publicados")
E <- C$esperado

preparar <- function(env = parent.frame()) {
  ambiente_limpo(env)
  origem_falsa(C$arquivos, env)
}

test_that("contrato compartilhado está disponível", {
  skip_if(is.null(C), "contrato/ fora do pacote instalado")
  expect_gt(length(C$arquivos), 0)
})

for (funcao in c("get_kpis_publicados", "get_series_publicadas", "get_ranking_publicado",
                 "get_detalhamento_publicado", "get_destaques_publicados", "get_atualizacao_publicada")) {
  local({
    funcao <- funcao
    test_that(paste("colunas e linhas do contrato:", funcao), {
      skip_if(is.null(C)); preparar()
      df <- do.call(funcao, E[[funcao]]$args)
      expect_s3_class(df, "tbl_df")
      expect_equal(names(df), unlist(E[[funcao]]$colunas))
      expect_equal(nrow(df), E[[funcao]]$linhas)
      expect_equal(names(df), .sdic_colunas_de(funcao))  # as do catálogo
    })
  })
}

test_that("kpis: capa primeiro, com fonte e referência", {
  skip_if(is.null(C)); preparar()
  df <- do.call(get_kpis_publicados, E$get_kpis_publicados$args)
  primeira <- E$get_kpis_publicados$primeira
  expect_equal(as.list(df[1, names(primeira)]), primeira)
  expect_equal(sum(df$capa), 1)
  expect_true(all(df$uf == "SP") && all(df$secao == "emprego"))
  expect_type(df$valor, "double")
  expect_type(df$capa, "logical")
})

test_that("destaques trocam os marcadores pelos valores", {
  skip_if(is.null(C)); preparar()
  textos <- do.call(get_destaques_publicados, E$get_destaques_publicados$args)$texto
  expect_false(any(grepl("{{", textos, fixed = TRUE)))
})

test_that("ranking numera na ordem publicada", {
  skip_if(is.null(C)); preparar()
  df <- do.call(get_ranking_publicado, E$get_ranking_publicado$args)
  expect_type(df$posicao, "integer")
  expect_true(all(df$posicao[!duplicated(df$lista)] == 1L))
})

test_that("Brasil e sinônimos", {
  skip_if(is.null(C)); preparar()
  for (uf in list("BRASIL", "br", NULL)) {
    expect_equal(nrow(get_kpis_publicados(uf, "pib_nacional", ambiente = "homologacao")), E$brasil$linhas_kpis)
  }
  expect_error(get_secao_publicada("SP", "pib_nacional", ambiente = "homologacao"), "só existe para o Brasil",
               class = "sdic_valor_invalido")
})

test_that("ambiente vem da variável quando não informado", {
  skip_if(is.null(C)); origem <- preparar()
  withr::local_envvar(SDIC_AMBIENTE = "homologacao")
  get_kpis_publicados("SP", "emprego")
  expect_match(utils::tail(origem$urls, 1), "/homologacao/SP/emprego.json", fixed = TRUE)
})

test_that("produção vazia dá erro que diz o que fazer", {
  skip_if(is.null(C)); preparar()
  expect_error(get_kpis_publicados("SP", "emprego"), "não está publicada em 'producao'.*homologacao",
               class = "sdic_nao_publicado")
})

test_that("troca de local (SDIC_DADOS_URL) é transparente", {
  skip_if(is.null(C)); origem <- preparar()
  withr::local_envvar(SDIC_DADOS_URL = "https://dados.exemplo.gov.br/novo-bucket/")
  df <- get_kpis_publicados("SP", "emprego", ambiente = "homologacao")
  expect_equal(nrow(df), E$get_kpis_publicados$linhas)
  expect_equal(utils::tail(origem$urls, 1), "https://dados.exemplo.gov.br/novo-bucket/homologacao/SP/emprego.json")
})

test_that("entradas inválidas", {
  skip_if(is.null(C)); preparar()
  expect_error(get_secao_publicada("SP", "pib"), "Seção desconhecida", class = "sdic_valor_invalido")
  expect_error(get_secao_publicada("XX", "emprego"), "UF inválida", class = "sdic_valor_invalido")
})

test_that("contrato de versão maior é recusado", {
  ambiente_limpo()
  origem_falsa(list("homologacao/SP/emprego.json" = list(schema_version = "2.0")))
  expect_error(get_secao_publicada("SP", "emprego", ambiente = "homologacao"), "contrato 2.0")
})

test_that("seção sem itens devolve tabelas vazias com as colunas", {
  ambiente_limpo()
  origem_falsa(list("homologacao/SP/emprego.json" = list(schema_version = "1.1")))
  for (funcao in c("get_kpis_publicados", "get_series_publicadas", "get_ranking_publicado",
                   "get_detalhamento_publicado", "get_destaques_publicados")) {
    df <- do.call(funcao, list("SP", "emprego", ambiente = "homologacao"))
    expect_equal(nrow(df), 0)
    expect_equal(names(df), .sdic_colunas_de(funcao))
  }
})

test_that("get_secao_publicada devolve a lista como publicada", {
  skip_if(is.null(C)); preparar()
  p <- get_secao_publicada("sp", "emprego", ambiente = "homologacao")
  expect_type(p, "list")
  expect_equal(p$reference, E$get_kpis_publicados$primeira$referencia)
})

test_that("listar_secoes_publicadas", {
  ambiente_limpo()
  df <- listar_secoes_publicadas()
  expect_setequal(df$secao, c("emprego", "pib_estadual", "comercio", "comercio_ue", "producao_industrial", "pib_nacional"))
  expect_equal(names(df), c("secao", "titulo", "unidades", "fonte"))
})
