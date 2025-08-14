;; Digital Asset Vault System
;; Vault and treasury-focused design

;; Vault Administration
(define-constant vault-keeper tx-sender)
(define-constant vault-err-forbidden (err u500))
(define-constant vault-err-empty-vault (err u501))
(define-constant vault-err-zero-deposit (err u502))
(define-constant vault-err-price-slippage (err u503))
(define-constant vault-err-asset-mismatch (err u504))
(define-constant vault-err-operation-failed (err u505))
(define-constant vault-err-vault-exists (err u506))
(define-constant vault-err-vault-not-ready (err u507))

;; Asset Vault Holdings
(define-data-var vault-stx-holdings uint u0)
(define-data-var vault-token-holdings uint u0)
(define-data-var vault-certificates-issued uint u0)
(define-data-var vault-operational bool false)

;; Paired Asset Address
(define-data-var vault-asset-address principal .token)

;; Certificate Ownership Registry
(define-map certificate-registry principal uint)

;; Vault Transaction History
(define-map vault-transactions 
  { transaction-ref: uint }
  { 
    account-holder: principal,
    stx-deposited: uint,
    tokens-released: uint,
    stx-released: uint,
    tokens-deposited: uint,
    transaction-height: uint
  }
)

(define-data-var transaction-reference uint u0)

;; Digital Asset Interface
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

;; Utility Functions

;; Select minimum value
(define-private (minimum-value (x uint) (y uint))
  (if (< x y) x y))

;; Vault Status Queries

(define-read-only (check-vault-holdings)
  {
    stx-holdings: (var-get vault-stx-holdings),
    token-holdings: (var-get vault-token-holdings)
  }
)

(define-read-only (check-certificate-balance (holder principal))
  (default-to u0 (map-get? certificate-registry holder))
)

(define-read-only (check-total-certificates)
  (var-get vault-certificates-issued)
)

(define-read-only (check-vault-status)
  (var-get vault-operational)
)

(define-read-only (check-vault-asset)
  (var-get vault-asset-address)
)

;; Vault Pricing Engine (0.3% transaction fee)
(define-read-only (calculate-vault-output (deposit-amount uint) (deposit-vault uint) (withdrawal-vault uint))
  (if (or (is-eq deposit-amount u0) (is-eq deposit-vault u0) (is-eq withdrawal-vault u0))
    u0
    (let (
      (fee-adjusted-deposit (* deposit-amount u997))
      (output-numerator (* fee-adjusted-deposit withdrawal-vault))
      (output-denominator (+ (* deposit-vault u1000) fee-adjusted-deposit))
    )
    (/ output-numerator output-denominator)))
)

(define-read-only (calculate-vault-input (withdrawal-amount uint) (deposit-vault uint) (withdrawal-vault uint))
  (if (or (is-eq withdrawal-amount u0) (is-eq deposit-vault u0) (is-eq withdrawal-vault u0))
    u0
    (let (
      (input-numerator (* (* deposit-vault withdrawal-amount) u1000))
      (input-denominator (* (- withdrawal-vault withdrawal-amount) u997))
    )
    (+ (/ input-numerator input-denominator) u1)))
)

(define-read-only (calculate-certificate-ratio (asset-amount uint) (asset-vault uint) (paired-vault uint))
  (if (is-eq asset-vault u0)
    u0
    (/ (* asset-amount paired-vault) asset-vault))
)

;; Vault Management Operations

(define-public (establish-vault (asset-interface <digital-asset>) (stx-initial uint) (token-initial uint))
  (let (
    (initial-certificates (minimum-value stx-initial token-initial))
  )
    (asserts! (not (var-get vault-operational)) vault-err-vault-exists)
    (asserts! (> stx-initial u0) vault-err-zero-deposit)
    (asserts! (> token-initial u0) vault-err-zero-deposit)
    (asserts! (> initial-certificates u0) vault-err-empty-vault)
    
    (var-set vault-asset-address (contract-of asset-interface))
    
    (try! (contract-call? asset-interface transfer token-initial tx-sender (as-contract tx-sender) none))
    
    (var-set vault-stx-holdings stx-initial)
    (var-set vault-token-holdings token-initial)
    (var-set vault-certificates-issued initial-certificates)
    (var-set vault-operational true)
    
    (map-set certificate-registry tx-sender initial-certificates)
    
    (ok initial-certificates)
  )
)

(define-public (expand-vault (asset-interface <digital-asset>) (stx-deposit uint) (token-deposit uint) (min-certificates uint))
  (let (
    (current-stx-vault (var-get vault-stx-holdings))
    (current-token-vault (var-get vault-token-holdings))
    (current-certificate-supply (var-get vault-certificates-issued))
    (new-certificates (minimum-value 
                       (/ (* stx-deposit current-certificate-supply) current-stx-vault)
                       (/ (* token-deposit current-certificate-supply) current-token-vault)))
    (current-certificate-balance (check-certificate-balance tx-sender))
  )
    (asserts! (var-get vault-operational) vault-err-vault-not-ready)
    (asserts! (is-eq (contract-of asset-interface) (var-get vault-asset-address)) vault-err-asset-mismatch)
    (asserts! (> stx-deposit u0) vault-err-zero-deposit)
    (asserts! (> token-deposit u0) vault-err-zero-deposit)
    (asserts! (>= new-certificates min-certificates) vault-err-price-slippage)
    
    (try! (contract-call? asset-interface transfer token-deposit tx-sender (as-contract tx-sender) none))
    
    (var-set vault-stx-holdings (+ current-stx-vault stx-deposit))
    (var-set vault-token-holdings (+ current-token-vault token-deposit))
    (var-set vault-certificates-issued (+ current-certificate-supply new-certificates))
    
    (map-set certificate-registry tx-sender (+ current-certificate-balance new-certificates))
    
    (ok new-certificates)
  )
)

