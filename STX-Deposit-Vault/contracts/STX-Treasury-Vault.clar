;; STX COLLATERALIZED LENDING PROTOCOL SMART CONTRACT
;; Protocol Name: STX Collateralized Lending Protocol
;;
;; Description:
;; A comprehensive decentralized lending platform that enables users to obtain USD-denominated
;; loans by collateralizing their STX token holdings. The protocol ensures financial stability
;; through strict over-collateralization requirements, real-time price monitoring, and
;; automated liquidation mechanisms. Users retain ownership of their STX collateral while
;; accessing liquidity through the protocol's lending services. The system features
;; governance controls, fee management, and comprehensive risk assessment tools to maintain
;; protocol solvency and user protection.
;;
;; Key Features:
;; - STX token collateralization for USD loan generation
;; - 150% minimum collateralization ratio enforcement
;; - Automated liquidation at 130% collateral ratio threshold
;; - Oracle-based real-time price discovery system
;; - Decentralized governance parameter management
;; - Advanced position monitoring and risk assessment
;; - Sustainable fee structure for protocol operations

;; ERROR CODE DEFINITIONS

(define-constant ERR-UNAUTHORIZED-ACCESS u1)
(define-constant ERR-INSUFFICIENT-COLLATERAL-BALANCE u2)
(define-constant ERR-INSUFFICIENT-PROTOCOL-LIQUIDITY u3)
(define-constant ERR-INADEQUATE-COLLATERAL-RATIO u4)
(define-constant ERR-BORROWER-ACCOUNT-NOT-FOUND u5)
(define-constant ERR-BORROWER-ACCOUNT-ALREADY-EXISTS u6)
(define-constant ERR-INVALID-TRANSACTION-AMOUNT u7)
(define-constant ERR-LIQUIDATION-CONDITIONS-NOT-MET u8)
(define-constant ERR-PROTOCOL-FEE-EXCEEDS-MAXIMUM u9)
(define-constant ERR-ZERO-AMOUNT-NOT-ALLOWED u10)

;; PROTOCOL CONFIGURATION CONSTANTS

(define-constant minimum-collateralization-ratio u150)
(define-constant liquidation-threshold-ratio u130)
(define-constant maximum-integer-value u340282366920938463463374607431768211455)
(define-constant maximum-protocol-fee-rate u10)
(define-constant default-origination-fee-rate u1)

;; PROTOCOL STATE VARIABLES

(define-data-var governance-controller principal tx-sender)
(define-data-var total-locked-stx-collateral uint u0)
(define-data-var total-outstanding-loan-debt uint u0)
(define-data-var active-borrower-count uint u0)
(define-data-var current-protocol-fee-rate uint default-origination-fee-rate)

;; DATA STRUCTURE DEFINITIONS

;; Borrower account information storage
(define-map borrower-loan-accounts
  { borrower-address: principal }
  {
    stx-collateral-locked: uint,
    usd-loan-debt-balance: uint,
    last-interaction-block: uint
  }
)

;; Asset price oracle data feeds
(define-map crypto-asset-price-oracle
  { asset-symbol: (string-ascii 32) }
  { price-per-unit-usd-cents: uint }
)

;; READ-ONLY QUERY FUNCTIONS

;; Retrieve borrower account information
(define-read-only (get-borrower-account-details (borrower-address principal))
  (map-get? borrower-loan-accounts { borrower-address: borrower-address })
)

;; Get current STX token market price
(define-read-only (fetch-current-stx-price)
  (default-to u100 
    (get price-per-unit-usd-cents 
      (map-get? crypto-asset-price-oracle { asset-symbol: "STX" })))
)

;; Calculate borrower's current collateralization ratio
(define-read-only (compute-collateralization-ratio (borrower-address principal))
  (let (
    (account-data (get-borrower-account-details borrower-address))
  )
  (match account-data
    borrower-info
    (let (
      (collateral-value-usd (* (get stx-collateral-locked borrower-info) (fetch-current-stx-price)))
      (debt-balance (get usd-loan-debt-balance borrower-info))
    )
    (if (is-eq debt-balance u0)
      u0
      (/ (* collateral-value-usd u100) debt-balance)))
    u0
  ))
)

