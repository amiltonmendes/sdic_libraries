# sdic_libraries (Python)

Leitura dos dados da plataforma da SDIC, sempre como `DataFrame`: emprego (RAIS, Novo CAGED), comércio
exterior (ComexStat), séries da API, seções publicadas em JSON e políticas da SDIC. As mesmas funções existem
em R (`sdic.libraries`).

```python
from sdic_libraries import listar_bases, descrever, sdic_config
listar_bases()                      # o que existe
descrever("get_kpis_publicados")    # de onde vem e que colunas tem
sdic_config()                       # de onde a biblioteca está lendo
```

Documentação: <https://github.com/amiltonmendes/sdic_libraries/blob/main/docs/index.md>.
