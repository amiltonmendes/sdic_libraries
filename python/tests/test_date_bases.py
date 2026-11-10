"""get_date_bases sem /data_bases (sdic_api 4.0.0): data da 1ª linha de uma rota por base (mock, sem rede)."""
from unittest.mock import patch

import pytest

from sdic_libraries.dados.emprego.api import Emprego, EmpregoAPIError

RESPOSTAS = {
    "/exportacao_isic_divisao": {"count": 9, "items": [{"Ano": 2026, "Mes": 9, "DivisaoISIC": "10"}]},
    "/saldo_caged/nacional/divisao": {"count": 9, "items": [{"mes_referencia": "2026-09-01"}]},
    "/get_estoque_emprego_nacional/": {"count": 9, "items": [{"ano": 2024}]},
}


def test_uma_linha_por_base_e_pagina_de_uma_linha():
    chamadas = []

    def falso(self, rota, params=None):
        chamadas.append((rota, params))
        return RESPOSTAS[rota]

    with patch.object(Emprego, "_make_request", falso):
        bases = Emprego(base_url="https://sdicapi.teste").get_date_bases()
    assert bases == [
        {"Base": "ComexStat", "DataUltimaAtualizacao": "2026-09-01"},
        {"Base": "CAGED", "DataUltimaAtualizacao": "2026-09-01"},
        {"Base": "RAIS", "DataUltimaAtualizacao": "2024-12-31"},
    ]
    assert all(p["tamanho_pagina"] == 1 and p["pagina"] == 1 for _, p in chamadas)
    assert "/data_bases" not in [r for r, _ in chamadas]


def test_base_que_falha_fica_de_fora_e_todas_falhando_erra():
    def sem_rais(self, rota, params=None):
        if rota.startswith("/get_estoque"):
            raise EmpregoAPIError("fora do ar")
        return RESPOSTAS[rota]

    with patch.object(Emprego, "_make_request", sem_rais):
        assert [b["Base"] for b in Emprego(base_url="https://sdicapi.teste").get_date_bases()] == ["ComexStat", "CAGED"]

    def tudo_falha(self, rota, params=None):
        raise EmpregoAPIError("fora do ar")

    with patch.object(Emprego, "_make_request", tudo_falha), pytest.raises(EmpregoAPIError):
        Emprego(base_url="https://sdicapi.teste").get_date_bases()
