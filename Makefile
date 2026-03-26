# AgentCanvas — Local Development Makefile
#
# Requirements: bash shell, uv (Python), pnpm (Node)
# Note: `make dev` runs both services in parallel using `&` — requires bash, not cmd.exe.
# On Windows, run from Git Bash, WSL, or the integrated terminal in VS Code (bash mode).

.PHONY: install dev-backend dev-frontend dev lint test build-frontend production-check

# ─── Install ──────────────────────────────────────────────────────────────────

## install: Install all backend and frontend dependencies
install:
	cd src/backend && uv sync
	cd src/frontend && pnpm install

# ─── Development servers ──────────────────────────────────────────────────────

## dev-backend: Start the FastAPI backend on :8000 with hot-reload
dev-backend:
	cd src/backend && uv run uvicorn main:app --reload --port 8000

## dev-frontend: Start the Vite dev server on :5173 with hot-reload
dev-frontend:
	cd src/frontend && pnpm run dev

## dev: Start both backend and frontend in parallel (requires bash)
dev:
	cd src/backend && uv run uvicorn main:app --reload --port 8000 & \
	cd src/frontend && pnpm run dev & \
	wait

# ─── Quality checks ───────────────────────────────────────────────────────────

## lint: Run ruff on the backend and tsc --noEmit on the frontend
lint:
	cd src/backend && uv run ruff check .
	cd src/frontend && pnpm exec tsc --noEmit

## test: Run pytest on the backend test suite
test:
	cd src/backend && uv run pytest

# ─── Build ────────────────────────────────────────────────────────────────────

## build-frontend: Compile the React app to a production bundle in src/frontend/dist/
build-frontend:
	cd src/frontend && pnpm run build

# ─── Production readiness ─────────────────────────────────────────────────────

## production-check: Verify FRONTEND_DIST_DIR is set and the dist/ directory exists
##   Exits non-zero with a clear message if either condition is not met.
##   Run this before deploying to confirm the frontend build is present.
production-check:
	@if [ -z "$(FRONTEND_DIST_DIR)" ]; then \
		echo "ERROR: FRONTEND_DIST_DIR is not set."; \
		echo "  Set it in your .env file or export it before running this target."; \
		echo "  Example: FRONTEND_DIST_DIR=src/frontend/dist"; \
		exit 1; \
	fi
	@if [ ! -d "$(FRONTEND_DIST_DIR)" ]; then \
		echo "ERROR: FRONTEND_DIST_DIR is set to '$(FRONTEND_DIST_DIR)' but the directory does not exist."; \
		echo "  Run 'make build-frontend' first to generate the production build."; \
		exit 1; \
	fi
	@echo "OK: FRONTEND_DIST_DIR='$(FRONTEND_DIST_DIR)' exists. Production build is present."