(define-public (redeem-certificates (asset-interface <digital-asset>) (certificate-amount uint) (min-stx uint) (min-tokens uint))
  (let (
    (current-stx-vault (var-get vault-stx-holdings))
    (current-token-vault (var-get vault-token-holdings))
    (current-certificate-supply (var-get vault-certificates-issued))
    (current-certificate-balance (check-certificate-balance tx-sender))
    (stx-redemption (/ (* certificate-amount current-stx-vault) current-certificate-supply))
    (token-redemption (/ (* certificate-amount current-token-vault) current-certificate-supply))
  )
    (asserts! (var-get vault-operational) vault-err-vault-not-ready)
    (asserts! (is-eq (contract-of asset-interface) (var-get vault-asset-address)) vault-err-asset-mismatch)
    (asserts! (> certificate-amount u0) vault-err-zero-deposit)
    (asserts! (>= current-certificate-balance certificate-amount) vault-err-empty-vault)
    (asserts! (>= stx-redemption min-stx) vault-err-price-slippage)
    (asserts! (>= token-redemption min-tokens) vault-err-price-slippage)
    
    (var-set vault-stx-holdings (- current-stx-vault stx-redemption))
    (var-set vault-token-holdings (- current-token-vault token-redemption))
    (var-set vault-certificates-issued (- current-certificate-supply certificate-amount))
    
    (map-set certificate-registry tx-sender (- current-certificate-balance certificate-amount))
    
    (try! (as-contract (stx-transfer? stx-redemption tx-sender tx-sender)))
    (try! (as-contract (contract-call? asset-interface transfer token-redemption tx-sender tx-sender none)))
    
    (ok { stx: stx-redemption, tokens: token-redemption })
  )
)

(define-public (vault-exchange-stx-to-tokens (asset-interface <digital-asset>) (stx-amount uint) (min-token-output uint))
  (let (
    (current-stx-vault (var-get vault-stx-holdings))
    (current-token-vault (var-get vault-token-holdings))
    (token-output (calculate-vault-output stx-amount current-stx-vault current-token-vault))
    (tx-ref (var-get transaction-reference))
  )
    (asserts! (var-get vault-operational) vault-err-vault-not-ready)
    (asserts! (is-eq (contract-of asset-interface) (var-get vault-asset-address)) vault-err-asset-mismatch)
    (asserts! (> stx-amount u0) vault-err-zero-deposit)
    (asserts! (>= token-output min-token-output) vault-err-price-slippage)
    (asserts! (< token-output current-token-vault) vault-err-empty-vault)
    
    (var-set vault-stx-holdings (+ current-stx-vault stx-amount))
    (var-set vault-token-holdings (- current-token-vault token-output))
    
    (try! (as-contract (contract-call? asset-interface transfer token-output tx-sender tx-sender none)))
    
    (map-set vault-transactions 
      { transaction-ref: tx-ref }
      { 
        account-holder: tx-sender,
        stx-deposited: stx-amount,
        tokens-released: token-output,
        stx-released: u0,
        tokens-deposited: u0,
        transaction-height: block-height
      }
    )
    (var-set transaction-reference (+ tx-ref u1))
    
    (ok token-output)
  )
)

(define-public (vault-exchange-tokens-to-stx (asset-interface <digital-asset>) (token-amount uint) (min-stx-output uint))
  (let (
    (current-stx-vault (var-get vault-stx-holdings))
    (current-token-vault (var-get vault-token-holdings))
    (stx-output (calculate-vault-output token-amount current-token-vault current-stx-vault))
    (tx-ref (var-get transaction-reference))
  )
    (asserts! (var-get vault-operational) vault-err-vault-not-ready)
    (asserts! (is-eq (contract-of asset-interface) (var-get vault-asset-address)) vault-err-asset-mismatch)
    (asserts! (> token-amount u0) vault-err-zero-deposit)
    (asserts! (>= stx-output min-stx-output) vault-err-price-slippage)
    (asserts! (< stx-output current-stx-vault) vault-err-empty-vault)
    
    (try! (contract-call? asset-interface transfer token-amount tx-sender (as-contract tx-sender) none))
    
    (var-set vault-stx-holdings (- current-stx-vault stx-output))
    (var-set vault-token-holdings (+ current-token-vault token-amount))
    
    (try! (as-contract (stx-transfer? stx-output tx-sender tx-sender)))
    
    (map-set vault-transactions 
      { transaction-ref: tx-ref }
      { 
        account-holder: tx-sender,
        stx-deposited: u0,
        tokens-released: u0,
        stx-released: stx-output,
        tokens-deposited: token-amount,
        transaction-height: block-height
      }
    )
    (var-set transaction-reference (+ tx-ref u1))
    
    (ok stx-output)
  )
)