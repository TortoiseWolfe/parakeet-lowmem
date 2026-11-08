# parakeet-lowmem: LocalAI's parakeet-cpp backend with a memory-saving patch (parakeet-lowmem.patch).
# Same libraries and run.sh as upstream, only parakeet-cpp-grpc is rebuilt.
#   docker build -t ghcr.io/tortoisewolfe/parakeet-lowmem:v4.11.0-1 .
FROM golang:1.26@sha256:670bb5aa5349ae03b8516764718486f4f16399134bdc9acd0c46a23f043ab05c AS build
RUN apt-get update && apt-get install -y --no-install-recommends protobuf-compiler git \
 && rm -rf /var/lib/apt/lists/*
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2 \
 && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@1958fcbe
ENV PATH=/go/bin:$PATH CGO_ENABLED=0
# v4.11.0 is commit 58830f7ac508845a6f4efa32cfca06af422d4d82; fetched by commit, tags can move.
RUN git init /src && cd /src \
 && git fetch --depth 1 https://github.com/mudler/LocalAI 58830f7ac508845a6f4efa32cfca06af422d4d82 \
 && git checkout FETCH_HEAD
WORKDIR /src
COPY parakeet-lowmem.patch /tmp/
RUN git apply /tmp/parakeet-lowmem.patch \
 && mkdir -p pkg/grpc/proto \
 && protoc --experimental_allow_proto3_optional -Ibackend/ \
      --go_out=pkg/grpc/proto/ --go_opt=paths=source_relative \
      --go-grpc_out=pkg/grpc/proto/ --go-grpc_opt=paths=source_relative backend/backend.proto \
 && cd backend/go/parakeet-cpp && go test ./... && go build -o /out/parakeet-cpp-grpc .

# upstream parakeet-cpp CPU backend that goes with LocalAI v4.11.0
FROM quay.io/go-skynet/local-ai-backends@sha256:2bbdf135e018041f0b7914eab02d8725c34dfb19875763332efd2f9b5af4f718
COPY --from=build /out/parakeet-cpp-grpc /parakeet-cpp-grpc
# Same layout as upstream's backend images: files at the image root, run.sh first.
# LocalAI's backend install unpacks the image into a backend folder and starts run.sh.
LABEL org.opencontainers.image.source="https://github.com/TortoiseWolfe/parakeet-lowmem" \
      org.opencontainers.image.description="LocalAI parakeet-cpp backend (CPU) with a memory-saving patch for long recordings" \
      org.opencontainers.image.licenses="MIT"
