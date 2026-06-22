# Makefile para instalação automática da biblioteca SDIC

.PHONY: help install install-python install-r test test-python test-r clean

# Default target
help:
	@echo "📦 Biblioteca SDIC - Comandos de Instalação"
	@echo "==========================================="
	@echo ""
	@echo "Principais comandos:"
	@echo "  install          Instalar ambas as linguagens (Python + R)"
	@echo "  install-python   Instalar apenas Python"
	@echo "  install-r        Instalar apenas R"
	@echo "  test             Testar ambas as linguagens"
	@echo "  test-python      Testar apenas Python"
	@echo "  test-r           Testar apenas R"
	@echo "  clean            Limpar arquivos temporários"
	@echo ""
	@echo "Uso:"
	@echo "  make install     # Instalação completa"
	@echo "  make test        # Testes completos"

# Instalação completa (Python + R)
install: install-python install-r
	@echo ""
	@echo "🎉 Instalação completa da biblioteca SDIC finalizada!"
	@echo "📖 Consulte INSTALL.md para instruções de uso"

# Instalação Python
install-python:
	@echo "🐍 Instalando biblioteca SDIC Python..."
	cd python && python install.py

# Instalação R  
install-r:
	@echo "📊 Instalando biblioteca SDIC R..."
	cd r && Rscript install.R

# Testes completos
test: test-python test-r
	@echo "✅ Todos os testes concluídos!"

# Teste Python
test-python:
	@echo "🧪 Testando biblioteca Python..."
	cd python && python -c "from sdic_libraries.data_access.emprego import Emprego; print('✅ Python OK')"

# Teste R
test-r:
	@echo "🧪 Testando biblioteca R..."
	cd r && Rscript -e "source('R/data_access/emprego.R'); api <- Emprego\$$new(); cat('✅ R OK\n')"

# Limpeza
clean:
	@echo "🧹 Limpando arquivos temporários..."
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -delete
	find . -name ".pytest_cache" -delete
	rm -rf python/build/
	rm -rf python/dist/
	rm -rf python/sdic_libraries.egg-info/
	@echo "✅ Limpeza concluída"

# Instalação para desenvolvimento
dev: install
	@echo "🔧 Configurando ambiente de desenvolvimento..."
	cd python && pip install -r requirements-dev.txt
	cd r && Rscript -e "install.packages(c('testthat', 'devtools', 'pkgdown', 'usethis'))"
	@echo "✅ Ambiente de desenvolvimento configurado"

# Docker build (futuro)
docker:
	@echo "🐳 Funcionalidade Docker em desenvolvimento..."

# Verificação rápida
check:
	@echo "🔍 Verificação rápida da instalação..."
	@echo "Python:" 
	@cd python && python -c "import sys; print(f'  ✅ Python {sys.version}')" 2>/dev/null || echo "  ❌ Python não encontrado"
	@echo "R:"
	@Rscript -e "cat('  ✅ R', R.version\$$version.string, '\n')" 2>/dev/null || echo "  ❌ R não encontrado"
	@echo ""