# Bastion - Digital Asset Vault System

A sophisticated automated market maker (AMM) and liquidity pool system built on the Stacks blockchain using Clarity smart contracts. Bastion enables secure asset swapping, liquidity provision, and treasury management for STX and digital tokens.

## 🏛️ Overview

Bastion is a decentralized vault system that allows users to:
- Create and manage liquidity pools between STX and digital assets
- Swap assets with automated pricing (0.3% fee)
- Provide liquidity and earn certificates representing pool ownership
- Redeem certificates for underlying assets

## ✨ Key Features

### 🔐 Secure Vault Management
- **Vault Establishment**: Initialize liquidity pools with STX and token pairs
- **Certificate System**: LP tokens that represent proportional ownership of vault assets
- **Access Control**: Secure operations with proper authorization checks

### 💱 Automated Market Making
- **Asset Swapping**: Bidirectional STX ↔ Token exchanges
- **Dynamic Pricing**: Constant product formula with slippage protection
- **Fee Structure**: 0.3% transaction fee on all swaps

### 📊 Liquidity Operations
- **Liquidity Addition**: Expand existing vaults with proportional deposits
- **Liquidity Removal**: Redeem certificates for underlying assets
- **Balance Tracking**: Real-time vault holdings and certificate balances

## 🚀 Getting Started

### Prerequisites
- Stacks blockchain testnet/mainnet access
- Clarity CLI or compatible development environment
- Digital asset contract implementing the required trait

### Deployment

1. Deploy your digital asset contract (must implement `digital-asset` trait)
2. Deploy the Bastion vault contract
3. Initialize the vault with your asset pair

### Basic Usage

#### Establish a Vault
```clarity
(establish-vault .your-token-contract stx-amount token-amount)
```

#### Add Liquidity
```clarity
(expand-vault .your-token-contract stx-deposit token-deposit min-certificates)
```

#### Swap STX for Tokens
```clarity
(vault-exchange-stx-to-tokens .your-token-contract stx-amount min-token-output)
```

#### Swap Tokens for STX
```clarity
(vault-exchange-tokens-to-stx .your-token-contract token-amount min-stx-output)
```

#### Redeem Liquidity
```clarity
(redeem-certificates .your-token-contract certificate-amount min-stx min-tokens)
```

## 🔍 Query Functions

### Vault Information
- `check-vault-holdings` - View current STX and token reserves
- `check-vault-status` - Check if vault is operational
- `check-vault-asset` - Get the paired token contract address
- `check-total-certificates` - Total certificates in circulation

### User Information
- `check-certificate-balance` - User's certificate balance

### Pricing Calculations
- `calculate-vault-output` - Estimate swap output amounts
- `calculate-vault-input` - Calculate required input for desired output
- `calculate-certificate-ratio` - Estimate certificates for liquidity addition

## 📋 Digital Asset Interface

Your token contract must implement the following trait:

```clarity
(define-trait digital-asset
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)
```

## ⚡ Technical Details

### Fee Structure
- **Swap Fee**: 0.3% (30 basis points) on all exchanges
- **Fee Calculation**: Applied to input amount before calculating output

### Pricing Formula
Uses constant product market maker formula:
```
k = x × y (where k remains constant)
output = (input × 997 × y) / (x × 1000 + input × 997)
```

### Security Features
- **Slippage Protection**: Minimum output requirements
- **Zero Amount Guards**: Prevents zero-value transactions
- **Vault Status Checks**: Operations only when vault is operational
- **Asset Verification**: Ensures correct token contract usage

## 🛡️ Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 500 | `vault-err-forbidden` | Unauthorized operation |
| 501 | `vault-err-empty-vault` | Insufficient vault liquidity |
| 502 | `vault-err-zero-deposit` | Zero amount not allowed |
| 503 | `vault-err-price-slippage` | Output below minimum threshold |
| 504 | `vault-err-asset-mismatch` | Wrong token contract |
| 505 | `vault-err-operation-failed` | General operation failure |
| 506 | `vault-err-vault-exists` | Vault already established |
| 507 | `vault-err-vault-not-ready` | Vault not operational |

## 📈 Transaction History

The system maintains detailed transaction records including:
- Account holder
- STX amounts (deposited/released)
- Token amounts (deposited/released)
- Block height
- Unique transaction reference

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Implement your changes with tests
4. Submit a pull request

## ⚠️ Disclaimer

This is experimental software. Use at your own risk. Thoroughly test on testnet before mainnet deployment. Smart contract code should be audited before handling significant value.
