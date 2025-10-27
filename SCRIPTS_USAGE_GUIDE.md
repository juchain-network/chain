# Ju Chain Management Scripts Usage Guide

## Quick Start

### 1. Initialize 5-Validator Network

```bash
# Initialize the entire network
./pm2-init.sh

# Start all nodes
pm2 start ecosystem.config.js
```

### 2. Network Management and Monitoring

```bash
# Interactive management interface
./pm2-manager.sh

# Quick status check
./all-in-one-check.sh -q

# Full health check
./all-in-one-check.sh -f

# Check individual validator
./all-in-one-check.sh -v 1    # Check validator 1
```

## Script Functions

### pm2-init.sh - Network Initialization

- ✅ Supports 5 validators initialization
- ✅ Auto-generates genesis.json (testnet and mainnet)
- ✅ Creates all validator accounts
- ✅ Auto-fetches and configures static nodes
- ✅ Supports mainnet sync node initialization

**Usage:**

```bash
./pm2-init.sh
```

### pm2-manager.sh - Interactive Management

- ✅ Start/stop/restart for all 5 validators
- ✅ Testnet and mainnet sync node management
- ✅ Log viewing (multiple options)
- ✅ Mainnet management submenu

**Function Menu:**

1. Start all validators
2. Stop all validators
3. Restart all validators
4. Start testnet sync node
5. Stop testnet sync node
6. Restart testnet sync node
7. View all process status
8. Initialize network
9. View logs
10. Mainnet management

### all-in-one-check.sh - Unified Monitoring

This is the most comprehensive monitoring script with the following features:

- ✅ PM2 process status check
- ✅ Node online status monitoring
- ✅ Network sync status check
- ✅ Validator mining status monitoring
- ✅ P2P connection count statistics
- ✅ Transaction pool status check
- ✅ System resource monitoring (disk, memory)
- ✅ Recent block production status
- ✅ Network health scoring system (100-point scale)

**Command Options:**

```bash
./all-in-one-check.sh          # Full check (default)
./all-in-one-check.sh -q       # Quick check
./all-in-one-check.sh -f       # Full check (explicit)
./all-in-one-check.sh -v 2     # Check validator 2 detailed status
./all-in-one-check.sh --mining # Check mining status only
./all-in-one-check.sh --processes # Check PM2 processes only
./all-in-one-check.sh --system # Check system resources only
./all-in-one-check.sh --json   # JSON format output
./all-in-one-check.sh --help   # Show help information
```

**Output Examples:**

- **Quick Check**: PM2 status + mining status + latest block
- **Full Check**: All check items + health score
- **Specific Validator**: HTTP interface + mining status + P2P connections + transaction pool
- **JSON Output**: Structured data for program processing

## Port Configuration

### Validator Nodes

- Validator 1: HTTP 8545, P2P 30301
- Validator 2: HTTP 8553, P2P 30303  
- Validator 3: HTTP 8556, P2P 30304
- Validator 4: HTTP 8559, P2P 30305
- Validator 5: HTTP 8562, P2P 30306

### Sync Nodes

- Testnet sync: HTTP 8547, P2P 30302
- Mainnet sync: HTTP 8549, P2P 30312

## Monitoring Strategy

### Daily Monitoring

```bash
# Daily health check
./all-in-one-check.sh

# Real-time status monitoring (every 30 seconds)
watch -n 30 './all-in-one-check.sh -q'

# View real-time logs
pm2 logs --lines 100
```

### Specialized Checks

```bash
# Check mining status only
./all-in-one-check.sh --mining

# Check system resources only
./all-in-one-check.sh --system

# Check specific validator issues
./all-in-one-check.sh -v 3

# Get JSON data for automation
./all-in-one-check.sh --json
```

## Log Management

### View Real-Time Logs

```bash
# Select logs via pm2-manager.sh menu
./pm2-manager.sh → Select 9 → Select specific node

# Or use PM2 commands directly
pm2 logs ju-chain-validator1
pm2 logs ju-chain-validator2
pm2 logs ju-chain-syncnode
pm2 logs ju-chain-syncnode-mainnet
```

### Log File Locations

```bash
logs/validator1.log
logs/validator2.log
logs/validator3.log
logs/validator4.log
logs/validator5.log
logs/syncnode.log
logs/syncnode-mainnet.log
```

## Network Identifiers

### Testnet

- Network ID: 202599
- Genesis: genesis.json
- 5 validators + 1 sync node

### Mainnet

- Network ID: 210000  
- Genesis: genesis-mainnet.json
- 1 sync node

## Troubleshooting

### Common Issues

1. **Validator Not Mining**

```bash
# Check specific validator status
./all-in-one-check.sh -v 1

# Check all validator mining status
./all-in-one-check.sh --mining
```

2. **Node Cannot Start**

```bash
# View all process status
./all-in-one-check.sh --processes

# View error logs
pm2 logs ju-chain-validator1 --err

# Check port usage
lsof -i :8545
```

3. **Network Sync Issues**

```bash
# Check overall network health
./all-in-one-check.sh -f

# Check P2P connection
curl -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
    http://localhost:8545
```

4. **System Resource Issues**

```bash
# Check disk and memory usage
./all-in-one-check.sh --system

# Clean old logs
pm2 flush
```

### Health Scoring

The `all-in-one-check.sh` provides a 100-point health score:

- **90-100 points**: Excellent network status
- **70-89 points**: Good network status  
- **50-69 points**: Fair network status, needs attention
- **30-49 points**: Poor network status, needs handling
- **0-29 points**: Critical network status, requires immediate action

## Automated Monitoring

### Scheduled Checks

```bash
# Add to crontab, check every 5 minutes
*/5 * * * * /path/to/all-in-one-check.sh -q >> /var/log/ju-chain-monitor.log

# Full check every hour
0 * * * * /path/to/all-in-one-check.sh -f >> /var/log/ju-chain-health.log
```

### Script Integration

```bash
# Get JSON format data for other script processing
health_data=$(./all-in-one-check.sh --json)
echo "$health_data" | jq '.summary'
```

## Best Practices

1. **Regular Health Checks**

```bash
# Daily full check
./all-in-one-check.sh -f

# Real-time monitoring
watch -n 30 './all-in-one-check.sh -q'
```

2. **Log Monitoring**

```bash
# View critical errors
pm2 logs --err

# Regular log cleanup
pm2 flush
```

3. **Backup Important Data**

```bash
# Backup keystore
cp -r keystore/ backup/keystore-$(date +%Y%m%d)/

# Backup configuration
cp .env backup/env-$(date +%Y%m%d)
cp ecosystem.config.js backup/
```

4. **Performance Monitoring**

```bash
# Monitor system resources with all-in-one script
./all-in-one-check.sh --system

# Monitor network connections
./all-in-one-check.sh | grep "P2P Connections"
```

## Security Considerations

- 🔒 Properly secure keystore files and passwords
- 🔒 Regularly backup validator private keys
- 🔒 Monitor unusual network activity
- 🔒 Keep system updated
- 🔒 Restrict unnecessary network access
- 🔒 Regularly check transaction pool status to prevent transaction backlog

## Support

If encountering issues, check:

1. Use `./all-in-one-check.sh -f` to get full diagnostic information
2. Check PM2 logs: `pm2 logs`
3. View system resources: `./all-in-one-check.sh --system`
4. Check network connections: Are P2P ports reachable
5. Verify node configuration: Are ports, network IDs etc. correct