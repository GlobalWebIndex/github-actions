FROM gcr.io/gwi-host-net/drone-helm:v1

LABEL version="1.0.0"
LABEL repository="https://github.com/GlobalWebIndex/github-actions"
LABEL maintainer="GWI's DevOps team"

LABEL com.github.actions.name="GitHub Action for Helm secret templates validation"
LABEL com.github.actions.description="Checks if helm templates are valid, using the helm secret command"
LABEL com.github.actions.icon="cloud"
LABEL com.github.actions.color="blue"

ADD entrypoint.sh /entrypoint.sh
CMD ["bash", "/entrypoint.sh"]
