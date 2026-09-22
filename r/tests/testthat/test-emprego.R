# Testes de integração dos métodos novos e corrigidos de emprego (RAIS/CAGED).
#
# Ao contrário de test-comex.R (que mocka httr2::req_perform), estes testes
# batem numa sdic_api real, apontada por EMPLOYMENT_API_BASE_URL (padrão:
# http://127.0.0.1:8123, uma instância local de desenvolvimento). Se a API
# não estiver acessível ou ainda não tiver os endpoints novos (ex.: produção
# antes do deploy), a suíte inteira é pulada via skip() em vez de falhar.
#
# Endpoints cobertos:
# - Novos: estoque por porte/setor (nacional/estadual), estoque por classe
#   CNAE (nacional/estadual), estoque por UF+CBO, renda média, índice Potec.
# - Corrigidos: get_estoque_emprego_nacional (antes retornava quebrado por UF
#   por padrão) e get_date_bases (antes omitia a linha "RAIS" silenciosamente).

.emprego_base_url <- Sys.getenv("EMPLOYMENT_API_BASE_URL", "http://127.0.0.1:8123")

.skip_se_api_indisponivel <- function(api) {
  disponivel <- tryCatch({
    api$get_date_bases()
    TRUE
  }, error = function(e) FALSE)

  if (!disponivel) {
    testthat::skip(paste0("sdic_api indisponível ou sem os endpoints novos em ", .emprego_base_url))
  }
}

test_that("estoque por porte nacional agrega sem quebra por UF", {
  api <- Emprego$new(base_url = .emprego_base_url)
  .skip_se_api_indisponivel(api)

  dados <- api$get_estoque_emprego_porte_nacional(nivel_cnae = "divisao", codigos_cnae = "47")
  expect_true(length(dados) > 0)

  siglas_uf <- vapply(dados, function(x) is.null(x$sigla_uf) || is.na(x$sigla_uf %||% NA), logical(1))
  expect_true(all(siglas_uf))

  setores <- vapply(dados, function(x) x$setor, character(1))
  expect_true(all(setores == "Comércio e Serviços"))
})

test_that("estoque por porte estadual filtra pelas UFs informadas", {
  api <- Emprego$new(base_url = .emprego_base_url)
  .skip_se_api_indisponivel(api)

  dados <- api$get_estoque_emprego_porte_estadual(ufs = c("SP", "RJ"), nivel_cnae = "classe", codigos_cnae = "4711")
  expect_true(length(dados) > 0)
  siglas_uf <- vapply(dados, function(x) x$sigla_uf, character(1))
  expect_true(all(siglas_uf %in% c("SP", "RJ")))
})

test_that("nivel_cnae invalido leva a erro", {
  api <- Emprego$new(base_url = .emprego_base_url)
  .skip_se_api_indisponivel(api)

  expect_error(api$get_estoque_emprego_porte_nacional(nivel_cnae = "subclasse"))
})

test_that("estoque por classe CNAE nacional traz descricao", {
  api <- Emprego$new(base_url = .emprego_base_url)
  .skip_se_api_indisponivel(api)

  dados <- api$get_estoque_emprego_classe_cnae_nacional(codigos_classe = "4711")
  expect_true(length(dados) > 0)
  descricoes <- vapply(dados, function(x) !is.null(x$classe_cnae_desc), logical(1))
  expect_true(any(descricoes))
})

test_that("estoque por classe CNAE estadual pagina ate o fim sem erro", {
  api <- Emprego$new(base_url = .emprego_base_url)
  .skip_se_api_indisponivel(api)

  # Volume alto (~13k linhas para SP) — cobre a regressão de
  # classe_cnae_cod nulo em páginas tardias (ResponseValidationError).
  dados <- api$get_estoque_emprego_classe_cnae_estadual(ufs = "SP")
  expect_true(length(dados) > 1000)
})

test_that("estoque por UF e CBO filtra corretamente", {
  api <- Emprego$new(base_url = .emprego_base_url)
  .skip_se_api_indisponivel(api)

  dados <- api$get_estoque_emprego_uf_cbo(siglas_uf = "SP", codigos_classe = "4711")
  expect_true(length(dados) > 0)
  siglas_uf <- vapply(dados, function(x) x$sigla_uf, character(1))
  expect_true(all(siglas_uf == "SP"))
})

test_that("renda media e indice Potec retornam dados", {
  api <- Emprego$new(base_url = .emprego_base_url)
  .skip_se_api_indisponivel(api)

  renda <- api$get_renda_media_emprego(tipos = "Geral")
  expect_true(length(renda) > 0)

  potec <- api$get_potec_emprego(codigos_classe = "7210")
  expect_true(length(potec) > 0)
  codigos <- vapply(potec, function(x) x$classe_cnae_cod, character(1))
  expect_true(all(codigos == "7210"))
})

test_that("REGRESSAO: estoque nacional sempre agrega mesmo com o default", {
  api <- Emprego$new(base_url = .emprego_base_url)
  .skip_se_api_indisponivel(api)

  dados_default <- api$get_estoque_emprego_nacional(codigos_cnae = "47", nivel_cnae = 2)
  dados_explicito <- api$get_estoque_emprego_nacional(codigos_cnae = "47", nivel_cnae = 2, agregado = TRUE)

  anos_default <- sort(vapply(dados_default, function(x) x$ano, integer(1)))
  anos_explicito <- sort(vapply(dados_explicito, function(x) x$ano, integer(1)))
  expect_equal(anos_default, anos_explicito)
  expect_equal(length(dados_default), length(unique(anos_default)))  # 1 linha por ano, sem quebra por UF
})

test_that("REGRESSAO: get_date_bases inclui RAIS", {
  api <- Emprego$new(base_url = .emprego_base_url)
  .skip_se_api_indisponivel(api)

  bases <- api$get_date_bases()
  nomes <- vapply(bases, function(x) x$Base, character(1))
  expect_true("RAIS" %in% nomes)
  expect_true("CAGED" %in% nomes)
})
