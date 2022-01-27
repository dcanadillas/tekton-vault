PLATFORM="x86_64"
OS="linux"

define usage
	@echo "Usage: make [all|install|configure|run|clean] [TFEORG=<TFC_ORG> [TFEUSER=<YOUR_TFC_USER>] [TFEWORK=<YOUR_TFC_WORKSPACE>]]"
endef


.PHONY: all
all: install configure

install:
	./00-install.sh
# Installing manually Tekton CLI in /usr/local/bin
ifeq  ($(OS),linux);then
	@curl -L "https://github.com/tektoncd/cli/releases/download/v0.21.0/tkn_0.21.0_Linux_$(PLATFORM).tar.gz" -o /tmp/tektoncd.tar.gz
else
	@curl -L "https://github.com/tektoncd/cli/releases/download/v0.21.0/tkn_0.21.0_Darwin_$(PLATFORM).tar.gz" -o /tmp/tektoncd.tar.gz
endif
	
	@if ! which tkn > /dev/null;then \
		tar -zxvf /tmp/tektoncd.tar.gz \
		sudo mv tkn /usr/local/bin; \
	else \
		echo "\nTekton CLI already installed...\n"; \
	fi \
	

configure:
ifdef TFEORG
ifdef TFEUSER
	./01-deploy.sh $(TFEORG) $(TFEUSER)
else
	@echo "There is no Terraform username defined\n"
	$(call usage)
endif
else
	@echo "There is no Terraform organization in the parameters\n"
	$(call usage)
endif

run:
ifdef TFEWORK
	kubectl apply -f ./config
	kubectl apply -f ./pipelines
	tkn pipeline start -p tfc-organization="$(TFEORG)" -p tfc-workspace="$(TFEWORK)" -s tekton-sa vault-tfc-pipeline
	tkn tr logs -f -L
else
	@echo "There is no Terraform workspace in the parameters\n"
	$(call usage)
endif

clean:
	./02-clean.sh

help:
	$(call usage)