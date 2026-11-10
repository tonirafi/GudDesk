# Makefile — GudDesk (pola LinkMu / NGTBackend)
.PHONY: help show-config build-client remote-deploy-prod release-prod

help:
	@echo "GudDesk deployment commands"
	@echo ""
	@echo "  make release-prod          Build client lokal + deploy server"
	@echo "  make build-client          Build .deb + .apk (local only) ke ./downloads"
	@echo "  make remote-deploy-prod    rsync + SSH deploy (pull + up)"
	@echo ""
	@echo "Server: /opt/gutekno/guddesk"
	@echo "Domain: https://guddesk.gutekno.com"

show-config:
	@cat project-config 2>/dev/null || echo "project-config not found"

build-client:
	@chmod +x scripts/build-client.sh
	@./scripts/build-client.sh

remote-deploy-prod:
	@chmod +x scripts/remote-deploy-prod.sh
	@./scripts/remote-deploy-prod.sh

release-prod: build-client remote-deploy-prod
