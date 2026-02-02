PORT?=4000

.PHONY:

all: site

serve: .PHONY
	mkdocs serve -a localhost:$(PORT) --livereload

site:
	mkdocs build --verbose --clean --strict 