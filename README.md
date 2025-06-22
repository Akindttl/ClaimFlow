
-----

# ClaimFlow: Automated Insurance Claims Settlement Protocol

## Table of Contents

  * Introduction
  * Features
  * Smart Contract Architecture
      * Core Components
      * Error Handling
  * Getting Started
      * Prerequisites
      * Deployment
      * Contract Interaction Examples
  * Security & Auditing
  * Contributing
  * License
  * Contact
  * Acknowledgments

-----

## Introduction

**ClaimFlow** is an innovative Clarity smart contract designed to decentralize and automate the traditional insurance claims settlement process. Operating on the Stacks blockchain, this protocol enables transparent, efficient, and auditable management of insurance policies from creation through automated claim resolution. By integrating predefined policy conditions and leveraging oracle-verified data, ClaimFlow minimizes human intervention, reduces operational overhead, and enhances trust between policyholders and the insurance protocol.

-----

## Features

ClaimFlow provides a comprehensive suite of functionalities to manage the lifecycle of a blockchain-based insurance policy:

  * **Decentralized Policy Management:** Securely create and manage insurance policies on-chain, defining premiums, coverage amounts, policy types, and durations. All premiums are held within the contract's reserves.
  * **Streamlined Claim Submission:** Policyholders can submit claims against their active policies, with each claim initially set to a "pending" status, awaiting verification.
  * **Oracle-Based Verification:** A designated contract owner acts as an oracle, responsible for verifying external event data relevant to claims. This verification marks claims as "approved" or "rejected," initiating the automated settlement workflow.
  * **Automated Claim Settlement:** Approved and oracle-verified claims are automatically processed, and the calculated settlement amount is disbursed directly to the claimant from the respective policy's balance.
  * **Advanced Risk Assessment and Fraud Detection:** Incorporates sophisticated logic within the settlement process, allowing for dynamic adjustment of payouts based on risk scores, detected fraud indicators, and independent damage assessments. High-risk or clearly fraudulent claims can be automatically rejected.
  * **Dynamic Policy Balance Tracking:** Each policy maintains an internal balance from which claims are paid. Policies are automatically deactivated if their balance is depleted, ensuring responsible fund management.
  * **Centralized Reserve Management:** All collected premiums contribute to a `total-reserves` pool, providing a transparent overview of the protocol's overall financial solvency.
  * **Immutability and Auditability:** Every transaction, policy creation, and claim status update is immutably recorded on the Stacks blockchain, providing a full, tamper-proof audit trail.

-----

## Smart Contract Architecture

The ClaimFlow contract is meticulously structured in Clarity, adhering to best practices for secure and efficient blockchain protocols.

### Core Components

  * **Constants:**

      * `CONTRACT-OWNER`: The principal address authorized for critical administrative functions, such as oracle verification.
      * `ERR-*`: A comprehensive set of error codes (e.g., `ERR-UNAUTHORIZED`, `ERR-POLICY-NOT-FOUND`, `ERR-INSUFFICIENT-FUNDS`) for precise debugging and user feedback.
      * `MIN-PREMIUM` (u1000000 STX): Enforces a minimum premium amount to ensure policy viability.
      * `MAX-COVERAGE` (u100000000 STX): Sets a ceiling on the maximum coverage amount offered.

  * **Data Structures (Maps and Variables):**

      * `policies` (map): Stores granular details for each insurance policy, including `holder`, `premium`, `coverage-amount`, `policy-type`, `start-block`, `end-block`, and `active` status.
      * `claims` (map): Records comprehensive information for each claim, such as `policy-id`, `claimant`, `amount`, `description`, `submitted-block`, `status` ("pending", "approved", "rejected", "paid"), and `oracle-verified` boolean.
      * `policy-balances` (map): Tracks the STX balance allocated to each individual policy.
      * `next-policy-id` (data variable): Auto-increments to assign unique identifiers for new policies.
      * `next-claim-id` (data variable): Auto-increments to assign unique identifiers for new claims.
      * `total-reserves` (data variable): Aggregates all premiums collected by the contract, representing its total liquid assets.

  * **Private Functions (Internal Logic):**

      * `(is-policy-valid (policy-id uint))`: An internal utility to verify a policy's active status and ensure it falls within its valid block-height duration.
      * `(calculate-settlement-amount (claim-amount uint) (coverage uint))`: Determines the actual payout amount, capped by the policy's maximum coverage.
      * `(update-reserves (amount uint) (operation (string-ascii 10)))`: Manages the addition or subtraction of funds from the `total-reserves` pool, triggered by policy creation or claim settlement.

  * **Public Functions (External API):**

      * `(create-policy (premium uint) (coverage-amount uint) (policy-type (string-ascii 20)) (duration-blocks uint))`: Facilitates the creation of a new insurance policy by any Stacks user, requiring a premium transfer to the contract.
      * `(submit-claim (policy-id uint) (amount uint) (description (string-ascii 200)))`: Allows policyholders to submit a claim against their policy, subject to policy validity and holder authentication.
      * `(verify-claim-oracle (claim-id uint) (verified bool))`: An exclusive function for the `CONTRACT-OWNER` to authenticate claim details via external oracle data, transitioning the claim status.
      * `(process-automated-settlement (claim-id uint))`: Triggers the automated payout for an approved and verified claim, managing fund transfers, balance updates, and policy deactivation if funds are exhausted.
      * `(process-claim-with-risk-assessment (claim-id uint) (risk-score uint) (fraud-indicators (list 5 (string-ascii 50))) (weather-data-hash (buff 32)) (damage-assessment-score uint))`: A specialized function for the `CONTRACT-OWNER` to process claims with integrated risk and fraud analytics, dynamically calculating settlement amounts or outright rejecting claims based on predefined thresholds.

