package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/borderzero/examples/batch-connector-provisioner/provisioner"
)

func main() {
	ctx := context.Background()

	p := provisioner.New(
		provisioner.WithSourceFilename("source.json"),
		provisioner.WithStateFilename("provisioner.state"),
		provisioner.WithAuthToken(os.Getenv("BORDER0_TOKEN")),
	)

	if err := p.Apply(ctx); err != nil {
		log.Fatalf("failed to apply with provisioner: %v", err)
	}

	pause()

	if err := p.Destroy(ctx); err != nil {
		log.Fatalf("failed to destroy with provisioner: %v", err)
	}
}

func pause() {
	scanner := bufio.NewScanner(os.Stdin)

	for {
		fmt.Println("Done applying demo! Enter 'proceed' to tear-down the demo.")
		scanner.Scan()
		input := strings.TrimSpace(scanner.Text())

		if input == "proceed" {
			fmt.Println("You entered 'proceed'. Proceeding...")
			break
		} else {
			fmt.Println("Invalid input, please try again.")
		}
	}
}
