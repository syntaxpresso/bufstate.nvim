TEST_DIR := tests
TEST_FILES := $(TEST_DIR)/bufstate

.PHONY: test test-file clean lint format

test:
	nvim --headless --noplugin \
		-u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory $(TEST_FILES)/ { minimal_init = 'tests/minimal_init.lua', sequential = true }" \
		-c "qa!"

test-file:
ifndef FILE
	$(error Usage: make test-file FILE=tests/bufstate/state_spec.lua)
endif
	nvim --headless --noplugin \
		-u tests/minimal_init.lua \
		-c "PlenaryBustedFile $(FILE)" \
		-c "qa!"

clean:
	rm -rf tests/.tests

lint:
	stylua --check lua/ plugin/ tests/

format:
	stylua lua/ plugin/ tests/
