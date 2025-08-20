# Makefile for Intune Backup Restore
# Works on Windows with make installed (e.g., via chocolatey, scoop, or Git for Windows)

# Variables
PYTHON = python
PIP = $(PYTHON) -m pip
POWERSHELL = powershell -NoProfile -ExecutionPolicy Bypass
PROJECT_DIR = $(shell pwd)

# Default target
.PHONY: all
all: install test

# Install all dependencies
.PHONY: install
install: install-python install-powershell

# Install Python dependencies
.PHONY: install-python
install-python:
	@echo "Installing Python dependencies..."
	$(PYTHON) --version || (echo "Python not found. Please install Python 3.8+" && exit 1)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt
	@echo "✓ Python dependencies installed"

# Install PowerShell dependencies
.PHONY: install-powershell
install-powershell:
	@echo "Installing PowerShell dependencies..."
	$(POWERSHELL) -File scripts/Install-Requirements.ps1
	@echo "✓ PowerShell dependencies installed"

# Run tests
.PHONY: test
test:
	@echo "Running tests..."
	$(PYTHON) tests/test_runner.py --type unit

# Run compliance policies export
.PHONY: export-compliance
export-compliance:
	@echo "Exporting compliance policies..."
	$(PYTHON) -m src.export_runner --module compliance_policies

# Run configuration profiles export  
.PHONY: export-config
export-config:
	@echo "Exporting configuration profiles..."
	$(PYTHON) export_config_profiles.py

# Run all exports
.PHONY: export-all
export-all: export-compliance export-config
	@echo "Generating change log..."
	$(PYTHON) -m src.generate_changelog
	@echo "✓ All exports completed"

# Clean Python cache and temporary files
.PHONY: clean
clean:
	@echo "Cleaning temporary files..."
	-rmdir /s /q __pycache__ 2>nul
	-rmdir /s /q src\__pycache__ 2>nul
	-rmdir /s /q src\utils\__pycache__ 2>nul
	-rmdir /s /q src\modules\__pycache__ 2>nul
	-rmdir /s /q src\modules\python\__pycache__ 2>nul
	-rmdir /s /q tests\__pycache__ 2>nul
	-rmdir /s /q .pytest_cache 2>nul
	-del /q *.pyc 2>nul
	@echo "✓ Cleanup completed"

# Setup development environment
.PHONY: setup
setup: install
	@echo "Setting up development environment..."
	@if not exist ".env" (copy env.template .env && echo "✓ Created .env file - please configure it") else (echo "✓ .env file already exists")
	@echo "✓ Development environment ready"

# Run GitHub Actions workflow locally (requires act)
.PHONY: run-workflow
run-workflow:
	@echo "Running GitHub Actions workflow locally..."
	act -W .github/workflows/intune-backup.yml

# Show help
.PHONY: help
help:
	@echo "Intune Backup Restore - Make targets:"
	@echo "  make install          - Install all dependencies"
	@echo "  make install-python   - Install Python dependencies only"
	@echo "  make install-powershell - Install PowerShell dependencies only"
	@echo "  make test            - Run unit tests"
	@echo "  make export-compliance - Export compliance policies"
	@echo "  make export-config   - Export configuration profiles"
	@echo "  make export-all      - Run all exports and generate change log"
	@echo "  make clean           - Clean temporary files"
	@echo "  make setup           - Setup development environment"
	@echo "  make help            - Show this help message"
