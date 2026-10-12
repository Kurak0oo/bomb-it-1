FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe LP_NUM_THREADS=1
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl unzip python3 python3-venv xvfb xauth libgl1 libgl1-mesa-dri \
    libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libasound2t64 libpulse0 libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /work
RUN apt-get update && apt-get install -y --no-install-recommends libxkbcommon0 \
    && rm -rf /var/lib/apt/lists/*
COPY tools/godot-version.txt /tmp/godot-version.txt
RUN version=$(cat /tmp/godot-version.txt) && \
    asset="Godot_v${version}-stable_linux.x86_64.zip" && \
    base="https://github.com/godotengine/godot-builds/releases/download/${version}-stable" && \
    cd /tmp && curl -fL --retry 3 "$base/$asset" -o "$asset" && \
    curl -fL --retry 3 "$base/SHA512-SUMS.txt" -o SHA512-SUMS.txt && \
    grep " $asset\$" SHA512-SUMS.txt | sha512sum --check --strict - && \
    unzip -q "$asset" -d /opt/godot && \
    ln -s "/opt/godot/Godot_v${version}-stable_linux.x86_64" /usr/local/bin/godot && \
    rm "$asset" SHA512-SUMS.txt
COPY tools/requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/checks && /opt/checks/bin/pip install --no-cache-dir -r /tmp/requirements.txt
ENV PATH="/opt/checks/bin:${PATH}"
COPY tools /work/tools
COPY godot /work/godot
COPY xfl /work/xfl
COPY reference/visual-baselines /work/reference/visual-baselines
CMD ["xvfb-run", "-a", "python", "tools/run_checks.py", "--suite", "view", "--suite", "timeline", "--visual", "--compare-baselines", "reference/visual-baselines", "--output", "/artifacts"]