;; Calculate maximum borrowing capacity
(define-read-only (compute-maximum-borrowing-capacity (borrower-address principal))
  (let (
    (account-data (get-borrower-account-details borrower-address))
  )
  (match account-data
    borrower-info
    (let (
      (total-collateral-value (* (get stx-collateral-locked borrower-info) (fetch-current-stx-price)))
    )
    (/ (* total-collateral-value u100) minimum-collateralization-ratio))
    u0
  ))
)

;; Check if account is eligible for liquidation
(define-read-only (check-liquidation-eligibility (borrower-address principal))
  (let (
    (collateralization-ratio (compute-collateralization-ratio borrower-address))
  )
  (and 
    (> collateralization-ratio u0)
    (< collateralization-ratio liquidation-threshold-ratio)
  ))
)

;; Calculate position health score (percentage above liquidation threshold)
(define-read-only (compute-position-health-score (borrower-address principal))
  (let (
    (collateralization-ratio (compute-collateralization-ratio borrower-address))
  )
  (if (is-eq collateralization-ratio u0)
    u0
    (/ (* collateralization-ratio u100) liquidation-threshold-ratio)
  ))
)

;; ACCOUNT MANAGEMENT FUNCTIONS

;; Create new borrower account
(define-public (create-new-borrower-account)
  (let (
    (new-borrower tx-sender)
  )
  ;; Ensure borrower doesn't already have an account
  (asserts! (is-none (get-borrower-account-details new-borrower)) 
            (err ERR-BORROWER-ACCOUNT-ALREADY-EXISTS))
  
  ;; Initialize new account with zero balances
  (map-set borrower-loan-accounts
    { borrower-address: new-borrower }
    {
      stx-collateral-locked: u0,
      usd-loan-debt-balance: u0,
      last-interaction-block: block-height
    }
  )
  
  ;; Update protocol statistics
  (var-set active-borrower-count 
           (+ (var-get active-borrower-count) u1))
  (ok true))
)

;; Deposit STX tokens as collateral
(define-public (deposit-stx-collateral (stx-deposit-amount uint))
  (let (
    (depositor tx-sender)
    (borrower-account (unwrap! (get-borrower-account-details depositor) 
                               (err ERR-BORROWER-ACCOUNT-NOT-FOUND)))
    (current-collateral (get stx-collateral-locked borrower-account))
  )
  ;; Validate deposit amount
  (asserts! (> stx-deposit-amount u0) (err ERR-ZERO-AMOUNT-NOT-ALLOWED))
  
  ;; Prevent arithmetic overflow
  (asserts! (<= (+ current-collateral stx-deposit-amount) maximum-integer-value) 
            (err ERR-INVALID-TRANSACTION-AMOUNT))
  (asserts! (<= (+ (var-get total-locked-stx-collateral) stx-deposit-amount) maximum-integer-value) 
            (err ERR-INVALID-TRANSACTION-AMOUNT))
  
  ;; Transfer STX to protocol contract
  (try! (stx-transfer? stx-deposit-amount depositor (as-contract tx-sender)))
  
  ;; Update borrower account record
  (map-set borrower-loan-accounts
    { borrower-address: depositor }
    {
      stx-collateral-locked: (+ current-collateral stx-deposit-amount),
      usd-loan-debt-balance: (get usd-loan-debt-balance borrower-account),
      last-interaction-block: block-height
    }
  )
  
  ;; Update protocol totals
  (var-set total-locked-stx-collateral 
           (+ (var-get total-locked-stx-collateral) stx-deposit-amount))
  (ok true))
)

