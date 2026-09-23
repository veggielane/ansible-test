# The Ansible "control node": the machine that RUNS Ansible.
# Ansible's control node must be Linux/macOS, so on a Windows PC we run it in
# this container and point it at the Windows Windchill servers over WinRM/SSH.
FROM python:3.12-slim

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONUNBUFFERED=1 \
    ANSIBLE_FORCE_COLOR=1

# git: some ansible-galaxy sources; openssh-client + sshpass: the ssh connection alternative.
RUN apt-get update \
 && apt-get install -y --no-install-recommends git openssh-client sshpass ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Artifactory behind a corporate certificate? Copy the CA in and trust it:
# COPY docker/corporate-ca.crt /usr/local/share/ca-certificates/corporate-ca.crt
# RUN update-ca-certificates

# ansible-core : the engine (ansible-playbook, ansible-vault, ansible-galaxy, ...)
# pywinrm      : lets Ansible talk WinRM to Windows (NTLM works out of the box;
#                add pywinrm[kerberos] + krb5 packages if you need Kerberos/AD SSO)
# ansible-lint : style/bug checker used in the lessons
RUN pip install \
      "ansible-core>=2.17" \
      "pywinrm>=0.5" \
      "requests-credssp" \
      "ansible-lint"

WORKDIR /work

# --- Collections --------------------------------------------------------------
# Public collections (ansible.windows, ...) come from Galaxy, or from
# Artifactory's virtual Ansible repo when ARTIFACTORY_GALAXY_URL is given.
# The Windchill collection (acme.windchill) is installed only in RELEASE MODE:
#   docker build -f docker/Dockerfile -t windchill-ansible-control:latest \
#     --build-arg ARTIFACTORY_GALAXY_URL=https://artifactory.example.com/artifactory/api/ansible/ansible/ \
#     --secret id=artifactory_token,src=.artifactory_token .
# In DEV MODE (plain `docker compose build`) docker-compose.yml mounts your local
# checkout of the collection instead. See docs/09-collection-and-artifactory.md.
ARG ARTIFACTORY_GALAXY_URL=""
COPY requirements.yml requirements-windchill.yml /tmp/
RUN --mount=type=secret,id=artifactory_token,required=false \
    if [ -n "$ARTIFACTORY_GALAXY_URL" ]; then \
      export ANSIBLE_GALAXY_SERVER_LIST=artifactory \
             ANSIBLE_GALAXY_SERVER_ARTIFACTORY_URL="$ARTIFACTORY_GALAXY_URL"; \
      if [ -s /run/secrets/artifactory_token ]; then \
        export ANSIBLE_GALAXY_SERVER_ARTIFACTORY_TOKEN="$(cat /run/secrets/artifactory_token)"; \
      fi; \
      ansible-galaxy collection install -r /tmp/requirements.yml \
   && ansible-galaxy collection install -r /tmp/requirements-windchill.yml; \
    else \
      ansible-galaxy collection install -r /tmp/requirements.yml \
   && echo "dev mode: acme.windchill will come from the checkout mounted by docker-compose.yml"; \
    fi

CMD ["bash"]
