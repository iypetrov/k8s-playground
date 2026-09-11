FROM golang:1.21 AS builder
WORKDIR /app
COPY go.mod .
COPY main.go .
# Build WITHOUT stripping symbols so eBPF DWARF analysis works
RUN CGO_ENABLED=0 GOOS=linux go build -o demo-app .

FROM debian:bookworm-slim
COPY --from=builder /app/demo-app /usr/local/bin/demo-app
CMD ["/usr/local/bin/demo-app"]
