.PHONY: clean
clean:
	@rm -rf .build "$(or $(BUILD_DIR),build)"
