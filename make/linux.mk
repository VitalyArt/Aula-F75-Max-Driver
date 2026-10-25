.PHONY: linux-check-deps linux-build linux-install-udev linux-deb linux-run linux-test
linux-check-deps:
	@scripts/linux/linux-check-deps.sh

linux-build: linux-check-deps
	@scripts/linux/linux-build.sh

linux-install-udev:
	@scripts/linux/linux-install-udev.sh

linux-deb: linux-build
	@scripts/linux/linux-deb.sh

linux-run: linux-check-deps
	@scripts/linux/linux-run.sh

linux-test: linux-check-deps
	@swift test
	@bash scripts/linux/linux-ui-test.sh
