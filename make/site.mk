.PHONY: site-build

site-build:
	@rm -rf build/site
	@mkdir -p build/site/assets
	@cp -R site/. build/site/
	@cp assets/app-icon.png build/site/assets/app-icon.png
