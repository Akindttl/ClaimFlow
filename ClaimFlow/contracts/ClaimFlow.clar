;; Automated Insurance Claims Settlement Contract
;; This contract manages insurance policies and automates claim settlements
;; based on predefined conditions and oracle data verification

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-POLICY-NOT-FOUND (err u101))
(define-constant ERR-CLAIM-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-POLICY-EXPIRED (err u104))
(define-constant ERR-CLAIM-ALREADY-PROCESSED (err u105))
(define-constant ERR-INVALID-AMOUNT (err u106))
(define-constant ERR-POLICY-INACTIVE (err u107))
(define-constant MIN-PREMIUM u1000000) ;; 1 STX minimum premium
(define-constant MAX-COVERAGE u100000000) ;; 100 STX maximum coverage

;; Data maps and vars
(define-map policies
  { policy-id: uint }
  {
    holder: principal,
    premium: uint,
    coverage-amount: uint,
    policy-type: (string-ascii 20),
    start-block: uint,
    end-block: uint,
    active: bool
  }
)

(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    amount: uint,
    description: (string-ascii 200),
    submitted-block: uint,
    status: (string-ascii 20), ;; "pending", "approved", "rejected", "paid"
    oracle-verified: bool
  }
)

(define-map policy-balances
  { policy-id: uint }
  { balance: uint }
)

(define-data-var next-policy-id uint u1)
(define-data-var next-claim-id uint u1)
(define-data-var total-reserves uint u0)

;; Private functions
(define-private (is-policy-valid (policy-id uint))
  (match (map-get? policies { policy-id: policy-id })
    policy (and 
             (get active policy)
             (>= block-height (get start-block policy))
             (<= block-height (get end-block policy)))
    false
  )
)

(define-private (calculate-settlement-amount (claim-amount uint) (coverage uint))
  (if (<= claim-amount coverage)
    claim-amount
    coverage
  )
)

(define-private (update-reserves (amount uint) (operation (string-ascii 10)))
  (if (is-eq operation "add")
    (var-set total-reserves (+ (var-get total-reserves) amount))
    (var-set total-reserves (- (var-get total-reserves) amount))
  )
)

;; Public functions
(define-public (create-policy 
  (premium uint) 
  (coverage-amount uint) 
  (policy-type (string-ascii 20))
  (duration-blocks uint))
  (let (
    (policy-id (var-get next-policy-id))
    (end-block (+ block-height duration-blocks))
  )
    (asserts! (>= premium MIN-PREMIUM) ERR-INVALID-AMOUNT)
    (asserts! (<= coverage-amount MAX-COVERAGE) ERR-INVALID-AMOUNT)
    (asserts! (> duration-blocks u0) ERR-INVALID-AMOUNT)
    
    (try! (stx-transfer? premium tx-sender (as-contract tx-sender)))
    
    (map-set policies
      { policy-id: policy-id }
      {
        holder: tx-sender,
        premium: premium,
        coverage-amount: coverage-amount,
        policy-type: policy-type,
        start-block: block-height,
        end-block: end-block,
        active: true
      }
    )
    
    (map-set policy-balances
      { policy-id: policy-id }
      { balance: premium }
    )
    
    (update-reserves premium "add")
    (var-set next-policy-id (+ policy-id u1))
    (ok policy-id)
  )
)

(define-public (submit-claim 
  (policy-id uint) 
  (amount uint) 
  (description (string-ascii 200)))
  (let (
    (claim-id (var-get next-claim-id))
    (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR-POLICY-NOT-FOUND))
  )
    (asserts! (is-policy-valid policy-id) ERR-POLICY-EXPIRED)
    (asserts! (is-eq (get holder policy) tx-sender) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (map-set claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        claimant: tx-sender,
        amount: amount,
        description: description,
        submitted-block: block-height,
        status: "pending",
        oracle-verified: false
      }
    )
    
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

(define-public (verify-claim-oracle (claim-id uint) (verified bool))
  (let (
    (claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status claim) "pending") ERR-CLAIM-ALREADY-PROCESSED)
    
    (map-set claims
      { claim-id: claim-id }
      (merge claim { 
        oracle-verified: verified,
        status: (if verified "approved" "rejected")
      })
    )
    (ok verified)
  )
)

