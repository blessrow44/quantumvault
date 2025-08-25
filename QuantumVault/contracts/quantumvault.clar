;; Quantum Vault - Advanced Time-Locked Savings Protocol with Dynamic Yields
;; Features: Time-locked vaults, dynamic APY, social recovery, automated compounding

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-vault-locked (err u102))
(define-constant err-vault-not-found (err u103))
(define-constant err-invalid-duration (err u104))
(define-constant err-max-vaults (err u105))
(define-constant err-recovery-active (err u106))
(define-constant err-invalid-guardian (err u107))
(define-constant err-already-guardian (err u108))
(define-constant err-not-guardian (err u109))
(define-constant err-too-early (err u110))
(define-constant err-already-claimed (err u111))
(define-constant err-invalid-amount (err u112))

;; Protocol Parameters
(define-constant min-lock-duration u144) ;; ~1 day minimum
(define-constant max-lock-duration u52560) ;; ~365 days maximum
(define-constant min-deposit u1000000) ;; 1 STX minimum
(define-constant max-vaults-per-user u10)
(define-constant base-apy u500) ;; 5% base APY (in basis points)
(define-constant max-apy u2000) ;; 20% max APY
(define-constant early-withdrawal-penalty u1000) ;; 10% penalty
(define-constant protocol-fee u200) ;; 2% protocol fee
(define-constant guardian-threshold u2) ;; 2 of 3 guardians needed

;; Data Variables
(define-data-var vault-counter uint u0)
(define-data-var total-locked uint u0)
(define-data-var total-rewards-paid uint u0)
(define-data-var protocol-treasury uint u0)
(define-data-var emergency-mode bool false)
(define-data-var global-apy-multiplier uint u10000) ;; basis points (10000 = 1x)

;; Data Maps
(define-map vaults
    uint ;; vault-id
    {
        owner: principal,
        amount: uint,
        locked-until: uint,
        created-at: uint,
        apy-rate: uint,
        rewards-claimed: uint,
        is-active: bool,
        auto-compound: bool,
        guardian-recovery: bool
    })

(define-map user-vaults
    principal
    (list 10 uint)) ;; List of vault IDs

(define-map vault-guardians
    uint ;; vault-id
    {
        guardian1: (optional principal),
        guardian2: (optional principal),
        guardian3: (optional principal),
        recovery-initiated: uint,
        recovery-executor: (optional principal),
        votes: uint
    })

(define-map guardian-votes
    { vault-id: uint, guardian: principal }
    { voted: bool, vote-block: uint })

(define-map vault-history
    { vault-id: uint, action-id: uint }
    {
        action: (string-ascii 20),
        amount: uint,
        block: uint
    })

(define-map user-stats
    principal
    {
        total-deposited: uint,
        total-withdrawn: uint,
        total-rewards: uint,
        vault-count: uint,
        first-deposit: uint
    })

(define-map yield-tiers
    uint ;; tier level (1-5)
    {
        min-amount: uint,
        min-duration: uint,
        apy-bonus: uint ;; basis points added to base
    })

;; Initialize yield tiers
(map-set yield-tiers u1 { min-amount: u1000000, min-duration: u144, apy-bonus: u0 })
(map-set yield-tiers u2 { min-amount: u10000000, min-duration: u1008, apy-bonus: u200 })
(map-set yield-tiers u3 { min-amount: u50000000, min-duration: u4320, apy-bonus: u500 })
(map-set yield-tiers u4 { min-amount: u100000000, min-duration: u13140, apy-bonus: u800 })
(map-set yield-tiers u5 { min-amount: u500000000, min-duration: u26280, apy-bonus: u1200 })

;; Private Functions
(define-private (calculate-apy (amount uint) (duration uint))
    (let ((tier1 (default-to { min-amount: u0, min-duration: u0, apy-bonus: u0 } 
                             (map-get? yield-tiers u1)))
          (tier2 (default-to { min-amount: u0, min-duration: u0, apy-bonus: u0 } 
                             (map-get? yield-tiers u2)))
          (tier3 (default-to { min-amount: u0, min-duration: u0, apy-bonus: u0 } 
                             (map-get? yield-tiers u3)))
          (tier4 (default-to { min-amount: u0, min-duration: u0, apy-bonus: u0 } 
                             (map-get? yield-tiers u4)))
          (tier5 (default-to { min-amount: u0, min-duration: u0, apy-bonus: u0 } 
                             (map-get? yield-tiers u5))))
        (if (and (>= amount (get min-amount tier5)) (>= duration (get min-duration tier5)))
            (+ base-apy (get apy-bonus tier5))
            (if (and (>= amount (get min-amount tier4)) (>= duration (get min-duration tier4)))
                (+ base-apy (get apy-bonus tier4))
                (if (and (>= amount (get min-amount tier3)) (>= duration (get min-duration tier3)))
                    (+ base-apy (get apy-bonus tier3))
                    (if (and (>= amount (get min-amount tier2)) (>= duration (get min-duration tier2)))
                        (+ base-apy (get apy-bonus tier2))
                        base-apy))))))

