# Biblioteca de dados da SDIC

<!-- Gerado por scripts/documentar.py a partir de contrato/catalogo.json. Não edite à mão. -->

Uma porta única para ler os dados da plataforma, com as mesmas funções em **Python** (`sdic_libraries`) e em
**R** (`sdic.libraries`). Toda função devolve uma tabela (`DataFrame` ou `tibble`). Versão 0.7.0.

- [Qual função usar](qual_funcao_usar.md)
- [Referência das funções](referencia.md)
- [Dados consultados](dados.md): de onde vem cada número
- [Configuração](configuracao.md): chave, endereços, ambientes e erros comuns
- [Mudanças](mudancas.md)

## Instalar

```bash
# Python
pip install "git+https://github.com/amiltonmendes/sdic_libraries.git#subdirectory=python"
```

```r
# R
remotes::install_github("amiltonmendes/sdic_libraries", subdir = "r")
```

## Chave da API

A API exige uma chave individual (peça ao dono do projeto). Guarde-a uma vez, com a própria biblioteca:

```python
from sdic_libraries import salvar_chave
salvar_chave()          # pergunta a chave sem mostrá-la, confere na API e grava
```

```r
library(sdic.libraries)
salvar_chave()
```

A chave vai para `~/.config/sdic/.env` (`%APPDATA%\sdic\.env` no Windows), legível só por você, e vale para
Python e para R. Para trocar, chame de novo. Alternativas: a variável de ambiente `SDIC_API_KEY`, ou um arquivo
`.env.local` na pasta do projeto (fora do git) com `SDIC_API_KEY=sua-chave`. `sdic_config()` mostra se a chave
foi encontrada e de onde veio, sem exibi-la.

As seções publicadas e as políticas são arquivos públicos e não precisam de chave.

## Primeiro uso

```python
from sdic_libraries import listar_bases, descrever, get_kpis_publicados, get_serie

listar_bases()                                   # o que existe
descrever("get_kpis_publicados")                 # de onde vem e que colunas tem
get_kpis_publicados("SP", "emprego", ambiente="homologacao")
get_serie("contas_regionais_vab", sg_uf="SP", com_nomes=True)
```

```r
library(sdic.libraries)

listar_bases()
descrever("get_kpis_publicados")
get_kpis_publicados("SP", "emprego", ambiente = "homologacao")
get_serie("contas_regionais_vab", sg_uf = "SP", com_nomes = TRUE)
```

## Ajuda dentro do ambiente

| | Python | R |
|---|---|---|
| Ajuda de uma função | `help(get_serie)` ou `get_serie?` (Jupyter) | `?get_serie` |
| Visão geral do pacote | `help(sdic_libraries)` | `?sdic.libraries`, `help(package = "sdic.libraries")` |
| O que existe | `listar_bases()` | `listar_bases()` |
| Ficha de uma base ou função | `descrever("politicas")` | `descrever("politicas")` |
| O que está configurado | `sdic_config()` | `sdic_config()` |