### Error Handling

ClaimFlow employs a robust error handling mechanism, utilizing distinct `ERR-` constants to provide clear and actionable feedback for failed transactions. This design simplifies debugging and enhances the user experience by precisely indicating the reason for an error.

-----

## Getting Started

To deploy and interact with the ClaimFlow smart contract, follow the steps below.

### Prerequisites

  * **Stacks CLI:** Ensure you have the Stacks Command Line Interface installed for contract deployment and interaction.
  * **Stacks Wallet:** A Stacks wallet (e.g., Leather, Xverse) with sufficient STX tokens for transaction fees and policy premiums.
  * **Clarity Development Environment:** Familiarity with Clarity syntax and smart contract development is recommended.

### Deployment

1.  **Save the Contract:** Save the provided Clarity code into a file named `claim-flow.clar`.
2.  **Deploy using Stacks CLI:** Execute the deployment command from your terminal:
    ```bash
    clarity deploy claim-flow ./claim-flow.clar --sender <YOUR_STACKS_ADDRESS>
    ```
    Replace `<YOUR_STACKS_ADDRESS>` with the Stacks address that will act as the `CONTRACT-OWNER`.

### Contract Interaction Examples

Once deployed, you can interact with the public functions of the ClaimFlow contract. The following examples illustrate common use cases. Replace `.claim-flow` with your deployed contract's principal and name if different.

  * **1. Create a New Insurance Policy:**

    ```clarity
    (contract-call? .claim-flow create-policy u1000000 u5000000 "Auto" u1000)
    ;; Parameters: premium (1 STX), coverage (5 STX), policy type ("Auto"), duration (1000 blocks)
    ```

  * **2. Submit a Claim for an Existing Policy:**

    ```clarity
    (contract-call? .claim-flow submit-claim u1 u2000000 "Minor collision with a deer, front bumper damage.")
    ;; Parameters: policy-id (1), claim amount (2 STX), description
    ```

  * **3. Oracle Verification of a Claim (by CONTRACT-OWNER):**

    ```clarity
    (contract-call? .claim-flow verify-claim-oracle u1 true)
    ;; Parameters: claim-id (1), verification status (true = approved)
    ```

  * **4. Process Automated Settlement of an Approved Claim:**

    ```clarity
    (contract-call? .claim-flow process-automated-settlement u1)
    ;; Parameters: claim-id (1)
    ```

  * **5. Process Claim with Advanced Risk Assessment (by CONTRACT-OWNER):**

    ```clarity
    (contract-call? .claim-flow process-claim-with-risk-assessment 
      u1 
      u25 
      (list "minor impact" "no prior claims history") 
      0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef 
      u90
    )
    ;; Parameters: claim-id (1), risk-score (25), fraud-indicators (list), weather-data-hash (example hash), damage-assessment-score (90)
    ```

-----

## Security & Auditing

ClaimFlow is designed with security as a paramount concern. The contract incorporates robust input validation, authorization checks (e.g., `CONTRACT-OWNER` specific functions), and careful management of STX transfers using `as-contract`.

While every effort has been made to ensure the contract's integrity, it is crucial for any real-world deployment to undergo comprehensive security audits by independent third parties. Users and developers are encouraged to review the code thoroughly and report any potential vulnerabilities.

-----

## Contributing

We welcome contributions from the community to enhance ClaimFlow. If you have ideas for improvements, discover a bug, or wish to add new features, please follow these guidelines:

1.  **Fork the Repository:** Start by forking the ClaimFlow GitHub repository.
2.  **Create a Feature Branch:** Branch out for your specific feature or fix (`git checkout -b feature/your-feature-name`).
3.  **Commit Your Changes:** Make your modifications and commit them with descriptive messages.
4.  **Push to Your Branch:** Push your committed changes to your forked repository.
5.  **Open a Pull Request:** Submit a pull request to the main repository, detailing your changes and their benefits.

-----

## License

ClaimFlow is open-sourced under the MIT License. This permits broad usage, modification, and distribution, both for commercial and non-commercial purposes, provided the original license and copyright notice are included.

-----

## Contact

For inquiries, support, or collaboration opportunities regarding ClaimFlow, please reach out to:

  * **[Your Name / Organization Name]**
  * **Email:** [Your Professional Email Address]
  * **Project Repository:** [Link to your GitHub Repository for ClaimFlow]

-----

## Acknowledgments

  * The Stacks blockchain community for providing a robust and secure platform for decentralized applications.
  * The Clarity language developers for enabling safe and predictable smart contract execution.
  * All future contributors and users who will help shape the evolution of ClaimFlow.

-----
