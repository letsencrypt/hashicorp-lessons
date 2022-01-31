ARG VARIANT=1-bullseye
FROM mcr.microsoft.com/vscode/devcontainers/go:0-${VARIANT}

ARG NODE_VERSION="none"
RUN if [ "${NODE_VERSION}" != "none" ]; then su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"; fi

RUN apt-get update && apt-get upgrade -y && apt-get install -y software-properties-common
RUN apt-get install -y byobu tmux nano vim socat

RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
RUN apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

RUN apt-get update && apt-get install -y consul nomad terraform


ENTRYPOINT ["sleep", "infinity"]
