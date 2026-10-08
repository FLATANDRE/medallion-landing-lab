.PHONY: up trigger run query smoke doctor down reset
up:
	bash scripts/up.sh
trigger:
	bash scripts/trigger.sh
run:
	bash scripts/run-local.sh all
query:
	bash scripts/query.sh
smoke:
	bash scripts/smoke-test.sh
doctor:
	bash scripts/doctor.sh
down:
	docker compose down
reset:
	bash scripts/reset.sh --yes-delete-lab-data
