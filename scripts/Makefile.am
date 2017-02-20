dysnomia.1: dysnomia.in
	$(HELP2MAN) --output=$@ --no-info --name 'Execute deployment operations of mutable components' "$(SHELL) dysnomia"

dysnomia-snapshots.1: dysnomia-snapshots.in
	$(HELP2MAN) --output=$@ --no-info --name 'Manage the contents of the Dysnomia snapshots store' "$(SHELL) dysnomia-snapshots"

dysnomia-containers.1: dysnomia-containers.in
	$(HELP2MAN) --output=$@ --no-info --name 'Manage the contents of a set of Dysnomia containers' "$(SHELL) dysnomia-containers"

bin_SCRIPTS = dysnomia dysnomia-snapshots dysnomia-containers
man1_MANS = dysnomia.1 dysnomia-snapshots.1 dysnomia-containers.1

EXTRA_DIST = dysnomia.in dysnomia-snapshots.in dysnomia-containers.in \
  $(man1_MANS)
