# Demo: Estoque de Emprego (R)
#
# Este script demonstra os métodos disponíveis para consulta de estoque de emprego
# utilizando a biblioteca sdic_libraries em R.
#
# Os exemplos abaixo assumem que os scripts/utilitários R estão corretamente instalados
# e disponíveis no diretório R/ do projeto.

# Carregar pacotes necessários
library(dplyr)
# Se necessário, ajustar o caminho para o diretório R/
source('../R/emprego.R')

# 1. Inicialização do cliente
emprego <- Emprego()
cat('Cliente inicializado com sucesso.\n')

# 2. Estoque Nacional
# 2.1 Todos os setores — nível divisão (padrão)
dados_nacional <- get_estoque_emprego_nacional(emprego, nivel_cnae = 2, agregado = TRUE)
df_nacional <- as.data.frame(dados_nacional)
cat('Registros retornados:', nrow(df_nacional), '\n')

colunas_removidas_esperadas <- names(df_nacional)[
  grepl('uf|estado|municipio|grupo|subclasse', tolower(names(df_nacional)))
]
cat('Colunas com granularidade acima do solicitado:', paste(colunas_removidas_esperadas, collapse = ', '), '\n')

head(df_nacional)

df_nacional %>% group_by(ano) %>% summarise(estoque_trabalhadores = sum(estoque_trabalhadores))

df_nacional %>% filter(ano == 2022) %>% group_by(ano) %>% summarise(estoque_trabalhadores = sum(estoque_trabalhadores))

# 2.2 Estoque nacional agregado (soma de todos os estados)
dados_nacional_agg <- get_estoque_emprego_nacional(emprego, nivel_cnae = 2, agregado = FALSE)
df_nacional_agg <- as.data.frame(dados_nacional_agg)
cat('Registros retornados:', nrow(df_nacional_agg), '\n')
head(df_nacional_agg, 50)

# 2.3 Filtrando por CNAEs específicos — nível grupo
codigos <- c('01', '26', '62')
dados_nacional_cnae <- get_estoque_emprego_nacional(emprego, codigos_cnae = codigos, nivel_cnae = 2, agregado = FALSE)
df_nacional_cnae <- as.data.frame(dados_nacional_cnae)
cat('Registros retornados:', nrow(df_nacional_cnae), '\n')
df_nacional_cnae %>% filter(sigla_uf == 'SP')

# 3. Estoque Estadual
# 3.1 Todos os setores de uma UF
dados_sp <- get_estoque_emprego_estadual(emprego, ufs = 'SP', nivel_cnae = 2)
df_sp <- as.data.frame(dados_sp)
cat('Registros retornados (SP):', nrow(df_sp), '\n')
colunas_removidas_esperadas_sp <- names(df_sp)[
  grepl('municipio|ibge|grupo|subclasse', tolower(names(df_sp)))
]
cat('Colunas com granularidade acima do solicitado:', paste(colunas_removidas_esperadas_sp, collapse = ', '), '\n')
head(df_sp[df_sp$ano == 2022, ])

# 3.2 Filtrando por CNAEs para uma UF
dados_sp_cnae <- get_estoque_emprego_estadual(emprego, ufs = 'SP', codigos_cnae = c('10', '26', '62'), nivel_cnae = 2)
df_sp_cnae <- as.data.frame(dados_sp_cnae)
cat('Registros retornados (SP | CNAEs 10, 26, 62):', nrow(df_sp_cnae), '\n')
head(df_sp_cnae)

# 4. Estoque Nacional — Lista de CNAEs (POST)
lista_cnae <- c('10', '13', '14', '15', '16', '17', '18', '19', '20')
dados_lista <- get_estoque_emprego_nacional_lista_cnae(emprego, codigos_cnae = lista_cnae, nivel_cnae = 2, agregado = TRUE)
df_lista <- as.data.frame(dados_lista)
cat('Registros retornados:', nrow(df_lista), '\n')
head(df_lista)

# 5. Estoque Nacional — Grupos de CNAEs (POST)
grupos <- list(
  list(nome_grupo = 'Indústria de Transformação', codigos_cnae = c('10', '13', '14', '15', '16', '17', '18')),
  list(nome_grupo = 'Tecnologia da Informação', codigos_cnae = c('26', '61', '62', '63'))
)
dados_grupos <- get_estoque_emprego_nacional_grupos_cnae(emprego, grupos_cnae = grupos, nivel_cnae = 2, agregado = TRUE)
df_grupos <- as.data.frame(dados_grupos)
cat('Registros retornados:', nrow(df_grupos), '\n')
head(df_grupos)

# 6. Estoque Estadual — Lista de CNAEs (POST)
dados_rj_lista <- get_estoque_emprego_estadual_lista_cnae(emprego, ufs = 'RJ', codigos_cnae = c('10', '13', '14', '20'), nivel_cnae = 2)
df_rj_lista <- as.data.frame(dados_rj_lista)
cat('Registros retornados (RJ):', nrow(df_rj_lista), '\n')
head(df_rj_lista)

# 7. Estoque Estadual — Grupos de CNAEs (POST)
grupos_mg <- list(
  list(nome_grupo = 'Agronegócio', codigos_cnae = c('01', '02', '03', '10', '11')),
  list(nome_grupo = 'Construção Civil', codigos_cnae = c('41', '42', '43'))
)
dados_mg_grupos <- get_estoque_emprego_estadual_grupos_cnae(emprego, ufs = 'MG', grupos_cnae = grupos_mg, nivel_cnae = 2)
df_mg_grupos <- as.data.frame(dados_mg_grupos)
cat('Registros retornados (MG):', nrow(df_mg_grupos), '\n')
head(df_mg_grupos)

# 8. Comparativo entre estados
lista_ufs <- c('SP', 'RJ', 'MG', 'RS', 'PR')
cnae_ti <- c('62')
dados_comparativo <- get_estoque_emprego_estadual(emprego, ufs = lista_ufs, codigos_cnae = cnae_ti, nivel_cnae = 2)
df_comparativo <- as.data.frame(dados_comparativo)
cat('Total de registros:', nrow(df_comparativo), '\n')
head(df_comparativo, 10)
