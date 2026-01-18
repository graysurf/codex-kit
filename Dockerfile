FROM ubuntu:24.04

SHELL ["/bin/bash", "-lc"]

ARG DEBIAN_FRONTEND=noninteractive
ARG ZSH_KIT_REPO="https://github.com/graysurf/zsh-kit.git"
ARG ZSH_KIT_REF="main"
ARG CODEX_KIT_REPO="https://github.com/graysurf/codex-kit.git"
ARG CODEX_KIT_REF="main"
ARG INSTALL_TOOLS="1"
ARG INSTALL_OPTIONAL_TOOLS="1"
ARG INSTALL_VSCODE="1"

ENV LANG="C.UTF-8"
ENV LC_ALL="C.UTF-8"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    file \
    git \
    gnupg \
    locales \
    sudo \
    tzdata \
    zsh \
    python3 \
    python3-venv \
    python3-pip \
    build-essential \
    procps \
    unzip \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /usr/bin/zsh dev \
  && echo "dev ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/dev \
  && chmod 0440 /etc/sudoers.d/dev \
  && mkdir -p /opt/zsh-kit /opt/codex-kit /opt/codex-env /home/dev/.codex \
  && chown -R dev:dev /opt/zsh-kit /opt/codex-kit /opt/codex-env /home/dev

USER dev

RUN NONINTERACTIVE=1 /bin/bash -lc "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
  && /home/linuxbrew/.linuxbrew/bin/brew --version

ENV HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
ENV HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar"
ENV HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew"
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:${PATH}"

RUN git clone "${ZSH_KIT_REPO}" /opt/zsh-kit \
  && (cd /opt/zsh-kit && git checkout "${ZSH_KIT_REF}")

RUN git clone "${CODEX_KIT_REPO}" /opt/codex-kit \
  && (cd /opt/codex-kit && git checkout "${CODEX_KIT_REF}")

ENV ZSH_KIT_DIR="/opt/zsh-kit"
ENV CODEX_KIT_DIR="/opt/codex-kit"
ENV ZDOTDIR="/opt/zsh-kit"
ENV HOME="/home/dev"
ENV CODEX_HOME="/home/dev/.codex"

COPY docker/codex-env/ /opt/codex-env/

USER root
RUN chmod +x /opt/codex-env/bin/*.sh
USER dev

RUN if [[ "${INSTALL_TOOLS}" == "1" ]]; then \
    INSTALL_OPTIONAL_TOOLS="${INSTALL_OPTIONAL_TOOLS}" INSTALL_VSCODE="${INSTALL_VSCODE}" /opt/codex-env/bin/install-tools.sh; \
  fi

USER root

WORKDIR /work

ENTRYPOINT ["/opt/codex-env/bin/entrypoint.sh"]
CMD ["zsh", "-l"]
