.PHONY: lint template test package install upgrade uninstall

CHART_NAME = hello-spring-app
RELEASE_NAME = my-app
NAMESPACE = default

lint:
	helm lint ./$(CHART_NAME)

template:
	helm template $(RELEASE_NAME) ./$(CHART_NAME) --namespace $(NAMESPACE)

test:
	helm test $(RELEASE_NAME) --namespace $(NAMESPACE)

package:
	helm package ./$(CHART_NAME)

install:
	helm install $(RELEASE_NAME) ./$(CHART_NAME) --namespace $(NAMESPACE)

upgrade:
	helm upgrade $(RELEASE_NAME) ./$(CHART_NAME) --namespace $(NAMESPACE)

uninstall:
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

values:
	helm show values ./$(CHART_NAME)

dry-run:
	helm install $(RELEASE_NAME) ./$(CHART_NAME) --namespace $(NAMESPACE) --dry-run --debug

dependency-update:
	helm dependency update ./$(CHART_NAME)
