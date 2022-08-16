FROM gcr.io/gwi-host-net/drone-helm:v1

LABEL version="1.0.0"
LABEL repository="https://github.com/GlobalWebIndex/github-actions"
LABEL maintainer="GWI's DevOps team"

LABEL com.github.actions.name="GitHub Action for Helm deploy"
LABEL com.github.actions.description="Deploys an application on a GKE cluster, using helm secrets"
LABEL com.github.actions.icon="cloud"
LABEL com.github.actions.color="blue"

ADD entrypoint.sh /entrypoint.sh
CMD ["bash", "/entrypoint.sh"]
