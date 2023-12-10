#syntax=docker/dockerfile:1.6

# debian 12 (bookworm).
FROM debian:12-slim

# install ansible dependencies.
# see https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-with-pip
RUN <<EOF
#!/bin/bash
set -euxo pipefail
apt-get update
apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    postgresql-client-common \
    pylint \
    python3-argcomplete \
    python3-cryptography \
    python3-netaddr \
    python3-openssl \
    python3-pip \
    python3-psycopg2 \
    python3-yaml
rm -rf /var/lib/apt/lists/*
install -d /etc/bash_completion.d
activate-global-python-argcomplete
EOF

# install ansible.
# NB this pip install will display several "error: invalid command 'bdist_wheel'"
#    messages, those can be ignored.
COPY requirements.txt .
RUN <<EOF
#!/bin/bash
set -euxo pipefail
python3 -m pip install --break-system-packages -r requirements.txt
EOF

# install ansible collections and roles.
COPY requirements.yml .
RUN <<EOF
#!/bin/bash
set -euxo pipefail
ansible-galaxy collection install \
    -r requirements.yml \
    -p /usr/share/ansible/collections
ansible-galaxy role install \
    -r requirements.yml \
    -p /usr/share/ansible/roles
EOF

# install the default inventory.
# NB this prevents the warning:
#       [WARNING]: No inventory was parsed, only implicit localhost is available
#       [WARNING]: provided hosts list is empty, only localhost is available. Note that the implicit localhost does not match 'all'
COPY <<EOF /etc/ansible/hosts
[hosts]
localhost ansible_host=127.0.0.1
EOF

# install the binaries.
COPY --chmod=0755 ansible-init-postgres.sh /bin/ansible-init-postgres

# set the working directory.
WORKDIR /playbooks

# set the entrypoint.
ENTRYPOINT ["/bin/ansible-init-postgres"]
