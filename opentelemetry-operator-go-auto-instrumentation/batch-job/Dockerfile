FROM golang:1.26.6 AS build-stage
WORKDIR /app
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 go build -o bin/main .

FROM gcr.io/distroless/base-debian12 AS run-stage
COPY --from=build-stage /app/bin/main /bin/main
CMD ["/bin/main"]
