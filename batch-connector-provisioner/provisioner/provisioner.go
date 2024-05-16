package provisioner

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"

	"github.com/borderzero/border0-go"
	"github.com/borderzero/border0-go/client"
	"github.com/borderzero/border0-go/types/service"
)

const (
	defaultSourceFilename = "source.json"
	defaultStateFilename  = "provisioner.state"
)

var (
	ErrFailedToFindSourceFile   = errors.New("failed to find source file")
	ErrFailedToReadSourceFile   = errors.New("failed to read source file")
	ErrFailedToDecodeSourceFile = errors.New("failed to decode source file")

	ErrFailedToFindStateFile   = errors.New("failed to find state file")
	ErrFailedToReadStateFile   = errors.New("failed to read state file")
	ErrFailedToDecodeStateFile = errors.New("failed to decode state file")
)

type Provisioner interface {
	Apply(ctx context.Context) error
	Destroy(ctx context.Context) error
}

type provisioner struct {
	sourceFilename string
	stateFilename  string

	authToken string

	api client.Requester
}

type source struct {
	Sockets    map[string]*service.Configuration `json:"sockets"`
	Connectors []string                          `json:"connectors"`
}

type state struct {
	Sockets    map[string]*client.Socket     `json:"sockets"`
	Connectors map[string]*connectorMetadata `json:"connectors"`
}

type connectorMetadata struct {
	Connector *client.Connector      `json:"connector"`
	Token     *client.ConnectorToken `json:"token"`
}

type Option func(*provisioner)

func WithSourceFilename(fname string) Option {
	return func(p *provisioner) { p.sourceFilename = fname }
}

func WithStateFilename(fname string) Option {
	return func(p *provisioner) { p.stateFilename = fname }
}

func WithAuthToken(token string) Option {
	return func(p *provisioner) { p.authToken = token }
}

func New(opts ...Option) Provisioner {
	p := &provisioner{
		sourceFilename: defaultSourceFilename,
		stateFilename:  defaultStateFilename,
	}
	for _, opt := range opts {
		opt(p)
	}
	p.api = border0.NewAPIClient(
		client.WithAuthToken(p.authToken),
		client.WithRetryMax(2),
	)
	return p
}

func (p *provisioner) Apply(ctx context.Context) error {
	source, err := p.getSource()
	if err != nil {
		return fmt.Errorf("failed to acquire source: %v", err)
	}

	state, err := p.getState()
	if err != nil {
		return fmt.Errorf("failed to acquire state: %v", err)
	}
	defer state.Save(p.stateFilename)

	// TODO: catch signals and save state

	for _, connectorName := range source.Connectors {
		connector, err := p.api.CreateConnector(ctx, &client.Connector{
			Name:                     connectorName,
			Description:              fmt.Sprintf("Bulk provisioned connector %s", connectorName),
			BuiltInSshServiceEnabled: false,
		})
		if err != nil {
			fmt.Printf("❌ Failed to create connector %s: %v\n", connectorName, err)
			continue
		}
		fmt.Printf("✅ Created connector %s\n", connectorName)

		connectorTokenName := fmt.Sprintf("%s-token", connectorName)
		connectorToken, err := p.api.CreateConnectorToken(ctx, &client.ConnectorToken{Name: connectorTokenName, ConnectorID: connector.ConnectorID})
		if err != nil {
			fmt.Printf("❌ Failed to create connector token for connector %s: %v\n", connectorName, err)
			continue
		}
		fmt.Printf("✅ Created connector token %s for connector %s\n", connectorTokenName, connectorName)

		state.Connectors[connectorName] = &connectorMetadata{Connector: connector, Token: connectorToken}

		for socketSuffix, socketConfig := range source.Sockets {
			socketName := fmt.Sprintf("%s-%s", connectorName, socketSuffix)

			socket, err := p.api.CreateSocket(ctx, &client.Socket{
				Name:             socketName,
				SocketType:       socketConfig.ServiceType,
				Description:      fmt.Sprintf("Bulk provisioned socket for %s with connector %s", socketSuffix, connectorName),
				RecordingEnabled: true,
				ConnectorID:      connector.ConnectorID,
				UpstreamConfig:   socketConfig,
				Tags: map[string]string{
					"border0_client_category":    "drones",
					"border0_client_subcategory": connectorName,
					"border0_client_icon_url":    "https://pbs.twimg.com/profile_images/1487876492642197504/eX0g5kIC_400x400.jpg",
					"border0_client_icon_text":   "My Awesome Drone",
				},
			})
			if err != nil {
				fmt.Printf("❌ Failed to create socket %s: %v\n", socketName, err)
				continue
			}
			fmt.Printf("✅ Created socket %s attached to connector %s\n", socketName, connectorName)

			state.Sockets[socketName] = socket
		}
	}

	return nil
}

