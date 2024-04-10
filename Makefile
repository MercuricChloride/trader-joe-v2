#ENDPOINT ?= mainnet.eth.streamingfast.io:443
ENDPOINT ?= arb-one.streamingfast.io:443
CARGO_VERSION := $(shell cargo version 2>/dev/null)
#START_BLOCK ?= 47891979
#STOP_BLOCK ?=  47895979
#START_BLOCK ?= 72491700
START_BLOCK ?= 72491700
STOP_BLOCK ?= +1000
MODULE ?= graph_out

.PHONY: build
build:
	streamline-cli build src/TraderJoe.strm $(if $(START_BLOCK), -s $(START_BLOCK))

.PHONY: run
run:
	substreams run -e $(ENDPOINT) ./output.spkg $(MODULE) $(if $(START_BLOCK),-s $(START_BLOCK)) $(if $(STOP_BLOCK),-t $(STOP_BLOCK))

.PHONY: gui
gui:
	substreams gui -e $(ENDPOINT) ./output.spkg $(MODULE) $(if $(START_BLOCK),-s $(START_BLOCK)) $(if $(STOP_BLOCK),-t $(STOP_BLOCK))

.PHONY: graph-deploy
graph-deploy: schema build
	npx @graphprotocol/graph-cli build && npx @graphprotocol/graph-cli deploy

.PHONY: schema
schema:
	streamline-cli schema src/TraderJoe.strm
