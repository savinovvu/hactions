.PHONY: lint template test package install upgrade uninstall

CHART_NAME = quotes-api
CHART_PATH = helm/$(CHART_NAME)
RELEASE_NAME = haction
NAMESPACE = ufr-uspil2-copy1

lint:
	helm lint ./$(CHART_PATH)

template:
	helm template $(RELEASE_NAME) ./$(CHART_PATH) --namespace $(NAMESPACE)

test:
	helm test $(RELEASE_NAME) --namespace $(NAMESPACE)

package:
	helm package ./$(CHART_PATH)  # Создаст пакет в текущей директории

install:
	helm install $(RELEASE_NAME) ./$(CHART_PATH) --namespace $(NAMESPACE)

upgrade:
	helm upgrade $(RELEASE_NAME) ./$(CHART_PATH) --namespace $(NAMESPACE)

uninstall:
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

# Добавим команду для отладки
dry-run:
	helm install $(RELEASE_NAME) ./$(CHART_PATH) --namespace $(NAMESPACE) --dry-run --debug

# Показать values
values:
	helm show values ./$(CHART_PATH)