.PHONY: help deploy status stop clean test ping

help:
	@echo "Available targets:"
	@echo "  deploy     - Deploy application and metrics to all nodes"
	@echo "  app        - Deploy only application configuration"
	@echo "  metrics    - Deploy only metrics (Prometheus + Node Exporter)"
	@echo "  status     - Check status of all services"
	@echo "  stop       - Stop all services"
	@echo "  ping       - Test SSH connectivity"
	@echo "  clean      - Stop services and clean up logs"

deploy:
	ansible-playbook playbooks/site.yaml

app:
	ansible-playbook playbooks/site.yaml --tags application

metrics:
	ansible-playbook playbooks/site.yaml --tags metrics

status:
	ansible-playbook playbooks/status.yaml

stop:
	ansible-playbook playbooks/stop.yaml

ping:
	ansible all -m ping

clean:
	ansible-playbook playbooks/stop.yaml
	ansible all -m shell -a "rm -rf {{ prometheus_log_dir }}/* {{ node_exporter_log_dir }}/*"