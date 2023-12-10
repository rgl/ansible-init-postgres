# About

[![Build status](https://github.com/rgl/ansible-init-postgres/workflows/build/badge.svg)](https://github.com/rgl/ansible-init-postgres/actions?query=workflow%3Abuild)

This initializes a PostgreSQL database with a Ansible playbook.

# Usage

To use in a Docker Compose file do as the [example docker-compose.yml file](docker-compose.yml).

To use in a Ansible Playbook Kubernetes Job do as:

```yml
# try kubectl logs -n yugabytedb jobs/initialize-dex-database
# NB as an alternative/complement see https://github.com/coderanger/migrations-operator.
- name: Initialize the dex database
  block:
    # NB unfortunately we need this delete step because using force:true fails
    #    with:
    #       field is immutable","field":"spec.template"
    - name: Delete the dex database initialization job
      kubernetes.core.k8s:
        namespace: yugabytedb
        state: absent
        definition:
          apiVersion: batch/v1
          kind: Job
          metadata:
            name: initialize-dex-database
      changed_when: false
    - name: Initialize the dex database
      # TODO derive changed_when from the ansible playbook execution result.
      kubernetes.core.k8s:
        namespace: yugabytedb
        wait: yes
        wait_condition:
          type: Complete
          status: "True"
        definition:
          apiVersion: batch/v1
          kind: Job
          metadata:
            name: initialize-dex-database
          spec:
            template:
              spec:
                containers:
                  - name: init
                    image: ghcr.io/rgl/ansible-init-postgres:main
                    env:
                      # see https://www.postgresql.org/docs/16/libpq-envars.html
                      - name: PGHOST
                        value: yb-tservers.yugabytedb
                      - name: PGPORT
                        value: '5433'
                      - name: PGUSER
                        value: yugabyte
                      - name: DEX_PASSWORD
                        value: 66964843358242dbaaa7778d8477c288
                    command:
                      - ansible-init-postgres
                      - |
                        {%- raw -%}
                        - hosts: localhost
                          connection: local
                          vars:
                            database: dex
                            users:
                              - name: dex
                                password: "{{ lookup('ansible.builtin.env', 'DEX_PASSWORD') }}"
                                privs: all
                          tasks:
                            - name: Create database
                              postgresql_db:
                                name: '{{ database }}'
                            - name: Create user
                              postgresql_user:
                                name: '{{ item.name }}'
                                password: '{{ item.password }}'
                              loop: '{{ users }}'
                            - name: Grant user database permissions
                              postgresql_privs:
                                type: database
                                database: '{{ database }}'
                                roles: '{{ item.name }}'
                                privs: '{{ item.privs }}'
                                grant_option: false
                              loop: '{{ users }}'
                        {%- endraw -%}
                restartPolicy: Never
            backoffLimit: 1
```