;; Withdraw excess collateral
(define-public (withdraw-excess-collateral (stx-withdrawal-amount uint))
  (let (
    (withdrawer tx-sender)
    (borrower-account (unwrap! (get-borrower-account-details withdrawer) 
                               (err ERR-BORROWER-ACCOUNT-NOT-FOUND)))
    (current-collateral (get stx-collateral-locked borrower-account))
    (current-debt (get usd-loan-debt-balance borrower-account))
  )
    ;; Validate withdrawal parameters
    (asserts! (> stx-withdrawal-amount u0) (err ERR-ZERO-AMOUNT-NOT-ALLOWED))
    (asserts! (<= stx-withdrawal-amount current-collateral) 
              (err ERR-INSUFFICIENT-COLLATERAL-BALANCE))
    
    ;; Calculate post-withdrawal collateralization
    (let (
      (remaining-collateral (- current-collateral stx-withdrawal-amount))
      (remaining-collateral-value (* remaining-collateral (fetch-current-stx-price)))
      (new-collateralization-ratio (if (is-eq current-debt u0)
                                    u0
                                    (/ (* remaining-collateral-value u100) current-debt)))
    )
      ;; Ensure withdrawal maintains required collateralization
      (asserts! (or (is-eq current-debt u0) 
                    (>= new-collateralization-ratio minimum-collateralization-ratio)) 
                (err ERR-INADEQUATE-COLLATERAL-RATIO))
      
      ;; Execute STX withdrawal
      (try! (as-contract (stx-transfer? stx-withdrawal-amount 
                                       (as-contract tx-sender) 
                                       withdrawer)))
      
      ;; Update account record
      (map-set borrower-loan-accounts
        { borrower-address: withdrawer }
        {
          stx-collateral-locked: remaining-collateral,
          usd-loan-debt-balance: current-debt,
          last-interaction-block: block-height
        }
      )
      
      ;; Update protocol totals
      (var-set total-locked-stx-collateral 
               (- (var-get total-locked-stx-collateral) stx-withdrawal-amount))
      (ok true)
    ))
)

;; LOAN OPERATIONS

;; Originate new loan against collateral
(define-public (originate-collateralized-loan (loan-amount-requested uint))
  (let (
    (borrower tx-sender)
    (borrower-account (unwrap! (get-borrower-account-details borrower) 
                               (err ERR-BORROWER-ACCOUNT-NOT-FOUND)))
    (collateral-balance (get stx-collateral-locked borrower-account))
    (current-debt-balance (get usd-loan-debt-balance borrower-account))
  )
  ;; Validate loan request
  (asserts! (> loan-amount-requested u0) (err ERR-ZERO-AMOUNT-NOT-ALLOWED))
  
  ;; Prevent integer overflow
  (asserts! (<= (+ current-debt-balance loan-amount-requested) maximum-integer-value) 
            (err ERR-INVALID-TRANSACTION-AMOUNT))
  
  ;; Verify collateral sufficiency
  (let (
    (total-collateral-value (* collateral-balance (fetch-current-stx-price)))
    (maximum-loan-amount (/ (* total-collateral-value u100) minimum-collateralization-ratio))
    (projected-total-debt (+ current-debt-balance loan-amount-requested))
  )
    ;; Ensure loan maintains collateralization requirements
    (asserts! (<= projected-total-debt maximum-loan-amount) 
              (err ERR-INADEQUATE-COLLATERAL-RATIO))
    
    ;; Verify protocol has sufficient liquidity
    (asserts! (<= loan-amount-requested (stx-get-balance (as-contract tx-sender))) 
              (err ERR-INSUFFICIENT-PROTOCOL-LIQUIDITY))
    
    ;; Disburse loan to borrower
    (try! (as-contract (stx-transfer? loan-amount-requested 
                                     (as-contract tx-sender) 
                                     borrower)))
    
    ;; Update borrower account with new debt
    (map-set borrower-loan-accounts
      { borrower-address: borrower }
      {
        stx-collateral-locked: collateral-balance,
        usd-loan-debt-balance: projected-total-debt,
        last-interaction-block: block-height
      }
    )
    
    ;; Update protocol debt tracking
    (var-set total-outstanding-loan-debt 
             (+ (var-get total-outstanding-loan-debt) loan-amount-requested))
    (ok true)
  ))
)

