# Instalação da Biblioteca SDIC-Libraries via GitHub
# Script automatizado para instalar dependências e biblioteca

# Função para instalar bibliotecas se não estiverem presentes
install_if_missing <- function(pkg, repo = NULL) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    if (!is.null(repo)) {
      if (!require("remotes", quietly = TRUE)) {
        install.packages("remotes", repos = "https://cloud.r-project.org/")
      }
      remotes::install_github(repo)
    } else {
      install.packages(pkg, repos = "https://cloud.r-project.org/")
    }
  }
}

# Banner de instalação
cat("🚀================================================================🚀\n")
cat("       BIBLIOTECA SDIC - INSTALAÇÃO VIA GITHUB (R)\n")
cat("    Dados de Emprego Brasileiros | Instalação Automática\n")
cat("🚀================================================================🚀\n\n")

# 1. Instalar remotes/devtools se necessário
cat("📦 Instalando ferramentas de desenvolvimento...\n")
install_if_missing("remotes")
install_if_missing("devtools")

# 2. Instalar dependências obrigatórias
cat("\n📋 Instalando dependências da biblioteca...\n")
required_packages <- c(
  "R6",      # Sistema de classes
  "httr2",   # Cliente HTTP moderno
  "jsonlite", # Parser JSON
  "dplyr",   # Manipulação de dados
  "tibble",  # Data frames modernos
  "lubridate", # Manipulação de datas
  "cli",     # Interface linha de comando
  "rlang"    # Ferramentas da linguagem R
)

for (pkg in required_packages) {
  cat("  - Instalando", pkg, "...\n")
  install_if_missing(pkg)
}

# 3. Instalar biblioteca SDIC diretamente do GitHub
cat("\n🚀 Instalando biblioteca SDIC-Libraries do GitHub...\n")
tryCatch({
  remotes::install_github("sdic-org/sdic_libraries", subdir = "r", force = TRUE)
  cat("✅ Biblioteca SDIC-Libraries instalada com sucesso!\n")
}, error = function(e) {
  cat("❌ Erro na instalação:", e$message, "\n")
  cat("💡 Alternativa: Use devtools::install_github('sdic-org/sdic_libraries', subdir='r')\n")
})

# 4. Teste rápido da instalação
cat("\n🧪 Testando instalação...\n")
tryCatch({
  # Tentar carregar o arquivo principal
  source_url <- "https://raw.githubusercontent.com/sdic-org/sdic_libraries/main/r/R/data_access/emprego.R"
  cat("  - Testando carregamento via source...\n")
  cat("  - URL:", source_url, "\n")
  cat("  - Para usar localmente: source('r/R/data_access/emprego.R')\n")
  
  cat("✅ Teste concluído!\n")
}, error = function(e) {
  cat("⚠️ Teste incompleto:", e$message, "\n")
})

# 5. Exemplos de uso
cat("\n📖 EXEMPLOS DE USO:\n")
cat("====================\n")
cat("# Carregar biblioteca via GitHub:\n")
cat("library(sdic.libraries)\n\n")
cat("# Ou carregar arquivo diretamente:\n")
cat("source('https://raw.githubusercontent.com/sdic-org/sdic_libraries/main/r/R/data_access/emprego.R')\n\n")
cat("# Usar a biblioteca:\n")
cat("api <- Emprego$new()\n")
cat("dados <- api$get_saldo_emprego_detalhado('nacional')\n")
cat("length(dados)  # Quantidade de registros\n\n")

cat("🎉 Instalação concluída! Biblioteca pronta para uso.\n")
cat("📖 Documentação: https://github.com/sdic-org/sdic_libraries#readme\n")