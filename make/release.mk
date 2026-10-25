.PHONY: release-package release-publish packaging-test
release-package:
	@python3 scripts/release/package.py
release-publish:
	@python3 scripts/release/publish.py
packaging-test:
	@python3 -m unittest discover -s Tests/Packaging
