# batch-connector-provisioner

A library, script, and demo which leverages the public [Border0 Go SDK](https://github.com/borderzero/border0-go) to create `n` connectors, each with `m` sockets.

A scenario where this is useful is say you have `n` machines each with the same `m` services.

To get started simply populate the `BORDER0_TOKEN` environment variable with a Border0 admin token and run the `main.go` program with

```
export BORDER0_TOKEN=eyJhbGciOiJIUzI1NiIsInR....
```

```
go run main.go
```

### Library Usage

```
ctx := context.Background()

p := provisioner.New(
	provisioner.WithSourceFilename("source.json"),
	provisioner.WithStateFilename("provisioner.state"),
	provisioner.WithAuthToken(os.Getenv("BORDER0_TOKEN")),
)

if err := p.Apply(ctx); err != nil {
	log.Fatalf("failed to apply with provisioner: %v", err)
}
```