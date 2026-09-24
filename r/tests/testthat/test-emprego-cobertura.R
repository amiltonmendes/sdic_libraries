# Cobertura completa dos métodos da API de emprego (RAIS/CAGED) via sdic.libraries.
#
# Objetivo: garantir que TODO endpoint com a tag "Emprego" na sdic_api (mais
# /data_bases, ligado ao bug do RAIS já corrigido) tem pelo menos um método
# na biblioteca R que o exercita com sucesso contra uma API real.
#
# Bate numa sdic_api real (EMPLOYMENT_API_BASE_URL, padrão
# http://127.0.0.1:8123) e pula a suíte inteira se ela não estiver acessível
# — mesma convenção de test-emprego.R. Inclui o nível municipal do saldo
# CAGED, que só passou a funcionar depois da correção do cast STRING/INT64
# em _aplicar_filtros_base (sdic_api).

.cobertura_base_url <- Sys.getenv("EMPLOYMENT_API_BASE_URL", "http://127.0.0.1:8123")
.cobertura_uf <- "SP"
.cobertura_municipio <- 3550308  # município de São Paulo

.skip_se_api_indisponivel_cobertura <- function(api) {
  disponivel <- tryCatch({
    api$get_date_bases()
    TRUE
  }, error = function(e) FALSE)

  if (!disponivel) {
    testthat::skip(paste0("sdic_api indisponível em ", .cobertura_base_url))
  }
}

# ===== Estoque RAIS básico: nacional/estadual x básico/lista_cnae/grupos_cnae =====

test_that("estoque nacional e estadual (basico) retornam dados", {
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  expect_true(length(api$get_estoque_emprego_nacional(codigos_cnae = "47")) > 0)
  expect_true(length(api$get_estoque_emprego_estadual(ufs = .cobertura_uf, codigos_cnae = "47")) > 0)
})

test_that("estoque lista_cnae cobre nacional e estadual", {
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  nacional <- api$get_estoque_emprego_lista_cnae_agregado(codigos_cnae = "47")
  estadual <- api$get_estoque_emprego_lista_cnae_agregado(codigos_cnae = "47", ufs = .cobertura_uf)
  expect_true(length(nacional) > 0)
  expect_true(length(estadual) > 0)
})

test_that("estoque grupos_cnae cobre nacional e estadual", {
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  grupos <- list(list(nome_grupo = "Comercio", codigos_cnae = "47"))
  nacional <- api$get_estoque_emprego_grupos_cnae(grupos_cnae = grupos)
  estadual <- api$get_estoque_emprego_grupos_cnae(grupos_cnae = grupos, ufs = .cobertura_uf)
  expect_true(length(nacional) > 0)
  expect_true(length(estadual) > 0)
})

# ===== 7 endpoints novos: porte x2, classe_cnae x2, uf_cbo, renda_media, potec =====

test_that("estoque por porte nacional e estadual retornam dados", {
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  expect_true(length(api$get_estoque_emprego_porte_nacional(codigos_cnae = "47")) > 0)
  expect_true(length(api$get_estoque_emprego_porte_estadual(ufs = .cobertura_uf, codigos_cnae = "47")) > 0)
})

test_that("estoque por classe CNAE nacional e estadual retornam dados", {
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  expect_true(length(api$get_estoque_emprego_classe_cnae_nacional(codigos_classe = "4711")) > 0)
  expect_true(length(api$get_estoque_emprego_classe_cnae_estadual(ufs = .cobertura_uf, codigos_classe = "4711")) > 0)
})

test_that("estoque por UF e CBO, renda media e potec retornam dados", {
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  expect_true(length(api$get_estoque_emprego_uf_cbo(siglas_uf = .cobertura_uf, codigos_classe = "4711")) > 0)
  expect_true(length(api$get_renda_media_emprego(tipos = "Geral")) > 0)
  expect_true(length(api$get_potec_emprego(codigos_classe = "7210")) > 0)
})

# ===== 9 endpoints: {nacional,estadual,municipal} x {divisao,grupo,subclasse} =====