func (p *provisioner) Destroy(ctx context.Context) error {
	state, err := p.getState()
	if err != nil {
		return fmt.Errorf("failed to acquire state: %v", err)
	}
	defer state.Save(p.stateFilename)

	// TODO: catch signals and save state

	for socketName, socket := range state.Sockets {
		if err := p.api.DeleteSocket(ctx, socket.SocketID); err != nil {
			fmt.Printf("❌ Failed to delete socket %s: %v\n", socketName, err)
		}
		fmt.Printf("✅ Deleted socket %s\n", socketName)
		delete(state.Sockets, socketName)
	}

	for connectorName, connectorMetadata := range state.Connectors {
		if err := p.api.DeleteConnectorToken(ctx, connectorMetadata.Connector.ConnectorID, connectorMetadata.Token.ID); err != nil {
			fmt.Printf("❌ Failed to delete connector token %s for connector %s: %v\n", connectorMetadata.Token.Name, connectorName, err)
		}
		fmt.Printf("✅ Deleted connector token %s for connector %s\n", connectorMetadata.Token.Name, connectorName)
		state.Connectors[connectorName].Token = nil

		if err := p.api.DeleteConnector(ctx, connectorMetadata.Connector.ConnectorID); err != nil {
			fmt.Printf("❌ Failed to delete connector %s: %v\n", connectorName, err)
		}
		fmt.Printf("✅ Deleted connector %s\n", connectorName)
		state.Connectors[connectorName].Connector = nil

		delete(state.Connectors, connectorName)
	}

	return nil
}

func (p *provisioner) getSource() (*source, error) {
	if _, err := os.Stat(p.sourceFilename); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrFailedToFindSourceFile, err)
	}
	sourceFileBytes, err := os.ReadFile(p.sourceFilename)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrFailedToReadSourceFile, err)
	}
	var source *source
	if err = json.Unmarshal(sourceFileBytes, &source); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrFailedToDecodeSourceFile, err)
	}
	return source, nil
}

func (p *provisioner) getState() (*state, error) {
	if _, err := os.Stat(p.stateFilename); err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return &state{
				Sockets:    make(map[string]*client.Socket),
				Connectors: make(map[string]*connectorMetadata),
			}, nil
		}
		return nil, fmt.Errorf("%w: %v", ErrFailedToFindStateFile, err)
	}
	stateFileBytes, err := os.ReadFile(p.stateFilename)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrFailedToReadStateFile, err)
	}
	var state *state
	if err = json.Unmarshal(stateFileBytes, &state); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrFailedToDecodeStateFile, err)
	}
	return state, nil
}

func (s *state) Save(filename string) error {
	jsonBytes, err := json.Marshal(&s)
	if err != nil {
		return fmt.Errorf("failed to encode state file: %v", err)
	}
	if err = os.WriteFile(filename, jsonBytes, 0660); err != nil {
		return fmt.Errorf("failed to write state file: %v", err)
	}
	return nil
}
