"""juntar_emprego_comex: chave (ano, divisão), soma do comex antes da união, validação de colunas."""
from __future__ import annotations

import pandas as pd
import pytest

from sdic_libraries.utils import juntar_emprego_comex

EMPREGO = pd.DataFrame({"ano": [2025, 2025, 2025], "divisao_cnae_cod": ["10", "47", "24"],
                        "estoque_trabalhadores": [100, 500, 40]})
# comex com várias linhas por (ano, divisão): meses/UFs — não pode multiplicar o emprego
COMEX = pd.DataFrame({"ano": [2025, 2025, 2025, 2025], "divisao_isic_cod": ["10", "10", "24", "89"],
                      "vl_fob": [1.0, 2.0, 5.0, 9.0], "kg_liquido": [10, 20, 50, 90]})


def test_soma_comex_e_nao_multiplica_linhas_do_emprego():
    r = juntar_emprego_comex(EMPREGO, COMEX)
    assert len(r) == 3
    dez = r[r.divisao_cnae_cod == "10"].iloc[0]
    assert (dez.vl_fob, dez.kg_liquido, dez.estoque_trabalhadores) == (3.0, 30, 100)


def test_left_mantem_servicos_com_comex_nulo_e_inner_descarta():
    r = juntar_emprego_comex(EMPREGO, COMEX)
    assert pd.isna(r[r.divisao_cnae_cod == "47"].vl_fob.iloc[0])
    assert set(juntar_emprego_comex(EMPREGO, COMEX, how="inner").divisao_cnae_cod) == {"10", "24"}
    assert "89" in set(juntar_emprego_comex(EMPREGO, COMEX, how="outer").divisao_cnae_cod)


def test_coluna_faltando_da_erro_claro():
    with pytest.raises(ValueError, match="comex sem a.*divisao_isic_cod"):
        juntar_emprego_comex(EMPREGO, COMEX.drop(columns="divisao_isic_cod"))
    with pytest.raises(ValueError, match="emprego sem a.*ano"):
        juntar_emprego_comex(EMPREGO.drop(columns="ano"), COMEX)