(define-private (calculate-rewards (principal-amount uint) (apy uint) (blocks uint))
    (let ((annual-blocks u52560) ;; ~365 days in blocks
          (rate-adjusted (/ (* apy (var-get global-apy-multiplier)) u10000)))
        (/ (* (* principal-amount rate-adjusted) blocks) (* annual-blocks u10000))))

(define-private (add-vault-to-user (user principal) (vault-id uint))
    (let ((current-vaults (default-to (list) (map-get? user-vaults user))))
        (map-set user-vaults user 
                (unwrap-panic (as-max-len? (append current-vaults vault-id) u10)))))

(define-private (update-user-stats (user principal) (deposit-amount uint) (reward-amount uint))
    (let ((current-stats (default-to 
                         { total-deposited: u0, total-withdrawn: u0, total-rewards: u0, 
                           vault-count: u0, first-deposit: burn-block-height }
                         (map-get? user-stats user))))
        (map-set user-stats user
                (merge current-stats {
                    total-deposited: (+ (get total-deposited current-stats) deposit-amount),
                    total-rewards: (+ (get total-rewards current-stats) reward-amount),
                    vault-count: (+ (get vault-count current-stats) u1)
                }))))

(define-private (record-history (vault-id uint) (action-id uint) (action (string-ascii 20)) (amount uint))
    (map-set vault-history 
            { vault-id: vault-id, action-id: action-id }
            { action: action, amount: amount, block: burn-block-height }))

;; Read-only Functions
(define-read-only (get-vault (vault-id uint))
    (ok (map-get? vaults vault-id)))

(define-read-only (get-user-vaults (user principal))
    (ok (default-to (list) (map-get? user-vaults user))))

(define-read-only (get-vault-guardians (vault-id uint))
    (ok (map-get? vault-guardians vault-id)))

(define-read-only (get-user-stats (user principal))
    (ok (map-get? user-stats user)))

(define-read-only (calculate-current-rewards (vault-id uint))
    (match (map-get? vaults vault-id)
        vault (let ((blocks-locked (- burn-block-height (get created-at vault)))
                    (rewards (calculate-rewards (get amount vault) (get apy-rate vault) blocks-locked)))
                (ok rewards))
        (err err-vault-not-found)))

(define-read-only (get-total-locked)
    (ok (var-get total-locked)))

(define-read-only (get-protocol-stats)
    (ok {
        total-locked: (var-get total-locked),
        total-rewards: (var-get total-rewards-paid),
        treasury: (var-get protocol-treasury),
        vault-count: (var-get vault-counter)
    }))

(define-read-only (estimate-rewards (amount uint) (duration uint))
    (let ((apy (calculate-apy amount duration)))
        (ok (calculate-rewards amount apy duration))))

;; Public Functions
(define-public (create-vault (amount uint) (lock-duration uint) (auto-compound bool))
    (let ((vault-id (+ (var-get vault-counter) u1))
          (user-vault-list (default-to (list) (map-get? user-vaults tx-sender)))
          (apy-rate (calculate-apy amount lock-duration))
          (unlock-block (+ burn-block-height lock-duration)))
        
        ;; Validations
        (asserts! (not (var-get emergency-mode)) err-unauthorized)
        (asserts! (>= amount min-deposit) err-invalid-amount)
        (asserts! (>= lock-duration min-lock-duration) err-invalid-duration)
        (asserts! (<= lock-duration max-lock-duration) err-invalid-duration)
        (asserts! (< (len user-vault-list) max-vaults-per-user) err-max-vaults)
        
        ;; Transfer STX to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Create vault
        (map-set vaults vault-id {
            owner: tx-sender,
            amount: amount,
            locked-until: unlock-block,
            created-at: burn-block-height,
            apy-rate: apy-rate,
            rewards-claimed: u0,
            is-active: true,
            auto-compound: auto-compound,
            guardian-recovery: false
        })
        
        ;; Initialize guardians
        (map-set vault-guardians vault-id {
            guardian1: none,
            guardian2: none,
            guardian3: none,
            recovery-initiated: u0,
            recovery-executor: none,
            votes: u0
        })
        
        ;; Update user vaults list
        (add-vault-to-user tx-sender vault-id)
        
        ;; Update stats
        (update-user-stats tx-sender amount u0)
        (record-history vault-id u0 "created" amount)
        
        ;; Update global counters
        (var-set vault-counter vault-id)
        (var-set total-locked (+ (var-get total-locked) amount))
        
        (ok vault-id)))

