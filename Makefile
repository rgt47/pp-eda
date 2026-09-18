# Makefile for zzcollab research compendium
# Docker-first workflow for reproducible research

# Auto-detect from project (no manual configuration needed)
PACKAGE_NAME := $(shell basename $(CURDIR))
R_VERSION := $(shell grep 'R_VERSION=' Dockerfile 2>/dev/null | head -1 | sed 's/.*R_VERSION=//' || echo "4.5.1")
PROJECT_NAME := $(PACKAGE_NAME)
DOCKERHUB_ACCOUNT = rgt47

# Git-based versioning for reproducibility (use git SHA or date)
GIT_SHA := $(shell git rev-parse --short HEAD 2>/dev/null || echo "$(shell date +%Y%m%d)")
IMAGE_TAG = $(GIT_SHA)

# Help target (default)
help:
	@echo "Available targets:"
	@echo ""
	@echo "  Validation (runs zzrenvcheck on the host; requires local R):"
	@echo "    check-renv            - Full validation: strict + auto-fix (recommended)"
	@echo "    check-renv-no-fix     - Validation only, no auto-install"
	@echo "    check-renv-no-strict  - Standard mode (skip tests/, vignettes/)"
	@echo "    ensure-zzrenvcheck    - Install zzrenvcheck on the host if missing"
	@echo ""
	@echo "  Native R - requires local R installation:"
	@echo "    document, build, check, install, vignettes, test, deps"
	@echo "    check-renv-ci (legacy alias for check-renv)"
	@echo ""
	@echo "  Docker - works without local R:"
	@echo "    r                     - Start container (RECOMMENDED! Auto-detects profile, mounts cache)"
	@echo "    docker-run            - Same as 'make r' (auto-detects profile, mounts cache, validates)"
	@echo "    docker-build          - Build image from current renv.lock"
	@echo "    docker-rebuild        - Rebuild image without cache (force fresh build)"
	@echo "    docker-build-log      - Build with detailed logs (for debugging)"
	@echo "    docker-rstudio        - Start RStudio Server"
	@echo "    docker-push-team, docker-document, docker-build-pkg, docker-check"
	@echo "    docker-test, docker-vignettes, docker-render, docker-render-qmd"
	@echo "    docker-check-renv, docker-check-renv-fix"
	@echo ""
	@echo "  Cleanup:"
	@echo "    clean, docker-clean"
	@echo "    docker-prune-cache       - Remove Docker build cache"
	@echo "    docker-prune-all         - Deep clean (all unused Docker resources)"
	@echo "    docker-disk-usage        - Show Docker disk usage"

# Native R targets (require local R installation)
document:
	R --quiet -e "devtools::document()"

build:
	R CMD build .

check: document
	R CMD check --as-cran *.tar.gz

install: document
	R --quiet -e "devtools::install()"

vignettes: document
	R --quiet -e "devtools::build_vignettes()"

test:
	R --quiet -e "devtools::test()"

deps:
	R --quiet -e "devtools::install_deps(dependencies = TRUE)"

