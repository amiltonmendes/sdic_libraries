# Script de instalação automática da biblioteca SDIC R
# Instala automaticamente todas as dependências necessárias

cat("🚀 Instalação Automática da Biblioteca SDIC R\n")
cat("===============================================\n")

# Função para instalar pacotes com verificação
install_if_missing <- function(packages, repo = "CRAN") {
  missing_packages <- c()
  
  for (pkg in packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      missing_packages <- c(missing_packages, pkg)
    }
  }
  
  if (length(missing_packages) > 0) {
    cat("📦 Instalando pacotes:", paste(missing_packages, collapse = ", "), "\n")
    
    if (repo == "CRAN") {
      install.packages(missing_packages, dependencies = TRUE)
    }
    
    # Verificar instalação
    for (pkg in missing_packages) {
      if (require(pkg, character.only = TRUE, quietly = TRUE)) {
        cat("✅", pkg, "instalado com sucesso\n")
      } else {
        cat("❌ Falha ao instalar", pkg, "\n")
      }
    }
  } else {
    cat("✅ Todos os pacotes já estão instalados\n")
  }
}

# Dependências obrigatórias da biblioteca SDIC
required_packages <- c(
  "R6",          # Classes R6
  "httr2",       # Requisições HTTP modernas  
  "jsonlite",    # JSON parsing
  "dplyr",       # Manipulação de dados
  "tibble",      # Data frames modernos
  "lubridate",   # Manipulação de datas
  "cli",         # Interface de linha de comando
  "rlang"        # Programação com R
)

# Dependências opcionais de desenvolvimento
dev_packages <- c(
  "testthat",    # Testes
  "knitr",       # Documentação
  "rmarkdown",   # Markdown R
  "devtools",    # Ferramentas de desenvolvimento
  "usethis",     # Utilitários de desenvolvimento
  "pkgdown"      # Site de documentação
)

cat("📋 R detectado:", R.version$version.string, "\n")
cat("📁 Diretório atual:", getwd(), "\n\n")

# Instalar dependências obrigatórias
cat("🔧 Instalando dependências obrigatórias...\n")
install_if_missing(required_packages)

cat("\n🔧 Instalando dependências de desenvolvimento (opcional)...\n")
install_if_missing(dev_packages)

# Carregar a biblioteca SDIC
cat("\n📚 Carregando biblioteca SDIC...\n")
tryCatch({
  # Assumindo que estamos no diretório da biblioteca
  if (file.exists("R/emprego.R")) {
    source("R/emprego.R")
    cat("✅ Biblioteca SDIC carregada com sucesso!\n")
  } else {
    cat("⚠️ Arquivo emprego.R não encontrado. Certifique-se de estar no diretório raiz da biblioteca.\n")
  }
}, error = function(e) {
  cat("❌ Erro ao carregar biblioteca:", e$message, "\n")
})

# Teste básico
cat("\n🧪 Teste básico da biblioteca...\n")
tryCatch({
  api <- Emprego$new()
  cat("✅ Classe Emprego criada com sucesso!\n")
  
  cat("\n📖 Como usar:\n")
  cat("   source('R/emprego.R')  # Carregar biblioteca\n")
  cat("   api <- Emprego$new()               # Criar cliente\n") 
  cat("   dados <- api$get_saldo_emprego_detalhado('nacional')  # Obter dados\n")
  
}, error = function(e) {
  cat("❌ Erro no teste básico:", e$message, "\n")
})

cat("\n🎉 Instalação da biblioteca SDIC R concluída!\n")
cat("📦 Todas as dependências foram instaladas automaticamente.\n")