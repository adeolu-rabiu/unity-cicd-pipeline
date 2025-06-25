FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    unzip \
    xvfb \
    libglu1 \
    libxcursor1 \
    libxrandr2 \
    libxinerama1 \
    ca-certificates \
    openjdk-11-jdk \
    python3 \
    python3-pip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Unity Hub
RUN wget -qO - https://hub.unity3d.com/linux/keys/public | apt-key add - \
    && echo 'deb https://hub.unity3d.com/linux/repos/deb stable main' > /etc/apt/sources.list.d/unityhub.list \
    && apt-get update \
    && apt-get install -y unityhub

# Install Unity Editor (2022.3 LTS)
RUN unityhub --headless install --version 2022.3.12f1 --changeset 4fe6e059c7ef

# Install Android SDK
ENV ANDROID_SDK_ROOT=/opt/android-sdk
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-8512546_latest.zip \
    && unzip commandlinetools-linux-8512546_latest.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools \
    && mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm commandlinetools-linux-8512546_latest.zip

ENV PATH="${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${PATH}"

# Accept Android licenses and install build tools
RUN yes | sdkmanager --licenses \
    && sdkmanager "build-tools;30.0.3" "platforms;android-30" "platform-tools"

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

WORKDIR /workspace

COPY build-unity.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/build-unity.sh

CMD ["/bin/bash"]

