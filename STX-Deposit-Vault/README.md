# STX Collateralized Lending Protocol

## Overview

The STX Collateralized Lending Protocol is a comprehensive decentralized lending platform built on the Stacks blockchain that enables users to obtain USD-denominated loans by collateralizing their STX token holdings. The protocol ensures financial stability through strict over-collateralization requirements, real-time price monitoring, and automated liquidation mechanisms.

## Key Features

- **STX Token Collateralization**: Users can deposit STX tokens as collateral to secure USD loans
- **Over-Collateralization Requirements**: 150% minimum collateralization ratio enforcement
- **Automated Liquidation**: Positions are liquidated when collateral ratio drops below 130%
- **Oracle-Based Pricing**: Real-time price discovery system for accurate asset valuation
- **Decentralized Governance**: Community-controlled parameter management
- **Risk Assessment Tools**: Advanced position monitoring and health scoring
- **Sustainable Fee Structure**: Built-in fee system for protocol operations and sustainability

## Protocol Parameters

### Collateralization Requirements
- **Minimum Collateralization Ratio**: 150%
- **Liquidation Threshold**: 130%
- **Default Origination Fee**: 1%
- **Maximum Protocol Fee**: 10%

### Safety Mechanisms
- Over-collateralization requirements protect against market volatility
- Automated liquidation prevents protocol insolvency
- Real-time price monitoring ensures accurate position assessment

## Smart Contract Functions

### Account Management

#### `create-new-borrower-account()`
Creates a new borrower account in the protocol.
- **Returns**: `(ok true)` on success
- **Errors**: `ERR-BORROWER-ACCOUNT-ALREADY-EXISTS` if account exists

#### `deposit-stx-collateral(stx-deposit-amount)`
Deposits STX tokens as collateral into the protocol.
- **Parameters**: 
  - `stx-deposit-amount`: Amount of STX to deposit (uint)
- **Returns**: `(ok true)` on success
- **Errors**: Various validation errors for insufficient funds or invalid amounts

#### `withdraw-excess-collateral(stx-withdrawal-amount)`
Withdraws excess collateral while maintaining minimum collateralization.
- **Parameters**: 
  - `stx-withdrawal-amount`: Amount of STX to withdraw (uint)
- **Returns**: `(ok true)` on success
- **Requirements**: Must maintain minimum 150% collateralization ratio

### Loan Operations

#### `originate-collateralized-loan(loan-amount-requested)`
Creates a new loan against deposited collateral.
- **Parameters**: 
  - `loan-amount-requested`: USD amount to borrow (uint)
- **Returns**: `(ok true)` on success
- **Requirements**: Sufficient collateral and protocol liquidity

#### `process-loan-repayment(repayment-amount)`
Processes loan repayment and reduces debt balance.
- **Parameters**: 
  - `repayment-amount`: Amount to repay (uint)
- **Returns**: `(ok true)` on success
- **Note**: Automatically calculates protocol fees

### Liquidation System

#### `execute-position-liquidation(target-borrower-address)`
Liquidates undercollateralized positions.
- **Parameters**: 
  - `target-borrower-address`: Address of borrower to liquidate (principal)
- **Returns**: `(ok true)` on success
- **Requirements**: Target position must be below 130% collateralization ratio

### Governance Functions

#### `update-asset-price-oracle(asset-symbol, new-price-usd-cents)`
Updates asset prices in the oracle system (governance only).
- **Parameters**: 
  - `asset-symbol`: Asset identifier (string-ascii 32)
  - `new-price-usd-cents`: New price in USD cents (uint)
- **Access**: Governance controller only

#### `adjust-protocol-fee-structure(new-fee-rate)`
Adjusts the protocol fee rate (governance only).
- **Parameters**: 
  - `new-fee-rate`: New fee percentage (uint)
- **Access**: Governance controller only
- **Limit**: Maximum 10% fee rate

#### `transfer-governance-control(new-governance-controller)`
Transfers governance control to a new address.
- **Parameters**: 
  - `new-governance-controller`: New governance address (principal)
- **Access**: Current governance controller only

## Read-Only Functions

### Position Information

#### `get-borrower-account-details(borrower-address)`
Retrieves complete borrower account information.

#### `compute-collateralization-ratio(borrower-address)`
Calculates current collateralization ratio for a borrower.

#### `compute-maximum-borrowing-capacity(borrower-address)`
Determines maximum additional borrowing capacity.

#### `check-liquidation-eligibility(borrower-address)`
Checks if a position is eligible for liquidation.

#### `compute-position-health-score(borrower-address)`
Calculates position health as percentage above liquidation threshold.

### Protocol Analytics

#### `get-protocol-statistics()`
Returns comprehensive protocol statistics including:
- Total STX collateral locked
- Total loan debt outstanding
- Number of active borrowers
- Current fee rates
- Protocol capital efficiency

#### `get-borrower-position-report(borrower-address)`
Generates detailed borrower position report with risk metrics.

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u1 | ERR-UNAUTHORIZED-ACCESS | Caller lacks required permissions |
| u2 | ERR-INSUFFICIENT-COLLATERAL-BALANCE | Insufficient collateral for operation |
| u3 | ERR-INSUFFICIENT-PROTOCOL-LIQUIDITY | Protocol lacks liquidity for loan |
| u4 | ERR-INADEQUATE-COLLATERAL-RATIO | Operation would violate collateralization requirements |
| u5 | ERR-BORROWER-ACCOUNT-NOT-FOUND | Borrower account does not exist |
| u6 | ERR-BORROWER-ACCOUNT-ALREADY-EXISTS | Borrower account already exists |
| u7 | ERR-INVALID-TRANSACTION-AMOUNT | Invalid transaction amount |
| u8 | ERR-LIQUIDATION-CONDITIONS-NOT-MET | Liquidation conditions not satisfied |
| u9 | ERR-PROTOCOL-FEE-EXCEEDS-MAXIMUM | Fee exceeds maximum allowed rate |
| u10 | ERR-ZERO-AMOUNT-NOT-ALLOWED | Zero amounts not permitted |

## Usage Examples

### Basic Lending Workflow

1. **Create Account**
   ```clarity
   (contract-call? .lending-protocol create-new-borrower-account)
   ```

2. **Deposit Collateral**
   ```clarity
   (contract-call? .lending-protocol deposit-stx-collateral u1000000)
   ```

3. **Originate Loan**
   ```clarity
   (contract-call? .lending-protocol originate-collateralized-loan u500000)
   ```

4. **Repay Loan**
   ```clarity
   (contract-call? .lending-protocol process-loan-repayment u100000)
   ```

### Position Monitoring

```clarity
;; Check position health
(contract-call? .lending-protocol compute-position-health-score tx-sender)

;; Get detailed position report
(contract-call? .lending-protocol get-borrower-position-report tx-sender)
```

## Risk Management

### For Borrowers
- Maintain collateralization above 150% to avoid liquidation risk
- Monitor position health regularly
- Consider market volatility when borrowing maximum amounts
- Repay loans promptly to reduce interest exposure

### For Liquidators
- Monitor positions approaching 130% collateralization ratio
- Execute liquidations promptly when conditions are met
- Understand liquidation mechanics and profit calculations

## Security Considerations

- All arithmetic operations include overflow protection
- Strict access controls for governance functions
- Comprehensive validation of input parameters
- Real-time collateralization ratio enforcement
- Automated liquidation prevents protocol insolvency

## Governance

The protocol is governed by a designated controller address that can:
- Update asset price oracles
- Adjust protocol fee structures
- Transfer governance control
- Modify protocol parameters (within safety limits)