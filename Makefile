# sdic_libraries: comandos de desenvolvimento
PYTHON ?= python
.PHONY: help documentar conferir test test-python test-r clean

help:
	@echo "make documentar   copia contrato/catalogo.json para os pacotes, gera CATALOGO.md, docs/ e a ajuda do R"
	@echo "make conferir     falha se algo gerado estiver desatualizado"
	@echo "make test         testes das duas linguagens + conferir"
	@echo "make test-python | make test-r"

documentar:
	$(PYTHON) scripts/documentar.py
	Rscript -e 'roxygen2::roxygenise("r")'

conferir:
	$(PYTHON) scripts/documentar.py --conferir

test: conferir test-python test-r

test-python:
	cd python && $(PYTHON) -m pytest -q

test-r:
	Rscript -e 'r <- as.data.frame(testthat::test_local("r", reporter = "summary", stop_on_failure = FALSE)); if (sum(r$$failed) + sum(r$$error) > 0) quit(status = 1)'

clean:
	find . -name "__pycache__" -prune -exec rm -rf {} +
	rm -rf python/build python/dist python/*.egg-info python/.pytest_cache
