# GreenBonds Smart Contract

A Solidity smart contract for issuing, managing, and redeeming green bonds to support climate and environmental projects.

## Overview

GreenBonds is a smart contract implementation that enables organizations to issue tokenized green bonds on the blockchain. It provides transparency in fund allocation, automated coupon payments, and verifiable environmental impact reporting.

### What are Green Bonds?

Green bonds are fixed-income financial instruments specifically earmarked to raise money for climate and environmental projects. This smart contract digitizes the entire green bond lifecycle while enhancing transparency and reducing administrative overhead.

## Features

- **Bond Issuance**: Create bonds with customizable parameters (face value, coupon rate, maturity period)
- **Bond Purchasing**: Investors can purchase bonds with ERC20 tokens
- **Automated Coupon Payments**: Investors can claim interest at regular intervals
- **Bond Redemption**: Redeem bonds at maturity for principal plus any unclaimed interest
- **Environmental Impact Reporting**: Track and verify environmental impact metrics
- **Green Certifications**: Document and verify environmental certifications
- **Fund Allocation Tracking**: Transparently record how bond proceeds are used
- **Role-Based Access Control**: Separate issuer and verifier roles for proper governance

## Smart Contract Architecture

The contract uses several OpenZeppelin libraries:
- `AccessControl` for role-based permissions
- `ReentrancyGuard` for protection against reentrancy attacks
- `IERC20` for interacting with the payment token

### Key Roles

- **Admin**: Can add verifiers and manage contract settings
- **Issuer**: Can add impact reports, allocate funds, and add certifications
- **Verifier**: Independent party that validates environmental impact reports
- **Investors**: Users who purchase, hold, and redeem bonds

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (optional, for front-end integration)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/green-bonds.git
   cd green-bonds
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

### Testing

Run the comprehensive test suite:

```bash
forge test
```

For detailed test output:

```bash
forge test -vvv
```

### Deployment

You can deploy the contract to a local Anvil instance:

```bash
# Start Anvil in one terminal
anvil

# In another terminal, run the deployment script
forge script script/DeployGreenBonds.s.sol --broadcast --fork-url http://localhost:8545
```

For testnet or mainnet deployment, modify the `DeployGreenBonds.s.sol` script with your private key and token address.

## Usage Examples

### For Bond Issuers

```solidity
// Deploy the GreenBonds contract
GreenBonds greenBonds = new GreenBonds(
    "Solar Energy Bond",
    "SEB",
    1000 * 10**18, // 1000 USDC per bond
    1000, // 1000 bonds
    500, // 5.00% annual interest
    90 days, // Quarterly coupon payments
    3 * 365 days, // 3-year maturity
    address(usdcToken),
    "Solar farm development in Arizona",
    "CO2 reduction, renewable energy production"
);

// Add impact reports
greenBonds.addImpactReport(
    "https://example.com/report1",
    "0x1234567890abcdef",
    "50 tons CO2 reduced, 100MWh green energy produced"
);

// Add certifications
greenBonds.addGreenCertification("Gold Standard Certified");
```

### For Investors

```solidity
// Approve tokens for bond purchase
usdcToken.approve(address(greenBonds), 2000 * 10**18);

// Purchase 2 bonds
greenBonds.purchaseBonds(2);

// Claim coupon after coupon period
greenBonds.claimCoupon();

// Redeem bonds at maturity
greenBonds.redeemBonds();
```

### For Verifiers

```solidity
// Verify an impact report
greenBonds.verifyImpactReport(0);
```

## Contract Interface

### Bond Management
- `purchaseBonds(uint256 bondAmount)`: Buy bonds with approved tokens
- `claimCoupon()`: Claim accumulated coupon payments
- `redeemBonds()`: Redeem bonds at maturity for principal plus interest
- `calculateClaimableCoupon(address investor)`: Calculate claimable interest

### Environmental Impact
- `addImpactReport(string reportURI, string reportHash, string metrics)`: Add impact report
- `verifyImpactReport(uint256 reportId)`: Verify an impact report
- `addGreenCertification(string certification)`: Add certification
- `allocateFunds(string projectComponent, uint256 amount)`: Record fund allocation

### Administration
- `addVerifier(address verifier)`: Add a new verifier
- `issuerEmergencyWithdraw(uint256 amount)`: Emergency fund withdrawal (time-locked)

## Future Enhancements
- Timelock mechanism for emergency withdrawals, potentially using a separate timelock contract
- A circuit breaker/pause functionality to halt operations in case of emergencies
- A multisig wallet for the admin role to prevent single points of failure
- More granular roles beyond the current ISSUER_ROLE and VERIFIER_ROLE
- Rate limiting for bond purchases to prevent market manipulation
- Support for secondary market trading by implementing an ERC-20 or ERC-1155 interface for the bonds
- Graduated impact verification tiers rather 
- Automatic coupon payments 
- Oracle integration for real-world impact verification data
- Support for multiple payment tokens (stable coins)
- On-chain voting for bondholders on specific project decisions
- Detailed fund tracking with milestone-based releases
- Slashing conditions if green metrics aren't met
- Emissions data verification through trusted oracles

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.


## Acknowledgements

- [OpenZeppelin](https://openzeppelin.com/) for secure smart contract components
- [Foundry](https://book.getfoundry.sh/) for development framework