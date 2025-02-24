default: build test

build:
	dune build @install

doc:
	dune build @doc

test:
	dune runtest

all:
	dune build @all

install:
	dune install

uninstall:
	dune uninstall

clean:
	dune clean

fmt:
	dune fmt

lint:
	opam-dune-lint
	dune build @fmt

git-pre-commit-hook: test lint

.PHONY: build doc test all install uninstall clean fmt lint git-pre-commit-hook

deploy: doc test
	dune-release lint
	dune-release tag
	git push --all
	git push --tag
	dune-release

.PHONY: deploy

headache:
	find ./ \
	  -name _darcs -prune -false \
	  -o -name _build -prune -false \
	  -o -name dist -prune -false \
	  -o -name log-html -prune -false \
	  -o -name '*[^~]' -type f \
	  | xargs /usr/bin/headache -h .header -c .headache.config

.PHONY: headache
