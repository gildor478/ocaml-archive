version = dev

default: test

build:
	dune build @install

doc:
	dune build @doc

test:
	dune runtest

all:
	dune build @all
	dune runtest

clean:
	dune clean

.PHONY: build doc test all uninstall clean

PRECOMMIT_ARGS= \
	    --exclude log-html \
	    --exclude Makefile

precommit:
	 -@if command -v OCamlPrecommit > /dev/null; then \
	   OCamlPrecommit $(PRECOMMIT_ARGS); \
	 else \
	   echo "Skipping precommit checks.";\
	 fi

test: precommit

.PHONY: precommit

deploy: doc test
	dune-release lint
	git push --all
	dune-release tag
	dune-release distrib --skip-tests
	dune-release publish
	dune-release opam pkg
	dune-release opam submit

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
