# 🎮 E-Sports Prize Pool Automation

> Automated tournament prize pools with guaranteed payouts using Stacks blockchain smart contracts

## 🚀 Overview

This smart contract automates e-sports tournament prize pool management, eliminating disputes and ensuring automatic distribution of winnings to tournament winners. Organizers can create tournaments, participants can register with entry fees, and prizes are automatically distributed based on predefined percentages.

## ✨ Features

- 🏆 **Automated Prize Distribution** - Winners receive payouts automatically
- 💰 **Secure Prize Pools** - Entry fees locked in smart contract
- 🎯 **Customizable Payouts** - Organizers set prize distribution percentages
- ⏰ **Time-locked Tournaments** - Registration and tournament deadlines enforced
- 🛡️ **Emergency Refunds** - Participants can claim refunds if tournaments are abandoned
- 📊 **Transparent Results** - All tournament data publicly viewable

## 🎯 Core Functions

### Tournament Management

- `create-tournament` - Create a new tournament with prize distribution
- `start-tournament` - Begin the tournament (organizer only)
- `complete-tournament` - Set winners and finalize results

### Participant Actions

- `register-for-tournament` - Join a tournament with entry fee
- `claim-prize` - Winners claim their prizes after completion
- `emergency-refund` - Get refund if tournament is abandoned

### Information Queries

- `get-tournament` - View tournament details
- `tournament-info` - Complete tournament information with status
- `get-tournament-winners` - View tournament results
- `calculate-prize` - Check prize amounts for each position

## 📋 Usage Instructions

### 1. Creating a Tournament 🏗️

```clarity
(create-tournament 
    "Championship 2024"    ;; Tournament name
    u16                    ;; Max participants
    u144                   ;; Registration blocks (≈24 hours)
    u1008                  ;; Tournament blocks (≈7 days)
    u1000000               ;; Entry fee in microSTX (1 STX)
    u50                    ;; First place: 50%
    u30                    ;; Second place: 30%
    u20)                   ;; Third place: 20%
```

### 2. Registering for a Tournament 📝

```clarity
(register-for-tournament u1)  ;; Tournament ID
```

### 3. Starting the Tournament 🎮

```clarity
(start-tournament u1)  ;; Only organizer can call this
```

### 4. Completing the Tournament 🏁

```clarity
(complete-tournament 
    u1                          ;; Tournament ID
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; 1st place
    'SP2HTZ3J0CZ4HH2X6W6ZBM0Q4TNAJQ4BGABGSA8K  ;; 2nd place
    'SP3D6PV2ACBPEKYJTCMH7HEN02KP87QSP8KTEH335) ;; 3rd place
```

### 5. Claiming Prizes 💎

```clarity
(claim-prize u1)  ;; Winners call this to receive STX
```

## 🔍 Tournament States

- **Created** (0) - Tournament created, accepting registrations
- **Active** (1) - Tournament started, registration closed
- **Completed** (2) - Results finalized, prizes claimable

## ⚡ Smart Contract Architecture

The contract uses three main data structures:
- `tournaments` - Core tournament information
- `participants` - Player registration data
- `tournament-winners` - Results and prize claim status

## 🛡️ Security Features

- ✅ Only organizers can manage their tournaments
- ✅ Participants must register before deadlines
- ✅ Winners are verified participants
- ✅ Prizes can only be claimed once
- ✅ Emergency refunds available for abandoned tournaments
- ✅ All STX transfers are secured by the blockchain

## 📊 Example Tournament Flow

1. **Organizer** creates tournament with 10 STX entry fee
2. **16 players** register, contributing 160 STX total to prize pool
3. **Tournament begins** after registration deadline
4. **Organizer** sets winners after tournament completion
5. **Winners automatically receive**:
   - 1st place: 80 STX (50%)
   - 2nd place: 48 STX (30%)
   - 3rd place: 32 STX (20%)

## ⚙️ Development Setup

```bash
# Install Clarinet
npm install -g @hirosystems/clarinet-cli

# Check contract syntax
clarinet check

# Run tests
clarinet test

# Deploy to testnet
clarinet integrate
```

## 🎮 Perfect For

- E-sports tournaments
- Gaming competitions  
- Community events
- Skill-based contests
- Any competitive event with entry fees

Built with ❤️ on Stacks blockchain