test_that("saldo CAGED nacional e estadual retornam dados nos 3 niveis CNAE", {
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  expect_true(length(api$get_saldo_caged_nacional_divisao(codigos = "47")) > 0)
  expect_true(length(api$get_saldo_caged_nacional_grupo(codigos = "471")) > 0)
  expect_true(length(api$get_saldo_caged_nacional_subclasse(codigos = "4711301")) > 0)

  expect_true(length(api$get_saldo_caged_estadual_divisao(siglas_uf = .cobertura_uf, codigos = "47")) > 0)
  expect_true(length(api$get_saldo_caged_estadual_grupo(siglas_uf = .cobertura_uf, codigos = "471")) > 0)
  expect_true(length(api$get_saldo_caged_estadual_subclasse(siglas_uf = .cobertura_uf, codigos = "4711301")) > 0)
})

test_that("REGRESSAO: saldo CAGED municipal retorna dados nos 3 niveis CNAE", {
  # Quebrava com 500 (IN UNNEST STRING vs ARRAY<INT64>) antes da correção
  # de cast em cod_municipio (_aplicar_filtros_base, sdic_api).
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  divisao <- api$get_saldo_caged_municipal_divisao(codigos_municipio = .cobertura_municipio, codigos = "47")
  grupo <- api$get_saldo_caged_municipal_grupo(codigos_municipio = .cobertura_municipio, codigos = "471")
  subclasse <- api$get_saldo_caged_municipal_subclasse(codigos_municipio = .cobertura_municipio, codigos = "4711301")

  expect_true(length(divisao) > 0)
  expect_true(length(grupo) > 0)
  expect_true(length(subclasse) > 0)

  cods_municipio <- vapply(divisao, function(x) x$cod_municipio, integer(1))
  expect_true(all(cods_municipio == .cobertura_municipio))
})

# ===== lista_codigos / grupos_codigos genéricos, nos 3 niveis de agregação =====

test_that("saldo CAGED detalhado (lista_cnae) cobre nacional, estadual e municipal", {
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  nacional <- api$get_saldo_emprego_detalhado_lista_cnae(
    lista_cnae = "47", nome_grupo = "Comercio", nivel_agregacao = "nacional", nivel_cnae = 2
  )
  estadual <- api$get_saldo_emprego_detalhado_lista_cnae(
    lista_cnae = "47", nome_grupo = "Comercio", nivel_agregacao = "estadual", sigla_uf = .cobertura_uf, nivel_cnae = 2
  )
  municipal <- api$get_saldo_emprego_detalhado_lista_cnae(
    lista_cnae = "47", nome_grupo = "Comercio", nivel_agregacao = "municipal", municipio = .cobertura_municipio, nivel_cnae = 2
  )

  expect_true(length(nacional) > 0)
  expect_true(length(estadual) > 0)
  expect_true(length(municipal) > 0)
})

test_that("saldo CAGED detalhado (grupos_cnae) cobre nacional, estadual e municipal", {
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  grupos <- list(list(nome_grupo = "Comercio", codigos_cnae = "47"))

  nacional <- api$get_saldo_emprego_detalhado_grupos_cnae(
    grupos_cnae = grupos, nivel_agregacao = "nacional", nivel_cnae = 2
  )
  estadual <- api$get_saldo_emprego_detalhado_grupos_cnae(
    grupos_cnae = grupos, nivel_agregacao = "estadual", sigla_uf = .cobertura_uf, nivel_cnae = 2
  )
  municipal <- api$get_saldo_emprego_detalhado_grupos_cnae(
    grupos_cnae = grupos, nivel_agregacao = "municipal", municipio = .cobertura_municipio, nivel_cnae = 2
  )

  expect_true(length(nacional) > 0)
  expect_true(length(estadual) > 0)
  expect_true(length(municipal) > 0)
})

# ===== Metadados =====

test_that("get_date_bases inclui ComexStat, CAGED e RAIS", {
  api <- Emprego$new(base_url = .cobertura_base_url)
  .skip_se_api_indisponivel_cobertura(api)

  bases <- vapply(api$get_date_bases(), function(x) x$Base, character(1))
  expect_true(all(c("ComexStat", "CAGED", "RAIS") %in% bases))
})
