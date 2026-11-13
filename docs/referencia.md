# Referência das funções

<!-- Gerado por scripts/documentar.py a partir de contrato/catalogo.json. Não edite à mão. -->

Uma entrada por função pública, igual em Python (`sdic_libraries`) e em R (`sdic.libraries`). A ajuda completa de cada uma, com todos os parâmetros, está no próprio ambiente: `help(funcao)` ou `funcao?` em Python, `?funcao` em R.

## Emprego (RAIS e Novo CAGED)

### `get_estoque_emprego_nacional`

Estoque de vínculos ativos (31/12) por divisão ou grupo CNAE.

```python
# Python
from sdic_libraries import get_estoque_emprego_nacional
get_estoque_emprego_nacional(codigos_cnae=['10'], nivel_cnae=2)
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_nacional(codigos_cnae = '10', nivel_cnae = 2)
```

Assinatura (Python): `get_estoque_emprego_nacional(codigos_cnae: 'List[str]' = None, nivel_cnae: 'int' = 2, agregado: 'bool' = False, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_estoque_emprego_estadual`

Igual ao nacional, por UF.

```python
# Python
from sdic_libraries import get_estoque_emprego_estadual
get_estoque_emprego_estadual(uf='SP', codigos_cnae=['10'])
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_estadual(sigla_uf = 'SP', codigos_cnae = '10')
```

Assinatura (Python): `get_estoque_emprego_estadual(uf: 'str', codigos_cnae: 'List[str]' = None, nivel_cnae: 'int' = 2, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_estoque_emprego_nacional_agrupado`

Estoque somado para uma lista de CNAEs sob um nome de grupo (ex.: 'TI').

```python
# Python
from sdic_libraries import get_estoque_emprego_nacional_agrupado
get_estoque_emprego_nacional_agrupado('TI', ['620', '631'])
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_nacional_agrupado('TI', c('620', '631'))
```

Assinatura (Python): `get_estoque_emprego_nacional_agrupado(nome_grupo: 'str', lista_cnae: 'List[str]', agregado: 'bool' = True) -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_estoque_emprego_estadual_agrupado`

Igual ao agrupado nacional, por UF.

```python
# Python
from sdic_libraries import get_estoque_emprego_estadual_agrupado
get_estoque_emprego_estadual_agrupado(sigla_uf='SP', nome_grupo='TI', lista_cnae=['620'])
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_estadual_agrupado(sigla_uf = 'SP', nome_grupo = 'TI', lista_cnae = '620')
```

Assinatura (Python): `get_estoque_emprego_estadual_agrupado(sigla_uf: 'Union[str, List[str]]', nome_grupo: 'str', lista_cnae: 'List[str]') -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_estoque_emprego_estimado_nacional_anual`

Estoque real (RAIS) + projeção com o saldo CAGED acumulado até o ano corrente (coluna 'origem': Real/Estimação).

```python
# Python
from sdic_libraries import get_estoque_emprego_estimado_nacional_anual
get_estoque_emprego_estimado_nacional_anual(codigo_cnae='10')
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_estimado_nacional_anual(codigo_cnae = '10')
```

