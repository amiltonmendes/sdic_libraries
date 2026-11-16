"""Configuração: precedência, .env sem efeitos colaterais, nomes antigos e destino da chave."""
from __future__ import annotations

import logging
import os
import warnings

import pytest
import requests

from sdic_libraries import config, sdic_config
from sdic_libraries.dados.comex import Comex
from sdic_libraries.dados.emprego import Emprego


def test_padroes_sem_configuracao():
    assert config.url("api") == "https://sdicapi.dados.ninja"
    assert config.ambiente() == "producao"
    assert config.timeout() == 30
    assert config.chave() is None


def test_precedencia_argumento_variavel_env_local_env(monkeypatch, tmp_path):
    (tmp_path / ".env").write_text("SDIC_API_URL=https://do-env\nSDIC_TIMEOUT=11\n")
    assert config.url("api") == "https://do-env"
    (tmp_path / ".env.local").write_text("SDIC_API_URL=https://do-env-local\n")
    assert config.url("api") == "https://do-env-local"
    assert config.timeout() == 11  # .env continua valendo para o que .env.local não define
    monkeypatch.setenv("SDIC_API_URL", "https://da-variavel")
    assert config.url("api") == "https://da-variavel"
    assert config.url("api", "https://do-argumento/") == "https://do-argumento"


def test_timeout_explicito_vence_a_variavel(monkeypatch):
    monkeypatch.setenv("SDIC_TIMEOUT", "5")
    assert Emprego(timeout=120).timeout == 120
    assert Emprego().timeout == 5


def test_timeout_invalido_diz_qual_variavel(monkeypatch):
    monkeypatch.setenv("SDIC_TIMEOUT", "abc")
    with pytest.raises(ValueError, match="SDIC_TIMEOUT"):
        config.timeout()


def test_env_nao_altera_o_ambiente_do_processo_nem_o_logger_raiz(tmp_path):
    (tmp_path / ".env").write_text("OUTRA_COISA_DO_PROJETO=1\nLOG_LEVEL=DEBUG\nSDIC_API_KEY=k\n")
    nivel = logging.getLogger().level
    cliente = Emprego()
    assert cliente.api_key == "k"
    assert "OUTRA_COISA_DO_PROJETO" not in os.environ and "SDIC_API_KEY" not in os.environ
    assert logging.getLogger().level == nivel


def test_chave_no_env_local_vale_para_os_dois_clientes(tmp_path):
    (tmp_path / ".env.local").write_text('SDIC_API_KEY="chave-unica"\n')
    assert Emprego().api_key == Comex().api_key == "chave-unica"
    assert Emprego().session.headers["Authorization"] == "Bearer chave-unica"


def test_nomes_antigos_continuam_valendo_com_aviso(monkeypatch):
    monkeypatch.setenv("COMEX_API_KEY", "antiga")
    config._avisados.clear()
    with pytest.warns(DeprecationWarning, match="SDIC_API_KEY"):
        assert config.chave() == "antiga"
    monkeypatch.setenv("SDIC_API_KEY", "nova")
    with warnings.catch_warnings():
        warnings.simplefilter("error")
        assert config.chave() == "nova"


def test_chave_nao_viaja_sem_https(monkeypatch):
    monkeypatch.setenv("SDIC_API_KEY", "k")
    with pytest.raises(ValueError, match="https"):
        Emprego(base_url="http://host-alheio")
    Emprego(base_url="http://127.0.0.1:8123")  # teste local é permitido
    monkeypatch.delenv("SDIC_API_KEY")
    Emprego(base_url="http://host-alheio")  # sem chave não há o que proteger


def test_ambiente_invalido():
    with pytest.raises(ValueError, match="producao ou homologacao"):
        config.ambiente("prod")


def test_sdic_config_nunca_mostra_a_chave(monkeypatch):
    monkeypatch.setenv("SDIC_API_KEY", "segredo-123")
    df = sdic_config()
    assert list(df.columns) == ["item", "valor", "variavel", "de_onde"]
    assert "segredo-123" not in df.to_string()
    assert df.loc[df["item"] == "chave da API", "valor"].item() == "definida"
    assert "segredo-123" not in repr(Emprego()) + repr(Comex())


# ── salvar_chave ────────────────────────────────────────────────────────────────────────────────
CHAVE = "abcdef0123456789abcdef0123456789"


def test_salvar_chave_grava_so_para_o_dono_e_passa_a_valer(tmp_path):
    from sdic_libraries import salvar_chave
    arquivo = salvar_chave(CHAVE, testar=False)
    assert arquivo == str(tmp_path / ".config" / "sdic" / ".env")
    if os.name != "nt":
        assert oct(os.stat(arquivo).st_mode & 0o777) == "0o600"
        assert oct(os.stat(os.path.dirname(arquivo)).st_mode & 0o777) == "0o700"
    assert config.chave() == CHAVE
    linha = sdic_config().set_index("item").loc["chave da API"]
    assert linha["valor"] == "definida" and linha["de_onde"].startswith(arquivo)
    assert CHAVE not in sdic_config().to_string()


def test_salvar_chave_troca_a_anterior_e_mantem_o_resto(tmp_path, monkeypatch):
    from sdic_libraries import salvar_chave
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path / "cfg"))
    (tmp_path / "cfg" / "sdic").mkdir(parents=True)
    (tmp_path / "cfg" / "sdic" / ".env").write_text("SDIC_AMBIENTE=homologacao\nexport SDIC_API_KEY=velha0123456789abc\n")
    arquivo = salvar_chave(CHAVE, testar=False)
    assert open(arquivo).read() == f"SDIC_AMBIENTE=homologacao\nSDIC_API_KEY={CHAVE}\n"
    assert config.ambiente() == "homologacao"


@pytest.mark.parametrize("ruim", ["", "curta", "tem espaco no meio 0123456789", "a=b0123456789abcdef"])
def test_salvar_chave_recusa_chave_mal_formada(ruim, tmp_path):
    from sdic_libraries import salvar_chave
    with pytest.raises(ValueError, match="Nada foi salvo"):
        salvar_chave(ruim, testar=False)
    assert not (tmp_path / ".config" / "sdic" / ".env").exists()


def test_salvar_chave_recusada_pela_api_nao_grava(monkeypatch, tmp_path):
    from sdic_libraries import salvar_chave, transporte
    pedidos = []

    def get(self, url, timeout=None):
        pedidos.append((url, self.headers.get("Authorization")))
        r = requests.Response()
        r.status_code = 401
        return r
    monkeypatch.setattr(transporte.requests.Session, "get", get)
    with pytest.raises(ValueError, match="recusou a chave"):
        salvar_chave(CHAVE)
    assert pedidos == [("https://sdicapi.dados.ninja/series", f"Bearer {CHAVE}")]
    assert not (tmp_path / ".config" / "sdic" / ".env").exists()


def test_salvar_chave_avisa_quando_outra_tem_precedencia(monkeypatch):
    from sdic_libraries import salvar_chave
    monkeypatch.setenv("SDIC_API_KEY", "da-variavel-0123456789")
    with pytest.warns(UserWarning, match="tem precedência"):
        salvar_chave(CHAVE, testar=False)