(define-public (add-guardian (vault-id uint) (guardian principal))
    (let ((vault (unwrap! (map-get? vaults vault-id) err-vault-not-found))
          (guardians (unwrap! (map-get? vault-guardians vault-id) err-vault-not-found)))
        
        ;; Validations
        (asserts! (is-eq tx-sender (get owner vault)) err-unauthorized)
        (asserts! (not (is-eq guardian tx-sender)) err-invalid-guardian)
        
        ;; Add guardian to first available slot
        (let ((updated-guardians 
               (if (is-none (get guardian1 guardians))
                   (merge guardians { guardian1: (some guardian) })
                   (if (is-none (get guardian2 guardians))
                       (merge guardians { guardian2: (some guardian) })
                       (if (is-none (get guardian3 guardians))
                           (merge guardians { guardian3: (some guardian) })
                           guardians)))))
            
            (map-set vault-guardians vault-id updated-guardians)
            (map-set vaults vault-id (merge vault { guardian-recovery: true }))
            
            (ok true))))

(define-public (initiate-recovery (vault-id uint))
    (let ((vault (unwrap! (map-get? vaults vault-id) err-vault-not-found))
          (guardians (unwrap! (map-get? vault-guardians vault-id) err-vault-not-found)))
        
        ;; Check if sender is a guardian
        (asserts! (or (is-eq (some tx-sender) (get guardian1 guardians))
                     (is-eq (some tx-sender) (get guardian2 guardians))
                     (is-eq (some tx-sender) (get guardian3 guardians)))
                 err-not-guardian)
        (asserts! (is-eq (get recovery-initiated guardians) u0) err-recovery-active)
        
        ;; Initiate recovery
        (map-set vault-guardians vault-id
                (merge guardians {
                    recovery-initiated: burn-block-height,
                    recovery-executor: (some tx-sender),
                    votes: u1
                }))
        
        ;; Record guardian vote
        (map-set guardian-votes 
                { vault-id: vault-id, guardian: tx-sender }
                { voted: true, vote-block: burn-block-height })
        
        (record-history vault-id u1 "recovery-initiated" u0)
        
        (ok true)))

(define-public (vote-recovery (vault-id uint))
    (let ((vault (unwrap! (map-get? vaults vault-id) err-vault-not-found))
          (guardians (unwrap! (map-get? vault-guardians vault-id) err-vault-not-found))
          (existing-vote (map-get? guardian-votes { vault-id: vault-id, guardian: tx-sender })))
        
        ;; Validations
        (asserts! (or (is-eq (some tx-sender) (get guardian1 guardians))
                     (is-eq (some tx-sender) (get guardian2 guardians))
                     (is-eq (some tx-sender) (get guardian3 guardians)))
                 err-not-guardian)
        (asserts! (> (get recovery-initiated guardians) u0) err-recovery-active)
        (asserts! (is-none existing-vote) err-unauthorized)
        
        ;; Record vote
        (map-set guardian-votes 
                { vault-id: vault-id, guardian: tx-sender }
                { voted: true, vote-block: burn-block-height })
        
        ;; Update vote count
        (map-set vault-guardians vault-id
                (merge guardians { votes: (+ (get votes guardians) u1) }))
        
        (ok true)))

(define-public (execute-recovery (vault-id uint) (new-owner principal))
    (let ((vault (unwrap! (map-get? vaults vault-id) err-vault-not-found))
          (guardians (unwrap! (map-get? vault-guardians vault-id) err-vault-not-found)))
        
        ;; Validations
        (asserts! (is-eq (some tx-sender) (get recovery-executor guardians)) err-unauthorized)
        (asserts! (>= (get votes guardians) guardian-threshold) err-unauthorized)
        (asserts! (> (get recovery-initiated guardians) u0) err-recovery-active)
        
        ;; Transfer ownership
        (map-set vaults vault-id (merge vault { owner: new-owner }))
        
        ;; Reset recovery state
        (map-set vault-guardians vault-id
                (merge guardians {
                    recovery-initiated: u0,
                    recovery-executor: none,
                    votes: u0
                }))
        
        (record-history vault-id u2 "recovery-executed" u0)
        
        (ok true)))

