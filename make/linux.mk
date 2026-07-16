linux-check-deps:
	@scripts/linux-check-deps.sh

linux-build: linux-check-deps
	@scripts/linux-build.sh

linux-install-udev:
	@scripts/linux-install-udev.sh

linux-package: linux-build
	@scripts/linux-package.sh

linux-deb: linux-build
	@scripts/linux-deb.sh

linux-run: linux-check-deps
	@scripts/linux-run.sh