;; Process loan repayment
(define-public (process-loan-repayment (repayment-amount uint))
  (let (
    (borrower tx-sender)
    (borrower-account (unwrap! (get-borrower-account-details borrower) 
                               (err ERR-BORROWER-ACCOUNT-NOT-FOUND)))
    (current-debt-balance (get usd-loan-debt-balance borrower-account))
  )
  ;; Validate repayment amount
  (asserts! (> repayment-amount u0) (err ERR-ZERO-AMOUNT-NOT-ALLOWED))
  
  ;; Calculate actual payment and fee distribution
  (let (
    (effective-payment-amount (if (> repayment-amount current-debt-balance) 
                              current-debt-balance 
                              repayment-amount))
    (protocol-fee-amount (/ (* effective-payment-amount (var-get current-protocol-fee-rate)) u100))
    (principal-payment-amount (- effective-payment-amount protocol-fee-amount))
  )
    ;; Process payment from borrower
    (try! (stx-transfer? effective-payment-amount borrower (as-contract tx-sender)))
    
    ;; Update borrower account with reduced debt
    (map-set borrower-loan-accounts
      { borrower-address: borrower }
      {
        stx-collateral-locked: (get stx-collateral-locked borrower-account),
        usd-loan-debt-balance: (- current-debt-balance principal-payment-amount),
        last-interaction-block: block-height
      }
    )
    
    ;; Update protocol debt tracking
    (var-set total-outstanding-loan-debt 
             (- (var-get total-outstanding-loan-debt) principal-payment-amount))
    (ok true)
  ))
)

;; LIQUIDATION SYSTEM

;; Execute liquidation of undercollateralized position
(define-public (execute-position-liquidation (target-borrower-address principal))
  (let (
    (liquidator tx-sender)
  )
  ;; Verify liquidation eligibility
  (asserts! (check-liquidation-eligibility target-borrower-address) 
            (err ERR-LIQUIDATION-CONDITIONS-NOT-MET))
  
  ;; Retrieve account data for liquidation
  (let (
    (target-account (unwrap! (get-borrower-account-details target-borrower-address) 
                             (err ERR-BORROWER-ACCOUNT-NOT-FOUND)))
    (collateral-to-seize (get stx-collateral-locked target-account))
    (debt-to-cover (get usd-loan-debt-balance target-account))
  )
    ;; Validate liquidation targets
    (asserts! (> collateral-to-seize u0) (err ERR-INVALID-TRANSACTION-AMOUNT))
    (asserts! (> debt-to-cover u0) (err ERR-INVALID-TRANSACTION-AMOUNT))
    
    ;; Confirm liquidation conditions with current market price
    (let (
      (current-collateral-value (* collateral-to-seize (fetch-current-stx-price)))
      (actual-collateralization-ratio (/ (* current-collateral-value u100) debt-to-cover))
    )
      ;; Verify position is below liquidation threshold
      (asserts! (< actual-collateralization-ratio liquidation-threshold-ratio) 
                (err ERR-LIQUIDATION-CONDITIONS-NOT-MET))
      
      ;; Liquidator pays off borrower's debt
      (try! (stx-transfer? debt-to-cover liquidator (as-contract tx-sender)))
      
      ;; Liquidator receives collateral assets
      (try! (as-contract (stx-transfer? collateral-to-seize 
                                       (as-contract tx-sender) 
                                       liquidator)))
      
      ;; Clear liquidated account
      (map-set borrower-loan-accounts
        { borrower-address: target-borrower-address }
        {
          stx-collateral-locked: u0,
          usd-loan-debt-balance: u0,
          last-interaction-block: block-height
        }
      )
      
      ;; Update protocol accounting
      (var-set total-locked-stx-collateral 
               (- (var-get total-locked-stx-collateral) collateral-to-seize))
      (var-set total-outstanding-loan-debt 
               (- (var-get total-outstanding-loan-debt) debt-to-cover))
      (ok true)
    )))
)

;; GOVERNANCE FUNCTIONS

