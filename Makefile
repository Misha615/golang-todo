include .env
export

export PROJECT_ROOT=${shell pwd}

env-up:
	@make fix-postgres-perms
	@docker compose up -d todoapp-postgres

env-down:
	@docker compose down todoapp-postgres

env-cleanup:
	@make fix-postgres-perms
	@read -p "clean all volumes? Danger of wasting data. [y/N]: " ans; \
	if [ "$$ans" = "y" ]; then \
		make fix-postgres-perms && \
		docker compose down todoapp-postgres port-forwarder && \
		rm -rf out/pgdata && \
		echo "Volumes are deleted"; \
	else \
		echo "Deletion is canceled"; \
	fi

fix-postgres-perms:
	@sudo chown -R 999:999 out/pgdata 2>/dev/null || true
	@sudo chmod 755 out out/pgdata 2>/dev/null || true
	@sudo find out/pgdata -type d -exec chmod 755 {} + 2>/dev/null || true
	@sudo find out/pgdata -type f -exec chmod 644 {} + 2>/dev/null || true

env-port-forward:
	@docker compose up -d port-forwarder

env-port-close:
	@docker compose down port-forwarder

migrate-create:
	@if [ -z "${seq}" ]; then \
		echo "No parameter seq. Example: make migrate-create seq=init"; \
		exit 1; \
	fi; \
	docker compose run --rm todoapp-postgres-migrate \
		create \
		-ext sql \
		-dir /migrations \
		-seq "${seq}"

migrate-up:
	@make migrate-action action=up

migrate-down:
	@make migrate-action action=down

migrate-action:
	@if [ -z "${action}" ]; then \
		echo "No parameter seq. Example: make migrate-action action=up"; \
		exit 1; \
	fi; \
	docker compose run --rm todoapp-postgres-migrate \
		-path /migrations \
		-database postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@todoapp-postgres:5432/${POSTGRES_DB}?sslmode=disable "${action}"

logs-cleanup:
	@make fix-postgres-perms
	@read -p "clean all log files? Danger of wasting data. [y/N]: " ans; \
	if [ "$$ans" = "y" ]; then \
		make fix-postgres-perms && \
		docker compose down todoapp-postgres port-forwarder && \
		rm -rf out/pgdata && \
		echo "Logs are deleted"; \
	else \
		echo "Deletion is canceled"; \
	fi

todoapp-run:
	@make fix-postgres-perms
	@export LOGGER_FOLDER=${PROJECT_ROOT}/out/logs && \
	export POSTGRES_HOST=$${POSTGRES_HOST:-$$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' todoapp-env-postgres 2>/dev/null || echo localhost)} && \
	go mod tidy && \
	go run cmd/todoapp/main.go