# Validate package dependencies (zzrenvcheck on the HOST, requires host R)
# Checks that all packages used in code are in DESCRIPTION and renv.lock
# Validation is static analysis: it reads R/, analysis/, scripts/ (plus tests/
# and vignettes/ in strict mode) together with DESCRIPTION and renv.lock, and
# queries the repos for versions. It never needs the container's library.
# Host repos are pinned to the image's PPM snapshot (parsed from the
# Dockerfile) so versions resolved here match the container; falls back to
# CRAN when no Dockerfile is present.
PPM_REPO := $(shell sed -n 's/.*RENV_CONFIG_REPOS_OVERRIDE="\([^"]*\)".*/\1/p' Dockerfile 2>/dev/null | head -1)
PPM_REPO := $(if $(PPM_REPO),$(PPM_REPO),https://cloud.r-project.org)
HOST_CHECK := Rscript -e "options(repos = c(CRAN = '$(PPM_REPO)'))" -e

# Install zzrenvcheck on the host if missing (validation tool)
ensure-zzrenvcheck:
	@Rscript -e "if (!requireNamespace('zzrenvcheck', quietly = TRUE)) { install.packages('remotes'); remotes::install_github('rgt47/zzrenvcheck', upgrade = 'never') }"

# Full validation with strict mode and auto-fix (DEFAULT behavior)
# Auto-adds missing packages to DESCRIPTION and renv.lock
# Run this before `git commit` to catch issues locally (prevents CI failures)
check-renv: ensure-zzrenvcheck
	$(HOST_CHECK) "zzrenvcheck::check_packages(auto_fix = TRUE, strict = TRUE)"

# Validation only, no auto-fix (report issues without modifying files)
check-renv-no-fix: ensure-zzrenvcheck
	$(HOST_CHECK) "zzrenvcheck::check_packages(auto_fix = FALSE, strict = TRUE)"

# Standard mode validation (skip tests/, vignettes/, inst/ directories)
check-renv-no-strict: ensure-zzrenvcheck
	$(HOST_CHECK) "zzrenvcheck::check_packages(auto_fix = TRUE, strict = FALSE)"

# Legacy alias retained for backward compatibility with older CI configs
check-renv-ci: check-renv

# Docker targets (work without local R)
# Docker-first workflow:
#   1. Work in containers (make r or make docker-run)
#   2. Install packages (renv::install("pkg"))
#   3. Exit container (auto-snapshot on exit)
#   4. Build new image (make docker-build)
docker-build:
	DOCKER_BUILDKIT=1 docker build --platform linux/amd64 --build-arg R_VERSION=$(R_VERSION) -t $(PACKAGE_NAME) .

docker-rebuild:
	DOCKER_BUILDKIT=1 docker build --no-cache --platform linux/amd64 --build-arg R_VERSION=$(R_VERSION) -t $(PACKAGE_NAME) .

docker-build-log:
	@echo "Building Docker image and saving log to docker-build.log..."
	DOCKER_BUILDKIT=1 docker build --platform linux/amd64 --progress=plain --build-arg R_VERSION=$(R_VERSION) -t $(PACKAGE_NAME) . 2>&1 | tee docker-build.log
	@echo "✅ Build complete. Log saved to docker-build.log"

docker-push-team:
	@echo "Tagging image as $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)"
	docker tag $(PACKAGE_NAME) $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)
	@echo "Pushing to Docker Hub..."
	docker push $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)
	@echo "✅ Team image pushed: $(DOCKERHUB_ACCOUNT)/$(PROJECT_NAME):$(IMAGE_TAG)"
	@echo "   Team members should update .zzcollab_team_setup to reference this tag"

docker-document:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "devtools::document()"

docker-build-pkg:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R CMD build .

docker-check: docker-document
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R CMD check --as-cran *.tar.gz

docker-test:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "devtools::test()"

docker-vignettes: docker-document
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "devtools::build_vignettes()"

docker-render:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "rmarkdown::render('analysis/paper/paper.Rmd')"

docker-render-qmd:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project -w /home/analyst/project $(PACKAGE_NAME) quarto render analysis/report/index.qmd

docker-check-renv:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "renv::status()"

docker-check-renv-fix:
	docker run --platform linux/amd64 --rm -v $$(pwd):/home/analyst/project $(PACKAGE_NAME) R --quiet -e "renv::snapshot()"

docker-rstudio:
	@echo "Starting RStudio Server on http://localhost:8787"
	@echo "Username: analyst, Password: analyst"
	docker run --platform linux/amd64 --rm --user root -p 8787:8787 -v $$(pwd):/home/analyst/project -e USER=analyst -e PASSWORD=analyst $(PACKAGE_NAME) /init