(define-public (withdraw (vault-id uint))
    (let ((vault (unwrap! (map-get? vaults vault-id) err-vault-not-found)))
        
        ;; Validations
        (asserts! (is-eq tx-sender (get owner vault)) err-unauthorized)
        (asserts! (get is-active vault) err-already-claimed)
        
        (let ((is-matured (>= burn-block-height (get locked-until vault)))
              (blocks-locked (- burn-block-height (get created-at vault)))
              (rewards (calculate-rewards (get amount vault) (get apy-rate vault) blocks-locked))
              (penalty (if is-matured u0 (/ (* (get amount vault) early-withdrawal-penalty) u10000)))
              (fee (/ (* rewards protocol-fee) u10000))
              (net-amount (if is-matured
                            (+ (get amount vault) (- rewards fee))
                            (- (get amount vault) penalty))))
            
            ;; Transfer funds
            (try! (as-contract (stx-transfer? net-amount tx-sender (get owner vault))))
            
            ;; Update vault
            (map-set vaults vault-id
                    (merge vault {
                        is-active: false,
                        rewards-claimed: rewards
                    }))
            
            ;; Update global stats
            (var-set total-locked (- (var-get total-locked) (get amount vault)))
            (var-set total-rewards-paid (+ (var-get total-rewards-paid) rewards))
            (var-set protocol-treasury (+ (var-get protocol-treasury) (+ fee penalty)))
            
            ;; Update user stats
            (match (map-get? user-stats tx-sender)
                stats (map-set user-stats tx-sender
                             (merge stats {
                                 total-withdrawn: (+ (get total-withdrawn stats) net-amount),
                                 total-rewards: (+ (get total-rewards stats) rewards)
                             }))
                true)
            
            (record-history vault-id u3 "withdrawn" net-amount)
            
            (ok { amount: net-amount, rewards: rewards, penalty: penalty }))))

(define-public (compound-rewards (vault-id uint))
    (let ((vault (unwrap! (map-get? vaults vault-id) err-vault-not-found)))
        
        ;; Validations
        (asserts! (is-eq tx-sender (get owner vault)) err-unauthorized)
        (asserts! (get is-active vault) err-already-claimed)
        (asserts! (get auto-compound vault) err-unauthorized)
        
        (let ((blocks-locked (- burn-block-height (get created-at vault)))
              (rewards (calculate-rewards (get amount vault) (get apy-rate vault) blocks-locked))
              (new-amount (+ (get amount vault) rewards)))
            
            ;; Update vault with compounded amount
            (map-set vaults vault-id
                    (merge vault {
                        amount: new-amount,
                        created-at: burn-block-height  ;; Reset reward calculation
                    }))
            
            ;; Update total locked
            (var-set total-locked (+ (var-get total-locked) rewards))
            
            (record-history vault-id u4 "compounded" rewards)
            
            (ok rewards))))

(define-public (extend-lock (vault-id uint) (additional-blocks uint))
    (let ((vault (unwrap! (map-get? vaults vault-id) err-vault-not-found)))
        
        ;; Validations
        (asserts! (is-eq tx-sender (get owner vault)) err-unauthorized)
        (asserts! (get is-active vault) err-already-claimed)
        (asserts! (> additional-blocks u0) err-invalid-duration)
        
        (let ((new-unlock (+ (get locked-until vault) additional-blocks))
              (new-duration (- new-unlock (get created-at vault)))
              (new-apy (calculate-apy (get amount vault) new-duration)))
            
            ;; Update vault
            (map-set vaults vault-id
                    (merge vault {
                        locked-until: new-unlock,
                        apy-rate: new-apy
                    }))
            
            (record-history vault-id u5 "extended" additional-blocks)
            
            (ok new-unlock))))

;; Admin Functions
(define-public (set-emergency-mode (enabled bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (var-set emergency-mode enabled)
        (ok enabled)))

(define-public (update-apy-multiplier (multiplier uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (asserts! (and (>= multiplier u5000) (<= multiplier u20000)) err-invalid-amount)
        (var-set global-apy-multiplier multiplier)
        (ok multiplier)))

(define-public (withdraw-treasury (amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (asserts! (<= amount (var-get protocol-treasury)) err-insufficient-balance)
        (var-set protocol-treasury (- (var-get protocol-treasury) amount))
        (as-contract (stx-transfer? amount tx-sender contract-owner))))