(define-public (process-automated-settlement (claim-id uint))
  (let (
    (claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
    (policy (unwrap! (map-get? policies { policy-id: (get policy-id claim) }) ERR-POLICY-NOT-FOUND))
    (policy-balance (unwrap! (map-get? policy-balances { policy-id: (get policy-id claim) }) ERR-INSUFFICIENT-FUNDS))
    (settlement-amount (calculate-settlement-amount (get amount claim) (get coverage-amount policy)))
  )
    ;; Verify claim is approved and oracle verified
    (asserts! (is-eq (get status claim) "approved") ERR-CLAIM-ALREADY-PROCESSED)
    (asserts! (get oracle-verified claim) ERR-UNAUTHORIZED)
    (asserts! (>= (get balance policy-balance) settlement-amount) ERR-INSUFFICIENT-FUNDS)
    
    ;; Process payment
    (try! (as-contract (stx-transfer? settlement-amount tx-sender (get claimant claim))))
    
    ;; Update policy balance
    (map-set policy-balances
      { policy-id: (get policy-id claim) }
      { balance: (- (get balance policy-balance) settlement-amount) }
    )
    
    ;; Update claim status
    (map-set claims
      { claim-id: claim-id }
      (merge claim { status: "paid" })
    )
    
    ;; Update total reserves
    (update-reserves settlement-amount "subtract")
    
    ;; Auto-deactivate policy if balance is depleted
    (if (<= (- (get balance policy-balance) settlement-amount) u0)
      (map-set policies
        { policy-id: (get policy-id claim) }
        (merge policy { active: false })
      )
      true
    )
    
    (ok settlement-amount)
  )
)

;; Advanced claim processing with risk assessment and fraud detection
(define-public (process-claim-with-risk-assessment 
  (claim-id uint) 
  (risk-score uint) 
  (fraud-indicators (list 5 (string-ascii 50)))
  (weather-data-hash (buff 32))
  (damage-assessment-score uint))
  (let (
    (claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
    (policy (unwrap! (map-get? policies { policy-id: (get policy-id claim) }) ERR-POLICY-NOT-FOUND))
    (policy-balance (unwrap! (map-get? policy-balances { policy-id: (get policy-id claim) }) ERR-INSUFFICIENT-FUNDS))
    (base-settlement (calculate-settlement-amount (get amount claim) (get coverage-amount policy)))
    (risk-multiplier (if (<= risk-score u30) u100 (if (<= risk-score u70) u80 u60)))
    (fraud-penalty (if (> (len fraud-indicators) u2) u20 u0))
    (damage-multiplier (if (>= damage-assessment-score u80) u100 (if (>= damage-assessment-score u50) u75 u50)))
    (final-settlement (/ (* (* base-settlement risk-multiplier) (- damage-multiplier fraud-penalty)) u10000))
  )
    ;; Comprehensive validation checks
    (asserts! (is-eq (get status claim) "pending") ERR-CLAIM-ALREADY-PROCESSED)
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= risk-score u100) ERR-INVALID-AMOUNT)
    (asserts! (<= damage-assessment-score u100) ERR-INVALID-AMOUNT)
    (asserts! (>= (get balance policy-balance) final-settlement) ERR-INSUFFICIENT-FUNDS)
    
    ;; Auto-reject high-risk claims with multiple fraud indicators
    (if (and (> risk-score u80) (> (len fraud-indicators) u3))
      (begin
        (map-set claims { claim-id: claim-id } (merge claim { status: "rejected" }))
        (ok u0)
      )
      (begin
        ;; Process approved claim with calculated settlement
        (try! (as-contract (stx-transfer? final-settlement tx-sender (get claimant claim))))
        
        ;; Update all relevant data structures
        (map-set policy-balances
          { policy-id: (get policy-id claim) }
          { balance: (- (get balance policy-balance) final-settlement) }
        )
        
        (map-set claims
          { claim-id: claim-id }
          (merge claim { 
            status: "paid",
            oracle-verified: true
          })
        )
        
        (update-reserves final-settlement "subtract")
        (ok final-settlement)
      )
    )
  )
)