# Smart docker-run: Automatically detect profile and run appropriately
# Runs validation BEFORE launching container (ensures DESCRIPTION/renv.lock are in sync)
# Runs validation AFTER exiting container (captures any new packages installed)
docker-run: check-renv
	@if [ ! -f Dockerfile ]; then \
		echo "❌ No Dockerfile found in current directory"; \
		exit 1; \
	fi
	@PROFILE=$$(head -20 Dockerfile | grep 'Profile:' | head -1 | sed 's/.*Profile: \([a-z0-9_]*\).*/\1/'); \
	if [ -z "$$PROFILE" ]; then \
		echo "❌ Could not detect profile from Dockerfile"; \
		echo "   Add '# Profile: <name>' comment to Dockerfile header"; \
		exit 1; \
	fi; \
	echo "🔍 Detected profile: $$PROFILE"; \
	echo ""; \
	case "$$PROFILE" in \
		*minimal) \
			echo "🐳 Starting minimal profile..."; \
			docker run --platform linux/amd64 --rm -it -v $$(pwd):/home/analyst/project -v $$HOME/.cache/R/renv:/home/analyst/.cache/R/renv $(PACKAGE_NAME); \
			;; \
		*x11*) \
			echo "🐳 Starting X11 profile (GUI support)..."; \
			echo "⚠️  Requires XQuartz running with 'Allow connections from network clients'"; \
			echo ""; \
			xhost + 127.0.0.1 > /dev/null 2>&1 || echo "⚠️  xhost command failed - XQuartz may not be running"; \
			docker run --platform linux/amd64 --rm -it -v $$(pwd):/home/analyst/project -v $$HOME/.cache/R/renv:/home/analyst/.cache/R/renv -e DISPLAY=host.docker.internal:0 $(PACKAGE_NAME); \
			;; \
		*shiny*) \
			echo "🐳 Starting Shiny Server..."; \
			echo "📊 Shiny: http://localhost:3838"; \
			echo ""; \
			docker run --platform linux/amd64 --rm -p 3838:3838 -v $$(pwd):/home/analyst/project -v $$HOME/.cache/R/renv:/home/analyst/.cache/R/renv $(PACKAGE_NAME); \
			;; \
		*analysis|*publishing) \
			echo "🐳 Starting $$PROFILE profile (RStudio Server)..."; \
			echo "📊 RStudio: http://localhost:8787"; \
			echo "👤 Username: analyst, Password: analyst"; \
			echo ""; \
			docker run --platform linux/amd64 --rm -p 8787:8787 -v $$(pwd):/home/analyst/project -v $$HOME/.cache/R/renv:/home/analyst/.cache/R/renv -e USER=analyst -e PASSWORD=analyst $(PACKAGE_NAME) /init; \
			;; \
		alpine_*) \
			echo "🐳 Starting Alpine profile..."; \
			docker run --rm -it -v $$(pwd):/home/analyst/project -v $$HOME/.cache/R/renv:/home/analyst/.cache/R/renv $(PACKAGE_NAME); \
			;; \
		*) \
			echo "❌ Unknown profile: $$PROFILE"; \
			echo "   Supported: *minimal, *analysis, *publishing, *shiny*, *x11*, alpine_*"; \
			exit 1; \
			;; \
	esac
	@echo ""
	@echo "📋 Post-session validation: checking for new packages..."
	@$(HOST_CHECK) "zzrenvcheck::check_packages(auto_fix = TRUE, strict = TRUE)" || echo "⚠️  Package validation failed - see above for details"
	@if [ -f renv.lock ]; then \
		if ! touch renv.lock; then \
			echo "⚠️  Warning: Failed to restore renv.lock timestamp (file may be readonly)" >&2; \
		fi; \
	fi

# Alias for docker-run (shorthand)
r: docker-run

# Cleanup
clean:
	rm -f *.tar.gz
	rm -rf *.Rcheck

docker-clean:
	docker rmi $(PACKAGE_NAME) || true
	docker system prune -f

# Docker disk management
docker-disk-usage:
	@echo "Docker disk usage:"
	@docker system df

docker-prune-cache:
	@echo "Removing Docker build cache..."
	docker builder prune -af
	@echo "✅ Build cache cleaned"
	@make docker-disk-usage

docker-prune-all:
	@echo "WARNING: This will remove all unused Docker images, containers, and build cache"
	@echo "Press Ctrl+C to cancel, or Enter to continue..."
	@read dummy
	@echo "Removing all unused Docker resources..."
	docker system prune -af
	@echo "✅ Docker cleanup complete"
	@make docker-disk-usage

.PHONY: all document build check install vignettes test deps ensure-zzrenvcheck check-renv check-renv-no-fix check-renv-no-strict check-renv-ci docker-build docker-rebuild docker-build-log docker-push-team docker-document docker-build-pkg docker-check docker-test docker-vignettes docker-render docker-render-qmd docker-rstudio docker-run r docker-check-renv docker-check-renv-fix clean docker-clean docker-disk-usage docker-prune-cache docker-prune-all help
