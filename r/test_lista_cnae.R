# Teste simples para verificar se a implementacao R funciona corretamente

# Carregando a biblioteca local (compatibilidade com estrutura atual)
if (file.exists("R/emprego.R")) {
  source("R/emprego.R")
} else if (file.exists("r/R/emprego.R")) {
  source("r/R/emprego.R")
} else {
  stop("Arquivo de origem nao encontrado: R/emprego.R")
}

is_api_error <- function(msg) {
  grepl("HTTP 404|HTTP 5[0-9]{2}|timeout|timed out|Falha na requisicao", msg, ignore.case = TRUE)
}

# Teste basico da nova funcionalidade
test_lista_cnae <- function() {
  cat("Testando funcionalidade get_saldo_emprego_detalhado_lista_cnae...\n")

  tryCatch({
    # Teste da funcao de conveniencia
    result <- get_saldo_emprego_detalhado_lista_cnae(
      lista_cnae = c("62", "63"),
      nome_grupo = "Tecnologia da Informacao",
      nivel_agregacao = "estadual",
      sigla_uf = "SP",
      nivel_cnae = 2
    )

    cat("✅ Teste bem-sucedido! Registros encontrados:", length(result), "\n")
  }, error = function(e) {
    if (is_api_error(e$message)) {
      cat("⚠️ API indisponivel no momento:", e$message, "\n")
    } else {
      cat("❌ Erro no teste:", e$message, "\n")
    }
  })
}

# Executar teste
if (!interactive()) {
  test_lista_cnae()
}