;; Update asset price in oracle system
(define-public (update-asset-price-oracle (asset-symbol (string-ascii 32)) (new-price-usd-cents uint))
  (begin
    ;; Verify governance permissions
    (asserts! (is-eq tx-sender (var-get governance-controller)) 
              (err ERR-UNAUTHORIZED-ACCESS))
    
    ;; Validate price update parameters
    (asserts! (> new-price-usd-cents u0) (err ERR-ZERO-AMOUNT-NOT-ALLOWED))
    (asserts! (> (len asset-symbol) u0) (err ERR-INVALID-TRANSACTION-AMOUNT))
    
    ;; Update price oracle feed
    (map-set crypto-asset-price-oracle 
      { asset-symbol: asset-symbol } 
      { price-per-unit-usd-cents: new-price-usd-cents }
    )
    (ok true)
  )
)

;; Adjust protocol fee structure
(define-public (adjust-protocol-fee-structure (new-fee-rate uint))
  (begin
    ;; Verify governance permissions
    (asserts! (is-eq tx-sender (var-get governance-controller)) 
              (err ERR-UNAUTHORIZED-ACCESS))
    
    ;; Enforce maximum fee constraints
    (asserts! (<= new-fee-rate maximum-protocol-fee-rate) 
              (err ERR-PROTOCOL-FEE-EXCEEDS-MAXIMUM))
    
    ;; Update fee structure
    (var-set current-protocol-fee-rate new-fee-rate)
    (ok true))
)

;; Transfer governance control
(define-public (transfer-governance-control (new-governance-controller principal))
  (begin
    ;; Verify current governance authority
    (asserts! (is-eq tx-sender (var-get governance-controller)) 
              (err ERR-UNAUTHORIZED-ACCESS))
    
    ;; Prevent transfer to burn address
    (asserts! (not (is-eq new-governance-controller 'SP000000000000000000002Q6VF78)) 
              (err ERR-UNAUTHORIZED-ACCESS))
    
    ;; Execute governance transfer
    (var-set governance-controller new-governance-controller)
    (ok true))
)

;; PROTOCOL ANALYTICS AND REPORTING

;; Generate comprehensive protocol statistics
(define-read-only (get-protocol-statistics)
  {
    total-stx-collateral-locked: (var-get total-locked-stx-collateral),
    total-loan-debt-outstanding: (var-get total-outstanding-loan-debt),
    number-of-active-borrowers: (var-get active-borrower-count),
    current-origination-fee-rate: (var-get current-protocol-fee-rate),
    protocol-governance-controller: (var-get governance-controller),
    protocol-capital-efficiency: (calculate-protocol-capital-efficiency),
    current-stx-market-price: (fetch-current-stx-price)
  }
)

;; Calculate protocol capital utilization efficiency
(define-read-only (calculate-protocol-capital-efficiency)
  (let (
    (total-collateral-value (* (var-get total-locked-stx-collateral) (fetch-current-stx-price)))
    (total-debt-issued (var-get total-outstanding-loan-debt))
  )
  (if (is-eq total-collateral-value u0)
    u0
    (/ (* total-debt-issued u100) total-collateral-value)
  ))
)

;; Generate comprehensive borrower position report
(define-read-only (get-borrower-position-report (borrower-address principal))
  (let (
    (account-details (get-borrower-account-details borrower-address))
  )
  (match account-details
    borrower-data
    {
      stx-collateral-amount: (get stx-collateral-locked borrower-data),
      loan-debt-balance: (get usd-loan-debt-balance borrower-data),
      last-activity-block: (get last-interaction-block borrower-data),
      position-health-percentage: (compute-position-health-score borrower-address),
      current-collateralization-ratio: (compute-collateralization-ratio borrower-address),
      maximum-additional-borrowing: (compute-maximum-borrowing-capacity borrower-address),
      at-risk-of-liquidation: (check-liquidation-eligibility borrower-address)
    }
    {
      stx-collateral-amount: u0,
      loan-debt-balance: u0,
      last-activity-block: u0,
      position-health-percentage: u0,
      current-collateralization-ratio: u0,
      maximum-additional-borrowing: u0,
      at-risk-of-liquidation: false
    }
  ))
)