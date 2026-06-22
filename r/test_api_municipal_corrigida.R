# ===================================================
# TESTE DE VALIDAÇÃO: API Municipal R vs Python
# ===================================================
# Verificar se as correções de tipos funcionaram

# Carregar biblioteca
library(devtools)
load_all(".")

# 🧪 TESTE 1: API Municipal básica
cat("🔧 Teste 1: API Municipal básica com códigos corrigidos\n")
cat("=" , rep("=", 50), "\n", sep="")

tryCatch({
  # Teste com mesmo código que funcionou no Python
  dados_r <- get_saldo_emprego_municipal_mensal_agrupado(
    sigla_uf = 'SP',
    codigo_municipio = 355030,  # Mesmo código que funcionou no curl
    nome_grupo = "Teste R Comércio",
    lista_cnae = c('45', '46'),  # Mesmos códigos do curl
    data_minima = "2023-01-01"
  )
  
  cat("✅ Resultado R:", nrow(dados_r), "registros\n")
  cat("📋 Colunas:", paste(names(dados_r), collapse=", "), "\n")
  
  if(nrow(dados_r) > 0) {
    cat("🎉 SUCESSO! API municipal R funcionando\n")
    print(head(dados_r, 3))
  } else {
    cat("❌ API R ainda retorna vazio\n")
  }
  
}, error = function(e) {
  cat("❌ Erro na API R:", e$message, "\n")
})

cat("\n🧪 TESTE 2: Função básica não-agrupada\n")
tryCatch({
  # Teste função mais simples
  dados_basico <- get_saldo_emprego_municipal_mensal(
    sigla_uf = 'SP',
    codigo_municipio = 355030,
    nivel_cnae = 'divisao',
    codigo_cnae = '45',
    data_minima = "2023-01-01"
  )
  
  cat("✅ Função básica R:", nrow(dados_basico), "registros\n")
  
}, error = function(e) {
  cat("❌ Erro função básica R:", e$message, "\n")
})

cat("\n📊 COMPARAÇÃO PYTHON vs R:\n")
cat("   • Python: 38 registros (funcionando) ✅\n")
cat("   • R:      ? registros (testando agora)\n")

cat("\n💡 ANÁLISE:\n")
cat("   • Se R funcionar: Ambas bibliotecas harmonizadas ✅\n")
cat("   • Se R falhar: Pode haver diferenças de endpoint\n")

cat("\n" , rep("=", 60), "\n", sep="")
cat("Teste concluído - verificar resultados acima\n")