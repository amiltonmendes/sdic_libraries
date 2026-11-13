# Instalação

Documentação de uso: [docs/index.md](docs/index.md). Configuração e erros comuns: [docs/configuracao.md](docs/configuracao.md).

## Python (3.8 ou mais novo)

```bash
pip install "git+https://github.com/amiltonmendes/sdic_libraries.git#subdirectory=python"
python -c "import sdic_libraries as s; print(s.__version__); print(s.sdic_config())"
```

Desenvolvimento local: `pip install -e "python/[dev]"`.

## R (4.1 ou mais novo)

```r
install.packages("remotes")
remotes::install_github("amiltonmendes/sdic_libraries", subdir = "r")
library(sdic.libraries)
sdic_config()
```

Desenvolvimento local: `devtools::load_all("r")`.

## Chave da API

A API exige uma chave individual. Crie `.env.local` na pasta do seu projeto (e ponha `.env.local` no
`.gitignore`) com:

```
SDIC_API_KEY=sua-chave
```

Ou defina a variável de ambiente `SDIC_API_KEY`. `sdic_config()` mostra se a chave foi encontrada (sem exibi-la).
As seções publicadas e as políticas não precisam de chave.

## Conferir

```python
from sdic_libraries import listar_bases, get_kpis_publicados, get_date_bases
listar_bases()                                                  # sem rede
get_kpis_publicados("SP", "emprego", ambiente="homologacao")    # arquivo público
get_date_bases()                                                # API (precisa da chave)
```

```r
listar_bases()
get_kpis_publicados("SP", "emprego", ambiente = "homologacao")
get_date_bases()
```

## Atualizar e remover

```bash
pip install --upgrade "git+https://github.com/amiltonmendes/sdic_libraries.git#subdirectory=python"
pip uninstall sdic-libraries
```

```r
remotes::install_github("amiltonmendes/sdic_libraries", subdir = "r", force = TRUE)
remove.packages("sdic.libraries")
```
