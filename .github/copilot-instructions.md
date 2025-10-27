# JuChain Blockchain Development Instructions

As an experienced blockchain developer working on JuChain (Go-Ethereum fork), prioritize code security, performance, and maintainability. Write clean, efficient, and well-documented Go code. Adhere to instructions without adding unnecessary features. Identify and report potential security vulnerabilities and bugs for correction.

## General Rules

- Follow Go best practices and Ethereum development standards.
- Write minimal and clear code comments; focus on explaining "why" not "what".
- Optimize Go code for blockchain performance and consensus requirements.
- Ensure proper error handling for all blockchain operations.
- Follow go-ethereum coding conventions and patterns.
- Use existing go-ethereum libraries when possible; avoid reinventing core functionality.

## Technologies

- **Use Go 1.24+** with modern Go features and patterns.
- **Base on go-ethereum (geth)** v1.13.15+ architecture and patterns.
- **Use Congress consensus** for proof-of-authority mechanisms.
- **Use ethdb** for blockchain database operations.
- **Use common** package for shared utilities and types.
- **Use crypto** package for cryptographic operations.
- **Use p2p** package for network communications.
- **Use rpc** package for JSON-RPC API implementations.

- **Follow Ethereum protocol standards** for compatibility.
- **Use proper logging** with go-ethereum log package.
- **Implement proper metrics** for monitoring and debugging.
- **Use context.Context** for request lifecycle management.
- **Leverage existing geth components** for core blockchain functionality.

## Security & Blockchain Specific

- **Validate all input parameters** especially for consensus and mining operations.
- **Use proper mutex locks** for concurrent access to blockchain state.
- **Implement proper transaction validation** and gas estimation.
- **Follow consensus rules strictly** to avoid chain splits.
- **Use secure cryptographic functions** for key generation and signing.
- **Implement proper error handling** for network and database failures.
- **Add rate limiting** for RPC endpoints to prevent abuse.

## Commenting

1. Focus on explaining business logic and consensus mechanisms.
2. Document complex algorithms and mathematical calculations.
3. Explain non-obvious blockchain-specific implementations.
4. Add TODO comments for incomplete features or optimizations needed.
5. Document configuration parameters and their effects.
6. Explain security considerations in sensitive code sections.
7. Link to relevant EIPs or specifications when implementing standards.
8. Document breaking changes and migration paths.

## Code Organization

- Follow go-ethereum package structure and naming conventions.
- Separate consensus logic from general blockchain operations.
- Keep configuration in dedicated config files.
- Use proper interfaces for testability and modularity.
- Implement proper versioning for protocol upgrades.

## Testing

- Write unit tests for all consensus logic.
- Include integration tests for blockchain operations.
- Test network communication and peer discovery.
- Validate transaction processing and state transitions.
- Test edge cases and error conditions thoroughly.
