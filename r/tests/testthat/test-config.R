# Configuração: precedência, .env sem efeitos colaterais, nomes antigos e destino da chave.
# Espelho de python/tests/test_config.py.

privado <- function(obj) obj$.__enclos_env__$private

test_that("padrões sem configuração", {
  ambiente_limpo()
  expect_equal(.sdic_url("api"), "https://sdicapi.dados.ninja")
  expect_equal(.sdic_ambiente(), "producao")
  expect_equal(.sdic_timeout(), 30L)
  expect_null(.sdic_chave())
})

test_that("precedência: argumento > variável > .env.local > .env", {
  pasta <- ambiente_limpo()
  writeLines(c("SDIC_API_URL=https://do-env", "SDIC_TIMEOUT=11"), file.path(pasta, ".env"))
  expect_equal(.sdic_url("api"), "https://do-env")
  writeLines("SDIC_API_URL=https://do-env-local", file.path(pasta, ".env.local"))
  expect_equal(.sdic_url("api"), "https://do-env-local")
  expect_equal(.sdic_timeout(), 11L)  # .env continua valendo para o que .env.local não define
  withr::local_envvar(SDIC_API_URL = "https://da-variavel")
  expect_equal(.sdic_url("api"), "https://da-variavel")
  expect_equal(.sdic_url("api", "https://do-argumento/"), "https://do-argumento")
})

test_that("~/.env vale quando o diretório atual não tem arquivo", {
  pasta <- ambiente_limpo()
  casa <- withr::local_tempdir()
  withr::local_envvar(HOME = casa)
  writeLines("export SDIC_AMBIENTE='homologacao'", file.path(casa, ".env"))
  expect_equal(.sdic_ambiente(), "homologacao")
})

test_that("timeout explícito vence a variável", {
  ambiente_limpo()
  withr::local_envvar(SDIC_TIMEOUT = "5")
  expect_equal(Emprego$new(timeout = 120)$timeout, 120L)
  expect_equal(Emprego$new()$timeout, 5L)
  expect_equal(Comex$new(timeout = 7)$timeout, 7L)
})

test_that("timeout inválido diz qual variável", {
  ambiente_limpo()
  withr::local_envvar(SDIC_TIMEOUT = "abc")
  expect_error(.sdic_timeout(), "SDIC_TIMEOUT", class = "sdic_valor_invalido")
})

test_that(".env passa a funcionar e não altera o ambiente do processo", {
  pasta <- ambiente_limpo()
  writeLines(c("OUTRA_COISA_DO_PROJETO=1", "LOG_LEVEL=DEBUG", "SDIC_API_KEY=k"), file.path(pasta, ".env"))
  cliente <- Emprego$new()
  expect_equal(privado(cliente)$api_key, "k")
  expect_equal(Sys.getenv("OUTRA_COISA_DO_PROJETO", unset = NA), NA_character_)
  expect_equal(Sys.getenv("SDIC_API_KEY", unset = NA), NA_character_)
})

test_that("chave no .env.local vale para os dois clientes e vai no Authorization", {
  pasta <- ambiente_limpo()
  writeLines('SDIC_API_KEY="chave-unica"', file.path(pasta, ".env.local"))
  expect_equal(privado(Emprego$new())$api_key, "chave-unica")
  expect_equal(privado(Comex$new())$api_key, "chave-unica")
  registro <- responde(list(resposta_json(list())))
  Emprego$new()$.make_request("/r")
  expect_equal(cabecalhos_da_requisicao(registro$chamadas[[1]])$Authorization, "Bearer chave-unica")
})

test_that("nomes antigos continuam valendo, com aviso uma vez", {
  ambiente_limpo()
  withr::local_envvar(COMEX_API_KEY = "antiga")
  expect_warning(expect_equal(.sdic_chave(), "antiga"), "SDIC_API_KEY", class = "deprecatedWarning")
  expect_no_warning(expect_equal(.sdic_chave(), "antiga"))  # só avisa uma vez
  withr::local_envvar(SDIC_API_KEY = "nova")
  expect_no_warning(expect_equal(.sdic_chave(), "nova"))
  withr::local_envvar(API_TIMEOUT = "77", EMPLOYMENT_API_BASE_URL = "https://antiga.exemplo")
  expect_equal(suppressWarnings(Emprego$new())$timeout, 77L)
  expect_equal(suppressWarnings(Comex$new())$base_url, "https://antiga.exemplo")
})

test_that("chave não viaja sem https", {
  ambiente_limpo()
  withr::local_envvar(SDIC_API_KEY = "k")
  expect_error(Emprego$new(base_url = "http://host-alheio"), "https", class = "sdic_valor_invalido")
  expect_no_error(Emprego$new(base_url = "http://127.0.0.1:8123"))  # teste local é permitido
  expect_no_error(Comex$new(base_url = "http://localhost:8123"))
  withr::local_envvar(SDIC_API_KEY = NA)
  expect_no_error(Emprego$new(base_url = "http://host-alheio"))  # sem chave não há o que proteger
})

test_that("ambiente inválido", {
  ambiente_limpo()
  expect_error(.sdic_ambiente("prod"), "producao ou homologacao", class = "sdic_valor_invalido")
})

test_that("sdic_config e print() nunca mostram a chave", {
  ambiente_limpo()
  withr::local_envvar(SDIC_API_KEY = "segredo-123")
  df <- sdic_config()
  expect_equal(names(df), c("item", "valor", "variavel", "de_onde"))
  expect_false(any(grepl("segredo-123", unlist(df), fixed = TRUE)))
  expect_equal(df$valor[df$item == "chave da API"], "definida")
  expect_equal(df$de_onde[df$item == "chave da API"], "variável de ambiente (SDIC_API_KEY)")
  expect_equal(df$valor[df$item == "origem dados"], "https://storage.googleapis.com/fast-sdic-dados")
  impresso <- paste(c(capture.output(print(Emprego$new())), capture.output(print(Comex$new())),
                      capture.output(str(Emprego$new())), format(Comex$new())), collapse = "\n")
  expect_false(grepl("segredo-123", impresso, fixed = TRUE))
  expect_match(impresso, "chave: definida")
  expect_null(Emprego$new()$api_key)  # não é mais campo público
  withr::local_envvar(SDIC_API_KEY = NA)
  expect_match(paste(capture.output(print(Emprego$new())), collapse = "\n"), "chave: não definida")
  expect_equal(sdic_config()$valor[2 + 2], "não definida")
})

test_that("criar o cliente não imprime nada", {
  ambiente_limpo()
  expect_silent(Emprego$new())
  expect_silent(Comex$new())
})