Assinatura (Python): `get_estoque_emprego_estimado_nacional_anual(nivel_cnae: 'str' = 'divisao', codigo_cnae: 'str' = None, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque estimado (RAIS + saldo do CAGED)](dados.md#rais_caged).

### `get_estoque_emprego_estimado_estadual_anual`

Igual ao estimado nacional, por UF.

```python
# Python
from sdic_libraries import get_estoque_emprego_estimado_estadual_anual
get_estoque_emprego_estimado_estadual_anual(sigla_uf='SP', codigo_cnae='10')
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_estimado_estadual_anual(sigla_uf = 'SP', codigo_cnae = '10')
```

Assinatura (Python): `get_estoque_emprego_estimado_estadual_anual(sigla_uf: 'str', nivel_cnae: 'str' = 'divisao', codigo_cnae: 'str' = None, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque estimado (RAIS + saldo do CAGED)](dados.md#rais_caged).

### `get_estoque_emprego_estimado_municipal_anual`

Igual ao estimado nacional, por município.

```python
# Python
from sdic_libraries import get_estoque_emprego_estimado_municipal_anual
get_estoque_emprego_estimado_municipal_anual(sigla_uf='SP', codigo_municipio=3550308, codigo_cnae='10')
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_estimado_municipal_anual(sigla_uf = 'SP', codigo_municipio = 3550308, codigo_cnae = '10')
```

Assinatura (Python): `get_estoque_emprego_estimado_municipal_anual(sigla_uf: 'str', codigo_municipio: 'int', nivel_cnae: 'str' = 'divisao', codigo_cnae: 'str' = None, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque estimado (RAIS + saldo do CAGED)](dados.md#rais_caged).

### `get_estoque_emprego_porte_nacional`

Estoque por porte do estabelecimento (Sebrae/DIEESE) e setor (Indústria x Comércio/Serviços).

```python
# Python
from sdic_libraries import get_estoque_emprego_porte_nacional
get_estoque_emprego_porte_nacional('divisao', codigos_cnae=['10'], setor='Indústria')
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_porte_nacional('divisao', codigos_cnae = '10', setor = 'Indústria')
```

Assinatura (Python): `get_estoque_emprego_porte_nacional(nivel_cnae: 'str' = 'divisao', codigos_cnae: 'List[str]' = None, porte: 'List[str]' = None, setor: 'str' = None, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_estoque_emprego_porte_estadual`

Igual ao porte nacional, por UF.

```python
# Python
from sdic_libraries import get_estoque_emprego_porte_estadual
get_estoque_emprego_porte_estadual(uf='SP', nivel_cnae='divisao', porte=['Microempresa'])
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_porte_estadual(uf = 'SP', nivel_cnae = 'divisao', porte = 'Microempresa')
```

Assinatura (Python): `get_estoque_emprego_porte_estadual(uf: 'Union[str, List[str]]', nivel_cnae: 'str' = 'divisao', codigos_cnae: 'List[str]' = None, porte: 'List[str]' = None, setor: 'str' = None, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_estoque_emprego_classe_cnae_nacional`

Estoque por classe CNAE (4 dígitos, mais fino que divisão/grupo).

```python
# Python
from sdic_libraries import get_estoque_emprego_classe_cnae_nacional
get_estoque_emprego_classe_cnae_nacional(codigos_classe=['1011'])
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_classe_cnae_nacional(codigos_classe = '1011')
```

Assinatura (Python): `get_estoque_emprego_classe_cnae_nacional(codigos_classe: 'List[str]' = None, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_estoque_emprego_classe_cnae_estadual`

Igual ao classe nacional, por UF.

```python
# Python
from sdic_libraries import get_estoque_emprego_classe_cnae_estadual
get_estoque_emprego_classe_cnae_estadual(uf='SP', codigos_classe=['1011'])
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_classe_cnae_estadual(uf = 'SP', codigos_classe = '1011')
```

Assinatura (Python): `get_estoque_emprego_classe_cnae_estadual(uf: 'Union[str, List[str]]', codigos_classe: 'List[str]' = None, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_estoque_emprego_uf_cbo`

Estoque por UF, classe CNAE e ocupação (CBO). Endpoint pesado: sempre filtre siglas_uf e codigos_classe.

```python
# Python
from sdic_libraries import get_estoque_emprego_uf_cbo
get_estoque_emprego_uf_cbo(siglas_uf=['SP'], codigos_classe=['4711'])
```

```r
# R
library(sdic.libraries)
get_estoque_emprego_uf_cbo(siglas_uf = 'SP', codigos_classe = '4711')
```

Assinatura (Python): `get_estoque_emprego_uf_cbo(siglas_uf: 'List[str]' = None, codigos_classe: 'List[str]' = None, codigos_cbo: 'List[str]' = None, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_renda_media_emprego`

Remuneração média (RAIS) por divisão/grupo CNAE ou geral.

```python
# Python
from sdic_libraries import get_renda_media_emprego
get_renda_media_emprego(tipos=['Divisao'], codigos=['10'])
```

```r
# R
library(sdic.libraries)
get_renda_media_emprego(tipos = 'Divisao', codigos = '10')
```

Assinatura (Python): `get_renda_media_emprego(tipos: 'List[str]' = None, codigos: 'List[str]' = None, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_potec_emprego`

Índice Potec: fração de pessoal ocupado técnico-científico por classe CNAE (proxy de P&D da PINTEC).

```python
# Python
from sdic_libraries import get_potec_emprego
get_potec_emprego(codigos_classe=['7210'])
```

```r
# R
library(sdic.libraries)
get_potec_emprego(codigos_classe = '7210')
```

Assinatura (Python): `get_potec_emprego(codigos_classe: 'List[str]' = None, ano_minimo: 'int' = None, ano_maximo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Estoque de emprego formal (RAIS)](dados.md#rais).

### `get_date_bases`

Data da última atualização de cada base (CAGED, RAIS, ComexStat).

```python
# Python
from sdic_libraries import get_date_bases
get_date_bases()
```

```r
# R
library(sdic.libraries)
get_date_bases()
```

Assinatura (Python): `get_date_bases() -> 'pd.DataFrame'`

Dados consultados: [Período mais recente de cada base](dados.md#atualizacao).

### `get_saldo_emprego_nacional_mensal`

Saldo mensal (admissões − desligamentos) por divisão/grupo/subclasse CNAE.

```python
# Python
from sdic_libraries import get_saldo_emprego_nacional_mensal
get_saldo_emprego_nacional_mensal(nivel_cnae='divisao', codigo_cnae='10')
```

```r
# R
library(sdic.libraries)
get_saldo_emprego_nacional_mensal(nivel_cnae = 'divisao', codigo_cnae = '10')
```

Assinatura (Python): `get_saldo_emprego_nacional_mensal(nivel_cnae: 'str' = 'subclasse', codigo_cnae: 'str' = None, data_minima: 'str' = None) -> 'pd.DataFrame'`

Dados consultados: [Saldo de emprego formal (Novo CAGED)](dados.md#caged).

### `get_saldo_emprego_nacional_anual`

Saldo somado por ano, mesmo recorte do mensal.

```python
# Python
from sdic_libraries import get_saldo_emprego_nacional_anual
get_saldo_emprego_nacional_anual(nivel_cnae='divisao', codigo_cnae='10')
```

```r
# R
library(sdic.libraries)
get_saldo_emprego_nacional_anual(nivel_cnae = 'divisao', codigo_cnae = '10')
```

Assinatura (Python): `get_saldo_emprego_nacional_anual(nivel_cnae: 'str' = 'subclasse', codigo_cnae: 'str' = None, ano_minimo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Saldo de emprego formal (Novo CAGED)](dados.md#caged).

### `get_saldo_emprego_nacional_mensal_agrupado`

Saldo mensal somado para uma lista de CNAEs sob um nome de grupo.

```python
# Python
from sdic_libraries import get_saldo_emprego_nacional_mensal_agrupado
get_saldo_emprego_nacional_mensal_agrupado('TI', ['620', '631'])
```

```r
# R
library(sdic.libraries)
get_saldo_emprego_nacional_mensal_agrupado('TI', c('620', '631'))
```

Assinatura (Python): `get_saldo_emprego_nacional_mensal_agrupado(nome_grupo: 'str', lista_cnae: 'List[str]', data_minima: 'str' = None) -> 'pd.DataFrame'`

Dados consultados: [Saldo de emprego formal (Novo CAGED)](dados.md#caged).

### `get_saldo_emprego_estadual_mensal`

Igual ao saldo mensal nacional, por UF.

```python
# Python
from sdic_libraries import get_saldo_emprego_estadual_mensal
get_saldo_emprego_estadual_mensal(sigla_uf='SP', nivel_cnae='divisao', codigo_cnae='10')
```

```r
# R
library(sdic.libraries)
get_saldo_emprego_estadual_mensal(sigla_uf = 'SP', nivel_cnae = 'divisao', codigo_cnae = '10')
```

Assinatura (Python): `get_saldo_emprego_estadual_mensal(sigla_uf: 'str', nivel_cnae: 'str' = 'subclasse', codigo_cnae: 'str' = None, data_minima: 'str' = None) -> 'pd.DataFrame'`

Dados consultados: [Saldo de emprego formal (Novo CAGED)](dados.md#caged).

### `get_saldo_emprego_estadual_anual`

Igual ao saldo anual nacional, por UF.

```python
# Python
from sdic_libraries import get_saldo_emprego_estadual_anual
get_saldo_emprego_estadual_anual(sigla_uf='SP', nivel_cnae='divisao', codigo_cnae='10')
```

```r
# R
library(sdic.libraries)
get_saldo_emprego_estadual_anual(sigla_uf = 'SP', nivel_cnae = 'divisao', codigo_cnae = '10')
```

Assinatura (Python): `get_saldo_emprego_estadual_anual(sigla_uf: 'str', nivel_cnae: 'str' = 'subclasse', codigo_cnae: 'str' = None, ano_minimo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Saldo de emprego formal (Novo CAGED)](dados.md#caged).

### `get_saldo_emprego_estadual_mensal_agrupado`

Igual ao saldo agrupado nacional, por UF.

```python
# Python
from sdic_libraries import get_saldo_emprego_estadual_mensal_agrupado
get_saldo_emprego_estadual_mensal_agrupado(sigla_uf='SP', nome_grupo='TI', lista_cnae=['620'])
```

```r
# R
library(sdic.libraries)
get_saldo_emprego_estadual_mensal_agrupado(sigla_uf = 'SP', nome_grupo = 'TI', lista_cnae = '620')
```

Assinatura (Python): `get_saldo_emprego_estadual_mensal_agrupado(sigla_uf: 'str', nome_grupo: 'str', lista_cnae: 'List[str]', data_minima: 'str' = None) -> 'pd.DataFrame'`

Dados consultados: [Saldo de emprego formal (Novo CAGED)](dados.md#caged).

### `get_saldo_emprego_municipal_mensal`

Igual ao saldo mensal nacional, por município.

```python
# Python
from sdic_libraries import get_saldo_emprego_municipal_mensal
get_saldo_emprego_municipal_mensal(sigla_uf='SP', codigo_municipio=3550308, nivel_cnae='divisao', codigo_cnae='10')
```

```r
# R
library(sdic.libraries)
get_saldo_emprego_municipal_mensal(sigla_uf = 'SP', codigo_municipio = 3550308, nivel_cnae = 'divisao', codigo_cnae = '10')
```

Assinatura (Python): `get_saldo_emprego_municipal_mensal(codigo_municipio: 'int', nivel_cnae: 'str' = 'subclasse', sigla_uf: 'str' = None, codigo_cnae: 'str' = None, data_minima: 'str' = None) -> 'pd.DataFrame'`

Dados consultados: [Saldo de emprego formal (Novo CAGED)](dados.md#caged).

### `get_saldo_emprego_municipal_anual`

Igual ao saldo anual nacional, por município.

```python
# Python
from sdic_libraries import get_saldo_emprego_municipal_anual
get_saldo_emprego_municipal_anual(sigla_uf='SP', codigo_municipio=3550308, nivel_cnae='divisao', codigo_cnae='10')
```

```r
# R
library(sdic.libraries)
get_saldo_emprego_municipal_anual(sigla_uf = 'SP', codigo_municipio = 3550308, nivel_cnae = 'divisao', codigo_cnae = '10')
```

Assinatura (Python): `get_saldo_emprego_municipal_anual(sigla_uf: 'str', codigo_municipio: 'int', nivel_cnae: 'str' = 'subclasse', codigo_cnae: 'str' = None, ano_minimo: 'int' = None) -> 'pd.DataFrame'`

Dados consultados: [Saldo de emprego formal (Novo CAGED)](dados.md#caged).

### `get_saldo_emprego_municipal_mensal_agrupado`

Igual ao saldo agrupado nacional, por município.

```python
# Python
from sdic_libraries import get_saldo_emprego_municipal_mensal_agrupado
get_saldo_emprego_municipal_mensal_agrupado(sigla_uf='SP', codigo_municipio=3550308, nome_grupo='TI', lista_cnae=['620'])
```

```r
# R
library(sdic.libraries)
get_saldo_emprego_municipal_mensal_agrupado(sigla_uf = 'SP', codigo_municipio = 3550308, nome_grupo = 'TI', lista_cnae = '620')
```

Assinatura (Python): `get_saldo_emprego_municipal_mensal_agrupado(codigo_municipio: 'int', nome_grupo: 'str', lista_cnae: 'List[str]', sigla_uf: 'str' = None, data_minima: 'str' = None) -> 'pd.DataFrame'`

Dados consultados: [Saldo de emprego formal (Novo CAGED)](dados.md#caged).

### `get_relatorio_emprego_saldo_estadual`

Saldo CAGED mensal por UF, lido do cache já publicado (GitHub Pages) — não chama a API ao vivo.

**Depreciada.** Use get_kpis_publicados(uf, 'emprego') e as demais funções de seções publicadas.

```python
# Python
from sdic_libraries import get_relatorio_emprego_saldo_estadual
get_relatorio_emprego_saldo_estadual(uf='SP')
```

```r
# R
library(sdic.libraries)
get_relatorio_emprego_saldo_estadual(uf = 'SP')
```

Assinatura (Python): `get_relatorio_emprego_saldo_estadual(uf: 'str', ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Cache de emprego no layout antigo do Pages](dados.md#emprego_portal_antigo).

### `get_relatorio_emprego_estoque_estadual`

Estoque RAIS por UF, lido do cache já publicado — não chama a API ao vivo.

**Depreciada.** Use get_kpis_publicados(uf, 'emprego') e as demais funções de seções publicadas.

```python
# Python
from sdic_libraries import get_relatorio_emprego_estoque_estadual
get_relatorio_emprego_estoque_estadual(uf='SP')
```

```r
# R
library(sdic.libraries)
get_relatorio_emprego_estoque_estadual(uf = 'SP')
```

Assinatura (Python): `get_relatorio_emprego_estoque_estadual(uf: 'str', ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Cache de emprego no layout antigo do Pages](dados.md#emprego_portal_antigo).

## Comércio exterior (ComexStat)

### `get_exportacao_ncm_nacional_mensal`

Exportações mensais por NCM (produto), com filtro opcional por seção ISIC.

```python
# Python
from sdic_libraries import get_exportacao_ncm_nacional_mensal
get_exportacao_ncm_nacional_mensal(ano_minimo=2024, secao='Indústria de Transformação')
```

```r
# R
library(sdic.libraries)
get_exportacao_ncm_nacional_mensal(ano_minimo = 2024, secao = 'Indústria de Transformação')
```

Assinatura (Python): `get_exportacao_ncm_nacional_mensal(*, ano_minimo: 'int' = None, mes_maximo: 'int' = None, anos: 'List[int]' = None, lista_ncms: 'List[Union[int, str]]' = None, secao: 'str' = None, agregado_ano: 'bool' = False) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_importacao_ncm_nacional_mensal`

Igual ao NCM de exportação, para importações.

```python
# Python
from sdic_libraries import get_importacao_ncm_nacional_mensal
get_importacao_ncm_nacional_mensal(ano_minimo=2024)
```

```r
# R
library(sdic.libraries)
get_importacao_ncm_nacional_mensal(ano_minimo = 2024)
```

Assinatura (Python): `get_importacao_ncm_nacional_mensal(*, ano_minimo: 'int' = None, mes_maximo: 'int' = None, anos: 'List[int]' = None, lista_ncms: 'List[Union[int, str]]' = None, secao: 'str' = None, agregado_ano: 'bool' = False) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_exportacao_isic_divisao_nacional_mensal`

Exportações mensais por divisão ISIC (setor) — a chave para juntar com emprego (juntar_emprego_comex).

```python
# Python
from sdic_libraries import get_exportacao_isic_divisao_nacional_mensal
get_exportacao_isic_divisao_nacional_mensal(ano_minimo=2024, agregado_ano=True)
```

```r
# R
library(sdic.libraries)
get_exportacao_isic_divisao_nacional_mensal(ano_minimo = 2024, agregado_ano = TRUE)
```

Assinatura (Python): `get_exportacao_isic_divisao_nacional_mensal(*, ano_minimo: 'int' = None, mes_maximo: 'int' = None, secao: 'str' = None, divisao: 'int' = None, agregado_ano: 'bool' = False) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_importacao_isic_divisao_nacional_mensal`

Igual ao ISIC de exportação, para importações.

```python
# Python
from sdic_libraries import get_importacao_isic_divisao_nacional_mensal
get_importacao_isic_divisao_nacional_mensal(ano_minimo=2024, agregado_ano=True)
```

```r
# R
library(sdic.libraries)
get_importacao_isic_divisao_nacional_mensal(ano_minimo = 2024, agregado_ano = TRUE)
```

Assinatura (Python): `get_importacao_isic_divisao_nacional_mensal(*, ano_minimo: 'int' = None, mes_maximo: 'int' = None, secao: 'str' = None, divisao: 'int' = None, agregado_ano: 'bool' = False) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_exportacao_isic_divisao_estadual_mensal`

Igual ao ISIC nacional, por UF (e opcionalmente por país/bloco).

```python
# Python
from sdic_libraries import get_exportacao_isic_divisao_estadual_mensal
get_exportacao_isic_divisao_estadual_mensal(estado='São Paulo', ano_minimo=2024)
```

```r
# R
library(sdic.libraries)
get_exportacao_isic_divisao_estadual_mensal(estado = 'São Paulo', ano_minimo = 2024)
```

Assinatura (Python): `get_exportacao_isic_divisao_estadual_mensal(*, estado: 'str' = None, pais: 'str' = None, ano_minimo: 'int' = None, mes_maximo: 'int' = None, secao: 'str' = None, divisao: 'int' = None, bloco: 'int' = None, agregado_ano: 'bool' = False, agregado_pais: 'bool' = False) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_importacao_isic_divisao_estadual_mensal`

Igual ao ISIC estadual de exportação, para importações.

```python
# Python
from sdic_libraries import get_importacao_isic_divisao_estadual_mensal
get_importacao_isic_divisao_estadual_mensal(estado='São Paulo', ano_minimo=2024)
```

```r
# R
library(sdic.libraries)
get_importacao_isic_divisao_estadual_mensal(estado = 'São Paulo', ano_minimo = 2024)
```

Assinatura (Python): `get_importacao_isic_divisao_estadual_mensal(*, estado: 'str' = None, pais: 'str' = None, ano_minimo: 'int' = None, mes_maximo: 'int' = None, secao: 'str' = None, divisao: 'int' = None, bloco: 'int' = None, agregado_ano: 'bool' = False, agregado_pais: 'bool' = False) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_exportacao_pais_nacional_mensal`

Exportações mensais por país de destino.

```python
# Python
from sdic_libraries import get_exportacao_pais_nacional_mensal
get_exportacao_pais_nacional_mensal(pais='Argentina', ano_minimo=2024)
```

```r
# R
library(sdic.libraries)
get_exportacao_pais_nacional_mensal(pais = 'Argentina', ano_minimo = 2024)
```

Assinatura (Python): `get_exportacao_pais_nacional_mensal(*, pais: 'str' = None, secao: 'str' = None, ano_minimo: 'int' = None, mes_maximo: 'int' = None, agregado_ano: 'bool' = False) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_importacao_pais_nacional_mensal`

Igual ao país de exportação, para importações (país de origem).

```python
# Python
from sdic_libraries import get_importacao_pais_nacional_mensal
get_importacao_pais_nacional_mensal(pais='Argentina', ano_minimo=2024)
```

```r
# R
library(sdic.libraries)
get_importacao_pais_nacional_mensal(pais = 'Argentina', ano_minimo = 2024)
```

Assinatura (Python): `get_importacao_pais_nacional_mensal(*, pais: 'str' = None, secao: 'str' = None, ano_minimo: 'int' = None, mes_maximo: 'int' = None, agregado_ano: 'bool' = False) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_ncm_isic_mapa`

De-para NCM → divisão/seção ISIC (catálogo estático, ~13 mil códigos).

```python
# Python
from sdic_libraries import get_ncm_isic_mapa
get_ncm_isic_mapa()
```

```r
# R
library(sdic.libraries)
get_ncm_isic_mapa()
```

Assinatura (Python): `get_ncm_isic_mapa() -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_agrupamentos_disponiveis`

Agrupamentos de NCM da SDIC (nome, departamento e coordenação): use para descobrir o nome a passar em `agrupamento`.

```python
# Python
from sdic_libraries import get_agrupamentos_disponiveis
get_agrupamentos_disponiveis()
```

```r
# R
library(sdic.libraries)
get_agrupamentos_disponiveis()
```

Assinatura (Python): `get_agrupamentos_disponiveis(*, departamento: 'str' = None, cg: 'str' = None) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_exportacao_agrupamentos`

Exportação mensal de um agrupamento de NCM da SDIC.

```python
# Python
from sdic_libraries import get_exportacao_agrupamentos
get_exportacao_agrupamentos(agrupamento='Complexo da Saúde', ano_minimo=2024)
```

```r
# R
library(sdic.libraries)
get_exportacao_agrupamentos(agrupamento = 'Complexo da Saúde', ano_minimo = 2024)
```

Assinatura (Python): `get_exportacao_agrupamentos(*, agrupamento: 'str', ano_minimo: 'int' = None, anos: 'List[int]' = None, departamento: 'str' = None, cg: 'str' = None) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_importacao_agrupamentos`

Importação mensal de um agrupamento de NCM da SDIC.

```python
# Python
from sdic_libraries import get_importacao_agrupamentos
get_importacao_agrupamentos(agrupamento='Complexo da Saúde', ano_minimo=2024)
```

```r
# R
library(sdic.libraries)
get_importacao_agrupamentos(agrupamento = 'Complexo da Saúde', ano_minimo = 2024)
```

Assinatura (Python): `get_importacao_agrupamentos(*, agrupamento: 'str', ano_minimo: 'int' = None, anos: 'List[int]' = None, departamento: 'str' = None, cg: 'str' = None) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_exportacao_agrupamentos_pais_ncm`

Exportação de um agrupamento por país e NCM, ou somada por setor, subsetor ou produto (`nivel_agregacao`).

```python
# Python
from sdic_libraries import get_exportacao_agrupamentos_pais_ncm
get_exportacao_agrupamentos_pais_ncm(agrupamento='Complexo da Saúde', ano_minimo=2024, nivel_agregacao='setor')
```

```r
# R
library(sdic.libraries)
get_exportacao_agrupamentos_pais_ncm(agrupamento = 'Complexo da Saúde', ano_minimo = 2024, nivel_agregacao = 'setor')
```

Assinatura (Python): `get_exportacao_agrupamentos_pais_ncm(*, agrupamento: 'str', ano_minimo: 'int' = None, mes_maximo: 'int' = None, nivel_agregacao: 'str' = None, agregado_ano: 'bool' = False, posicao: 'int' = None, departamento: 'str' = None, cg: 'str' = None) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

### `get_importacao_agrupamentos_pais_ncm`

Importação de um agrupamento por país e NCM, ou somada por setor, subsetor ou produto (`nivel_agregacao`).

```python
# Python
from sdic_libraries import get_importacao_agrupamentos_pais_ncm
get_importacao_agrupamentos_pais_ncm(agrupamento='Complexo da Saúde', ano_minimo=2024, nivel_agregacao='setor')
```

```r
# R
library(sdic.libraries)
get_importacao_agrupamentos_pais_ncm(agrupamento = 'Complexo da Saúde', ano_minimo = 2024, nivel_agregacao = 'setor')
```

Assinatura (Python): `get_importacao_agrupamentos_pais_ncm(*, agrupamento: 'str', ano_minimo: 'int' = None, mes_maximo: 'int' = None, nivel_agregacao: 'str' = None, agregado_ano: 'bool' = False, posicao: 'int' = None, departamento: 'str' = None, cg: 'str' = None) -> pandas.core.frame.DataFrame`

Dados consultados: [Comércio exterior (ComexStat)](dados.md#comexstat).

## Séries da API (bases do carga_base e indicadores)

### `listar_series`

Séries que a sdic_api publica em `/series` (bases do carga_base e indicadores oficiais): nome, descrição, fonte, filtros e dimensões.

```python
# Python
from sdic_libraries import listar_series
listar_series()
```

```r
# R
library(sdic.libraries)
listar_series()
```

Assinatura (Python): `listar_series() -> 'pd.DataFrame'`

Dados consultados: [Séries da sdic_api (/series)](dados.md#series).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `nome` | texto | nome a passar em get_serie |
| `descricao` | texto |  |
| `fonte` | texto |  |
| `colunas` | texto | colunas devolvidas, separadas por vírgula |
| `filtros` | texto | colunas aceitas como filtro |
| `obrigatorios` | texto | filtros sem os quais a consulta é recusada |
| `periodo` | texto | coluna a que `desde` e `ate` se aplicam |
| `dimensoes` | texto | dimensões com nomes, para get_dimensao_serie |

### `get_serie`

Valores de uma série, com filtros pelos nomes das colunas e período (`desde`, `ate`). `com_nomes` junta os nomes das dimensões.

```python
# Python
from sdic_libraries import get_serie
get_serie('sidra_producao', cod_tabela=8888, cod_localidade='35', desde='2025-01-01')
```

```r
# R
library(sdic.libraries)
get_serie('sidra_producao', cod_tabela = 8888, cod_localidade = '35', desde = '2025-01-01')
```

Assinatura (Python): `get_serie(nome: 'str', desde: 'Optional[Any]' = None, ate: 'Optional[Any]' = None, com_nomes: 'bool' = False, **filtros: 'Any') -> 'pd.DataFrame'`

Dados consultados: [Séries da sdic_api (/series)](dados.md#series).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `(colunas da série)` |  | as de listar_series(); códigos sempre como texto, `valor` numérico |
| `*_nome` | texto | com `com_nomes`: nome de cada código que tenha dimensão |

### `get_dimensao_serie`

Códigos e nomes de uma dimensão de uma série (variáveis, categorias, localidades, atividades).

```python
# Python
from sdic_libraries import get_dimensao_serie
get_dimensao_serie('sidra_producao', 'variavel')
```

```r
# R
library(sdic.libraries)
get_dimensao_serie('sidra_producao', 'variavel')
```

Assinatura (Python): `get_dimensao_serie(nome: 'str', dimensao: 'str') -> 'pd.DataFrame'`

Dados consultados: [Séries da sdic_api (/series)](dados.md#series).

### `listar_referencias`

Tabelas de de-para disponíveis (CNAE, ISIC, municípios, intensidade tecnológica, agrupamentos NCM).

```python
# Python
from sdic_libraries import listar_referencias
listar_referencias()
```

```r
# R
library(sdic.libraries)
listar_referencias()
```

Assinatura (Python): `listar_referencias() -> 'pd.DataFrame'`

Dados consultados: [Tabelas de de-para (CNAE, ISIC, municípios, intensidade tecnológica, agrupamentos NCM)](dados.md#referencias).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `nome` | texto | nome a passar em get_referencia |
| `descricao` | texto |  |

### `get_referencia`

Uma tabela de de-para inteira, com todos os códigos como texto.

```python
# Python
from sdic_libraries import get_referencia
get_referencia('isic_cnae')
```

```r
# R
library(sdic.libraries)
get_referencia('isic_cnae')
```

Assinatura (Python): `get_referencia(nome: 'str') -> 'pd.DataFrame'`

Dados consultados: [Tabelas de de-para (CNAE, ISIC, municípios, intensidade tecnológica, agrupamentos NCM)](dados.md#referencias).

## Seções publicadas (JSON do portal)

### `listar_secoes_publicadas`

Seções publicadas em JSON (as mesmas do portal) e para quais unidades existem.

```python
# Python
from sdic_libraries import listar_secoes_publicadas
listar_secoes_publicadas()
```

```r
# R
library(sdic.libraries)
listar_secoes_publicadas()
```

Assinatura (Python): `listar_secoes_publicadas() -> 'pd.DataFrame'`

Dados consultados: [Seções publicadas (JSON do portal e dos subsídios)](dados.md#secoes_publicadas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `secao` | texto | nome a passar em `secao` |
| `titulo` | texto |  |
| `unidades` | texto | para quem existe |
| `fonte` | texto |  |

### `get_kpis_publicados`

Indicadores de uma seção publicada, um por linha (inclui o indicador de capa), com fonte, referência e data.

```python
# Python
from sdic_libraries import get_kpis_publicados
get_kpis_publicados('SP', 'emprego')
```

```r
# R
library(sdic.libraries)
get_kpis_publicados('SP', 'emprego')
```

Assinatura (Python): `get_kpis_publicados(uf: 'Optional[str]', secao: 'str', ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Seções publicadas (JSON do portal e dos subsídios)](dados.md#secoes_publicadas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `secao` | texto | id da seção |
| `uf` | texto | sigla da UF ou BRASIL |
| `id` | texto | id do indicador |
| `rotulo` | texto | nome exibido |
| `valor` | número | valor numérico (nulo se só houver texto) |
| `valor_exibido` | texto | valor formatado como no portal |
| `unidade` | texto |  |
| `periodo` | texto |  |
| `capa` | lógico | verdadeiro para o indicador de capa |
| `variacao_direcao` | texto | up, down ou flat |
| `variacao_rotulo` | texto |  |
| `fonte` | texto | fonte da seção |
| `referencia` | texto | período de referência da seção |
| `atualizado_em` | texto | data da publicação (AAAA-MM-DD) |

### `get_series_publicadas`

Séries dos gráficos de uma seção publicada, em formato longo (gráfico, série, período, valor).

```python
# Python
from sdic_libraries import get_series_publicadas
get_series_publicadas('SP', 'emprego')
```

```r
# R
library(sdic.libraries)
get_series_publicadas('SP', 'emprego')
```

Assinatura (Python): `get_series_publicadas(uf: 'Optional[str]', secao: 'str', ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Seções publicadas (JSON do portal e dos subsídios)](dados.md#secoes_publicadas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `secao` | texto |  |
| `uf` | texto |  |
| `grafico` | texto | id do gráfico |
| `grafico_titulo` | texto |  |
| `unidade` | texto |  |
| `serie` | texto | id da série |
| `serie_rotulo` | texto |  |
| `t` | texto | período como publicado (AAAAMM, AAAA ou rótulo) |
| `v` | número | valor |

### `get_ranking_publicado`

Listas ordenadas de uma seção publicada (ex.: maiores saldos), um item por linha.

```python
# Python
from sdic_libraries import get_ranking_publicado
get_ranking_publicado('SP', 'emprego')
```

```r
# R
library(sdic.libraries)
get_ranking_publicado('SP', 'emprego')
```

Assinatura (Python): `get_ranking_publicado(uf: 'Optional[str]', secao: 'str', ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Seções publicadas (JSON do portal e dos subsídios)](dados.md#secoes_publicadas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `secao` | texto |  |
| `uf` | texto |  |
| `lista` | texto | id da lista |
| `titulo` | texto |  |
| `metrica` | texto |  |
| `unidade` | texto |  |
| `tom` | texto | pos, neg ou neutro |
| `posicao` | inteiro | ordem publicada, a partir de 1 |
| `nome` | texto |  |
| `valor` | número |  |
| `valor_exibido` | texto |  |

### `get_detalhamento_publicado`

Composições de uma seção publicada (ex.: por intensidade tecnológica), com valor e participação.

```python
# Python
from sdic_libraries import get_detalhamento_publicado
get_detalhamento_publicado('SP', 'emprego')
```

```r
# R
library(sdic.libraries)
get_detalhamento_publicado('SP', 'emprego')
```

Assinatura (Python): `get_detalhamento_publicado(uf: 'Optional[str]', secao: 'str', ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Seções publicadas (JSON do portal e dos subsídios)](dados.md#secoes_publicadas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `secao` | texto |  |
| `uf` | texto |  |
| `detalhamento` | texto | id |
| `titulo` | texto |  |
| `dimensao` | texto |  |
| `unidade` | texto |  |
| `periodo` | texto |  |
| `nome` | texto |  |
| `valor` | número |  |
| `valor_exibido` | texto |  |
| `participacao` | número | fração do total (0 a 1), quando publicada |

### `get_destaques_publicados`

Título, linha de apoio e destaques do texto de uma seção publicada, com os valores já preenchidos.

```python
# Python
from sdic_libraries import get_destaques_publicados
get_destaques_publicados('SP', 'emprego')
```

```r
# R
library(sdic.libraries)
get_destaques_publicados('SP', 'emprego')
```

Assinatura (Python): `get_destaques_publicados(uf: 'Optional[str]', secao: 'str', ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Seções publicadas (JSON do portal e dos subsídios)](dados.md#secoes_publicadas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `secao` | texto |  |
| `uf` | texto |  |
| `tipo` | texto | titulo, apoio ou destaque |
| `tom` | texto | pos, neg, neutro (só destaques) |
| `texto` | texto | com os valores já preenchidos |

### `get_secao_publicada`

JSON completo de uma seção publicada (contrato v1.1), como dicionário/lista. Baixo nível: prefira as funções que devolvem tabela.

```python
# Python
from sdic_libraries import get_secao_publicada
get_secao_publicada('SP', 'emprego')
```

```r
# R
library(sdic.libraries)
get_secao_publicada('SP', 'emprego')
```

Assinatura (Python): `get_secao_publicada(uf: 'Optional[str]', secao: 'str', ambiente: 'Optional[str]' = None) -> 'dict'`

Dados consultados: [Seções publicadas (JSON do portal e dos subsídios)](dados.md#secoes_publicadas).

### `get_atualizacao_publicada`

Quando cada carga foi publicada pela última vez nos JSON do ambiente.

```python
# Python
from sdic_libraries import get_atualizacao_publicada
get_atualizacao_publicada()
```

```r
# R
library(sdic.libraries)
get_atualizacao_publicada()
```

Assinatura (Python): `get_atualizacao_publicada(ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Seções publicadas (JSON do portal e dos subsídios)](dados.md#secoes_publicadas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `carga` | texto | carga do carga_base |
| `publicado_em` | texto | data e hora (UTC) da carga publicada |
| `ambiente` | texto |  |

## Políticas da SDIC (gaia_nib)

### `listar_politicas`

Políticas publicadas pelo gaia_nib, na ordem do catálogo publicado, com a marca `permitida`.

```python
# Python
from sdic_libraries import listar_politicas
listar_politicas()
```

```r
# R
library(sdic.libraries)
listar_politicas()
```

Assinatura (Python): `listar_politicas(ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Políticas da SDIC](dados.md#politicas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `id` | texto | id a passar em get_politica |
| `nome` | texto |  |
| `sigla` | texto |  |
| `departamento` | texto |  |
| `categoria` | texto |  |
| `regionalizavel` | lógico | tem arquivo por UF |
| `ordem` | inteiro | ordem publicada |
| `file` | texto | caminho do arquivo |
| `permitida` | lógico | está em politicas_permitidas.json |

### `get_politica`

Indicadores de uma política (capa, secundário e modalidades), um por linha, para uma UF ou para o Brasil (`uf=None`).

```python
# Python
from sdic_libraries import get_politica
get_politica('b_mais_p', uf='SP')
```

```r
# R
library(sdic.libraries)
get_politica('b_mais_p', uf = 'SP')
```

Assinatura (Python): `get_politica(id: 'str', uf: 'Optional[str]' = None, ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Políticas da SDIC](dados.md#politicas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `policy_id` | texto |  |
| `nome` | texto |  |
| `sigla` | texto |  |
| `uf` | texto | sigla ou BRASIL |
| `papel` | texto | capa, secundario ou modalidade |
| `id` | texto | id do indicador |
| `rotulo` | texto |  |
| `valor` | número |  |
| `valor_exibido` | texto |  |
| `unidade` | texto | não some indicadores de unidades diferentes |
| `periodo` | texto |  |
| `variacao_rotulo` | texto |  |
| `fonte` | texto |  |
| `referencia` | texto |  |
| `atualizado_em` | texto |  |

### `get_politicas_estado`

Indicadores de todas as políticas publicadas para uma UF, na ordem do catálogo. Não soma nem ordena políticas entre si.

```python
# Python
from sdic_libraries import get_politicas_estado
get_politicas_estado('SP')
```

```r
# R
library(sdic.libraries)
get_politicas_estado('SP')
```

Assinatura (Python): `get_politicas_estado(uf: 'Optional[str]', ambiente: 'Optional[str]' = None, so_permitidas: 'bool' = False) -> 'pd.DataFrame'`

Dados consultados: [Políticas da SDIC](dados.md#politicas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `policy_id` | texto |  |
| `nome` | texto |  |
| `sigla` | texto |  |
| `uf` | texto | sigla ou BRASIL |
| `papel` | texto | capa, secundario ou modalidade |
| `id` | texto | id do indicador |
| `rotulo` | texto |  |
| `valor` | número |  |
| `valor_exibido` | texto |  |
| `unidade` | texto | não some indicadores de unidades diferentes |
| `periodo` | texto |  |
| `variacao_rotulo` | texto |  |
| `fonte` | texto |  |
| `referencia` | texto |  |
| `atualizado_em` | texto |  |

### `get_resumo_politicas`

Resumo publicado das políticas de uma UF ou do Brasil (`uf=None`): quantidade, recursos, atendimentos e posição.

```python
# Python
from sdic_libraries import get_resumo_politicas
get_resumo_politicas('SP')
```

```r
# R
library(sdic.libraries)
get_resumo_politicas('SP')
```

Assinatura (Python): `get_resumo_politicas(uf: 'Optional[str]' = None, ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Políticas da SDIC](dados.md#politicas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `uf` | texto |  |
| `nome_uf` | texto |  |
| `n_politicas` | inteiro |  |
| `recursos` | número | R$ |
| `recursos_exibido` | texto |  |
| `atendimentos` | número |  |
| `atendimentos_exibido` | texto |  |
| `ranking_posicao` | inteiro |  |
| `ranking_de` | inteiro |  |
| `ranking_exibido` | texto |  |
| `nota_agregacao` | texto | leia antes de usar os totais |

### `get_municipios_elegiveis`

Municípios com políticas publicadas (código IBGE, nome, UF).

```python
# Python
from sdic_libraries import get_municipios_elegiveis
get_municipios_elegiveis()
```

```r
# R
library(sdic.libraries)
get_municipios_elegiveis()
```

Assinatura (Python): `get_municipios_elegiveis(ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Políticas da SDIC](dados.md#politicas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `ibge` | texto | código IBGE de 7 dígitos |
| `municipio` | texto |  |
| `uf` | texto |  |

### `get_manifesto_politicas`

Rótulo da fonte, diretorias exibidas e notas publicadas junto com as políticas.

```python
# Python
from sdic_libraries import get_manifesto_politicas
get_manifesto_politicas()
```

```r
# R
library(sdic.libraries)
get_manifesto_politicas()
```

Assinatura (Python): `get_manifesto_politicas(ambiente: 'Optional[str]' = None) -> 'pd.DataFrame'`

Dados consultados: [Políticas da SDIC](dados.md#politicas).

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `campo` | texto | rotulo_fonte, diretoria ou nota |
| `id` | texto | id da nota (vazio nos demais) |
| `valor` | texto |  |

### `get_politica_publicada`

JSON completo de uma política, como dicionário/lista. Baixo nível: prefira `get_politica`.

```python
# Python
from sdic_libraries import get_politica_publicada
get_politica_publicada('b_mais_p', uf='SP')
```

```r
# R
library(sdic.libraries)
get_politica_publicada('b_mais_p', uf = 'SP')
```

Assinatura (Python): `get_politica_publicada(id: 'str', uf: 'Optional[str]' = None, ambiente: 'Optional[str]' = None) -> 'Optional[dict]'`

Dados consultados: [Políticas da SDIC](dados.md#politicas).

## Utilitários e configuração

### `criar_indice`

Índice-base (ano_base = 100) para colunas numéricas de uma série temporal.

```python
# Python
from sdic_libraries import criar_indice
criar_indice(df, ano_base=2020, coluna_data='ano', colunas_valores=['estoque_trabalhadores'])
```

```r
# R
library(sdic.libraries)
criar_indice(df, ano_base = 2020, coluna_data = 'ano', colunas_valores = 'estoque_trabalhadores')
```

Assinatura (Python): `criar_indice(df: 'pd.DataFrame', ano_base: 'int', coluna_data: 'str', colunas_valores: 'Union[str, List[str]]') -> 'pd.DataFrame'`

### `juntar_emprego_comex`

Une emprego e comércio exterior por divisão CNAE/ISIC e ano.

```python
# Python
from sdic_libraries import juntar_emprego_comex
juntar_emprego_comex(df_emprego, df_comex)
```

```r
# R
library(sdic.libraries)
juntar_emprego_comex(df_emprego, df_comex)
```

Assinatura (Python): `juntar_emprego_comex(emprego: 'pd.DataFrame', comex: 'pd.DataFrame', how: 'str' = 'left') -> 'pd.DataFrame'`

### `sdic_config`

De onde a biblioteca está lendo (API, dados, políticas), ambiente, se há chave e de onde veio cada valor.

```python
# Python
from sdic_libraries import sdic_config
sdic_config()
```

```r
# R
library(sdic.libraries)
sdic_config()
```

Assinatura (Python): `sdic_config() -> 'pd.DataFrame'`

Colunas devolvidas:

| Coluna | Tipo | Significado |
|---|---|---|
| `item` | texto |  |
| `valor` | texto | a chave nunca é mostrada |
| `variavel` | texto | variável de ambiente correspondente |
| `de_onde` | texto | argumento, variável, arquivo ou padrão |

### `descrever`

Ficha de uma base ou função do catálogo: origem, fonte, periodicidade, colunas e funções que a leem.

```python
# Python
from sdic_libraries import descrever
descrever('secoes_publicadas')
```

```r
# R
library(sdic.libraries)
descrever('secoes_publicadas')
```

Assinatura (Python): `descrever(nome: 'str') -> 'pd.DataFrame'`

### `ler_json_publicado`

Lê um JSON público de uma origem do catálogo. Último recurso: use quando não houver função pronta.

```python
# Python
from sdic_libraries import ler_json_publicado
ler_json_publicado('dados', 'homologacao/SP/emprego.json')
```

```r
# R
library(sdic.libraries)
ler_json_publicado('dados', 'homologacao/SP/emprego.json')
```

Assinatura (Python): `ler_json_publicado(origem: 'str', caminho: 'str', base_url: 'Optional[str]' = None, timeout: 'Optional[int]' = None) -> 'Any'`
