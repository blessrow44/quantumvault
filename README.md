# Quantum Vault 🔐

A next-generation time-locked savings protocol on Stacks blockchain featuring dynamic APY, social recovery, and automated yield optimization.

## 🚀 Overview

Quantum Vault revolutionizes DeFi savings by combining traditional time deposits with blockchain innovation. Users lock STX tokens for predetermined periods to earn competitive yields, with rates dynamically adjusted based on lock duration and deposit size. The protocol features guardian-based social recovery, ensuring funds are never permanently lost.

## ✨ Core Features

### 1. **Dynamic Yield Tiers**
| Tier | Minimum STX | Lock Period | APY Rate |
|------|-------------|-------------|----------|
| Base | 1 STX | 1 day | 5% |
| Bronze | 10 STX | 7 days | 7% |
| Silver | 50 STX | 30 days | 10% |
| Gold | 100 STX | 90 days | 13% |
| Platinum | 500 STX | 180 days | 17% |

### 2. **Vault Management**
- Create up to 10 vaults per address
- Flexible lock periods (1-365 days)
- Auto-compound option for maximum returns
- Early withdrawal with 10% penalty
- Lock extension for better rates

### 3. **Social Recovery**
- Designate up to 3 guardians
- 2-of-3 multi-signature recovery
- Protection against lost private keys
- Time-locked recovery process
- Guardian vote tracking

### 4. **Protocol Features**
- Real-time reward calculation
- Historical transaction tracking
- User statistics dashboard
- Global APY multiplier adjustments
- Emergency mode protection

