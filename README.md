# Eigensurance AVS

Eigensurance is a decentralized disaster insurance protocol built on EigenLayer that leverages multiple operator validation for disaster event verification and claims processing.

## Architecture

The protocol consists of several key components:
- `DisasterInsuranceServiceManager`: Main contract handling policy creation, disaster validation, and claims
- `MockDisasterOracle`: Simulates disaster data feeds
- `MockStakeRegistry`: Handles operator registration and validation
- `MockAVSDirectory`: Manages AVS operator registration

## Setup Instructions

### Prerequisites
- [Node.js](https://nodejs.org/)
- [Foundry](https://getfoundry.sh/)
- [Git](https://git-scm.com/)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/andrewgcodes/eigen.git
cd eigen
```

2. Install dependencies:
```bash
npm install
```

3. Copy environment files:
```bash
cp .env.example .env
cp contracts/.env.example contracts/.env
```

### Local Development

1. Start local Anvil chain:
```bash
npm run start:anvil
```

2. In a new terminal, deploy the contracts:
```bash
# Deploy EigenLayer core contracts
npm run deploy:core

# Deploy Disaster Insurance contracts
npm run deploy:insurance
```

## Usage

### Create a Policy
Create a new insurance policy:
```bash
npm run insurance:create-policy
```
This creates a policy with:
- Coverage amount: 1 ETH
- Location: San Francisco
- Disaster Type: EARTHQUAKE
- Premium: 5% of coverage amount

### Simulate a Disaster
Simulate a disaster event:
```bash
npm run insurance:simulate-disaster
```
This simulates an earthquake in San Francisco with:
- Severity: 7.0 on Richter scale
- Multiple operator validations
- Event verification

### Process Claims
Process an insurance claim:
```bash
npm run insurance:process-claim
```
This processes the claim for:
- The most recently created policy
- The most recent disaster event
- Transfers coverage amount to policyholder if valid

## Testing

Run the test suite:
```bash
cd contracts
forge test -vv
```

The tests cover:
- Policy creation
- Disaster event simulation
- Multi-operator validation
- Claim processing
- Edge cases and error conditions

## Contract Addresses (Local Testnet)

After deployment, contract addresses can be found in:
- EigenLayer Core: `deployments/core/31337.json`
- Disaster Insurance: `deployments/disaster-insurance/31337.json`

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Security

This is a prototype and has not been audited. Do not use in production.