## 📋 Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) >= 1.0.0
- [Stacks CLI](https://docs.stacks.co/docs/cli)
- Node.js >= 14.0.0
- Minimum 1 STX for vault creation

## 🛠️ Installation

1. **Clone Repository**
```bash
git clone https://github.com/yourusername/quantum-vault.git
cd quantum-vault
```

2. **Install Dependencies**
```bash
npm install
clarinet install
```

3. **Verify Contract**
```bash
clarinet check
clarinet test
```

## 💻 Quick Start

### Deploy Contract
```bash
# Local deployment
clarinet console
> (deploy-contract 'quantum-vault)

# Testnet deployment
clarinet deploy --testnet

# Mainnet deployment
clarinet deploy --mainnet
```

### Basic Usage

#### 1. Create a Vault
```clarity
;; Create a 30-day vault with 100 STX and auto-compound enabled
(contract-call? .quantum-vault create-vault 
    u100000000    ;; 100 STX in microSTX
    u4320         ;; 30 days in blocks
    true          ;; auto-compound enabled
)
```

#### 2. Check Vault Status
```clarity
;; Get vault information
(contract-call? .quantum-vault get-vault u1)

;; Calculate current rewards
(contract-call? .quantum-vault calculate-current-rewards u1)
```

#### 3. Add Guardians
```clarity
;; Add a guardian for social recovery
(contract-call? .quantum-vault add-guardian 
    u1                                           ;; vault-id
    'SP2J6Y09JMFWWZCT4VJX0BA5W7A9HZP5EX96Y6VZY ;; guardian address
)
```

#### 4. Withdraw at Maturity
```clarity
;; Withdraw principal + rewards after lock period
(contract-call? .quantum-vault withdraw u1)
```

## 📚 API Reference

### Core Functions

| Function | Description | Parameters | Returns |
|----------|-------------|------------|---------|
| `create-vault` | Create new time-locked vault | `amount, duration, auto-compound` | `vault-id` |
| `withdraw` | Withdraw funds from matured vault | `vault-id` | `{amount, rewards, penalty}` |
| `compound-rewards` | Reinvest earned rewards | `vault-id` | `rewards amount` |
| `extend-lock` | Extend vault lock period | `vault-id, additional-blocks` | `new unlock time` |
| `add-guardian` | Add recovery guardian | `vault-id, guardian` | `success` |

### Recovery Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `initiate-recovery` | Start recovery process | `vault-id` |
| `vote-recovery` | Guardian votes for recovery | `vault-id` |
| `execute-recovery` | Complete recovery with new owner | `vault-id, new-owner` |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-vault` | Get vault details | Vault information |
| `get-user-vaults` | List user's vault IDs | List of vault IDs |
| `calculate-current-rewards` | Calculate pending rewards | Reward amount |
| `get-user-stats` | Get user statistics | User metrics |
| `estimate-rewards` | Estimate rewards for parameters | Expected rewards |
| `get-protocol-stats` | Get protocol statistics | Global metrics |

### Admin Functions

| Function | Description | Access |
|----------|-------------|--------|
| `set-emergency-mode` | Enable/disable emergency mode | Owner only |
| `update-apy-multiplier` | Adjust global APY rates | Owner only |
| `withdraw-treasury` | Withdraw protocol fees | Owner only |

## 💰 Economics

### Yield Calculation
```
Annual Yield = Principal × (Base APY + Tier Bonus) × Global Multiplier
Daily Rewards = Annual Yield ÷ 365
```

### Fee Structure
- **Protocol Fee**: 2% on rewards
- **Early Withdrawal Penalty**: 10% of principal
- **Minimum Deposit**: 1 STX
- **Maximum Vaults**: 10 per user

### APY Tiers Breakdown
| Deposit Amount | Lock Duration | Base APY | Bonus APY | Total APY |
|---------------|---------------|----------|-----------|-----------|
| 1-9 STX | Any | 5% | 0% | 5% |
| 10-49 STX | 7+ days | 5% | 2% | 7% |
| 50-99 STX | 30+ days | 5% | 5% | 10% |
| 100-499 STX | 90+ days | 5% | 8% | 13% |
| 500+ STX | 180+ days | 5% | 12% | 17% |

## 🔒 Security Features

### Protection Mechanisms
1. **Time Locks**: Funds locked until maturity
2. **Guardian System**: Social recovery for lost keys
3. **Multi-signature**: 2-of-3 guardian consensus
4. **Emergency Mode**: Admin can pause operations
5. **Penalty System**: Discourages early withdrawals

### Guardian Recovery Process
```
1. Guardian initiates recovery
2. Other guardians vote (2 of 3 required)
3. Recovery executor transfers ownership
4. New owner gains vault access
```

### Best Practices
- Choose trusted guardians
- Diversify vault durations
- Enable auto-compound for long-term vaults
- Monitor APY multiplier changes
- Keep backup of vault IDs

## 🧪 Testing

### Run Test Suite
```bash
# Run all tests
clarinet test

# Run specific test
clarinet test --filter test-vault-creation

# Generate coverage report
clarinet test --coverage
```

### Test Scenarios
- ✅ Vault creation and configuration
- ✅ Reward calculation accuracy
- ✅ Tier assignment logic
- ✅ Guardian recovery flow
- ✅ Early withdrawal penalties
- ✅ Auto-compounding mechanism
- ✅ Lock extension functionality
- ✅ Emergency procedures

## 📊 Contract Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `min-lock-duration` | 144 blocks (~1 day) | Minimum lock period |
| `max-lock-duration` | 52,560 blocks (~365 days) | Maximum lock period |
| `min-deposit` | 1 STX | Minimum vault deposit |
| `max-vaults-per-user` | 10 | Maximum vaults per address |
| `base-apy` | 500 (5%) | Base annual percentage yield |
| `max-apy` | 2000 (20%) | Maximum possible APY |
| `early-withdrawal-penalty` | 1000 (10%) | Penalty for early withdrawal |
| `protocol-fee` | 200 (2%) | Fee on rewards |
| `guardian-threshold` | 2 | Guardians needed for recovery |

## 🛠️ Development

### Project Structure
```
quantum-vault/
├── contracts/
│   └── quantum-vault.clar     # Main contract
├── tests/
│   ├── unit/
│   │   ├── vault_test.ts      # Vault tests
│   │   ├── guardian_test.ts   # Guardian tests
│   │   └── yield_test.ts      # Yield calculation tests
│   └── integration/
│       └── e2e_test.ts         # End-to-end tests
├── scripts/
│   ├── deploy.ts              # Deployment script
│   ├── setup.ts               # Initial configuration
│   └── monitor.ts             # Monitoring utilities
├── docs/
│   ├── architecture.md        # Technical design
│   ├── economics.md           # Economic model
│   └── security.md            # Security analysis
├── Clarinet.toml              # Project configuration
└── README.md                  # Documentation
```

### Local Development
```bash
# Start console
clarinet console

# Deploy contract
(deploy-contract .quantum-vault)

# Create test vault
(contract-call? .quantum-vault create-vault u10000000 u1008 true)

# Check vault
(contract-call? .quantum-vault get-vault u1)
```

## 🔗 Integration Examples

### Frontend Integration
```javascript
// Create vault with Stacks.js
const createVault = async (amount, days, autoCompound) => {
    const blocks = days * 144; // ~144 blocks per day
    const amountUstx = amount * 1000000; // Convert to microSTX
    
    const tx = await contract.createVault(
        amountUstx,
        blocks,
        autoCompound
    );
    
    return tx;
};
```

### Reward Monitoring
```javascript
// Monitor rewards in real-time
const monitorRewards = async (vaultId) => {
    const rewards = await contract.calculateCurrentRewards(vaultId);
    console.log(`Current rewards: ${rewards / 1000000} STX`);
    
    // Update every block
    setTimeout(() => monitorRewards(vaultId), 120000);
};
```

## 🗺️ Roadmap

### Phase 1 - Launch ✅
- [x] Core vault functionality
- [x] Dynamic yield tiers
- [x] Guardian recovery system
- [x] Auto-compounding

### Phase 2 - Enhancement (Q1 2025)
- [ ] Yield aggregator integration
- [ ] Governance token
- [ ] Referral system
- [ ] Mobile app

### Phase 3 - Expansion (Q2 2025)
- [ ] Cross-chain vaults
- [ ] Institutional features
- [ ] Insurance fund
- [ ] Advanced strategies

### Phase 4 - Ecosystem (Q3 2025)
- [ ] Vault NFTs
- [ ] Lending against vaults
- [ ] DAO governance
- [ ] Partner integrations

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### How to Contribute
1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## 📝 License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## ⚠️ Risk Disclaimer

**IMPORTANT**: DeFi protocols carry inherent risks. Users should:

- Understand time-lock implications
- Never deposit more than you can lock
- Choose guardians carefully
- Be aware of early withdrawal penalties
- Consider smart contract risks
- Verify all transactions before signing

This protocol is provided "as is" without warranties. Users assume all risks associated with DeFi protocols and smart contracts.

## 📞 Support

### Get Help
- **Documentation**: [docs.quantumvault.io](https://docs.quantumvault.io)
- **Discord**: [Join our community](https://discord.gg/quantum-vault)
- **Twitter**: [@QuantumVault](https://twitter.com/quantumvault)
- **Email**: support@quantumvault.io
- **GitHub Issues**: [Report bugs](https://github.com/quantum-vault/issues)

### Frequently Asked Questions

**Q: What happens if I withdraw early?**
A: You'll receive your principal minus a 10% penalty. No rewards are paid for early withdrawals.

**Q: Can I add to an existing vault?**
A: No, but you can create multiple vaults (up to 10) with different parameters.

**Q: How does auto-compound work?**
A: When enabled, you can call `compound-rewards` to add accumulated rewards to your principal.

**Q: What if I lose access to my wallet?**
A: Your designated guardians can initiate recovery with 2-of-3 consensus.

**Q: Are rewards guaranteed?**
A: Rewards are calculated based on the APY at vault creation and the global multiplier.

**Q: Can I change my lock period?**
A: You can extend it for better rates, but cannot reduce it.

---

**Built with ❤️ for the Stacks Community**

*Quantum Vault - Your Gateway to Sustainable DeFi Yields*
